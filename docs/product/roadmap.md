# Product roadmap

## Already landed on main

- SVM-only module docs under `docs/modules/`
- Public site under `website/` + GitHub Pages workflow
- Compiler/SDK slice coverage well past the old svm-sem / svm-sdk / svm-app research plan
- CI lanes `lean` / `svm` / `phoenix` (Phoenix-v1 Surfpool is nightly)

## Now (product surface)

1. **Honest public claims** — website/README match CLI + CI reality (locked sbpf, Mollusk + Surfpool, no fake MCP/doctor).
2. **Support matrix + writing guide** — this directory.
3. **Checkout quickstart that is copy-paste true** — `lake build pf` → `pf init` → `pf build`.
4. **Research archive banners** — `docs/research/00|01|02|03|07` marked historical.
5. **Template honesty** — no nonexistent git tags / wrong repo names as if released.

## Next

6. **Init smoke in CI** — empty-dir `pf init` → `lake build` → `pf build` for the counter template.
7. **Release v0.1** — tagged `pf` binary + template `require … @ tag` path; stop rewriting absolute checkout paths as the only story.
8. **Website artifact honesty** — generate Forge panel excerpts from real `pf build` output, or keep them clearly labeled illustrative.
9. **Non-Phoenix SDK consumers** — keep TicketLine / UniqueRoster / FeatureBits / VersionedLedger as the public proof that Phoenix is an application, not a compiler special case.

## Later (compiler depth; not P0 product copy)

10. Effect representation rewrite (remove `dummy` / fake CPI guards).
11. Broader Solanalib correspondence beyond the knife / skip-chain slices.
12. Optional Phoenix application split after the first SDK tag.

## Explicit non-goals

Dynamic remaining accounts, unbounded recursion, mainnet endorsement, ELF/loader refinement proofs, `solana-test-validator` as the product path.
