import ProofForge.Svm.Runtime
import ProofForge.Svm.Sdk.Pubkey

/-!
# SVM SDK bounded CPI return-data facade

Compile-time-capacity policy over the official `sol_get_return_data` semantics. Return data is a
per-transaction global buffer (hard limit `MAX_RETURN_DATA = 1024`) paired with the most recent
setter's program id; every CPI clears it on entry, and the callee that produced it may sit deeper
than the direct callee, so consumers must authenticate the setter program id before trusting the
payload. This facade exposes the actual length and the setter key as compiler-erased leaves and
keeps the setter check inside the SDK, matching the upstream `solana_cpi::get_return_data`
contract. Wider payload windows remain fail-closed at the current 8-byte payload profile.
-/

namespace ProofForge.Svm.Sdk.ReturnData

/-- On-chain hard limit `MAX_RETURN_DATA` in bytes. -/
def maxBytes : Nat := 1024

/-- Actual total length in bytes of the most recent CPI return data; zero when unset. -/
@[pf_inline] def len : UInt64 :=
  ProofForge.Svm.Runtime.cpiReturnLen

/-- Word `word` (0..3) of the most recent CPI return-data setter program id. On-chain Custom(1)
when no return data is present. -/
@[pf_inline] def setterWord (word : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.cpiReturnProgramIdWord word

/-- True exactly when the most recent CPI return data was set by `expected` (complete four-word
key equality). -/
@[pf_inline] def setterIs (expected : Pubkey) : Bool :=
  Pubkey.equals (Pubkey.ofWords (setterWord 0) (setterWord 1) (setterWord 2) (setterWord 3))
    expected

end ProofForge.Svm.Sdk.ReturnData
