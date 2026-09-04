import ProofForge.Svm.Prelude

namespace Examples.Svm.Token2022ExtOpen
open ProofForge.Svm.Sdk

structure State where
  dummy : UInt64
  deriving Repr, DecidableEq, Inhabited

inductive Error where
  | overflow
  deriving Repr, DecidableEq, Inhabited, BEq

@[pf_entry]
def init (_seed : UInt64) : State :=
  { dummy := 0 }

/-- MemoTransfer-flagged destination transfer (admission only; the token program owns
the NoMemo rejection). -/
@[pf_entry]
def transferMemo (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedMemoTransfer amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- TransferHook mint + TransferHookAccount destination transfer (admission only; hook
CPI emission stays with the token program). -/
@[pf_entry]
def transferHook (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedTransferHook amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- DefaultAccountState mint transfer (transfer-neutral admission). -/
@[pf_entry]
def transferDas (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedDefaultAccountState amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- MetadataPointer mint transfer (transfer-neutral admission). -/
@[pf_entry]
def transferMdptr (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedMetadataPointer amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- GroupPointer mint transfer (transfer-neutral admission). -/
@[pf_entry]
def transferGptr (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedGroupPointer amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- GroupMemberPointer mint transfer (transfer-neutral admission). -/
@[pf_entry]
def transferGmptr (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedGroupMemberPointer amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- TokenGroup mint transfer (transfer-neutral admission). -/
@[pf_entry]
def transferTgrp (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedTokenGroup amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- TokenGroupMember mint transfer (transfer-neutral admission). -/
@[pf_entry]
def transferTgmem (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedTokenGroupMember amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.Token2022ExtOpen