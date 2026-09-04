import Examples.Svm.Token2022CpiGuard
import ProofForge.Svm.Sdk.Token2022

namespace Tests.SvmToken2022CpiGuardSpec

open Lean Elab Command
open Examples.Svm.Token2022CpiGuard
open ProofForge.Svm
open ProofForge.Svm.Runtime

#guard token2022TransferCheckedCpiGuard 7 6 == 0

-- Account buffer: 165-byte base + account type byte 2 + one CpiGuard TLV
-- (type 11, 1-byte body) + end marker.
private def cpiGuardAccount : Array UInt8 :=
  (List.replicate 165 (0 : UInt8) ++ [2, 11, 0, 1, 0, 1]).toArray

#guard match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022CpiGuardAccount
    { dataLen := UInt64.ofNat cpiGuardAccount.size, readByte := fun off => cpiGuardAccount[off.toNat]? } with
  | .accept => true | .reject _ => false
#guard match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022CpiGuardAccount
    { dataLen := 165, readByte := fun _ => none } with
  | .accept => true | .reject _ => false

elab "#pf_guard_token_2022_cpi_guard_ir" : command => do
  let env ← getEnv
  let extracted ←
    match ProofForge.Extract.extractModuleIR env `Examples.Svm.Token2022CpiGuard with
    | .ok program => pure program
    | .error reason => throwError reason
  let program ←
    match IR.fromExtracted extracted with
    | .ok program => pure program
    | .error reason => throwError reason
  let some method := program.methods.find? (·.ixName == "transferGuarded")
    | throwError "missing Token2022CpiGuard transferGuarded method"
  let expectedInvoke : IR.Op :=
    .invoke 4
      #[{ acc := 1, writable := true, accountData := some .token2022CpiGuardAccount },
        { acc := 2, accountData := some (.token2022Base .mint) },
        { acc := 3, writable := true, accountData := some (.token2022Base .account) },
        { acc := 0, signer := true }]
      #[.u8le (.lit 12), .u64le (.arg 0), .u8le (.lit 6)] #[] none
  unless method.ops.contains expectedInvoke do
    throwError s!"cpi-guard constrained CPI was not retained: {repr method.ops}"
  let asm ←
    match Emit.emitAsm program with
    | .ok asm => pure asm
    | .error reason => throwError reason
  unless asm.contains "; token-2022 TLV cpi-guard policy" &&
      asm.contains "jne r5, 11, " &&
      asm.contains "jne r5, 1, " &&
      asm.contains "call sol_invoke_signed_c" do
    throwError "Token-2022 cpi-guard preflight is missing from assembly"

#pf_guard_token_2022_cpi_guard_ir

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
    throwError s!"{module}: cpi-guard facade changed canonical IR: {actual}"

elab "#pf_guard_token_2022_cpi_guard_digest" : command => do
  expectCanonical `Examples.Svm.Token2022CpiGuard "327a18cb7cad3696"

#pf_guard_token_2022_cpi_guard_digest

end Tests.SvmToken2022CpiGuardSpec