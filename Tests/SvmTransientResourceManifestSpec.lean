import Lean
import ProofForge.Svm.Prelude
import ProofForge.Svm.Sdk.TransientBytes
import ProofForge.Svm.Sdk.TransientVec
import ProofForge.Svm.TransientBytes
import ProofForge.Svm.TransientVec

/-!
`svm-sdk-004` resource-manifest gate checks.

Same-kind transient handles stay compile-time bounded. The packed deep-scratch layout derives
from the manifest: the historical 2+2 default reproduces the fixed emitter offsets, and
declaring more slots extends the same region upward until the packed end crosses the
account-storage temporal-reuse boundary at 2680. No runtime-dynamic slot count and no
half-open third-handle SDK surface.
-/

namespace Tests.SvmTransientResourceManifestSpec

open Lean Elab Command
open ProofForge.Svm
open ProofForge.Svm.Sdk.Transient

-- Default budget matches the historical two-slot packed layout.
#guard defaultManifest.vectorSlots == 2
#guard defaultManifest.bytesSlots == 2
#guard defaultManifest.wellFormed
#guard defaultManifest.admitsVectorSlot 0
#guard defaultManifest.admitsVectorSlot 1
#guard !defaultManifest.admitsVectorSlot 2
#guard defaultManifest.admitsBytesSlot 0
#guard defaultManifest.admitsBytesSlot 1
#guard !defaultManifest.admitsBytesSlot 2

-- The historical manifest reproduces the emitter's fixed offsets exactly.
#guard defaultManifest.vectorSlotBase 0 == TransientVec.pointerStack
#guard defaultManifest.vectorSlotBase 1 == TransientVec.pointerStack + slotStride
#guard defaultManifest.bytesSlotBase 0 == TransientBytes.pointerStack
#guard defaultManifest.bytesSlotBase 1 == TransientBytes.pointerStack + slotStride
#guard defaultManifest.descriptorBase + 16 == TransientBytes.descriptorStack

-- Shared deep-scratch budget: 2+2 and 3+2 and 2+3 fit; 3+3 and 4+2 cross the
-- account-storage temporal-reuse boundary and fail closed.
#guard ({ vectorSlots := 3, bytesSlots := 2 } : ResourceManifest).wellFormed
#guard ({ vectorSlots := 2, bytesSlots := 3 } : ResourceManifest).wellFormed
#guard !({ vectorSlots := 3, bytesSlots := 3 } : ResourceManifest).wellFormed
#guard !({ vectorSlots := 4, bytesSlots := 2 } : ResourceManifest).wellFormed
#guard !({ vectorSlots := 2, bytesSlots := 4 } : ResourceManifest).wellFormed
#guard !({ vectorSlots := 0, bytesSlots := 2 } : ResourceManifest).wellFormed
#guard !({ vectorSlots := 2, bytesSlots := 0 } : ResourceManifest).wellFormed

-- A tightened one-slot manifest still admits slot 0 and rejects slot 1.
def oneVector : ResourceManifest := { vectorSlots := 1, bytesSlots := 2 }
#guard oneVector.wellFormed
#guard oneVector.admitsVectorSlot 0
#guard !oneVector.admitsVectorSlot 1
#guard oneVector.admitsBytesSlot 1

-- Config gates compose the manifest: historical slots stay open; slot >= 2 needs a manifest
-- that admits it.
def vectorSlot0 : TransientVec.Config := { capacity := 4 }
def vectorSlot1 : TransientVec.Config := { capacity := secondSlotWord 4 }
def vectorSlot2 : TransientVec.Config := { capacity := slotWord 4 2 }
def bytesSlot0 : TransientBytes.Config := { capacity := 16 }
def bytesSlot1 : TransientBytes.Config := { capacity := secondSlotWord 16 }
def bytesSlot2 : TransientBytes.Config := { capacity := slotWord 16 2 }

#guard TransientVec.Config.wellFormed vectorSlot0
#guard TransientVec.Config.wellFormed vectorSlot1
#guard !TransientVec.Config.wellFormed vectorSlot2
#guard !TransientVec.Config.wellFormed vectorSlot1 oneVector
#guard TransientBytes.Config.wellFormed bytesSlot0
#guard TransientBytes.Config.wellFormed bytesSlot1
#guard !TransientBytes.Config.wellFormed bytesSlot2
#guard handleSlot (slotWord 4 2) == 2
#guard handlePayload (slotWord 4 2) == 4

#guard maxHandleSlots == 5
-- Historical two-slot facades remain the only same-kind openers at the default manifest.
#guard TransientVec.Config.wellFormed (Vector64.bounded 4)
#guard TransientVec.Config.wellFormed (Vector64.boundedAlt 4)
#guard TransientBytes.Config.wellFormed (Bytes.bounded 16)
#guard TransientBytes.Config.wellFormed (Bytes.boundedAlt 16)

elab "#pf_guard_transient_resource_manifest" : command => do
  let env ← getEnv
  let transientNs := Name.mkStr (Name.mkStr (Name.mkStr (Name.mkStr .anonymous
    "ProofForge") "Svm") "Sdk") "Transient"
  -- Reject accidental half-open third-slot facades before deep-scratch remapping.
  let vector64 := Name.mkStr transientNs "Vector64"
  let bytes := Name.mkStr transientNs "Bytes"
  let forbidden :=
    (["boundedAlt2", "bounded2", "boundedThird", "thirdSlotWord", "thirdHandle"].map
      (Name.mkStr transientNs)) ++
    (["boundedAlt2", "bounded2", "boundedThird"].map (Name.mkStr vector64)) ++
    (["boundedAlt2", "bounded2", "boundedThird"].map (Name.mkStr bytes))
  for name in forbidden do
    if (env.find? name).isSome then
      throwError s!"svm-sdk-004 policy violation: unexpected third-slot facade {name}"
  let manifest := Name.mkStr transientNs "ResourceManifest"
  let defaultM := Name.mkStr transientNs "defaultManifest"
  unless (env.find? manifest).isSome do
    throwError "missing Sdk.Transient.ResourceManifest"
  unless (env.find? defaultM).isSome do
    throwError "missing Sdk.Transient.defaultManifest"

#pf_guard_transient_resource_manifest

end Tests.SvmTransientResourceManifestSpec
