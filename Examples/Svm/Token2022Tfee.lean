import ProofForge

namespace Examples.Svm.Token2022Tfee
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

/-- Token-2022 TransferChecked over a transfer-fee mint; the token program charges the fee. -/
@[pf_entry]
def transferTfee (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedTransferFee amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.Token2022Tfee