import ProofForge.Svm.Memory
import ProofForge.Svm.Runtime

/-!
# SVM SDK bounded runtime-hash facade

Single-slice account-data hashing over the official `sol_sha256` / `sol_keccak256` syscalls. A span
carries compile-time account/offset/length geometry only; extraction erases it to one SolBytes
descriptor per call. Slice concatenation (multi-slice), runtime-composed buffers, Blake3, SHA-512,
Poseidon, and secp256k1 recovery remain fail-closed in this profile.
-/

namespace ProofForge.Svm.Sdk.Hash

/-- Official digest width in bytes. -/
def digestBytes : Nat := 32

/-- Bounded single-slice span length accepted by the data-hash leaves. -/
def maxSpanBytes : Nat := 1024

/-- SHA-256 digest word `word` (0..3) over the compile-time account-data `span`. -/
@[pf_inline] def sha256SpanWord (span : ProofForge.Svm.Memory.Span) (word : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.sha256DataWord (UInt64.ofNat span.account) (UInt64.ofNat span.offsetBytes)
    (UInt64.ofNat span.lengthBytes) word

/-- Keccak-256 digest word `word` (0..3) over the compile-time account-data `span`. -/
@[pf_inline] def keccak256SpanWord (span : ProofForge.Svm.Memory.Span) (word : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.keccak256DataWord (UInt64.ofNat span.account)
    (UInt64.ofNat span.offsetBytes) (UInt64.ofNat span.lengthBytes) word

end ProofForge.Svm.Sdk.Hash
