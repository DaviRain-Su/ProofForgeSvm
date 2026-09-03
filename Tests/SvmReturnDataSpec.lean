import ProofForge.Svm.Sdk.Token
import ProofForge.Svm.Sdk.ReturnData
import ProofForge.Svm.Runtime
import Examples.Svm.TokenSizeVerified
import Examples.Svm.Token2022SizeVerified
open Lean Elab Command

namespace Tests.SvmReturnDataSpec

open ProofForge.Svm.Sdk

-- Host stubs are irreducible zeros; the chain behavior is pinned by Mollusk and the digests below.
#guard ReturnData.len == 0
#guard ReturnData.setterWord 0 == 0
#guard ReturnData.setterWord 3 == 0
#guard ReturnData.maxBytes == 1024

private def expectCanonical (module : Name) (expected : String) : CommandElabM Unit := do
  let env ← getEnv
  let source ←
    match ProofForge.Extract.extractModuleIR env module with
    | .ok source => pure source
    | .error reason => throwError reason
  let program ←
    match ProofForge.Svm.IR.fromExtracted source with
    | .ok program => pure program
    | .error reason => throwError reason
  let actual := ProofForge.Svm.IR.digestHex program
  unless actual == expected do
    throwError s!"{module}: return-data facade changed canonical IR: {actual}"

elab "#pf_guard_svm_return_data_facades" : command => do
  expectCanonical `Examples.Svm.TokenSizeVerified "69cdf0151569dbc8"
  expectCanonical `Examples.Svm.Token2022SizeVerified "e6d0ef0d76a16a7a"

#pf_guard_svm_return_data_facades

end Tests.SvmReturnDataSpec
