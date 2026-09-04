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
Authorize external account 3 as the new nonce authority. Outer accounts: state(0) /
nonce(1 w) / current_authority(2 s) / new_authority(3 r) / System(4).
-/
@[pf_entry]
def reauthNonce (_s : State) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := System.authorizeNonce
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow

/--
Withdraw `lamports` from the nonce account (external 2) into external 3. Outer accounts:
state(0) / authority(1 s) / nonce(2 w) / dest(3 w) / recent(4 r) / rent(5 r) / System(6).
-/@[pf_entry]
def withdrawNonce (_s : State) (lamports : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := System.withdrawNonce lamports
    .ok ({ dummy := 0 }, lamports)
  else
    .error .overflow

/--
Upgrade the legacy `Versions::Legacy` nonce account at external account 1 to `Current`.
Outer accounts: state(0) / nonce(1 w) / System(2).
-/@[pf_entry]
def upgradeNonce (_s : State) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    let _ := System.upgradeNonce
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

end Examples.Svm.NonceLife