import Lake
open Lake DSL

package «proofforge» where
  version := v!"0.0.1"

require solanalib from git
  "https://github.com/solana-foundation/leanprover-solanalib.git" @
  "6c115ef1ef6a0cde8dbd6fd875b7dc87d60939ec"

require sbpfSemantics from git
  "https://github.com/DaviRain-Su/assembler-semantics.git" @ "64770b7a68c735f5ff6eea73f0d322daf34d7cad"

/-- Shared Attr + Core/Crypto surface, now maintained in ProofForgeCommon.
    `ProofForge.Svm.Attr` (below) extends the shared attributes with the SVM
    packed wire-entry adapters. -/
require «proofforge-common» from git
  "https://github.com/DaviRain-Su/ProofForgeCommon.git" @ "v0.1.0"

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
    `ProofForge.Svm.Sdk.Queue,
    `ProofForge.Svm.Sdk.ReturnData,
    `ProofForge.Svm.Sdk.Hash,
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

/-- Compiler: Extract, Svm IR/Emit/Assemble/Registry, and the `ProofForge` umbrella.
    The lib is named `ProofForgeSvm` (not `ProofForge`): a lean_lib name claims its
    namespace for this package and would shadow the `ProofForge.Core.*` /
    `ProofForge.Crypto.*` modules exported by `proofforge-common`. -/
@[default_target]
lean_lib ProofForgeSvm where
  globs := #[
    .one `ProofForge,
    .one `ProofForge.Cli,
    .one `ProofForge.Svm.Attr,
    .submodules `ProofForge.Svm,
    .one `ProofForge.Extract,
    .submodules `ProofForge.Extract
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
