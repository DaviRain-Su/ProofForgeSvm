import ProofForge

namespace Examples.Svm.TokenMintBurn
structure State where
  dummy : UInt64
  deriving Repr, DecidableEq, Inhabited

inductive Error where
  | overflow
  deriving Repr, DecidableEq, Inhabited, BEq

@[pf_entry]
def init (_seed : UInt64) : State :=
  { dummy := 0 }

/-- Token MintTo（tag 7）；mint authority = 账户 0。 -/
@[pf_entry]
def mint (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token.mintTo amount
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow

/-- Token Burn（tag 8）；owner = 账户 0。 -/
@[pf_entry]
def burn (_s : State) (amount : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token.burn amount
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow

/-- Token InitializeAccount2（tag 16）；owner = 账户 0。 -/
@[pf_entry]
def openAcc2 (_s : State) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := ProofForge.Svm.Sdk.Token.initializeAccount2
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow
@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.TokenMintBurn
