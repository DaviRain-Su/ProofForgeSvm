import ProofForge.Svm.Prelude

namespace Examples.Svm.Token2022CpiGuard
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

/-- Token-2022 TransferChecked whose source carries the CpiGuard extension; a locked
source is rejected on-chain by the token program because this CPI runs at stack
height ≥ 2 with an owner signature. -/
@[pf_entry]
def transferGuarded (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedCpiGuard amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.Token2022CpiGuard