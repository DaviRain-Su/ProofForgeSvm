# Support matrix (v0 product surface)

> Status: living product contract. If the website, README, and this file disagree, **this file wins**.

## Product one-liner

ProofForge SVM is a **checkout-first Lean 4 → sBPF → locked sbpf** compiler for a fail-closed Solana program subset, with Mollusk and Surfpool engineering gates. It is **not** a mainnet deployment product, not a full Phoenix-v1 exchange, and not a proved-ELF toolchain.

## Assembler

| Tool | Product status | CI posture | Notes |
|---|---|---|---|
| `sbpf` 0.2.2 `@d835bc6` (pinned) | **Supported** | Required merge gate (svm lane) | Emits `.so` / `.s` / `.idl.json` |

## CLI surface

| Command | Status |
|---|---|
| `pf build [--out DIR] [--module MOD] [Program ...]` | Supported |
| `pf init <name>` | Supported **inside a repo checkout** (copies `templates/svm-counter`, rewrites path-require) |
| `pf --version` / `-h` | Supported (`lean v4.31.0`; `sbpf 0.2.2@d835bc6`) |
| `--target svm` / `solana` / `sbpf` | Accepted (SVM-only build; other names refused) |
| `pf doctor` / `install` / `artifacts` / `local` / `deploy` / `call` | **Not implemented** |
| In-repo MCP server | **Not shipped** |

## Language / extract subset

| Area | Status |
|---|---|
| Ordinary `def` / `structure` / `Except` entries with `@[pf_entry]` | Supported |
| Profile refuse IO / partial / sorry / extern / unbounded recursion | Supported |
| Checked arithmetic, `ite`, bounded `for`, bit ops, account-resident POD | Supported |
| Closed CPI (System / Token / Memo / ATA / PDA) via `Svm.Sdk` | Supported |
| Account-resident Map / Queue / tree / allocator with compile-time capacity | Supported |
| Invocation-local heap / TransientVec (no account pointers) | Supported |
| Dynamic remaining accounts / unbounded loops / host `String`/`Vec` | **Out of scope** |

## SDK naming honesty

| Module | Say this | Do **not** say this |
|---|---|---|
| `Svm.Sdk.Token` | Classic SPL / Token-2022 **base-layout** TransferChecked | Full Token-2022 extension suite |
| `Svm.Sdk.Storage` | Fixed-capacity account-resident containers | Unbounded heap `Map` / `Vec` |
| Phoenix-v1 profile | Official tags 3–14 on a bounded geometry | Full Phoenix-v1 + public deployment |

## Proof boundary

| Claim | Status |
|---|---|
| Kernel-checked theorems about user `def` / static fields | Yes (examples + no-sorry CI) |
| Bounded Solanalib / SemanticsBridge correspondence slices | Engineering + selected kernel theorems (wider TCB where `native_decide`) |
| Theorems about `.so` / loader / full SVM refinement | **Not claimed** |
| Mollusk / Surfpool green ⇒ proved on-chain behavior | **Not claimed** (engineering gate only) |

## User-project path (supported)

From repo root after toolchain setup:

```bash
lake build pf
lake exe pf -- init demo
cd demo
lake build
../.lake/build/bin/pf build
```

`pf init` currently requires the checkout (template path + require rewrite). A standalone installer / release tarball is roadmap work, not v0.

## Related

- Writing guide: [writing-contracts.md](writing-contracts.md)
- Roadmap: [roadmap.md](roadmap.md)
- Module internals: [../modules/](../modules/)
- Historical research (archived): [../research/](../research/)
