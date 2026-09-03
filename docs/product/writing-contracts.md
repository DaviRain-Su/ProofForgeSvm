# Writing contracts (v0)

## Imports

User projects should import only:

```lean
import ProofForge.Attr
import ProofForge.Svm.Sdk
```

Do **not** import the `ProofForge` umbrella (it can pull Emit / Assemble / Registry).

## Entry shape

Mark chain entries with `@[pf_entry]`. Keep state in an explicit `structure`, errors in an `inductive`, and mutations as `Except`-style transitions when you need fail-closed overflow.

See `templates/svm-counter/MyProgram/Counter.lean` and `Examples/Svm/VersionedLedger.lean`.

## What works today

- Account-resident POD state + bounded Map / Queue / tree
- Checked math / bit ops / bounded loops / Vector index
- Closed System / Token / Memo / ATA / PDA CPI via SDK
- Kernel proofs about the Lean `def` (not about `.so`)

## Known sharp edges (be honest in examples)

1. **Effect carrier** — some CPI fixtures still park a `dummy : UInt64` field and a trivial `if` so Extract treats the method as effectful.
2. **Compile-time geometry** — account layouts, seed lists, and CPI metas are static. Runtime-assembled remaining accounts fail closed.
3. **Heap vs accounts** — invocation-local bump / TransientVec never store pointers in account bytes.
4. **Phoenix** — use the official-tag profile as a stress test of the component boundary, not as “ship Phoenix”.

These are product debts tracked in [roadmap.md](roadmap.md), not undocumented folklore.

## Build

```bash
# in a pf init project, from repo checkout
lake build
../.lake/build/bin/pf build
```

Artifacts: `Name.so`, `Name.s`, `Name.idl.json`.

## Prove

Keep theorems next to the program. CI refuses `sorry` in the proof batch. Prove properties of the Lean function; do not claim the theorem proved the `.so`.
