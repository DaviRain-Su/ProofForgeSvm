# 模块

| 模块 | 合同 |
|---|---|
| [Crypto](crypto.md) | 本机 SHA-256 / Keccak-256 |
| [Attr](attr.md) | `@[pf_entry]` 标记 |
| [IR](ir.md) | `Core.IR` 程序形状 + `Core.Target` 后端注册/投影 + SVM 物理布局 |
| [Profile](profile.md) | 传递闭包剖面 |
| [Ops](ops.md) | Expr 操作序列 |
| [Extract](extract.md) | Expr → IR + ops；任意用户项目 |
| [Phoenix](phoenix.md) | `Examples` 应用：双边 bounded N=4 与 Phoenix-v1 profile；只消费通用 SVM 组件 |
| [Svm](svm.md) | Ops → sBPF / IDL / locked sbpf |
| [Solanalib](solanalib.md) | Core/SVM target IR → bounded typed sBPF semantics |
| [SemanticsBridge](semantics-bridge.md) | Emit `.s` → sbpfSemantics parse/step（L3/E2 golden gate） |
| [Emit](emit.md) | `Svm.Emit`：抽出程序 → sBPF 文本 |
| [Assemble](assemble.md) | `Svm.Assemble`：`sbpf` 子进程 → `.so` + IDL |
| [Idl](idl.md) | `Svm.Idl`：Solana IDL spec 0.1.0 |
| [Cli](cli.md) | `pf build`（SVM） |
| [Runtime](runtime.md) | `Svm.Runtime` 宿主 stub；抽出按名认 |
| [Allocator bounds](allocator-bounds.md) | 账户内 allocator 仍有编译期容量 |
| [SDK mini-examples](sdk-mini-examples.md) | 非 Phoenix 的 Queue / Map / BitSet / Versioned 消费者 |
