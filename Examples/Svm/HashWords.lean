import ProofForge.Svm.Prelude

namespace Examples.Svm.HashWords
open ProofForge.Svm.Runtime

structure State where
  dummy : UInt64
  deriving Repr, DecidableEq, Inhabited

inductive Error where
  | overflow
  deriving Repr, DecidableEq, Inhabited, BEq

@[pf_entry]
def init (_seed : UInt64) : State :=
  { dummy := 0 }

/-- 无参 mutate 占入口。 -/
@[pf_entry]
def touch (_s : State) : Except Error (State × UInt64) :=
  if (0 : UInt64) ≠ 1 then
    .ok ({ dummy := 0 }, 0)
  else
    .error .overflow

@[pf_entry]
def get (_s : State) : UInt64 :=
  0

/-- `sha256("vault")` digest 的第 0 个小端 u64。 -/
@[pf_entry]
def shaW0 (_s : State) : UInt64 :=
  sha256LitWord "vault" 0

/-- `sha256("vault")` digest 的第 1 个小端 u64。 -/
@[pf_entry]
def shaW1 (_s : State) : UInt64 :=
  sha256LitWord "vault" 1

/-- `sha256("vault")` digest 的第 2 个小端 u64。 -/
@[pf_entry]
def shaW2 (_s : State) : UInt64 :=
  sha256LitWord "vault" 2

/-- `sha256("vault")` digest 的第 3 个小端 u64。 -/
@[pf_entry]
def shaW3 (_s : State) : UInt64 :=
  sha256LitWord "vault" 3

/-- `keccak256("vault")` digest 的第 0 个小端 u64。 -/
@[pf_entry]
def keccakW0 (_s : State) : UInt64 :=
  keccak256LitWord "vault" 0

/-- `keccak256("vault")` digest 的第 1 个小端 u64。 -/
@[pf_entry]
def keccakW1 (_s : State) : UInt64 :=
  keccak256LitWord "vault" 1

/-- `keccak256("vault")` digest 的第 2 个小端 u64。 -/
@[pf_entry]
def keccakW2 (_s : State) : UInt64 :=
  keccak256LitWord "vault" 2

/-- `keccak256("vault")` digest 的第 3 个小端 u64。 -/
@[pf_entry]
def keccakW3 (_s : State) : UInt64 :=
  keccak256LitWord "vault" 3

end Examples.Svm.HashWords
