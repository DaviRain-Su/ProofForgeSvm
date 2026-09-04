import ProofForge.Svm.Prelude
import ProofForge.Svm.Commands
import Examples.TokenShape

/-!
# TokenShape conformance (SVM)

`Examples.TokenShape` is the **transfer-shaped** UInt64 ledger subset (`initialize` / `get` /
`credit` / `debit`). The SVM digest is pinned below and in `ProofForge.Svm.Registry`.
-/

namespace Tests.TokenShapeSpec

#guard ProofForge.Svm.Registry.digestOf "TokenShape" == some "d9f1c090ffa3b9d"

open Lean Elab Command
open ProofForge
elab "#pf_token_shape_check" : command => do
  let env ← getEnv
  let module := `Examples.TokenShape
  let svmProgram ←
    match Extract.extractModuleIR env module none >>= ProofForge.Svm.IR.fromExtracted with
    | .ok program => pure program
    | .error reason => throwError reason
  let svmDigest := ProofForge.Svm.IR.digestHex svmProgram
  unless svmDigest == "d9f1c090ffa3b9d" do
    throwError s!"TokenShape digest mismatch: svm={svmDigest}"
  let shared := #["credit", "debit", "get", "initialize"]
  let svmMethods := svmProgram.methods.map (·.ixName) |>.qsort (· < ·)
  unless svmMethods == shared do
    throwError s!"TokenShape method surface diverged: svm={svmMethods}"
  logInfo m!"token-shape: svm={svmDigest}"

#pf_token_shape_check

#pf_build Examples.TokenShape

end Tests.TokenShapeSpec
