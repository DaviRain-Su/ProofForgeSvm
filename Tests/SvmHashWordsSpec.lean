import ProofForge.Svm.Runtime
import Examples.Svm.HashWords
import Examples.Svm.HashDataSha
import Examples.Svm.HashDataKeccak
open Lean Elab Command

namespace Tests.SvmHashWordsSpec

open ProofForge.Svm

-- Host stubs are irreducible zeros; chain behavior is pinned by Mollusk and the digest below.
#guard Runtime.sha256LitWord "vault" 0 == 0
#guard Runtime.sha256LitWord "vault" 3 == 0
#guard Runtime.keccak256LitWord "vault" 0 == 0
#guard Runtime.keccak256LitWord "vault" 3 == 0

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
    throwError s!"{module}: hash-word facade changed canonical IR: {actual}"

elab "#pf_guard_svm_hash_words" : command => do
  expectCanonical `Examples.Svm.HashWords "9b140013a7e21f45"
  expectCanonical `Examples.Svm.HashDataSha "175bc3dc0c726531"
  expectCanonical `Examples.Svm.HashDataKeccak "2f424c1bc65d97e4"

#pf_guard_svm_hash_words

end Tests.SvmHashWordsSpec
