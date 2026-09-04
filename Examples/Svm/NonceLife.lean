import ProofForge.Svm.Prelude

namespace Examples.Svm.NonceLife
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

/--
Create a rent-exempt 80-byte account at external account 2, funded by external account 1
(the payer). Outer accounts: state(0) / payer(1 s+w) / new(2 s+w) / System(3).
-/
@[pf_entry]
def openNonce (_s : State) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := System.createRentExempt 80
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow

/--
Initialize external account 1 as a durable nonce; authority = outer 0. Outer accounts:
state(0 s) / nonce(1 w) / rent(2 r) / System(3).
-/
@[pf_entry]
def initNonce (_s : State) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := System.initializeNonce
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow

/--
Authorize outer 0 as the new nonce authority. Outer accounts: state(0 s) / nonce(1 w) /
System(2).
-/
@[pf_entry]
def reauthNonce (_s : State) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := System.authorizeNonce
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.NonceLife