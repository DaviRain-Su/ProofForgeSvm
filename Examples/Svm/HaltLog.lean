import ProofForge.Svm.Prelude

namespace Examples.Svm.HaltLog
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

/-- Emit a compile-time UTF-8 log line; returns a fixed value. -/
@[pf_entry]
def announce : UInt64 :=
  let _ := ProofForge.Svm.Sdk.Telemetry.log "halt-log: announce"
  7

/-- Unconditional official panic halt; never returns on-chain. -/
@[pf_entry]
def boom (_s : State) : UInt64 :=
  ProofForge.Svm.Sdk.Telemetry.panic

/-- Unconditional official abort halt; never returns on-chain. -/
@[pf_entry]
def crash (_s : State) : UInt64 :=
  ProofForge.Svm.Sdk.Telemetry.abort

/-- Stamp the value into state; gives the program one honest mutating entry. -/
@[pf_entry]
def stamp (_s : State) (value : UInt64) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    .ok ({ dummy := value }, value)
  else
    .error .overflow

@[pf_entry]
def get (s : State) : UInt64 :=
  s.dummy

end Examples.Svm.HaltLog