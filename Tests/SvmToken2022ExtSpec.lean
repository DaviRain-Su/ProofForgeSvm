import Examples.Svm.Token2022Ext
import ProofForge.Svm.Sdk.Token2022

namespace Tests.SvmToken2022ExtSpec

open Lean Elab Command
open Examples.Svm.Token2022Ext
open ProofForge.Svm
open ProofForge.Svm.Runtime

#guard token2022TransferCheckedImmutable 7 6 == 0
#guard token2022TransferCheckedNonTransferable 7 6 == 0
#guard token2022SetAccountAuthorityImmutable == 0

-- Account buffer: 165-byte base + account type byte 2 + one ImmutableOwner TLV (type 7, len 0).
private def immutableOwnerAccount : Array UInt8 :=
  (List.replicate 165 (0 : UInt8) ++ [2, 7, 0, 0, 0]).toArray

-- Account buffer: 165-byte base + account type byte 2 + one NonTransferableAccount TLV (type 13, len 0).
private def nonTransferableAccount : Array UInt8 :=
  (List.replicate 165 (0 : UInt8) ++ [2, 13, 0, 0, 0]).toArray

-- Mint buffer: 82-byte base + 83 zero padding + mint type byte 1 + one NonTransferable TLV (type 9, len 0).
private def nonTransferableMint : Array UInt8 :=
  (List.replicate 165 (0 : UInt8) ++ [1, 9, 0, 0, 0]).toArray

#guard ProofForge.Svm.Sdk.Token2022.accountHasImmutableOwner immutableOwnerAccount
#guard !ProofForge.Svm.Sdk.Token2022.accountHasImmutableOwner nonTransferableAccount
#guard !ProofForge.Svm.Sdk.Token2022.accountHasImmutableOwner (List.replicate 165 (0 : UInt8)).toArray
#guard ProofForge.Svm.Sdk.Token2022.accountHasNonTransferable nonTransferableAccount
#guard !ProofForge.Svm.Sdk.Token2022.accountHasNonTransferable immutableOwnerAccount
#guard ProofForge.Svm.Sdk.Token2022.mintHasNonTransferable nonTransferableMint
#guard !ProofForge.Svm.Sdk.Token2022.mintHasNonTransferable immutableOwnerAccount

elab "#pf_guard_token_2022_ext_ir" : command => do
  let env ← getEnv
  let extracted ←
    match ProofForge.Extract.extractModuleIR env `Examples.Svm.Token2022Ext with
    | .ok program => pure program
    | .error reason => throwError reason
  let program ←
    match IR.fromExtracted extracted with
    | .ok program => pure program
    | .error reason => throwError reason
  let some immutableMethod := program.methods.find? (·.ixName == "transferImmutable")
    | throwError "missing Token2022Ext transferImmutable method"
  let expectedImmutable : IR.Op :=
    .invoke 4
      #[{ acc := 1, writable := true, accountData := some .token2022ImmutableOwner },
        { acc := 2, accountData := some (.token2022Base .mint) },
        { acc := 3, writable := true, accountData := some .token2022ImmutableOwner },
        { acc := 0, signer := true }]
      #[.u8le (.lit 12), .u64le (.arg 0), .u8le (.lit 6)] #[] none
  unless immutableMethod.ops.contains expectedImmutable do
    throwError s!"immutable-owner constrained CPI was not retained: {repr immutableMethod.ops}"
  let some ntMethod := program.methods.find? (·.ixName == "transferNonTransferable")
    | throwError "missing Token2022Ext transferNonTransferable method"
  let expectedNt : IR.Op :=
    .invoke 4
      #[{ acc := 1, writable := true, accountData := some .token2022NonTransferableAccount },
        { acc := 2, accountData := some .token2022NonTransferableMint },
        { acc := 3, writable := true, accountData := some .token2022NonTransferableAccount },
        { acc := 0, signer := true }]
      #[.u8le (.lit 12), .u64le (.arg 0), .u8le (.lit 6)] #[] none
  unless ntMethod.ops.contains expectedNt do
    throwError s!"non-transferable constrained CPI was not retained: {repr ntMethod.ops}"
  let asm ←
    match Emit.emitAsm program with
    | .ok asm => pure asm
    | .error reason => throwError reason
  unless asm.contains "; token-2022 TLV immutable-owner policy" &&
      asm.contains "; token-2022 TLV non-transferable-account policy" &&
      asm.contains "; token-2022 TLV non-transferable-mint policy" &&
      asm.contains "call sol_invoke_signed_c" do
    throwError "Token-2022 marker TLV preflights are missing from assembly"

#pf_guard_token_2022_ext_ir

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
    throwError s!"{module}: Token-2022 extension facade changed canonical IR: {actual}"

elab "#pf_guard_token_2022_ext_digest" : command => do
  expectCanonical `Examples.Svm.Token2022Ext "dbcfd1ef39d70536"

#pf_guard_token_2022_ext_digest

end Tests.SvmToken2022ExtSpec
