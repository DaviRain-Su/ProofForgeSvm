import ProofForge.Svm.Prelude

namespace Examples.Svm.Token2022Pause
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

/-- Token-2022 TransferChecked over a pausable mint; the token program owns the pause
semantics over the CPI boundary. -/
@[pf_entry]
def transferPause (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedPausable amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.Token2022Pause