import ProofForge

namespace Examples.Svm.TokenMultisig
structure State where
  dummy : UInt64
  deriving Repr, DecidableEq, Inhabited

inductive Error where
  | overflow
  deriving Repr, DecidableEq, Inhabited, BEq

@[pf_entry]
def init (_seed : UInt64) : State :=
  { dummy := 0 }

/-- Token TransferChecked，multisig authority（m=2）；两个 signer = 外层 0/1。 -/
@[pf_entry]
def transferMs2 (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token.transferCheckedMs2 amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- Token ApproveChecked，multisig authority（m=2）；两个 signer = 外层 0/1。 -/
@[pf_entry]
def approveMs2 (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token.approveCheckedMs2 amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.TokenMultisig
