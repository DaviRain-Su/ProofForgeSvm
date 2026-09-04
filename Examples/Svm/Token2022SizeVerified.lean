import ProofForge.Svm.Prelude

namespace Examples.Svm.Token2022SizeVerified
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

/-- Token-2022 `GetAccountDataSize`；先 CPI，再校验返回长度恰为 8 且设置者恰为 Token-2022。 -/
@[pf_entry]
def size (_s : State) : Except Error (State × UInt64) :=
  let _ := ProofForge.Svm.Sdk.Token.baseAccountDataSize
  if ProofForge.Svm.Sdk.ReturnData.len == 8 &&
      ProofForge.Svm.Sdk.ReturnData.setterIs ProofForge.Svm.Sdk.Program.token2022.key then
    .ok ({ dummy := ProofForge.Svm.Runtime.cpiReturn }, ProofForge.Svm.Runtime.cpiReturn)
  else
    .error .wrongProgram

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.Token2022SizeVerified
