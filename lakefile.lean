import Lake
open Lake DSL

package «proofforge» where
  version := v!"0.0.1"

require solanalib from git
  "https://github.com/solana-foundation/leanprover-solanalib.git" @
  "6c115ef1ef6a0cde8dbd6fd875b7dc87d60939ec"

require sbpfSemantics from git
  "https://github.com/DaviRain-Su/assembler-semantics.git" @ "64770b7a68c735f5ff6eea73f0d322daf34d7cad"

/-- Shared Attr + Core/Crypto surface used by the SVM SDK. -/
lean_lib ProofForgeCore where
  roots := #[
    `ProofForge.Attr,
    `ProofForge.Core.Codec,
    `ProofForge.Core.Collections,
    `ProofForge.Core.Math,
    `ProofForge.Core.Ops,
    `ProofForge.Core.SafeCast,
    `ProofForge.Core.Value
  ]

/-- Contract-facing SVM SDK (+ Runtime/Source needed for `pf_inline` erase). No Emit. -/
lean_lib ProofForgeSvmSdk where
  roots := #[
    `ProofForge.Svm.AccountStorage,
    `ProofForge.Svm.AccountStorage.Source,
    `ProofForge.Svm.AccountView,
    `ProofForge.Svm.Cpi.TokenTlv,
    `ProofForge.Svm.Heap,
    `ProofForge.Svm.Memo,
    `ProofForge.Svm.Memory,
    `ProofForge.Svm.Runtime,
    `ProofForge.Svm.Scratch,
    `ProofForge.Svm.Sdk,
    `ProofForge.Svm.Sdk.Account,
    `ProofForge.Svm.Sdk.AssociatedToken,
    `ProofForge.Svm.Sdk.Memo,
    `ProofForge.Svm.Sdk.Memory,
    `ProofForge.Svm.Sdk.Pda,
    `ProofForge.Svm.Sdk.Program,
    `ProofForge.Svm.Sdk.Pubkey,
    `ProofForge.Svm.Sdk.Queue,
    `ProofForge.Svm.Sdk.Storage,
    `ProofForge.Svm.Sdk.StorageBitSet,
    `ProofForge.Svm.Sdk.StorageEnumerableSet,
    `ProofForge.Svm.Sdk.System,
    `ProofForge.Svm.Sdk.Sysvar,
    `ProofForge.Svm.Sdk.Telemetry,
    `ProofForge.Svm.Sdk.Token,
    `ProofForge.Svm.Sdk.Transient,
    `ProofForge.Svm.Sdk.TransientBytes,
    `ProofForge.Svm.Sdk.TransientRecord64,
    `ProofForge.Svm.Sdk.TransientVec,
    `ProofForge.Svm.Sdk.TransientWideVec,
    `ProofForge.Svm.Sdk.Versioned,
    `ProofForge.Svm.Seed,
    `ProofForge.Svm.Telemetry,
    `ProofForge.Svm.TransientBytes,
    `ProofForge.Svm.TransientVec
  ]

/-- Compiler: Extract, Svm IR/Emit/Assemble/Registry, and the `ProofForge` umbrella. -/
@[default_target]
lean_lib ProofForge where
  roots := #[
    `ProofForge,
    `ProofForge.Cli,
    `ProofForge.Core.CFG,
    `ProofForge.Core.Eval,
    `ProofForge.Core.FixedPoint,
    `ProofForge.Core.IR,
    `ProofForge.Core.Schema,
    `ProofForge.Core.Target,
    `ProofForge.Crypto.Keccak,
    `ProofForge.Crypto.Sha256,
    `ProofForge.Crypto.Sha256Compat,
    `ProofForge.Extract,
    `ProofForge.Extract.Compat,
    `ProofForge.Extract.Decode,
    `ProofForge.Extract.IR,
    `ProofForge.Extract.LegacyAdapter,
    `ProofForge.Extract.LegacyEval,
    `ProofForge.Extract.LegacyGolden,
    `ProofForge.Extract.LegacyIR,
    `ProofForge.Extract.LegacyOps,
    `ProofForge.Extract.Lexical,
    `ProofForge.Extract.Ops,
    `ProofForge.Profile,
    `ProofForge.Svm.ABI,
    `ProofForge.Svm.ABICompat,
    `ProofForge.Svm.AccountData,
    `ProofForge.Svm.AccountData.Emit,
    `ProofForge.Svm.AccountStorage.Emit,
    `ProofForge.Svm.AccountView.Emit,
    `ProofForge.Svm.Assemble,
    `ProofForge.Svm.AssembleCompat,
    `ProofForge.Svm.AssembleMain,
    `ProofForge.Svm.BatchRecorder,
    `ProofForge.Svm.BatchRecorder.Emit,
    `ProofForge.Svm.BatchRecorder.Source,
    `ProofForge.Svm.Commands,
    `ProofForge.Svm.Component,
    `ProofForge.Svm.Component.Emit,
    `ProofForge.Svm.Cpi.Emit,
    `ProofForge.Svm.Cpi.TokenTlv.Emit,
    `ProofForge.Svm.Emit,
    `ProofForge.Svm.EmitCompat,
    `ProofForge.Svm.EntryAdapter,
    `ProofForge.Svm.EntryAdapter.Emit,
    `ProofForge.Svm.FifoCancel,
    `ProofForge.Svm.FifoCancel.Emit,
    `ProofForge.Svm.FifoCancel.Source,
    `ProofForge.Svm.Heap.Emit,
    `ProofForge.Svm.IR,
    `ProofForge.Svm.IRCompat,
    `ProofForge.Svm.Idl,
    `ProofForge.Svm.IdlCompat,
    `ProofForge.Svm.Lamports,
    `ProofForge.Svm.Lamports.Emit,
    `ProofForge.Svm.Memory.Emit,
    `ProofForge.Svm.Ops,
    `ProofForge.Svm.Registry,
    `ProofForge.Svm.Sdk.StorageModel,
    `ProofForge.Svm.Semantics,
    `ProofForge.Svm.SemanticsBridge,
    `ProofForge.Svm.Solanalib,
    `ProofForge.Svm.SolanalibSkipChain,
    `ProofForge.Svm.Sysvar,
    `ProofForge.Svm.Sysvar.Emit,
    `ProofForge.Svm.Telemetry.Emit,
    `ProofForge.Svm.Transient.Emit,
    `ProofForge.Svm.TransientBytes.Emit,
    `ProofForge.Svm.TransientVec.Emit
  ]

/-- Build every module under `Examples/` (SVM fixtures only). -/
lean_lib Examples where
  globs := #[.one `Examples, .submodules `Examples]

lean_lib Tests

/-- Phoenix application examples, split from the default build set so non-Phoenix
work does not pay for the 3k-line official profile. Built by the phoenix CI lane. -/
lean_lib PhoenixExamples where
  roots := #[
    `Examples.Svm.Phoenix,
    `Examples.Svm.PhoenixV1Layout,
    `Examples.Svm.PhoenixV1Profile
  ]

/-- Phoenix spec gates (PhoenixSpec / PhoenixV1ProfileSpec / PhoenixBuildSpec), split
from `Tests` so the lean lane skips the ~15-minute profile-spec elaboration. -/
lean_lib PhoenixTests where
  roots := #[
    `Tests.PhoenixBuildSpec,
    `Tests.PhoenixSpec,
    `Tests.PhoenixV1ProfileSpec
  ]

lean_exe pfAssemble where
  root := `ProofForge.Svm.AssembleMain

lean_exe pf where
  root := `ProofForge.Cli
  supportInterpreter := true
