export type TargetId = "svm";

export type Example = {
  id: string;
  name: string;
  targets: TargetId[];
  tags: { zh: string; en: string }[];
  summary: { zh: string; en: string };
  lean: string;
  theorems: { name: string; claim: { zh: string; en: string } }[];
  svm?: { asm: string; idl: string };
};

export const EXAMPLES: Example[] = [
  {
    id: "Counter",
    name: "Counter",
    targets: ["svm"],
    tags: [
      { zh: "竖切", en: "vertical slice" },
      { zh: "checked 算术", en: "checked arithmetic" },
    ],
    summary: {
      zh: "单账户 UInt64。init / get / increment。溢出 fail-closed，不回绕。",
      en: "Single-account UInt64. init / get / increment. Overflow is fail-closed — no wrap.",
    },
    lean: `import ProofForge.Attr
import ProofForge.Svm.Sdk

namespace MyProgram.Counter

structure State where
  value : UInt64

inductive Error where
  | overflow

@[pf_entry]
def init (initial : UInt64) : State :=
  { value := initial }

@[pf_entry]
def get (s : State) : UInt64 :=
  s.value

@[pf_entry]
def increment (s : State) (delta : UInt64) :
    Except Error (State × UInt64) :=
  if s.value ≤ u64Max - delta then
    let next := s.value + delta
    .ok ({ value := next }, next)
  else
    .error .overflow
`,
    theorems: [
      {
        name: "increment_ok",
        claim: {
          zh: "成功路径：新值恰为 s.value + d，返回值等于新状态。",
          en: "On success, the new value is exactly s.value + d and the return matches.",
        },
      },
      {
        name: "increment_ok_bound",
        claim: {
          zh: "成功路径单调：guard 保证不回绕，值不减。",
          en: "Success is monotonic: the guard forbids wraparound.",
        },
      },
      {
        name: "increment_overflow_not_ok",
        claim: {
          zh: "溢出分支与成功分支互斥。",
          en: "The overflow branch is exclusive of success.",
        },
      },
    ],
    svm: {
      asm: `; Counter — Loader V3 entry (excerpt)
.globl entrypoint
entrypoint:
  ldxdw r6, [r1+0]          ; num accounts
  ; packed wire → EntryAdapter
  call pf_entry_decode
  jeq  r0, 0, ix_init
  jeq  r0, 1, ix_increment
  jeq  r0, 2, ix_get
  lddw r0, 1                ; unknown ix
  exit

ix_increment:
  ldxdw r2, [r8+0]          ; state.value
  ldxdw r3, [r9+0]          ; delta
  ; checked add: fail closed on overflow
  mov64 r4, r2
  add64 r4, r3
  jlt  r4, r2, err_overflow
  stxdw [r8+0], r4
  mov64 r0, 0
  exit

err_overflow:
  lddw r0, 0x1001
  exit`,
      idl: `{
  "spec": "solana-idl-0.1.0",
  "name": "Counter",
  "instructions": [
    { "name": "init", "args": [{ "name": "initial", "type": "u64" }] },
    { "name": "increment", "args": [{ "name": "delta", "type": "u64" }] },
    { "name": "get", "args": [], "returns": "u64" }
  ]
}`,
    },
  },
  {
    id: "Book",
    name: "Book",
    targets: ["svm"],
    tags: [
      { zh: "有界向量", en: "bounded vector" },
      { zh: "indexSet", en: "indexSet" },
    ],
    summary: {
      zh: "固定 4 档 UInt64。钉 indexGet / indexSet / 有界 for。越界 fail-closed。",
      en: "Fixed 4-cell UInt64 vector. Pins indexGet / indexSet / bounded for. OOB is fail-closed.",
    },
    lean: `namespace Examples.Svm.Book

structure State where
  cells : Vector UInt64 4

@[pf_entry]
def init (first : UInt64) : State :=
  { cells := #v[first, 0, 0, 0] }

@[pf_entry]
def setAt (s : State) (i v : UInt64) :
    Except Error (State × UInt64) :=
  if h : i.toNat < 4 then
    .ok ({ cells := s.cells.set i.toNat v }, v)
  else
    .error .overflow
`,
    theorems: [
      {
        name: "setAt_oob",
        claim: {
          zh: "下标 ≥ 4 时 overflow，不写任何格。",
          en: "Index ≥ 4 is overflow; no cell is written.",
        },
      },
    ],
    svm: {
      asm: `; Book setAt — in-bound short-forward jump
  jlt  r2, r3, ok_set
  lddw r0, 0x1              ; Custom(1)
  exit
ok_set:
  ; stxdw into account data at stride * i
  exit`,
      idl: `{ "name": "Book", "instructions": [
  { "name": "setAt", "args": [
    { "name": "i", "type": "u64" },
    { "name": "v", "type": "u64" }
  ]}
]}`,
    },
  },
  {
    id: "Memo",
    name: "Memo",
    targets: ["svm"],
    tags: [{ zh: "CPI", en: "CPI" }, { zh: "Memo v3", en: "Memo v3" }],
    summary: {
      zh: "封闭 Memo CPI。payload 是编译期 ASCII「ok」，不是 runtime String。",
      en: "Closed Memo CPI. Payload is compile-time ASCII \"ok\", not a runtime String.",
    },
    lean: `namespace Examples.Svm.Memo

@[pf_entry]
def write (_s : State) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Memo.Ascii.write "ok"
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow
`,
    theorems: [
      {
        name: "write_is_effect",
        claim: {
          zh: "抽出保留 Memo CPI；缺 signer → Custom(1)。",
          en: "Extract keeps the Memo CPI; missing signer → Custom(1).",
        },
      },
    ],
    svm: {
      asm: `; Memo.Ascii.write "ok"
  ; invoke programIx=Memo metas data="ok"
  call sol_invoke_signed_c`,
      idl: `{ "name": "Memo", "instructions": [{ "name": "write", "args": [] }] }`,
    },
  },
  {
    id: "Transfer",
    name: "Transfer",
    targets: ["svm"],
    tags: [{ zh: "System", en: "System" }, { zh: "lamports", en: "lamports" }],
    summary: {
      zh: "封闭 system.transfer。账户表由 invoke 钉死，不进 Lean 参数。",
      en: "Closed system.transfer. The account table is pinned by invoke — not a Lean parameter.",
    },
    lean: `namespace Examples.Svm.Transfer

@[pf_entry]
def transfer (_s : State) (lamports : UInt64) :
    Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.System.transfer lamports
    .ok ({ dummy := 0 }, lamports)
  else
    .error .overflow
`,
    theorems: [
      {
        name: "transfer_returns_lamports",
        claim: {
          zh: "成功路径返回传入的 lamports。",
          en: "On success the return equals the given lamports.",
        },
      },
    ],
    svm: {
      asm: `; system.transfer — program=2, metas two slots
  ; data = u32le(2) || u64le(lamports)
  call sol_invoke_signed_c`,
      idl: `{ "name": "Transfer", "instructions": [
  { "name": "transfer", "args": [{ "name": "lamports", "type": "u64" }] }
]}`,
    },
  },
  {
    id: "TokenXfer",
    name: "TokenXfer",
    targets: ["svm"],
    tags: [{ zh: "SPL Token", en: "SPL Token" }, { zh: "TransferChecked", en: "TransferChecked" }],
    summary: {
      zh: "Token TransferChecked；decimals 钉死为 6。不是完整 Token-2022 extension。",
      en: "Token TransferChecked with decimals pinned to 6. Not a full Token-2022 extension suite.",
    },
    lean: `namespace Examples.Svm.TokenXfer

@[pf_entry]
def send (_s : State) (amount : UInt64) :
    Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token.transferChecked amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow
`,
    theorems: [
      {
        name: "send_returns_amount",
        claim: {
          zh: "成功路径返回传入的 amount。",
          en: "On success the return equals the given amount.",
        },
      },
    ],
    svm: {
      asm: `; Token.transferChecked amount decimals=6
  call sol_invoke_signed_c`,
      idl: `{ "name": "TokenXfer", "instructions": [
  { "name": "send", "args": [{ "name": "amount", "type": "u64" }] }
]}`,
    },
  },
  {
    id: "Phoenix",
    name: "PhoenixV1",
    targets: ["svm"],
    tags: [
      { zh: "订单簿", en: "order book" },
      { zh: "账户驻留", en: "account-resident" },
    ],
    summary: {
      zh: "Phoenix-v1 profile。128-seat trader tree、双 512-node book。持久结构只住在账户 bytes 里。",
      en: "Phoenix-v1 profile. 128-seat trader tree, dual 512-node books. Persistent structure lives in account bytes only.",
    },
    lean: `namespace Examples.Svm.PhoenixV1Profile

-- Persistent trees are account-resident.
-- Slot 0 is sentinel; no heap Map, no copied tree.

@[pf_entry]
def reduceOrderWithFreeFunds
    (m : Market) (trader : Seat) (side : Side) (qty : Lots) :
    Except Error (Market × Fill) :=
  -- bounded Sokoban insert/remove on the book
  AccountStorage.call m.book (.reduce trader side qty)
`,
    theorems: [
      {
        name: "no_heap_in_account",
        claim: {
          zh: "账户 bytes 不保存 heap 指针。",
          en: "Account bytes never store a heap pointer.",
        },
      },
    ],
    svm: {
      asm: `; Phoenix tag 6/7 FifoCancel — component-owned
  call pf_component_query        ; trader/bid/ask validator
  call pf_fifo_cancel            ; bids → asks, in-place
  ; owner filter, collateral unlock, event index
  ; stay inside the component; no Ops/IR leak`,
      idl: `{ "name": "PhoenixV1Profile", "notes": "Loader-v3 + Surfpool; not solana-test-validator" }`,
    },
  },
];

export function exampleById(id: string): Example | undefined {
  return EXAMPLES.find((e) => e.id === id);
}
