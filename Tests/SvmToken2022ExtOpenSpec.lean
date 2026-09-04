import Examples.Svm.Token2022ExtOpen
import ProofForge.Svm.Sdk.Token2022

namespace Tests.SvmToken2022ExtOpenSpec

open Lean Elab Command
open Examples.Svm.Token2022ExtOpen
open ProofForge.Svm
open ProofForge.Svm.Runtime

#guard token2022TransferCheckedMemoTransfer 7 6 == 0
#guard token2022TransferCheckedTransferHook 7 6 == 0
#guard token2022TransferCheckedDefaultAccountState 7 6 == 0
#guard token2022TransferCheckedMetadataPointer 7 6 == 0
#guard token2022TransferCheckedGroupPointer 7 6 == 0
#guard token2022TransferCheckedGroupMemberPointer 7 6 == 0
#guard token2022TransferCheckedTokenGroup 7 6 == 0
#guard token2022TransferCheckedTokenGroupMember 7 6 == 0

elab "#pf_guard_token_2022_ext_open_ir" : command => do
  let env ← getEnv
  let extracted ←
    match ProofForge.Extract.extractModuleIR env `Examples.Svm.Token2022ExtOpen with
    | .ok program => pure program
    | .error reason => throwError reason
  let program ←
    match IR.fromExtracted extracted with
    | .ok program => pure program
    | .error reason => throwError reason
  let expectEntry (ixName : String) (mintPolicy : Cpi.TokenTlv.Policy)
      (srcPolicy : Cpi.TokenTlv.Policy) (dstPolicy : Cpi.TokenTlv.Policy) : CommandElabM Unit := do
    let some method := program.methods.find? (·.ixName == ixName)
      | throwError s!"missing Token2022ExtOpen {ixName} method"
    let expectedInvoke : IR.Op :=
      .invoke 4
        #[{ acc := 1, writable := true, accountData := some srcPolicy },
          { acc := 2, accountData := some mintPolicy },
          { acc := 3, writable := true, accountData := some dstPolicy },
          { acc := 0, signer := true }]
        #[.u8le (.lit 12), .u64le (.arg 0), .u8le (.lit 6)] #[] none
    unless method.ops.contains expectedInvoke do
      throwError s!"{ixName} constrained CPI was not retained: {repr method.ops}"
  expectEntry "transferMemo" (.token2022Base .mint) (.token2022Base .account)
    .token2022MemoTransferAccount
  expectEntry "transferHook" .token2022TransferHookMint (.token2022Base .account)
    .token2022TransferHookAccount
  expectEntry "transferDas" .token2022DefaultAccountStateMint (.token2022Base .account)
    (.token2022Base .account)
  expectEntry "transferMdptr" .token2022MetadataPointerMint (.token2022Base .account)
    (.token2022Base .account)
  expectEntry "transferGptr" .token2022GroupPointerMint (.token2022Base .account)
    (.token2022Base .account)
  expectEntry "transferGmptr" .token2022GroupMemberPointerMint (.token2022Base .account)
    (.token2022Base .account)
  expectEntry "transferTgrp" .token2022TokenGroupMint (.token2022Base .account)
    (.token2022Base .account)
  expectEntry "transferTgmem" .token2022TokenGroupMemberMint (.token2022Base .account)
    (.token2022Base .account)
  let asm ←
    match Emit.emitAsm program with
    | .ok asm => pure asm
    | .error reason => throwError reason
  unless asm.contains "; token-2022 TLV memo-transfer policy" &&
      asm.contains "; token-2022 TLV transfer-hook-mint policy" &&
      asm.contains "; token-2022 TLV transfer-hook-account policy" &&
      asm.contains "; token-2022 TLV default-account-state policy" &&
      asm.contains "; token-2022 TLV metadata-pointer policy" &&
      asm.contains "; token-2022 TLV group-pointer policy" &&
      asm.contains "; token-2022 TLV group-member-pointer policy" &&
      asm.contains "; token-2022 TLV token-group policy" &&
      asm.contains "; token-2022 TLV token-group-member policy" &&
      asm.contains "call sol_invoke_signed_c" do
    throwError "Token-2022 extension-open preflights are missing from assembly"

#pf_guard_token_2022_ext_open_ir

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
    throwError s!"{module}: extension-open facade changed canonical IR: {actual}"

elab "#pf_guard_token_2022_ext_open_digest" : command => do
  expectCanonical `Examples.Svm.Token2022ExtOpen "40648bdc16780654"

#pf_guard_token_2022_ext_open_digest

end Tests.SvmToken2022ExtOpenSpec