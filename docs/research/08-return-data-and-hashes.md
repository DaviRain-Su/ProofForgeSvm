# Return Data 与 Runtime Hash Syscalls — 源码核实参考

> Date: 2026-09-03. 所有结论均来自 anza-xyz/agave 与 anza-xyz/solana-sdk 源码（本报告生成时 clone 的 master HEAD），逐条给出仓库路径。只读调研，不改动任何仓内文件。
> 结论服务于 ProofForgeSvm 的 Runtime / Sdk / EntryAdapter 切片设计（见 §5 有界策略提案）。

Sources:
- `anza-xyz/agave` @ master（syscalls crate 已从 `programs/bpf_loader/src/syscalls` 迁出为顶层 `syscalls/` crate）
- `anza-xyz/solana-sdk` @ master（`cpi` crate：`solana_cpi::{set_return_data, get_return_data, MAX_RETURN_DATA}`）

---

## 1. `sol_set_return_data` / `sol_get_return_data`

### 1.1 Syscall 签名（C ABI）

`agave/programs/sbf/c/inc/sol/return_data.h`（生成自 `platform-tools-sdk/sbf/c/inc/sol/inc/return_data.inc`）：

```c
#define MAX_RETURN_DATA 1024

void sol_set_return_data(const uint8_t *bytes, uint64_t bytes_len);
uint64_t sol_get_return_data(uint8_t *bytes, uint64_t bytes_len, SolPubkey *program_id);
```

- `sol_set_return_data`：无返回值；`bytes_len` 不得超 1024。
- `sol_get_return_data`：返回值是**返回数据的实际总长度**（可能超过 `bytes_len`，即调用者缓冲太小时仍返回真实长度）；`bytes`/`bytes_len` 是可选截断缓冲；`program_id` 仅在实际有返回数据（返回非 0）时被写入。

### 1.2 Runtime 实现（agave/syscalls/src/lib.rs）

注册：`syscalls/src/lib.rs:474-475` — 无 feature gate，所有版本可用：

```rust
SyscallSetReturnData::register(&mut result, "sol_set_return_data")?;
SyscallGetReturnData::register(&mut result, "sol_get_return_data")?;
```

**`SyscallSetReturnData`（lib.rs:1921-1960）**，签名 `(addr, len, _, _, _)`：
1. 计费：`len / cpi_bytes_per_unit + syscall_base_cost`（`cpi_bytes_per_unit = 250`，`syscall_base_cost = 100`，见 `program-runtime/src/execution_budget.rs:216/219`），`consume_checked` 失败即失败。
2. **`len > MAX_RETURN_DATA (1024)` → `SyscallError::ReturnDataTooLarge(len, 1024)`，整个指令失败**（fail-closed，不是截断）。
3. `len == 0` 合法（清空返回数据，等价 unset）。
4. 从 VM 内存 `translate_slice::<u8>` 拷出数据后调用 `TransactionContext::set_return_data(program_id, data)`，其中 `program_id` 取**当前正在执行的指令上下文的 program key**（lib.rs:1950-1957）。

**`SyscallGetReturnData`（lib.rs:1963-2010）**，签名 `(return_data_addr, length, program_id_addr, _, _)`：
1. 计费 `syscall_base_cost`（100 CU）+ 若拷贝：`(length + 32) / cpi_bytes_per_unit`。
2. 读 `(program_id, return_data) = TransactionContext::get_return_data()`。
3. `length = min(调用者给的 length, return_data.len())` —— **截断式拷贝，不报错**。
4. 把 `length` 字节写入 `return_data_addr`，32 字节 `Pubkey` 写入 `program_id_addr`（仅当 length ≠ 0）。
5. 返回**实际总长度**（不是拷贝长度）。返回 0 = 无返回数据。

### 1.3 存储：单一 per-transaction buffer + setter program id

`transaction-context/src/transaction.rs`：
- `TransactionFrame`（transaction.rs:38-42）持有 `return_data_pubkey: Pubkey`（"Pubkey of the last program to write to the return data scratchpad"）和 `return_data_scratchpad: VmSlice<u8>`（ABIv2 下与 guest 共享，地址 `RETURN_DATA_SCRATCHPAD = 7 * GUEST_REGION_SIZE`，`vm_addresses.rs:2`）。
- `TransactionContext::get_return_data()`（transaction.rs:496-501）：返回 `(&transaction_frame.return_data_pubkey, &return_data_bytes)` —— **return data 是 per-transaction 的单一全局 buffer，不是 per-stack-frame**。
- `set_return_data(program_id, data)`（transaction.rs:504-514）：直接覆盖 pubkey + bytes。

### 1.4 CPI 嵌套语义（关键）

- **CPI 前清空**：文档承诺 + 实测。`solana-sdk/cpi/src/lib.rs:350-371`（`get_return_data` doc）："Return data is cleared before every CPI invocation — a program that has invoked no other programs can expect the return data to be `None`; if no return data was set by the previous CPI invocation, then this function returns `None`." Runtime 侧对应清空发生在 callee 入口（builtin 路径见 `program-runtime/src/invoke_context.rs:672-674`，`process_executable_chain` 在执行 callee 前 `set_return_data(program_id, Vec::new())`）。
- **CPI 返回后不清空**：同一 doc："Return data is not cleared after returning from CPI invocations — a program that has called another program may retrieve return data that was not set by the called program, but instead set by a program further down the call stack"（递归调用同理）。即 caller 读到的可能是**更深一层 callee 的 callee** 设置的数据。
- **program-id 检查就是为此存在**：`get_return_data` 返回 setter 的 program id；SDK doc 明确要求调用者用 `Pubkey` 匹配期望的 callee program id 才能信任内容（"care must be taken to ensure that it represents what is expected"）。
- 谁可以 set：任何当前执行的程序（含 builtin，见上面 builtin 入口清空用法）；谁可以 get：任何程序（通常在 `sol_invoke_signed_*` 返回后立刻读）。
- 官方提案文档：`https://docs.solanalabs.com/proposals/return-data`（SDK doc 中链接 `rdp`）。

### 1.5 测试佐证

`agave/programs/sbf/c/src/return_data/return_data.c`：入口断言无数据（`sol_get_return_data(NULL, 0, NULL) == 0`），set 后子集读取/整读均返回真实长度。`agave/programs/sbf/c/src/invoked/invoked.c:17-18`：CPI callee 入口断言 "on entry, return data must not be set"。Rust 侧 `agave/program-test/tests/return_data.rs` 同主题。

---

## 2. Runtime Hash / Crypto Syscalls

### 2.1 通用 Hash syscall：`sol_sha256` / `sol_keccak256` / `sol_blake3`（+ feature-gated `sol_sha512`）

注册（`syscalls/src/lib.rs:382-404`）：`sol_sha256`、`sol_keccak256` 无 gate；`sol_blake3` gated on `blake3_syscall_enabled`（lib.rs:390-395）；`sol_sha512` gated on `enable_sha512_syscall`。

**统一实现 `SyscallHash<H>`（lib.rs:2720-2788）**：

```rust
fn rust(invoke_context, vals_addr: u64, vals_len: u64, result_addr: u64, _, _) -> Result<u64, Error>
```

C ABI（`programs/sbf/c/inc/sol/sha.h` / `keccak.h` / `blake3.inc`）：

```c
uint64_t sol_sha256(const SolBytes *vals, int vals_len, uint8_t *result);   // result: 32B
uint64_t sol_keccak256(const SolBytes *vals, int vals_len, uint8_t *result); // result: 32B
uint64_t sol_blake3(const SolBytes *vals, int vals_len, const uint8_t *result);
```

`SolBytes`（`programs/sbf/c/inc/sol/types.h:131-135`）：

```c
typedef struct {
  const uint8_t *addr;
  uint64_t len;
} SolBytes;
```

即 slices 参数是指向 `(addr, len)` 对数组（`VmSlice<u8>`，Rust 侧 `translate_slice::<VmSlice<u8>>`，lib.rs:2757）的指针 + 数量。语义：顺序把每个 slice 喂进同一个 hasher（concatenate-then-hash），写 32 字节 digest 到 `result_addr`，成功返回 0。

**限流**：
- **slices 上限**：`vals_len > compute_budget.sha256_max_slices` → `SyscallError::TooManySlices`（lib.rs:2737-2747）。默认 `sha256_max_slices = 20_000`（`program-runtime/src/execution_budget.rs:79`）。sha256/keccak256/blake3/sha512 **全部共用这个上限**（lib.rs:214/241/268/295 都返回 `sha256_max_slices`）。
- **成本**：`base_cost` + 每片 `max(mem_op_base_cost, byte_cost * (slice_len / 2))`（lib.rs:2762-2769）。默认 `sha256_base_cost = 85`，`sha256_byte_cost = 1`，`mem_op_base_cost = 10`（execution_budget.rs:213-214/231）。blake3/keccak 复用 sha256 的 base/byte 成本（lib.rs:208-217/235-244/262-271）。

### 2.2 `sol_secp256k1_recover`（lib.rs:920-993）

```c
uint64_t sol_secp256k1_recover(const uint8_t *hash,        // 32B keccak hash
                               uint64_t recovery_id,       // 0 或 1
                               const uint8_t *signature,   // 64B r||s
                               uint8_t *result);           // 64B pubkey (uncompressed, 无 0x04 前缀)
```

- 成本：固定 `secp256k1_recover_cost = 25_000` CU（execution_budget.rs:218）。
- 错误模型特殊：**翻译失败（非法指针）→ 指令失败；密码学失败 → 返回非 0 错误码**（`Secp256k1RecoverError::{InvalidHash, InvalidRecoveryId, InvalidSignature}`，Ok(1) 风格），VM 不断言。result 写 64 字节（`public_key[1..65]`）。

### 2.3 `sol_poseidon`（lib.rs:2455-2530；feature gate `enable_poseidon_syscall`）

```c
uint64_t sol_poseidon(const uint64_t parameters,   // POSEIDON_PARAMETERS_BN254_X5 = 0
                      const uint64_t endianness,   // 0 = big, 1 = little
                      const SolBytes *bytes, const uint64_t bytes_len,
                      uint8_t *result);            // 32B
```

- **slices 上限：`vals_len > 12` → `SyscallError::InvalidLength`**（lib.rs:2471-2477）。宽度 `2 <= t <= 13`，输入 `1 <= n <= 12`（`programs/sbf/c/inc/sol/poseidon.h` 注释）。注意不是题目说的"10"：**12**。
- 参数/endianness 非法 → `try_into` 失败 → `InvalidAttribute`。
- 成本：`poseidon_cost(n) = 61*n² + 542` CU（`poseidon_cost_coefficient_a = 61`, `poseidon_cost_coefficient_c = 542`，execution_budget.rs:242-243, 285-293；n=1→603, n=2→786, n=3→1091）。
- 哈希失败（如 input 不在域内）→ `Ok(1)`，不 panic。

### 2.4 `sol_curve25519` 系列（feature gate `curve25519_syscall_enabled`）

注册（lib.rs:409-428）：
- `sol_curve_validate_point` → `SyscallCurvePointValidation(curve_id, point_addr)`：验证点在曲线上。
- `sol_curve_group_op` → `SyscallCurveGroupOps(curve_id, op, left_addr, right_addr, result_addr)`。
- `sol_curve_multiscalar_mul` → `SyscallCurveMultiscalarMultiplication`。
- 另有 BLS12-381 gated 的 `sol_curve_decompress` / `sol_curve_pairing_map`（同名前缀，不同曲线 id）。

常量（`solana-sdk/curve25519/src/curve_syscall_traits.rs:80-85`）：

```rust
pub const CURVE25519_EDWARDS: u64 = 0;
pub const CURVE25519_RISTRETTO: u64 = 1;
pub const ADD: u64 = 0;   // group op
pub const SUB: u64 = 1;
pub const MUL: u64 = 2;
```

成本（execution_budget.rs Default，CU）：Edwards validate 159 / add 473 / sub 475 / mul 2_177；Ristretto validate 169 / add 521 / sub 519 / mul 2_208；MSM base 2_273 (ed) / 2_303 (ristretto)，incremental 758 / 788。运算失败（非法点等）→ `Ok(1)`；非法 curve_id/op → `InvalidAttribute`。

### 2.5 `sol_big_mod_exp`（feature gate `enable_big_mod_exp_syscall`；lib.rs:2381-2436）

```c
uint64_t sol_big_mod_exp(const uint8_t *params, uint8_t *result);
```

`params` 是序列化的 `BigModExpParams { base/base_len, exponent/exponent_len, modulus/modulus_len }`（SIMD-0529 布局）；结果 = `base^exp mod modulus`，写 `modulus_len` 字节。成本：`base_cost(422) + operation_complexity / divisor(189)`，complexity 由 operand 长度与调整后的指数位长决定（lib.rs:2339-2378；execution_budget.rs:156-162, 227-228）。

### 2.6 成本速查表（默认，CU）

| Syscall | 成本 |
|---|---|
| `sol_sha256` / `sol_keccak256` / `sol_blake3` | 85 + Σ max(10, len/2)；≤ 20_000 slices |
| `sol_sha512` (gated) | 同上 |
| `sol_poseidon` (gated) | 61n² + 542；≤ 12 slices |
| `sol_secp256k1_recover` | 25_000 固定 |
| `sol_curve_validate_point` (ed/rs) | 159 / 169 |
| `sol_curve_group_op` add/sub/mul | 473/475/2_177 (ed)；521/519/2_208 (rs) |
| `sol_curve_multiscalar_mul` | base + incremental × (n−1) |
| `sol_big_mod_exp` (gated) | 422 + complexity/189 |
| `sol_set_return_data` | 100 + len/250 |
| `sol_get_return_data` | 100 + (len+32)/250（len>0 时） |

（全部出自 `program-runtime/src/execution_budget.rs` Default impl 与 `syscalls/src/lib.rs` 计费代码；实际链上值可能随 feature 变化，编译器只做上界估算时用这些默认值。）

---

## 3. Rust SDK 暴露（`solana_cpi` / `solana_program`）

`solana-sdk/cpi/src/lib.rs`：

```rust
pub const MAX_RETURN_DATA: usize = 1024;                    // lib.rs:330

pub fn set_return_data(data: &[u8])                          // lib.rs:340
// → unsafe { sol_set_return_data(data.as_ptr(), data.len() as u64) }

pub fn get_return_data() -> Option<(Pubkey, Vec<u8>)>        // lib.rs:376
```

`get_return_data` 实现（lib.rs:377-402）：栈上分配 `[0u8; MAX_RETURN_DATA]`（1024B）+ `Pubkey::default()`，调 syscall，`size == 0 → None`，否则 `min(size, MAX_RETURN_DATA)` 截断后 `Some((program_id, buf[..size].to_vec()))`。

re-export：`solana_program::program::{set_return_data, get_return_data}`（`program/src/program.rs:103/117`，转发到 `solana_cpi`）。更新版 `solana_instruction_view::cpi::{set_return_data, get_return_data} -> Option<ReturnData>`（`instruction-view/src/cpi.rs:708/748`）。

关键文档承诺（cpi/src/lib.rs:337-374 doc 原文要点）：
- return data 是 **per-transaction 全局资源**，最多 1024 字节，配一个"最近 setter"的 Pubkey；
- 只有**最近一次设置**可见（"the program ID of the program that most recently set the return data"）；
- CPI 前清空、CPI 返回后不清空（见 §1.4）；
- caller 必须自己核对 program id 再消费。

---

## 4. 与 ProofForgeSvm 现状的衔接

现有 `ProofForge/Svm/Runtime.lean:1042-1060` 已有 `sha256Lit` / `keccak256Lit`：仅编译期 ASCII 字面量、返回 digest 首个 u64；"完整 32B / 多切片 / 运行时缓冲 / blake3 / poseidon 本剖面 fail closed"。本报告 §1–§3 即为后续切片（完整 digest、多 slice、运行时缓冲、return data、poseidon）提供边界事实。

---

## 5. 建议的 bounded policy（编译器自有 SVM SDK）

与 ProofForge 风格一致：编译期容量、fail-closed、无分配。按层划分：

### 5.1 容量（compile-time `Nat` 常量，模式同 `Memo.maxBytes`）

```lean
namespace ProofForge.Svm.Sdk.ReturnData
def maxBytes : Nat := 1024          -- 链上硬限 MAX_RETURN_DATA
end ProofForge.Svm.Sdk.ReturnData

namespace ProofForge.Svm.Sdk.Hash
def maxSlices : Nat := 20000        -- sha256_max_slices 默认；SDK 可收紧
def poseidonMaxInputs : Nat := 12   -- sol_poseidon 硬限
def digestBytes : Nat := 32
def secpRecoveryIds : Nat := 2      -- recovery_id ∈ {0,1}
end ProofForge.Svm.Sdk.Hash
```

要点：
- **Return data buffer = 1024，编译期钉死**；Sdk 层 set 前做 `len ≤ maxBytes` 静态/边界检查，超限**编译拒绝或 fail-closed**，绝不静默截断（runtime 对 set 是硬错误 `ReturnDataTooLarge`，语义必须对齐）。get 侧 runtime 是截断式，SDK 读取缓冲按 1024 预留即可。
- **多 slice hash**：slice 数上限编译期常量（默认 ≤ 20_000，但 SDK 建议 profile 收紧到小常数如 ≤ 8）；slice 内容允许运行时缓冲，但每片长度需 bounded（对齐 CU 模型 `len/2`）。
- **Poseidon**：inputs ≤ 12 为硬限，SDK 类型层面用 `Fin 13` / `Nat` 断言；parameters/endianness 仅枚举两个常量（BN254-X5, big/little），其余 fail closed。

### 5.2 错误词表（fail-closed，模式同 `Cpi.TokenTlv.Reason`/`Verdict`）

```lean
inductive ReturnDataReason where
  | tooLarge (len : Nat)            -- set 超 1024（对齐 ReturnDataTooLarge）
  | programIdMismatch (expected got : Nat)  -- get 后 setter ≠ 期望 callee
  | empty                            -- get 返回 None 的显式化
  | unsupportedProfile               -- 本剖面未支持（如 sBPFv3 直调指针）

inductive HashReason where
  | tooManySlices (n limit : Nat)    -- 对齐 TooManySlices
  | sliceTooLarge                    -- profile 收紧后的单片上限
  | invalidPoseidonInputs (n : Nat)  -- n > 12
  | invalidPoseidonParams            -- 非法 parameters/endianness
  | cryptoFailure                    -- secp256k1/poseidon/curve 的 Ok(1) 路径
  | unsupportedSyscall               -- blake3/sha512/big_mod_exp 等未入剖面
```

约定：**crypto-fail（Ok(1)）与 VM-fail（翻译错误）分开**——前者是可恢复的 `HashReason.cryptoFailure`（对应 secp256k1_recover 的设计意图），后者是 fail-closed 的 unsupported/profile 错误。

### 5.3 检查位置

- **Runtime（`ProofForge/Svm/Runtime.lean`）**：syscall 边界的纯语义——set 的 1024 硬限、get 的截断语义、hash 的 slices 上限、poseidon 12 输入。Runtime 只报 `Reason`，不做策略判断。
- **Sdk（`ProofForge/Svm/Sdk/*.lean`）**：策略与 API 形状——`ReturnData.get (expected : Pubkey)` 形式的门面把 **program-id 检查放在 SDK 内部**（get 后立即比对 setter，mismatch → `programIdMismatch`），因为"读到更深 callee 的数据"是运行时常态，靠调用者手查必然遗漏；`set` 提供静态容量证明（接受 `ByteArray` + 编译期长度证明或运行时 fail-closed 检查）。hash facade 只接受 `Fin maxSlices` 内的 slice 向量。
- **EntryAdapter / Emit**：不做数据面检查，只保证 syscall 编号/寄存器布局（§1.1/§2 签名）与 ABI 一致，以及在 sBPFv3 直调变体下选择正确的 stub 形态。
- **CPI 联动**：CPI 发射后立刻可见的 return-data 窗口由 Sdk 的 Cpi 模型承载（invoke → get_return_data → program-id 核对，一次性消费）；不得跨 CPI 复用旧数据（链上语义：每次 CPI 前清空）。

### 5.3 验证路径

- Lean build：容量/错误词表的 well-formed 定理（如 `len ≤ maxBytes → set 不报 tooLarge`）。
- Mollusk（`runtime-tests/solana`）：return_data set/get/program-id/CPI 清空行为对照 `agave/programs/sbf/c/src/{return_data,invoked}` 测试语义；sha256/keccak 多 slice 与 `agave/programs/sbf/tests` 对齐。
- Surfpool：仅当切片暴露外部可见行为（return data 通过 RPC `TransactionExecutionDetails::return_data` 可见，`svm/src/transaction_processor.rs:1238-1251`）时部署验证。
