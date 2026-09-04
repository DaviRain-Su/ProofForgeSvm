import Examples.Svm.NonceLife
import ProofForge.Svm.Sdk.System

namespace Tests.SvmNonceLifeSpec

open Lean Elab Command
open Examples.Svm.NonceLife
open ProofForge.Svm
open ProofForge.Svm.Runtime

#guard systemInitializeNonce == 0
#guard systemWithdrawNonce 7 == 0
#guard systemAuthorizeNonce == 0
#guard systemUpgradeNonce == 0

elab "#pf_guard_nonce_life_ir" : command => do
  let env ← getEnv
  let extracted ←
    match ProofForge.Extract.extractModuleIR env `Examples.Svm.NonceLife with
    | .ok program => pure program
    | .error reason => throwError reason
  let program ←
    match IR.fromExtracted extracted with
    | .ok program => pure program
    | .error reason => throwError reason
  let some initMethod := program.methods.find? (·.ixName == "initNonce")
    | throwError "missing NonceLife initNonce method"
  let rec hasInvoke (ops : Array IR.Op) (n : Nat) : Bool :=
    ops.any fun op =>
      match op with
      | .invoke _ metas _ _ _ => metas.size == n
      | _ => false
  unless hasInvoke initMethod.ops 3 do
    throwError s!"initNonce CPI was not retained: {repr initMethod.ops}"
  let some openMethod := program.methods.find? (·.ixName == "openNonce")
    | throwError "missing NonceLife openNonce method"
  -- createRentExempt computes the rent via sol_get_rent_sysvar, so the lamports word is
  -- dynamic (a rent sysvar value), not a literal. Match the invoke by metas count.
  let rec hasInvoke2 (ops : Array IR.Op) : Bool :=
    ops.any fun op =>
      match op with
      | .invoke _ metas _ _ _ => metas.size == 2
      | _ => false
  unless hasInvoke2 openMethod.ops do
    throwError s!"openNonce create CPI was not retained: {repr openMethod.ops}"
  let asm ←
    match Emit.emitAsm program with
    | .ok asm => pure asm
    | .error reason => throwError reason
  unless asm.contains "; invoke programIx=3 metas=2 dataLen=52" &&
      asm.contains "call sol_invoke_signed_c" &&
      asm.contains "call sol_get_rent_sysvar" do
    throwError "nonce-life create preflight is missing from assembly"

#pf_guard_nonce_life_ir

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
    throwError s!"{module}: nonce-life facade changed canonical IR: {actual}"

elab "#pf_guard_nonce_life_digest" : command => do
  expectCanonical `Examples.Svm.NonceLife "43a8c37e4bc90e8f"

#pf_guard_nonce_life_digest

end Tests.SvmNonceLifeSpec