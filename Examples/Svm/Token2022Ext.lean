import ProofForge.Svm.Prelude

namespace Examples.Svm.Token2022Ext
structure State where
  dummy : UInt64
  deriving Repr, DecidableEq, Inhabited

inductive Error where
  | overflow
  deriving Repr, DecidableEq, Inhabited, BEq

@[pf_entry]
def init (_seed : UInt64) : State :=
  { dummy := 0 }

/-- Token-2022 TransferChecked over ImmutableOwner 账户；普通转账在 immutable owner 下仍合法。 -/
@[pf_entry]
def transferImmutable (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedImmutable amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- Token-2022 TransferChecked over NonTransferable mint/account；链上由 token program 拒绝。 -/
@[pf_entry]
def transferNonTransferable (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.transferCheckedNonTransferable amount 6
    .ok ({ dummy := 0 }, amount)
  else
    .error .overflow

/-- Token-2022 SetAuthority(AccountOwner) over ImmutableOwner 账户；链上由 token program 拒绝。 -/
@[pf_entry]
def setAuthorityImmutable (_s : State) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token2022.setAccountAuthorityImmutable
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.Token2022Ext
