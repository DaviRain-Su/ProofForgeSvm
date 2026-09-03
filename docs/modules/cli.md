# ProofForge.Cli

## Purpose

`pf`：把源模块抽出后编成 SVM 制品。`Svm.Registry` 只登记源码模块名并钉
target IR digest，不能替代源模块 IR，也不依赖旧 mixed Golden。

## Surface

```
pf build [--out DIR] [--module MOD] [Program ...]
pf init <name>
pf --version
```

- 写出 `Name.so` / `Name.s` / `Name.idl.json`
- `--target svm` / `solana` / `sbpf` 可显式给出（本构建仅 SVM；其它名字 fail-closed）
- 裸名字映射到仓内 `Examples` fixture（`Counter` → `Examples.Counter`，其余多数在
  `Examples.Svm.*`）；`--module` 接受点分 Lean 模块（可重复）
- 用户工程应使用 `--module` 或 `pf.toml` 的 `[[program]]` 条目；不写名字 = 全部登记源模块
- 每次运行重新抽取 IR；`Examples` fixture 的 digest 必须与 `Svm.Registry` 钉值一致，
  否则 fail-closed（`ir/mismatch`）
- `pf init <name>` 复制 `templates/svm-counter`，并把 path-`require` 改写为指向本仓

## Tests

`Tests/CliSpec.lean` 钉参数解析与 usage；`Tests/BuildSpec.lean` 用 `#pf_build`
对登记 fixture 做 digest 门禁。
