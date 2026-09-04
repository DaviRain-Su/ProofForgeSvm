import ProofForge.Svm.Prelude

namespace Examples.Svm.HashDataKeccak
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

/-- 账户 1 数据区前 32 字节的 Keccak-256 digest 第 0 个小端 u64。 -/
@[pf_entry]
def dataW0 (_s : State) : UInt64 :=
  keccak256DataWord 1 0 32 0

/-- 账户 1 数据区前 32 字节的 Keccak-256 digest 第 1 个小端 u64。 -/
@[pf_entry]
def dataW1 (_s : State) : UInt64 :=
  keccak256DataWord 1 0 32 1

/-- 账户 1 数据区前 32 字节的 Keccak-256 digest 第 2 个小端 u64。 -/
@[pf_entry]
def dataW2 (_s : State) : UInt64 :=
  keccak256DataWord 1 0 32 2

/-- 账户 1 数据区前 32 字节的 Keccak-256 digest 第 3 个小端 u64。 -/
@[pf_entry]
def dataW3 (_s : State) : UInt64 :=
  keccak256DataWord 1 0 32 3

/-- 账户 1 数据区 `[4, 36)` 的 Keccak-256 digest 第 0 个小端 u64。 -/
@[pf_entry]
def sliceW0 (_s : State) : UInt64 :=
  keccak256DataWord 1 4 32 0

end Examples.Svm.HashDataKeccak
