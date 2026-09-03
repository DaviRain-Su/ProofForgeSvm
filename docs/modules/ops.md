# ProofForge.Core.Ops / Extract.Ops / Svm.Ops

## Purpose

抽出器与 backend 共享一套可扩展操作树。公共构造子在 `ProofForge.Core.Ops`；
抽出器方言是 `Extract.IR.ValKind` / `OpExt`；SVM 叶子和效应在
`Svm.Ops.ValKind` / `OpExt`。

`ProofForge/Extract/LegacyOps.lean` 暂时保留 `ProofForge.Ops` 命名空间，给 Golden
fixtures 和 `Extract.Compat` 使用。新的抽出链路走 `Core.Ops`、`Extract.IR` 和
`Svm.Ops`。发射 overflow 路径的依据是 checked 算术，不是方法名。

## Types

`Core.Ops.Val`：`arg` / `local` / `field` / `lit` / 位运算 `bitAnd` `bitOr` `bitXor`
`bitNot` `shiftL` `shiftR` / `indexGet` / `loopIx` / `select` / wrapping `*U64` /
`ext kind operands`。

`Core.Ops.Cmp`：`eq` / `ne` / `lt` / `le` / `gt` / `ge`。

`Core.Ops.Op`：`letLocal` / `joinLocal` / `setLocal`、checked 四则、`ite`、
`forAccum` / `forBody` / `indexSetLeaf` / `indexSet`、`storeField` / `okState` /
`errorOverflow` / `errorNamed` / `errorTyped` / `returnU64` / `returnState` /
`ext payload`。

`storeField name v`：写一个已摊平的账户叶。mutate 槽 diff 一次可发多条；单叶仍压成
`okState`。

`forBody n body`：有界 `for i in [:n]`，体里可用 `loopIx`。普通 early-return loop 和
显式 state-carrying fold 分开解码；callback-local index 会重写成 `loopIx`，外层方法
参数和 payload 保持原参数身份。Phoenix 的 17 / 19-phase fold 覆盖了跨迭代
state、动态 Vector 写和循环后的 continuation。

`Svm.Ops.ValKind` 含 sysvar / AccountInfo / PDA / hash 叶，以及 `.component query`。
`Svm.Ops.OpExt` 含 `invoke` 与 `.component call`。

## Tests

`Tests/CounterSpec.lean`：`increment` 抽出 `checkedAddU64`；`scale` / `divide` /
`modulo` 抽出对应 op。`wrapping*` fail closed。
`Tests/TargetOpsSpec.lean`：SVM value/op well-formed、Legacy round-trip。
`Tests/LangSpec.lean`：位运算、mod-64 移位、有界 for、运行时下标。
