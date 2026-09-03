import Examples.Lang
import Tests.Fixtures

open Lean Elab Command

namespace Tests.LangSpec

open Examples.Lang

#guard (init 7).cells[0]! == 7
#guard get (init 7) == 7
#guard band (init 0) 0xf0 0x0f == 0
#guard bor (init 0) 0xf0 0x0f == 0xff
#guard bxor (init 0) 0xff 0x0f == 0xf0
#guard bnot (init 0) 0 == u64Max
#guard shl (init 0) 1 3 == 8
#guard shr (init 0) 8 3 == 1
#guard shl (init 0) 1 65 == 2
#guard shr (init 0) 8 67 == 1
#guard mask8 (init 0) 7 == 7
#guard Tests.Fixtures.getNarrowPrevious (Tests.Fixtures.initNarrow 7) 0 == 7
#guard
  match both (init 9) with
  | (a, b) => a == 9 && b == 0

#guard
  match ProofForge.Svm.Emit.emitCounterAsm ProofForge.Golden.extractedLang with
  | .error _ => false
  | .ok asm =>
      asm.contains "and64" &&
        asm.contains "lsh64" &&
        asm.contains "and64 r2, 63" &&
        asm.contains "cfg_sum4_block_1:\n  ; load local 0" &&
        asm.contains "named error"

elab "#pf_guard_narrow_vector_codegen" : command => do
  let env ← getEnv
  let program ←
    match ProofForge.Extract.extractProgramIR env ``Tests.Fixtures.initNarrow
        ``Tests.Fixtures.setNarrow ``Tests.Fixtures.getNarrow with
    | .ok program => pure program
    | .error reason => throwError reason
  let svm ←
    match ProofForge.Svm.Emit.emitProgramAsm program with
    | .ok asm => pure asm
    | .error reason => throwError reason
  unless svm.contains "ldxb r1, [r1 + 0]" && svm.contains "stxb [r1 + 0], r3" do
    throwError "SVM indexed UInt8 leaves are not using byte loads/stores"

#pf_guard_narrow_vector_codegen

elab "#pf_guard_nat_sub_semantics" : command => do
  let env ← getEnv
  let program ←
    match ProofForge.Extract.extractProgramIR env ``Tests.Fixtures.initNarrow
        ``Tests.Fixtures.setNarrow ``Tests.Fixtures.getNarrowPrevious with
    | .ok program => pure program
    | .error reason => throwError reason
  let asm ←
    match ProofForge.Svm.Emit.emitProgramAsm program with
    | .ok asm => pure asm
    | .error reason => throwError reason
  unless asm.contains "call __pf_nat_sub_u64" do
    throwError "Nat.sub was not lowered as saturating subtraction"

#pf_guard_nat_sub_semantics

end Tests.LangSpec
