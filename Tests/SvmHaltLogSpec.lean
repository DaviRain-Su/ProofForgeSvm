import Examples.Svm.HaltLog

namespace Tests.SvmHaltLogSpec

open Lean Elab Command
open Examples.Svm.HaltLog
open ProofForge.Svm

#guard ProofForge.Svm.Sdk.Telemetry.panic == 0
#guard ProofForge.Svm.Sdk.Telemetry.abort == 0
#guard announce == 7

elab "#pf_guard_halt_log_ir" : command => do
  let env ← getEnv
  let extracted ←
    match ProofForge.Extract.extractModuleIR env `Examples.Svm.HaltLog with
    | .ok program => pure program
    | .error reason => throwError reason
  let program ←
    match IR.fromExtracted extracted with
    | .ok program => pure program
    | .error reason => throwError reason
  let some announceMethod := program.methods.find? (·.ixName == "announce")
    | throwError "missing HaltLog announce method"
  unless announceMethod.ops.contains (.component (.telemetry (.log "halt-log: announce"))) do
    throwError s!"telemetry log call was not retained: {repr announceMethod.ops}"
  let some boomMethod := program.methods.find? (·.ixName == "boom")
    | throwError "missing HaltLog boom method"
  unless boomMethod.ops.contains (.component (.telemetry .panic)) do
    throwError s!"telemetry panic call was not retained: {repr boomMethod.ops}"
  let some crashMethod := program.methods.find? (·.ixName == "crash")
    | throwError "missing HaltLog crash method"
  unless crashMethod.ops.contains (.component (.telemetry .abort)) do
    throwError s!"telemetry abort call was not retained: {repr crashMethod.ops}"
  let asm ←
    match Emit.emitAsm program with
    | .ok asm => pure asm
    | .error reason => throwError reason
  unless asm.contains "call sol_log_" &&
      asm.contains "call sol_panic_" &&
      asm.contains "  call abort" &&
      asm.contains ".section rodata" &&
      asm.contains ".ascii \"halt-log: announce\"" do
    throwError "sol_log_/sol_panic_/abort lowering missing from assembly"
  let pooled := Emit.collectRoData asm
  unless pooled.contains "\n.rodata\n" &&
      pooled.contains "rodata_announce_b0_0_msg:" &&
      !pooled.contains ".section rodata" do
    throwError "collectRoData did not pool the rodata fragments"

#pf_guard_halt_log_ir

private def expectCanonical (module : Name) (expected : String) : CommandElabM Unit := do
  let env ← getEnv
  let source ←
    match ProofForge.Extract.extractModuleIR env module with
    | .ok source => pure source
    | .error reason => throwError reason
  let program ←
    match ProofForge.Svm.IR.fromExtracted source with
    | .ok program => pure program
    | .error reason => throwError reason
  let actual := ProofForge.Svm.IR.digestHex program
  unless actual == expected do
    throwError s!"{module}: halt/log facade changed canonical IR: {actual}"

elab "#pf_guard_halt_log_digest" : command => do
  expectCanonical `Examples.Svm.HaltLog "2180b645ab5ac664"

#pf_guard_halt_log_digest

end Tests.SvmHaltLogSpec