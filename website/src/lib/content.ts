import type { Lang } from "@/lib/i18n";

export const REPO = "https://github.com/DaviRain-Su/ProofForgeSvm";

export const NAV = [
  { href: "/", zh: "概览", en: "Overview" },
  { href: "/docs", zh: "文档", en: "Docs" },
  { href: "/examples", zh: "示例", en: "Examples" },
  { href: "/cli", zh: "CLI", en: "CLI" },
] as const;

export const HERO = {
  kicker: { zh: "Lean 4 编译剖面", en: "Lean 4 compiler profile" },
  title: { zh: "普通 Lean。链上字节。", en: "Ordinary Lean. On-chain bytes." },
  lead: {
    zh: "不是一门新合约语言。普通 def 写合约，普通 theorem 证合约。同一主语抽出到 Solana sBPF；由钉死的 sbpf 汇编 .so / IDL。",
    en: "Not a new contract language. Write programs as defs, prove them as theorems. One subject lowers to Solana sBPF; pinned sbpf assembles .so / IDL.",
  },
};

export const PIPELINE = [
  {
    id: "lean",
    zh: "普通 Lean",
    en: "Ordinary Lean",
    detail: {
      zh: "def / theorem / structure。入口用 @[pf_entry] 标记。没有 program … where。",
      en: "def / theorem / structure. Mark entries with @[pf_entry]. No program … where.",
    },
  },
  {
    id: "profile",
    zh: "Profile",
    en: "Profile",
    detail: {
      zh: "传递闭包准入。拒绝 IO、partial、sorry、@[extern]、无界递归。Fail-closed。",
      en: "Transitive-closure admission. Rejects IO, partial, sorry, @[extern], unbounded recursion. Fail-closed.",
    },
  },
  {
    id: "extract",
    zh: "Extract",
    en: "Extract",
    detail: {
      zh: "Expr → typed Core + target-neutral Ops。示例 digest 由 Registry 钉住；用户模块每次重新抽出。",
      en: "Expr → typed Core + target-neutral Ops. Example digests are pinned by the registry; user modules re-extract every build.",
    },
  },
  {
    id: "split",
    zh: "SVM IR",
    en: "SVM IR",
    detail: {
      zh: "Core 降到 SVM IR。物化账户几何 / CPI / IDL。Registry 钉示例 digest。",
      en: "Core lowers to SVM IR. Owns account geometry / CPI / IDL. The registry pins example digests.",
    },
  },
  {
    id: "emit",
    zh: "sBPF → .so",
    en: "sBPF → .so",
    detail: {
      zh: "Emit 出 .s。钉死的 sbpf 0.2.2 汇编 .so / .s / .idl.json。工程门：Mollusk / Surfpool。",
      en: "Emit writes .s. Pinned sbpf 0.2.2 assembles .so / .s / .idl.json. Engineering gates: Mollusk / Surfpool.",
    },
  },
];

export const PILLARS = [
  {
    title: { zh: "同一主语", en: "One subject" },
    body: {
      zh: "定理钉在用户 def 上，编译走同一抽出 IR。禁止「证的是 A，编的是 B」。",
      en: "Theorems pin the user def; compile walks the same extracted IR. No proving A while emitting B.",
    },
  },
  {
    title: { zh: "Fail-closed 子集", en: "Fail-closed subset" },
    body: {
      zh: "能降到链上的才过 Profile。过不了的不是警告，是拒绝。",
      en: "Only what can lower on-chain passes Profile. Failures are refusals, not warnings.",
    },
  },
  {
    title: { zh: "一条 Core，一个产品后端", en: "One Core, one product backend" },
    body: {
      zh: "Lean / Profile / Extract / CFG / SVM IR 共享一条链。产品承诺钉在 locked sbpf。",
      en: "Lean / Profile / Extract / CFG / SVM IR share one chain. The product promise is pinned to locked sbpf.",
    },
  },
  {
    title: { zh: "诚实的信任边界", en: "Honest trust boundary" },
    body: {
      zh: "Kernel 接受的是关于 def 的定理。不声称 extracted IR / .so / loader / 公网部署已被证明。",
      en: "The kernel accepts theorems about the def. That is not a claim that extracted IR / .so / the loader / mainnet deployment are proved.",
    },
  },
];

export const TARGETS = [
  {
    id: "svm" as const,
    name: "Solana",
    kicker: { zh: "sBPF / Loader V3", en: "sBPF / Loader V3" },
    artifacts: [".so", ".s", ".idl.json"],
    points: {
      zh: [
        "Lean → Extract IR → SVM IR → .s → 钉死的 sbpf 0.2.2",
        "pf build 写出 Name.so / Name.s / Name.idl.json",
        "EntryAdapter 统一 packed wire 与账户合同",
        "Mollusk + Surfpool 工程门；v0 拒绝公网 broadcast",
      ],
      en: [
        "Lean → Extract IR → SVM IR → .s → pinned sbpf 0.2.2",
        "pf build writes Name.so / Name.s / Name.idl.json",
        "EntryAdapter owns packed wire and the account contract",
        "Mollusk + Surfpool engineering gates; v0 refuses public broadcast",
      ],
    },
  },
  {
    id: "phoenix" as const,
    name: "Phoenix-v1",
    kicker: { zh: "最大的 SVM 切片", en: "largest SVM slice" },
    artifacts: [".so", ".s", ".idl.json"],
    points: {
      zh: [
        "128-seat trader tree 与双 512-node book 住在账户 bytes",
        "官方 tag 3–14 走同一 component 边界，不是编译器特判",
        "Heap 只作 invocation-local bump，指针不进账户",
        "Phoenix 走 phoenix CI 车道；V1 Surfpool 仅 nightly",
      ],
      en: [
        "128-seat trader tree and dual 512-node books live in account bytes",
        "Official tags 3–14 share the component boundary — not a compiler special case",
        "Heap is invocation-local bump only — never in accounts",
        "Phoenix runs on the phoenix CI lane; V1 Surfpool is nightly-only",
      ],
    },
  },
];

export const TRUST = {
  title: { zh: "信任边界", en: "Trust boundary" },
  weak: {
    zh: "弱声明：kernel 接受了关于用户 def / 抽出 IR 的定理。TCB = Lean kernel + 主语绑定。这不等于 IR / .s / ELF 精化。",
    en: "Weak claim: the kernel accepted theorems about the user def / extracted IR. TCB = Lean kernel + subject binding. That is not IR / .s / ELF refinement.",
  },
  eng: {
    zh: "工程声明：同一 IR 经发射器 + 钉死的 sbpf，在 Mollusk 或 Surfpool 上与夹具一致。",
    en: "Engineering claim: the same IR, through the emitter and pinned sbpf, matches fixtures on Mollusk or Surfpool.",
  },
  not: {
    zh: "不做的声明：.so / loader / 全 SVM 语义精化 / 定理 ⇒ 已部署程序。",
    en: "Not claimed: .so / loader / full SVM refinement / theorem ⇒ deployed program.",
  },
};

export const TOOLCHAIN = [
  { name: "Lean 4", value: "v4.31.0" },
  { name: "sbpf", value: "0.2.2" },
  { name: "Surfpool", value: "1.5.0" },
  { name: "CLI", value: "pf" },
];

export const COMMANDS = [
  {
    title: { zh: "构建编译器与 CLI", en: "Build compiler + CLI" },
    cmd: "lake build && lake build pf",
  },
  {
    title: { zh: "编译 SVM 程序", en: "Compile an SVM program" },
    cmd: "lake exe pf -- build --out build/sbpf Counter",
    note: {
      zh: "写出 Counter.so / Counter.s / Counter.idl.json",
      en: "Writes Counter.so / Counter.s / Counter.idl.json",
    },
  },
  {
    title: { zh: "Mollusk 工程门", en: "Mollusk engineering gate" },
    cmd: "cd runtime-tests/solana && PF_COUNTER_SO=../../build/sbpf/Counter.so cargo test --locked --test counter",
  },
  {
    title: { zh: "Surfpool Loader-v3", en: "Surfpool Loader-v3" },
    cmd: "runtime-tests/surfpool/smoke.sh RawEntry",
  },
  {
    title: { zh: "用户项目（checkout 内）", en: "User project (from checkout)" },
    cmd: "lake exe pf -- init demo && cd demo && lake build && ../.lake/build/bin/pf build",
    note: {
      zh: "模板在 templates/svm-counter。当前 init 依赖仓库 checkout；尚无独立安装包。",
      en: "Template is templates/svm-counter. init currently requires a repo checkout; there is no standalone installer yet.",
    },
  },
];

export const DOC_SECTIONS = [
  { id: "start", zh: "开始", en: "Start" },
  { id: "surface", zh: "语言表面", en: "Surface" },
  { id: "pipeline", zh: "编译链", en: "Pipeline" },
  { id: "sdk", zh: "SDK", en: "SDK" },
  { id: "svm", zh: "SVM", en: "SVM" },
  { id: "proofs", zh: "证明", en: "Proofs" },
  { id: "trust", zh: "信任", en: "Trust" },
  { id: "limits", zh: "边界", en: "Limits" },
] as const;

export type DocId = (typeof DOC_SECTIONS)[number]["id"];

export const DOCS: Record<
  DocId,
  { zh: { title: string; blocks: string[] }; en: { title: string; blocks: string[] } }
> = {
  start: {
    zh: {
      title: "开始",
      blocks: [
        "ProofForge SVM 是 Lean 4 的编译剖面，不是 DSL。克隆仓库，用 Lake 构建，用 pf 编程序。",
        "Toolchain 钉死：leanprover/lean4:v4.31.0、sbpf 0.2.2@d835bc6、Surfpool 1.5.0。不要用 PATH 里随便一个汇编器顶替锁版本。",
        "可复制路径（在仓库根）：lake build pf && lake exe pf -- init demo && cd demo && lake build && ../.lake/build/bin/pf build。",
        "产品能力矩阵与写合约指南见 docs/product/。模块内部说明见 docs/modules/。",
      ],
    },
    en: {
      title: "Start",
      blocks: [
        "ProofForge SVM is a Lean 4 compiler profile, not a DSL. Clone the repo, build with Lake, compile with pf.",
        "Toolchain is pinned: leanprover/lean4:v4.31.0, sbpf 0.2.2@d835bc6, Surfpool 1.5.0. Do not substitute a PATH assembler for the lock.",
        "Reproducible path (repo root): lake build pf && lake exe pf -- init demo && cd demo && lake build && ../.lake/build/bin/pf build.",
        "See docs/product/ for the support matrix and writing guide. See docs/modules/ for internal module notes.",
      ],
    },
  },
  surface: {
    zh: {
      title: "语言表面",
      blocks: [
        "用户写的是普通 Lean。没有 program … where。入口用 @[pf_entry]；内联用 @[pf_inline]。",
        "Profile 检查传递闭包：IO、partial、sorry、@[extern]、@[implemented_by]、无界递归一律拒绝。",
        "抽出权威是 elaborated Expr 闭包，不是 Lean.Compiler.IR。业务类型检查仍由 Lean 完成。",
        "部分 CPI 夹具仍用 dummy 字段和假守卫让抽出器看见效应。这是已知产品债，不是推荐写法的终点。",
      ],
    },
    en: {
      title: "Surface",
      blocks: [
        "Users write ordinary Lean. There is no program … where. Mark entries @[pf_entry]; inline with @[pf_inline].",
        "Profile checks the transitive closure: IO, partial, sorry, @[extern], @[implemented_by], unbounded recursion are refused.",
        "Extract authority is the elaborated Expr closure, not Lean.Compiler.IR. Lean still owns business typing.",
        "Some CPI fixtures still use a dummy field and a fake guard so Extract sees the effect. That is known product debt, not the end state.",
      ],
    },
  },
  pipeline: {
    zh: {
      title: "编译链",
      blocks: [
        "Profile → Extract.IR / Core → Svm.IR → sBPF Emit → Assemble（locked sbpf）。Core 拥有 schema、control、checked arithmetic。",
        "CLI 构建必须重新从用户模块抽 IR，不能组装 legacy Golden fixture。Registry 只钉仓内 Examples digest。",
        "详细边界见 docs/product/support-matrix.md。",
      ],
    },
    en: {
      title: "Pipeline",
      blocks: [
        "Profile → Extract.IR / Core → Svm.IR → sBPF Emit → Assemble (locked sbpf). Core owns schema, control, checked arithmetic.",
        "CLI build re-extracts IR from the user module. It does not assemble a legacy Golden fixture. The registry pins in-tree Examples digests only.",
        "See docs/product/support-matrix.md for the detailed boundary.",
      ],
    },
  },
  sdk: {
    zh: {
      title: "SDK",
      blocks: [
        "ProofForge.Svm.Sdk 是程序源表面：账户、CPI、Token、sysvar、PDA、有界 storage。",
        "用户项目只 import ProofForge.Attr 与 ProofForge.Svm.Sdk，不碰 ProofForge 伞模块。SDK 传递闭包不得到达 Emit / Assemble / Registry。",
        "持久容器是账户 bytes 上的固定容量 POD，不是 heap Map。Token 是 classic SPL / Token-2022 base-layout，不是完整 extension 套件。",
      ],
    },
    en: {
      title: "SDK",
      blocks: [
        "ProofForge.Svm.Sdk is the program-facing surface: accounts, CPI, Token, sysvar, PDA, bounded storage.",
        "User projects import only ProofForge.Attr and ProofForge.Svm.Sdk — never the ProofForge umbrella. The SDK closure must not reach Emit / Assemble / Registry.",
        "Persistent containers are fixed-capacity POD views on account bytes, not heap Maps. Token is classic SPL / Token-2022 base-layout, not a full extension suite.",
      ],
    },
  },
  svm: {
    zh: {
      title: "SVM",
      blocks: [
        "SVM 是本仓库的唯一目标。普通 Lean、Profile、Extract 和 Core CFG 降到 SVM IR，再发射 sBPF。",
        "Svm.EntryAdapter 拥有 packed wire、raw/generated dispatch、账户前缀。AccountStorage 拥有账户内 Region/Field 与 bounded Query/Call。",
        "Heap 是 32 KiB（可到 256 KiB）向下 bump；dealloc 不回收；指针不进账户。Phoenix-v1 是这条边界的压力测试。",
      ],
    },
    en: {
      title: "SVM",
      blocks: [
        "SVM is the only target in this repository. Ordinary Lean, Profile, Extract, and Core CFG lower to SVM IR, then emit sBPF.",
        "Svm.EntryAdapter owns packed wire, raw/generated dispatch, and the account prefix. AccountStorage owns in-account Region/Field and bounded Query/Call.",
        "Heap is a 32 KiB (up to 256 KiB) downward bump; dealloc does not reclaim; pointers never enter accounts. Phoenix-v1 is the stress test of that boundary.",
      ],
    },
  },
  proofs: {
    zh: {
      title: "证明",
      blocks: [
        "第一批 kernel-checked 性质落在合约文件的 Proofs 节：成功路径后置条件、单调性。",
        "只依赖标准公理 propext / Quot.sound。CI 由 scripts/check_no_sorry.py 保证证明批次不含占位符。",
        "Solanalib L3 桥另用 native_decide 做具体检查，可信基因此更宽。当前定理钉的是用户 def / 静态字段，不是 .so 精化。",
      ],
    },
    en: {
      title: "Proofs",
      blocks: [
        "The first kernel-checked properties live in each program file's Proofs section: success postconditions, monotonicity.",
        "They depend only on the standard axioms propext / Quot.sound. CI (scripts/check_no_sorry.py) refuses placeholders in the proof batch.",
        "The Solanalib L3 bridge additionally uses native_decide, so its trust base is wider. Today's theorems pin the user def / static fields — not .so refinement.",
      ],
    },
  },
  trust: {
    zh: {
      title: "信任",
      blocks: [
        "弱声明（对外 v0）：kernel 接受了关于用户 def / 抽出 IR 的定理。TCB = Lean kernel + 主语绑定。",
        "工程声明：同一 IR 经 PF 发射器 + pinned sbpf 得到的 .so，在 pinned Mollusk / Surfpool 上行为与夹具一致。",
        "不做的声明：.so / loader / 全 SVM refinement；定理不蕴含公网部署正确。",
      ],
    },
    en: {
      title: "Trust",
      blocks: [
        "Weak claim (v0 public): the kernel accepted theorems about the user def / extracted IR. TCB = Lean kernel + subject binding.",
        "Engineering claim: the .so from that IR through the PF emitter + pinned sbpf matches fixtures on pinned Mollusk / Surfpool.",
        "Not claimed: .so / loader / full SVM refinement. A theorem does not imply a correct public deployment.",
      ],
    },
  },
  limits: {
    zh: {
      title: "边界",
      blocks: [
        "CLI 表面只有 pf build / pf init / pf --version。没有 doctor / install / artifacts / local / deploy / call，也没有本仓 MCP server。",
        "pf init 目前必须在仓库 checkout 根附近运行，并改写 path-require；离开 checkout 的独立安装包尚未发布。",
        "明确不做：动态 remaining accounts、无界循环、主网部署声明、ELF/loader refinement。",
        "官网 Forge 面板里的 .s / IDL 摘录是示意形状，不是每次构建的实时产物。",
      ],
    },
    en: {
      title: "Limits",
      blocks: [
        "The CLI surface is pf build / pf init / pf --version only. There is no doctor / install / artifacts / local / deploy / call, and no in-repo MCP server.",
        "pf init currently must run from a repo checkout and rewrites a path-require; a standalone installer outside the checkout is not published yet.",
        "Explicitly out of scope: dynamic remaining accounts, unbounded loops, mainnet deployment claims, ELF/loader refinement.",
        "Assembly/IDL excerpts in the website Forge panel are illustrative shapes, not live build artifacts.",
      ],
    },
  },
};

export function copy(lang: Lang, rec: { zh: string; en: string }): string {
  return rec[lang];
}
