import ProofForge.Attr
import ProofForge.Svm.Runtime
import ProofForge.Svm.Telemetry

/-!
# Source-facing SVM telemetry

Safe allocation-free wrappers for Solana's remaining-compute, invocation-stack, and numeric
logging syscalls. Host evaluation keeps Runtime's documented stubs; extracted SVM programs lower
through one target-owned Telemetry component.
-/

namespace ProofForge.Svm.Sdk.Telemetry

@[pf_inline] def remainingComputeUnits : UInt64 :=
  ProofForge.Svm.Runtime.remainingComputeUnits

/-- Transaction-level instructions observe height 1; each nested CPI increases it by one. -/
@[pf_inline] def stackHeight : UInt64 :=
  ProofForge.Svm.Runtime.stackHeight

/-- Emit Solana's standard compute-unit diagnostic line. It does not return the remaining value. -/
@[pf_inline] def logComputeUnits : UInt64 :=
  ProofForge.Svm.Runtime.logComputeUnits

/-- Emit five `UInt64` values with Solana's allocation-free hexadecimal numeric logger. -/
@[pf_inline] def log64
    (first second third fourth fifth : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.log64 first second third fourth fifth

/-- Emit one UTF-8 program log line through `sol_log_`. The message is a compile-time string;
the emitter places it in the ELF rodata pool, so no runtime pointer is formed. -/
@[pf_inline] def log (message : String) : UInt64 :=
  ProofForge.Svm.Runtime.log message

/--
Failing halt with the official `sol_panic_` terminal. Source code must treat every following
statement as unreachable; the host stub's value is meaningless.
-/
@[pf_inline] def panic : UInt64 :=
  ProofForge.Svm.Runtime.panic

/--
Failing halt with the official `abort` terminal, for compiler-internal unreachable paths.
Same unreachable-after discipline as `panic`.
-/
@[pf_inline] def abort : UInt64 :=
  ProofForge.Svm.Runtime.abort


/-!
### sf-014：Telemetry L1 形状

仅 Runtime 叶包装；无持久模型。矩阵标 **n/a-L2**。
-/

theorem remainingComputeUnits_def :
    remainingComputeUnits = ProofForge.Svm.Runtime.remainingComputeUnits := rfl
theorem stackHeight_def :
    stackHeight = ProofForge.Svm.Runtime.stackHeight := rfl

end ProofForge.Svm.Sdk.Telemetry
