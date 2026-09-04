import ProofForge.Svm.Ops
import ProofForge.Svm.Telemetry

namespace ProofForge.Svm.Telemetry.Emit

structure Context where
  loadValue : Ops.Val → Nat → Nat → String → Except String String

def emitQuery (query : Query) (operands : Array Ops.Val) (stackOff : Nat) :
    Except String String :=
  match query, operands with
  | .remainingComputeUnits, #[] =>
      .ok s!"  call sol_remaining_compute_units\n  stxdw [r10 - {stackOff}], r0\n"
  | .stackHeight, #[] =>
      .ok s!"  call sol_get_stack_height\n  stxdw [r10 - {stackOff}], r0\n"
  | _, _ => .error "extract/ir: malformed SVM telemetry query operands"

/-- One read-only rodata string entry; `Emit.collectRoData` pools these into the trailing
`.rodata` section that the `sbpf` assembler grammar requires. -/
private def emitRoDataString (label message : String) : String :=
  let escaped := message.foldl (init := "") fun acc c =>
    acc ++ if c == '"' then "\\\"" else String.singleton c
  s!"  .section rodata\n  rodata_{label}_msg:\n  .ascii \"{escaped}\"\n  .text\n"

def emitCall (context : Context) (label : String) : Call Ops.Val → Except String String
  | .logComputeUnits => return "  call sol_log_compute_units_\n"
  | .log64 first second third fourth fifth => do
      let loadFirst ← context.loadValue first 8 0 s!"{label}_first"
      let loadSecond ← context.loadValue second 16 1 s!"{label}_second"
      let loadThird ← context.loadValue third 24 2 s!"{label}_third"
      let loadFourth ← context.loadValue fourth 32 3 s!"{label}_fourth"
      let loadFifth ← context.loadValue fifth 40 4 s!"{label}_fifth"
      return loadFirst ++ loadSecond ++ loadThird ++ loadFourth ++ loadFifth ++
        "  ldxdw r1, [r10 - 8]\n" ++
        "  ldxdw r2, [r10 - 16]\n" ++
        "  ldxdw r3, [r10 - 24]\n" ++
        "  ldxdw r4, [r10 - 32]\n" ++
        "  ldxdw r5, [r10 - 40]\n" ++
        "  call sol_log_64_\n"
  | .log message =>
      -- sol_log_ takes (ptr, len) in r1/r2. The payload lives in a read-only ELF rodata
      -- section emitted beside the program; no stack scratch, no heap, no account bytes.
      let lit := emitRoDataString label message
      return lit ++
        "  lddw r1, rodata_" ++ label ++ "_msg\n" ++
        "  lddw r2, " ++ toString message.utf8ByteSize ++ "\n" ++
        "  call sol_log_\n"
  | .panic =>
      -- Official ABI: r1 = file ptr, r2 = len, r3 = line, r4 = column. A zero-length
      -- file string keeps the CU cost at the syscall's flat base.
      return "  lddw r1, 0\n  lddw r2, 0\n  lddw r3, 0\n  lddw r4, 0\n  call sol_panic_\n"
  | .abort => return "  call abort\n"

end ProofForge.Svm.Telemetry.Emit
