# ProofForge SVM

[![CI](https://github.com/DaviRain-Su/ProofForgeSvm/actions/workflows/ci.yml/badge.svg)](https://github.com/DaviRain-Su/ProofForgeSvm/actions/workflows/ci.yml)

[English](README.md)

Lean 4 → Solana sBPF 程序编译器：用 `@[pf_entry]` 标记普通 Lean 入口；ProofForge 抽出受检 IR，
发射 sBPF 汇编，再由 **钉死的 sbpf**（`0.2.2@d835bc6`）汇编 `.so` 与 IDL。
本仓库是 ProofForge 的 SVM 单目标分支。

产品契约：[`docs/product/support-matrix.md`](docs/product/support-matrix.md)。
写合约指南：[`docs/product/writing-contracts.md`](docs/product/writing-contracts.md)。
站点：[`website/`](website/)（GitHub Pages）。

## 布局

- `ProofForge/Core/` — 目标无关的值/效果 IR、CFG、codec、schema
- `ProofForge/Extract/` — Lean 表达式 → IR 抽取器（仅 SVM）
- `ProofForge/Svm/` — SVM Ops / IR / Emit / Assemble（locked sbpf）/ Registry / IDL
- `ProofForge/Svm/Sdk/` — 程序侧 SDK（账户、CPI、Token、sysvar、storage…）
- `ProofForge/Cli.lean` — `pf` CLI（`pf build` / `pf init` / `pf --version`）
- `Examples/` — SVM 程序示例（digest 钉在 `ProofForge/Svm/Registry.lean`）
- `Tests/` — elaboration 期规格（`#guard` / `example`）
- `templates/svm-counter/` — `pf init` 用户工程模板
- `runtime-tests/solana/` — Mollusk 集成门禁
- `runtime-tests/surfpool/` — Loader-v3 本地部署（不用 `solana-test-validator`）
- `runtime-tests/phoenix/` — Phoenix Mollusk crate（phoenix CI 车道）
- `docs/product/` — 能力矩阵、写合约指南、路线图
- `docs/research/` — **历史**决策笔记（已归档）
- `website/` — 项目站点（Vite + React）

## 构建与测试

```text
./.agents/setup        # 钉死工具链：elan/Lake v4.31.0、sbpf 0.2.2@d835bc6、Surfpool 1.5.0
lake build             # 编译器库
lake build pf          # CLI 可执行文件
lake build Tests       # 测试套件
lake build Examples    # 示例程序
```

本地 CI 镜像：`scripts/ci_local.sh`（`--fast` 只跑 Python 守卫）。

## CLI

```text
pf build [--out DIR] [--module MOD] [Program ...]
pf init <name>
pf --version
```

`pf build` 写出 `Name.so` / `Name.s` / `Name.idl.json`。
`--target svm` / `solana` / `sbpf` 可显式给出（本构建仅 SVM，其它 target 拒绝）。
裸名映射到仓内 `Examples`；用户工程传 `--module` 或在 `pf.toml` 写 `[[program]]`。

## 链上门禁

```text
runtime-tests/solana          # Mollusk（cargo test --locked）
runtime-tests/surfpool/smoke.sh RawEntry
runtime-tests/phoenix         # Phoenix Mollusk（phoenix 车道）
```

## 用户工程（在本仓 checkout 内）

```text
lake build pf
lake exe pf -- init demo
cd demo
lake build
../.lake/build/bin/pf build
```

`pf init` 目前依赖仓库 checkout（复制 `templates/svm-counter` 并改写 path-`require`）。
尚无独立安装包。

合约只 import `ProofForge.Attr` + `ProofForge.Svm.Sdk`，不要 import `ProofForge` 伞模块。
SDK 传递闭包不得触及 Emit/Assemble/Registry（CI：`scripts/check_sdk_import_closure.py`）。

## 信任边界

- Kernel 定理钉的是用户 `def` / 静态字段，**不是** `.so` 或 SVM 精化。
- Mollusk / Surfpool 变绿是**工程**门，不是证明。
- Phoenix-v1 是有界官方 tag 剖面，不是完整链上交易所。

## 许可证

[MIT](LICENSE)
