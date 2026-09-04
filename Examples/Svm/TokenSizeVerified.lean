import ProofForge.Svm.Prelude

namespace Examples.Svm.TokenSizeVerified
structure State where
  dummy : UInt64
  deriving Repr, DecidableEq, Inhabited

inductive Error where
  | overflow
  | wrongProgram
  deriving Repr, DecidableEq, Inhabited, BEq

@[pf_entry]
def init (_seed : UInt64) : State :=
  { dummy := 0 }

/-- Token `GetAccountDataSize`；先 CPI，再校验返回数据设置者恰为 classic Token。 -/
@[pf_entry]
def size (_s : State) : Except Error (State × UInt64) :=
  let _ := ProofForge.Svm.Sdk.Token.baseAccountDataSize
  if ProofForge.Svm.Sdk.ReturnData.setterIs ProofForge.Svm.Sdk.Program.classicToken.key then
    .ok ({ dummy := ProofForge.Svm.Runtime.cpiReturn }, ProofForge.Svm.Runtime.cpiReturn)
  else
    .error .wrongProgram

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.TokenSizeVerified
