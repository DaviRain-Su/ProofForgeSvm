import Examples.Svm.Token2022Pause
import ProofForge.Svm.Sdk.Token2022

namespace Tests.SvmToken2022PauseSpec

open Lean Elab Command
open Examples.Svm.Token2022Pause
open ProofForge.Svm
open ProofForge.Svm.Runtime

#guard token2022TransferCheckedPausable 7 6 == 0

-- Mint buffer: 82-byte base + 83 zero padding + mint type byte 1 + one Pausable TLV
-- (type 26, 33-byte body, zeroed) + end marker.
private def pausableMint : Array UInt8 :=
  (List.replicate 165 (0 : UInt8) ++ [1, 26, 0, 33, 0] ++ List.replicate 33 (0 : UInt8)).toArray

#guard match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022PausableMint
    { dataLen := UInt64.ofNat pausableMint.size, readByte := fun off => pausableMint[off.toNat]? } with
  | .accept => true | .reject _ => false
#guard match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022PausableMint
    { dataLen := 82, readByte := fun _ => none } with
  | .accept => true | .reject _ => false

elab "#pf_guard_token_2022_pause_ir" : command => do
  let env ← getEnv
  let extracted ←
    match ProofForge.Extract.extractModuleIR env `Examples.Svm.Token2022Pause with
    | .ok program => pure program
    | .error reason => throwError reason
  let program ←
    match IR.fromExtracted extracted with
    | .ok program => pure program
    | .error reason => throwError reason
  let some method := program.methods.find? (·.ixName == "transferPause")
    | throwError "missing Token2022Pause transferPause method"
  let expectedInvoke : IR.Op :=
    .invoke 4
      #[{ acc := 1, writable := true, accountData := some (.token2022Base .account) },
        { acc := 2, accountData := some .token2022PausableMint },
        { acc := 3, writable := true, accountData := some (.token2022Base .account) },
        { acc := 0, signer := true }]
      #[.u8le (.lit 12), .u64le (.arg 0), .u8le (.lit 6)] #[] none
  unless method.ops.contains expectedInvoke do
    throwError s!"pausable constrained CPI was not retained: {repr method.ops}"
  let asm ←
    match Emit.emitAsm program with
    | .ok asm => pure asm
    | .error reason => throwError reason
  unless asm.contains "; token-2022 TLV pausable-mint policy" &&
      asm.contains "jne r5, 33, " &&
      asm.contains "call sol_invoke_signed_c" do
    throwError "Token-2022 pausable preflight is missing from assembly"

#pf_guard_token_2022_pause_ir

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
    throwError s!"{module}: pausable facade changed canonical IR: {actual}"

elab "#pf_guard_token_2022_pause_digest" : command => do
  expectCanonical `Examples.Svm.Token2022Pause "7e354a73c6b794c3"

#pf_guard_token_2022_pause_digest

end Tests.SvmToken2022PauseSpec