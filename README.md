# ProofForge SVM

[![CI](https://github.com/DaviRain-Su/ProofForgeSvm/actions/workflows/ci.yml/badge.svg)](https://github.com/DaviRain-Su/ProofForgeSvm/actions/workflows/ci.yml)

[中文](README.zh-CN.md)

A Lean 4 → Solana sBPF program compiler. Mark entries with `@[pf_entry]` in ordinary
Lean source; ProofForge extracts a checked IR, emits sBPF assembly, and assembles
`.so` + IDL via **pinned sbpf** (`0.2.2@d835bc6`).
This repository is the SVM single-target fork of ProofForge.

Product contract: [`docs/product/support-matrix.md`](docs/product/support-matrix.md).
Writing guide: [`docs/product/writing-contracts.md`](docs/product/writing-contracts.md).
Site: [`website/`](website/) (GitHub Pages).

## Layout

- `ProofForge/Core/` — target-independent value/effect IR, CFG, codec, schema
- `ProofForge/Extract/` — Lean expression → IR extractor (SVM-only)
- `ProofForge/Svm/` — SVM Ops / IR / Emit / Assemble (locked sbpf) / Registry / IDL
- `ProofForge/Svm/Sdk/` — program-facing SDK (accounts, CPI, Token, sysvar, storage, …)
- `ProofForge/Cli.lean` — the `pf` CLI (`pf build` / `pf init` / `pf --version`)
- `Examples/` — SVM program examples (digests pinned in `ProofForge/Svm/Registry.lean`)
- `Tests/` — elaboration-time specs (`#guard` / `example`)
- `templates/svm-counter/` — `pf init` user project template
- `runtime-tests/solana/` — Mollusk integration gates
- `runtime-tests/surfpool/` — Loader-v3 local deploy (not `solana-test-validator`)
- `runtime-tests/phoenix/` — Phoenix Mollusk crate (phoenix CI lane)
- `docs/product/` — support matrix, writing guide, roadmap
- `docs/research/` — **historical** decision notes (archived)
- `website/` — project site (Vite + React)

## Build & test

```text
./.agents/setup        # pinned toolchain: elan/Lake v4.31.0, sbpf 0.2.2@d835bc6, Surfpool 1.5.0
lake build             # compiler library
lake build pf          # CLI executable
lake build Tests       # test suite (elaboration-time assertions)
lake build Examples    # example programs
```

Local CI mirror: `scripts/ci_local.sh` (`--fast` runs the Python guards only).

## CLI

```text
pf build [--out DIR] [--module MOD] [Program ...]
pf init <name>
pf --version
```

`pf build` writes `Name.so` / `Name.s` / `Name.idl.json` per program.
`--target svm` / `solana` / `sbpf` is accepted and ignored (this build is SVM-only).
Bare names map to in-tree `Examples` fixtures; user projects pass `--module`
or list `[[program]]` entries in `pf.toml`.

## On-chain gates

```text
runtime-tests/solana          # Mollusk (cargo test --locked)
runtime-tests/surfpool/smoke.sh RawEntry
runtime-tests/phoenix         # Phoenix Mollusk (phoenix lane)
```

## User projects (from this checkout)

```text
lake build pf
lake exe pf -- init demo
cd demo
lake build
../.lake/build/bin/pf build
```

`pf init` currently requires a repo checkout (copies `templates/svm-counter` and
rewrites a path-`require`). There is no standalone installer yet.

Contracts import only `ProofForge.Attr` + `ProofForge.Svm.Sdk` — never the
`ProofForge` umbrella. The SDK transitive closure must not reach
Emit/Assemble/Registry (enforced in CI by `scripts/check_sdk_import_closure.py`).

## Trust boundary

- Kernel theorems are about user `def`s / static fields — **not** about `.so` or SVM refinement.
- Mollusk / Surfpool green is an **engineering** gate, not a proof.
- Phoenix-v1 is a bounded official-tag profile, not a full on-chain exchange.

## License

[MIT](LICENSE)
