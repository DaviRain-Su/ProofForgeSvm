import Examples.Svm.Token2022Tfee
import ProofForge.Svm.Sdk.Token2022

namespace Tests.SvmToken2022TfeeSpec

open Lean Elab Command
open Examples.Svm.Token2022Tfee
open ProofForge.Svm
open ProofForge.Svm.Runtime

#guard token2022TransferCheckedTransferFee 7 6 == 0

-- Mint buffer: 82-byte base + 83 zero padding + mint type byte 1 + one TransferFeeConfig TLV
-- (type 1, official 108-byte body, zeroed) + end marker.
private def tfeeMint : Array UInt8 :=
  (List.replicate 165 (0 : UInt8) ++ [1, 1, 0, 108, 0] ++ List.replicate 108 (0 : UInt8)).toArray

-- Account buffer: 165-byte base + account type byte 2 + one TransferFeeAmount TLV
-- (type 2, 8-byte body) + end marker.
private def tfeeAccount : Array UInt8 :=
  (List.replicate 165 (0 : UInt8) ++ [2, 2, 0, 8, 0] ++ List.replicate 8 (0 : UInt8)).toArray

-- The transfer-fee policies accept exactly the official one-entry forms.
#guard match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022TransferFeeConfigMint
    { dataLen := UInt64.ofNat tfeeMint.size, readByte := fun off => tfeeMint[off.toNat]? } with
  | .accept => true | .reject _ => false
#guard match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022TransferFeeConfigMint
    { dataLen := UInt64.ofNat tfeeAccount.size, readByte := fun off => tfeeAccount[off.toNat]? } with
  | .accept => false | .reject _ => true
#guard match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022TransferFeeAmountAccount
    { dataLen := UInt64.ofNat tfeeAccount.size, readByte := fun off => tfeeAccount[off.toNat]? } with
  | .accept => true | .reject _ => false
#guard match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022TransferFeeAmountAccount
    { dataLen := UInt64.ofNat tfeeMint.size, readByte := fun off => tfeeMint[off.toNat]? } with
  | .accept => false | .reject _ => true
-- A classic 82-byte mint proceeds on the base-span arm (no fee schedule, token-2022 treats
-- it as a zero-fee mint), same closed-base discipline as the other policies.
#guard match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022TransferFeeConfigMint
    { dataLen := 82, readByte := fun _ => none } with
  | .accept => true | .reject _ => false

elab "#pf_guard_token_2022_tfee_ir" : command => do
  let env ← getEnv
  let extracted ←
    match ProofForge.Extract.extractModuleIR env `Examples.Svm.Token2022Tfee with
    | .ok program => pure program
    | .error reason => throwError reason
  let program ←
    match IR.fromExtracted extracted with
    | .ok program => pure program
    | .error reason => throwError reason
  let some method := program.methods.find? (·.ixName == "transferTfee")
    | throwError "missing Token2022Tfee transferTfee method"
  let expectedInvoke : IR.Op :=
    .invoke 4
      #[{ acc := 1, writable := true, accountData := some .token2022TransferFeeAmountAccount },
        { acc := 2, accountData := some .token2022TransferFeeConfigMint },
        { acc := 3, writable := true, accountData := some .token2022TransferFeeAmountAccount },
        { acc := 0, signer := true }]
      #[.u8le (.lit 12), .u64le (.arg 0), .u8le (.lit 6)] #[] none
  let rec opsDeepContains (fuel : Nat) (ops : Array IR.Op) : Bool :=
    match fuel with
    | 0 => false
    | fuel' + 1 =>
      ops.any fun op =>
        op == expectedInvoke ||
          match op with
          | .ite _ _ _ thn els => opsDeepContains fuel' thn || opsDeepContains fuel' els
          | _ => false
  unless opsDeepContains 64 method.ops do
    let all := program.methods.map fun m => s!"{m.ixName}:{repr m.ops}"
    throwError s!"transfer-fee constrained CPI was not retained: methods={all} ops={repr method.ops}"
  let asm ←
    match Emit.emitAsm program with
    | .ok asm => pure asm
    | .error reason => throwError reason
  unless asm.contains "; token-2022 TLV transfer-fee-mint policy" &&
      asm.contains "; token-2022 TLV transfer-fee-amount policy" &&
      asm.contains "; transfer-fee TLV: allow TransferFeeConfig(1,108) then end, or end alone" &&
      asm.contains "jne r5, 108, " &&
      asm.contains "call sol_invoke_signed_c" do
    throwError "Token-2022 transfer-fee preflights are missing from assembly"

#pf_guard_token_2022_tfee_ir

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
    throwError s!"{module}: Token-2022 transfer-fee facade changed canonical IR: {actual}"

elab "#pf_guard_token_2022_tfee_digest" : command => do
  expectCanonical `Examples.Svm.Token2022Tfee "9fa8422c103688b5"

#pf_guard_token_2022_tfee_digest

end Tests.SvmToken2022TfeeSpec