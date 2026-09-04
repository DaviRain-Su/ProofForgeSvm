import ProofForge.Attr
import ProofForge.Svm.Heap
import ProofForge.Svm.Scratch

/-!
# Invocation-local transient storage

Reusable SDK contracts for memory that dies with one SVM invocation. Persistent state belongs in
fixed-capacity account bytes; these descriptors instead model bounded heap buffers, fixed vectors,
byte writers, composed scratch codecs, and a compile-time `ResourceManifest` slot budget.

The module builds on the existing target contracts rather than hiding them behind another
allocator: `Heap.State` remains the official downward bump state, `Scratch.Plan` remains the
aligned stack-bank planner, and `Scratch.Lifetime.invocationOnly` remains the sole lifetime.
Descriptors contain only compile-time geometry. A `HeapReservation` contains an allocator result
for the emitter/runtime boundary, but it is never an account-state handle. Slot counts are
manifest-bounded (`svm-sdk-004`); the default remains two same-kind handles, and declaring more
fails closed until deep-scratch geometry is remapped.
-/

namespace ProofForge.Svm.Sdk.Transient

/-! ## Reusable multi-handle identity -/

/-!
Compile-time handle slots for one transient container kind. Every bounded transient kind owns
`ResourceManifest`-declared slots (two per kind by default); each slot owns a private metadata
bank (`Svm.Transient.Emit.slotCell`: four 8-byte cells, `Svm.Transient.Emit.slotStride` bytes
apart) and its own disjoint `begin` allocation from the shared official downward bump heap.
Simultaneous same-kind handles therefore never alias metadata or payload, while `begin` on the
same slot is the historical re-open that replaces that slot's metadata only.

Handle identity never reaches top-level Ops, IR, the main emitter, or the runtime-leaf signature:
the single compiler-erased `capacity` word keeps the historical plain-payload encoding for slot 0
and packs the slot index above bit 32 for slot 1, so extraction still decodes one static literal
per operation and the target component splits the word back into capacity and slot.
-/

/-! ## Handle slots -/

/-- Deep-scratch bytes per same-kind handle slot (four 8-byte metadata cells). Must match
`Svm.Transient.Emit.slotStride`. -/
def slotStride : Nat := 32

/-- Deep-scratch bytes reserved above the same-kind slot banks for the shared
`sol_log_data` descriptor that the Bytes `logData` call builds: a 16-byte
descriptor (payload pointer + current length). -/
def descriptorBudget : Nat := 16

/-- Deep-scratch window available to transient metadata: FIFO query scratch ends at 2496, and
the account-storage scratch's temporal-reuse claim starts at 2680, so transient metadata packs
from 2496 upward. The historical 2+2 manifest packs to exactly 2632..2648; declaring more slots
extends the same region upward toward 2680. -/
def transientLowWater : Nat := 2496
def transientHighWater : Nat := 2680

/--
Maximum same-kind handle slots the deep-scratch window supports. The window is
`transientHighWater - transientLowWater`; each Vector slot and each Bytes slot takes one
`slotStride` bank, and the shared descriptor takes `descriptorBudget`. The budget is shared
across kinds: the sum of both kinds' slots must fit.
-/
def maxHandleSlots : Nat :=
  (transientHighWater - transientLowWater - descriptorBudget) / slotStride

/-- Bit weight of the slot field inside the compiler-erased handle word. -/
@[pf_inline] def handleSlotBit : Nat := 4294967296

/-- Payload capacity (or byte capacity) carried by the erased word's low 32 bits. -/
def handlePayload (word : Nat) : Nat := word % handleSlotBit

/-- Slot index carried by the erased word. -/
def handleSlot (word : Nat) : Nat := word / handleSlotBit

/-- Slot-0 handle word: the historical plain-payload encoding. -/
def firstSlotWord (payload : Nat) : Nat := payload

/-- Slot-1 handle word: the payload with its slot packed above bit 32. Additive on literals so
extraction decodes it without any new runtime leaf or opcode. -/
@[pf_inline] def secondSlotWord (payload : Nat) : Nat := payload + handleSlotBit

/-- Generalized erased handle word for a compile-time slot index. Slot 0 stays the historical
plain payload; higher slots pack `slot * handleSlotBit` above the low 32-bit payload field. -/
def slotWord (payload slot : Nat) : Nat := payload + slot * handleSlotBit

/-! ## Resource manifest (`svm-sdk-004`)

Same-kind transient handles stay compile-time bounded. The manifest declares per-kind slot
counts; the packed deep-scratch layout derives from the manifest and fails closed at the
account-storage temporal-reuse boundary. Programs declare an explicit `ResourceManifest` when
they need more than the historical two slots per kind.
-/

/-- Compile-time per-program transient slot budget. Defaults preserve the historical two-slot
ceiling per kind. -/
structure ResourceManifest where
  vectorSlots : Nat := 2
  bytesSlots : Nat := 2
  deriving BEq, Repr, Inhabited

/-- Historical default: two Vector64 slots and two Bytes slots. Its packed layout reproduces
the emitter offsets today exactly: Vector slots at `2504`/`2536`, Bytes slots at
`2568`/`2600`, descriptor base `2632` (`descriptorStack = 2648`). -/
def defaultManifest : ResourceManifest := { vectorSlots := 2, bytesSlots := 2 }
/-- Historical two-per-kind manifest alias (`svm-sdk-004`). -/
def historicalManifest : ResourceManifest := defaultManifest

/-- Deep-scratch end offset of the Vector slot region for this manifest. Slot `k` banks at
`transientLowWater + k * slotStride .. + slotStride` (exclusive). The historical manifest
maps slot 0 to `2504..2535` and slot 1 to `2536..2567`. -/
def ResourceManifest.vectorSlotBase (manifest : ResourceManifest) (slot : Nat) : Nat :=
  transientLowWater + slot * slotStride + 8

/-- Deep-scratch end offset of the Vector slot region (exclusive): the base offset of the
first Bytes slot. -/
def ResourceManifest.vectorEnd (manifest : ResourceManifest) : Nat :=
  manifest.vectorSlotBase manifest.vectorSlots

/-- Bytes slot `k` banks densely above the Vector region: base `vectorEnd + slot * slotStride`.
The historical manifest keeps slot 0 at the fixed `2568` and slot 1 at `2600` that today's
emitter offsets use. -/
def ResourceManifest.bytesSlotBase (manifest : ResourceManifest) (slot : Nat) : Nat :=
  manifest.vectorEnd + slot * slotStride

def ResourceManifest.bytesEnd (manifest : ResourceManifest) : Nat :=
  manifest.bytesSlotBase manifest.bytesSlots

/-- Base stack offset of the shared `sol_log_data` descriptor: immediately above the Bytes
region. The historical manifest maps this to `2632`, with `descriptorStack = base + 16 = 2648`. -/
def ResourceManifest.descriptorBase (manifest : ResourceManifest) : Nat :=
  manifest.bytesEnd

/-- Deep-scratch end offset including the shared descriptor (exclusive). -/
def ResourceManifest.packedEnd (manifest : ResourceManifest) : Nat :=
  manifest.descriptorBase + descriptorBudget

/-- A manifest is well-formed when every declared kind keeps at least one slot and the packed
layout (both kinds' slots plus the shared descriptor) stays inside the deep-scratch window.
The budget is shared across kinds: the sum of both kinds' slots must fit, and the historical
2+2 default must reproduce today's fixed offsets exactly. -/
def ResourceManifest.wellFormed (manifest : ResourceManifest) : Bool :=
  0 < manifest.vectorSlots && 0 < manifest.bytesSlots &&
    manifest.vectorSlots + manifest.bytesSlots ≤ maxHandleSlots &&
    manifest.packedEnd ≤ transientHighWater

/-- Slot index admitted by the manifest for Vector64-backed containers. -/
def ResourceManifest.admitsVectorSlot (manifest : ResourceManifest) (slot : Nat) : Bool :=
  manifest.wellFormed && slot < manifest.vectorSlots

/-- Slot index admitted by the manifest for Bytes containers. -/
def ResourceManifest.admitsBytesSlot (manifest : ResourceManifest) (slot : Nat) : Bool :=
  manifest.wellFormed && slot < manifest.bytesSlots

/-! ## Heap-backed buffers -/

/-- Compile-time geometry for one bounded invocation-local heap buffer. -/
structure HeapBuffer where
  name : String
  capacityBytes : Nat
  alignment : Nat := 8
  frameBytes : Nat := Heap.defaultFrameBytes
  deriving BEq, Repr, Inhabited

def HeapBuffer.wellFormed (buffer : HeapBuffer) : Bool :=
  !buffer.name.isEmpty && 0 < buffer.capacityBytes &&
    Heap.alignmentValid buffer.alignment &&
    Heap.frameSizeValid buffer.frameBytes &&
    Heap.bumpWordBytes + buffer.capacityBytes ≤ buffer.frameBytes

/-- Smallest legal compute-budget heap frame that can hold this buffer. -/
def HeapBuffer.minimumFrame (buffer : HeapBuffer) : Option Nat :=
  let needed := Heap.bumpWordBytes + buffer.capacityBytes
  let rounded :=
    Nat.max Heap.defaultFrameBytes
      ((needed + Heap.frameGranularity - 1) / Heap.frameGranularity * Heap.frameGranularity)
  if Heap.frameSizeValid rounded then some rounded else none

/-- A live allocator result and the heap state to thread into the next reservation. -/
structure HeapReservation where
  allocation : Heap.Allocation
  heap : Heap.State
  deriving BEq, Repr

/-- Reserve this buffer from an explicit invocation heap. -/
def HeapBuffer.reserve (buffer : HeapBuffer) (heap : Heap.State) :
    Except String HeapReservation :=
  if !buffer.wellFormed then
    .error s!"extract/unsupported: malformed {buffer.name} heap buffer descriptor"
  else if heap.frameBytes != buffer.frameBytes then
    .error s!"extract/unsupported: {buffer.name} heap buffer does not match the invocation frame"
  else
    match Heap.allocate heap buffer.capacityBytes buffer.alignment with
    | some (allocation, heap) => .ok { allocation, heap }
    | none => .error s!"extract/unsupported: {buffer.name} heap buffer is out of memory"

def HeapBuffer.reserveFresh (buffer : HeapBuffer) : Except String HeapReservation :=
  buffer.reserve (Heap.initial buffer.frameBytes)

/-! ## Fixed vectors and byte writers -/

/-- A fixed-capacity vector view over a heap buffer. The buffer owns exactly the vector payload;
length/capacity metadata belongs to the consumer's explicit codec. -/
structure FixedVec where
  buffer : HeapBuffer
  elementBytes : Nat
  capacity : Nat
  deriving BEq, Repr, Inhabited

def FixedVec.wellFormed (vector : FixedVec) : Bool :=
  vector.buffer.wellFormed && 0 < vector.elementBytes && 0 < vector.capacity &&
    vector.elementBytes * vector.capacity == vector.buffer.capacityBytes

def FixedVec.indexFits (vector : FixedVec) (index : Nat) : Bool :=
  vector.wellFormed && index < vector.capacity

/-- Fixed contract for a bounded serialized-record writer. The consumer owns the record codec;
this contract owns capacity, count-header geometry, and flush-before-overflow semantics. -/
structure ByteWriter where
  buffer : HeapBuffer
  headerBytes : Nat
  countOffset : Nat
  maxRecords : Nat
  deriving BEq, Repr, Inhabited

def ByteWriter.wellFormed (writer : ByteWriter) : Bool :=
  writer.buffer.wellFormed && 0 < writer.headerBytes &&
    writer.countOffset + 2 ≤ writer.headerBytes &&
    writer.headerBytes ≤ writer.buffer.capacityBytes && 0 < writer.maxRecords

def ByteWriter.recordFits (writer : ByteWriter)
    (lengthBytes count recordBytes : Nat) : Bool :=
  writer.wellFormed && recordBytes > 0 && count < writer.maxRecords &&
    writer.headerBytes ≤ lengthBytes &&
    lengthBytes + recordBytes ≤ writer.buffer.capacityBytes

def ByteWriter.flushRequired (writer : ByteWriter)
    (lengthBytes count recordBytes : Nat) : Bool :=
  !writer.recordFits lengthBytes count recordBytes

/-! ## Composed scratch codecs -/

/-- Scratch geometry needed to encode one signed CPI. This composes the reusable instruction and
signer-seed planners without introducing a second plan, bank, lifetime, or allocator contract. -/
structure SignedCpiCodec where
  instruction : Scratch.InstructionPlan
  signer : Scratch.SignerSeedTail
  deriving BEq, Repr

def SignedCpiCodec.plan (bank : Scratch.Bank) (buffer : Scratch.InstructionBuffer)
    (seedBytes seedCount : Nat) : Except String SignedCpiCodec := do
  let instruction ← Scratch.instructionPlan bank buffer
  let signer ← instruction.scratch.signerSeedTail seedBytes seedCount
  pure { instruction, signer }

end ProofForge.Svm.Sdk.Transient
