import ProofForge.Extract.IR

namespace ProofForge.Extract.Ops

/-- Decoder-facing names over the extensible extraction dialect; no second Ops tree is created. -/
abbrev Cmp := IR.Cmp
abbrev Val := IR.Val
abbrev Op := IR.Op
abbrev CpiMeta := Svm.Ops.CpiMeta
abbrev CpiWord := Svm.Ops.CpiWord Val
abbrev PdaSeed := Svm.Ops.PdaSeed

private def svmLeaf (kind : Svm.Ops.ValKind) : Val :=
  .ext (.svm kind) #[]

@[match_pattern] def Val.clockSlot : Val := svmLeaf .clockSlot
@[match_pattern] def Val.clockEpoch : Val := svmLeaf .clockEpoch
@[match_pattern] def Val.unixTime : Val := svmLeaf .unixTime
@[match_pattern] def Val.slotsPerEpoch : Val := svmLeaf .slotsPerEpoch
@[match_pattern] def Val.signerKey0 : Val := svmLeaf .signerKey0
@[match_pattern] def Val.accLamports0 : Val := svmLeaf .accLamports0
@[match_pattern] def Val.accOwner0 : Val := svmLeaf .accOwner0
@[match_pattern] def Val.accDataLen0 : Val := svmLeaf .accDataLen0
@[match_pattern] def Val.accN : Val := svmLeaf .accN
@[match_pattern] def Val.isSigner0 : Val := svmLeaf .isSigner0
@[match_pattern] def Val.isWritable0 : Val := svmLeaf .isWritable0
@[match_pattern] def Val.isExecutable0 : Val := svmLeaf .isExecutable0
@[match_pattern] def Val.accLamports1 : Val := svmLeaf .accLamports1
@[match_pattern] def Val.accOwner1 : Val := svmLeaf .accOwner1
@[match_pattern] def Val.accDataLen1 : Val := svmLeaf .accDataLen1
@[match_pattern] def Val.isSigner1 : Val := svmLeaf .isSigner1
@[match_pattern] def Val.isWritable1 : Val := svmLeaf .isWritable1
@[match_pattern] def Val.isExecutable1 : Val := svmLeaf .isExecutable1
@[match_pattern] def Val.findPda (seed : String) : Val := svmLeaf (.findPda seed)
@[match_pattern] def Val.checkPda (seed : String) (bump : Val) : Val :=
  .ext (.svm (.checkPda seed)) #[bump]
@[match_pattern] def Val.rentExemption (dataLen : UInt64) : Val :=
  svmLeaf (.rentExemption dataLen)
@[match_pattern] def Val.cpiReturn : Val := svmLeaf .cpiReturn
@[match_pattern] def Val.cpiReturnLen : Val := svmLeaf .cpiReturnLen
@[match_pattern] def Val.cpiReturnProgramIdWord (word : Nat) : Val :=
  svmLeaf (.cpiReturnProgramIdWord word)
@[match_pattern] def Val.sha256Lit (seed : String) : Val := svmLeaf (.sha256Lit seed)
@[match_pattern] def Val.sha256LitWord (seed : String) (word : Nat) : Val :=
  svmLeaf (.sha256LitWord seed word)
@[match_pattern] def Val.sha256DataWord (acc offsetBytes lengthBytes : Nat) (word : Nat) : Val :=
  svmLeaf (.sha256DataWord acc offsetBytes lengthBytes word)
@[match_pattern] def Val.keccak256Lit (seed : String) : Val := svmLeaf (.keccak256Lit seed)
@[match_pattern] def Val.keccak256LitWord (seed : String) (word : Nat) : Val :=
  svmLeaf (.keccak256LitWord seed word)
@[match_pattern] def Val.keccak256DataWord (acc offsetBytes lengthBytes : Nat) (word : Nat) : Val :=
  svmLeaf (.keccak256DataWord acc offsetBytes lengthBytes word)
@[match_pattern] def Val.byteSwap64 (word : Val) : Val :=
  .ext (.svm .byteSwap64) #[word]
@[match_pattern] def Val.accKeyWord (acc word : Nat) : Val := svmLeaf (.accKeyWord acc word)
@[match_pattern] def Val.accOwnerWord (acc word : Nat) : Val :=
  svmLeaf (.accOwnerWord acc word)
@[match_pattern] def Val.accDataWord (acc word : Nat) : Val :=
  svmLeaf (.accDataWord acc word)
@[match_pattern] def Val.accDataWordAt
    (acc baseWord strideWords capacity : Nat) (index : Val) : Val :=
  .ext (.svm (.component (.accountStorage
    (.readWordZeroBased acc baseWord strideWords capacity)))) #[index]
@[match_pattern] def Val.accDataWordAtOneBased
    (acc baseWord strideWords capacity : Nat) (index : Val) : Val :=
  .ext (.svm (.component (.accountStorage
    (.readWordOneBased acc baseWord strideWords capacity)))) #[index]
@[match_pattern] def Val.accDataRbTreeKey4Find
    (acc rootWord linksBaseWord parentBaseWord keyBaseWord strideWords capacity : Nat)
    (key0 key1 key2 key3 : Val) : Val :=
  .ext (.svm (.component (.accountStorage (.key4FindOneBased
    acc rootWord linksBaseWord parentBaseWord keyBaseWord strideWords capacity))))
      #[key0, key1, key2, key3]
@[match_pattern] def Val.accDataRbTreeOrderFind
    (acc rootWord linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord strideWords capacity : Nat)
    (bid : Bool) (price sequence : Val) : Val :=
  .ext (.svm (.component (.accountStorage (.fifoFindOneBased
    acc rootWord linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord strideWords capacity bid))))
      #[price, sequence]
@[match_pattern] def Val.accDataRbTreeOrderCursor
    (acc rootWord linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord strideWords capacity : Nat)
    (bid : Bool) (hasCursor price sequence : Val) : Val :=
  .ext (.svm (.component (.accountStorage (.fifoCursorOneBased
    acc rootWord linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord strideWords capacity bid))))
      #[hasCursor, price, sequence]
@[match_pattern] def Val.accDataParentPathValid
    (acc linksBaseWord parentBaseWord strideWords capacity maxDepth : Nat)
    (index root bumpIndex : Val) : Val :=
  .ext (.svm (.component (.accountStorage (.parentPathValidOneBased
    acc linksBaseWord parentBaseWord strideWords capacity maxDepth)))) #[index, root, bumpIndex]
@[match_pattern] def Val.accDataRbTreeValid
    (acc linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord strideWords capacity : Nat)
    (bid : Bool) (root size bumpIndex freeListHead : Val) : Val :=
  .ext (.svm (.component (.accountStorage (.fifoRbTreeValidOneBased
    acc linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord strideWords capacity bid))))
      #[root, size, bumpIndex, freeListHead]
@[match_pattern] def Val.accDataRbTreeKey4Valid
    (acc linksBaseWord parentBaseWord keyBaseWord strideWords capacity : Nat)
    (root size bumpIndex freeListHead : Val) : Val :=
  .ext (.svm (.component (.accountStorage (.key4RbTreeValidOneBased
    acc linksBaseWord parentBaseWord keyBaseWord strideWords capacity))))
      #[root, size, bumpIndex, freeListHead]
@[match_pattern] def Val.fifoCancelResult (query : Svm.FifoCancel.Query) : Val :=
  .ext (.svm (.component (.fifoCancel query))) #[]
@[match_pattern] def Val.accLamportsN (acc : Nat) : Val := svmLeaf (.accLamportsN acc)
@[match_pattern] def Val.accDataLenN (acc : Nat) : Val := svmLeaf (.accDataLenN acc)
@[match_pattern] def Val.isSignerN (acc : Nat) : Val := svmLeaf (.isSignerN acc)
@[match_pattern] def Val.isWritableN (acc : Nat) : Val := svmLeaf (.isWritableN acc)
@[match_pattern] def Val.isExecutableN (acc : Nat) : Val := svmLeaf (.isExecutableN acc)
@[match_pattern] def Val.signerKeyN (acc : Nat) : Val := svmLeaf (.signerKeyN acc)
@[match_pattern] def Val.ownerIsSelf (acc : Nat) : Val := svmLeaf (.ownerIsSelf acc)
@[match_pattern] def Val.findPdaSeeds (seeds : Array PdaSeed) : Val :=
  svmLeaf (.findPdaSeeds seeds)
@[match_pattern] def Val.checkPdaSeeds (account : Nat) (seeds : Array PdaSeed) : Val :=
  svmLeaf (.checkPdaSeeds account seeds)

@[match_pattern] def Op.invoke (programIx : Nat) (metas : Array CpiMeta)
    (data : Array CpiWord) (seeds : Array PdaSeed := #[]) (bump : Option Val := none) : Op :=
  .ext (.svm (.invoke programIx metas data seeds bump))
@[match_pattern] def Op.component (call : Svm.Component.Call Val) : Op :=
  .ext (.svm (.component call))
@[match_pattern] def Op.accDataWordSetAt
    (acc baseWord strideWords capacity : Nat) (index value : Val) : Op :=
  .ext (.svm (.component (.accountStorage
    (.writeWordZeroBased acc baseWord strideWords capacity index value))))
@[match_pattern] def Op.accDataWordSetAtOneBased
    (acc baseWord strideWords capacity : Nat) (index value : Val) : Op :=
  .ext (.svm (.component (.accountStorage
    (.writeWordOneBased acc baseWord strideWords capacity index value))))
@[match_pattern] def Op.accDataRbTreeKey4Insert
    (acc rootWord linksBaseWord parentBaseWord keyBaseWord strideWords capacity : Nat)
    (key0 key1 key2 key3 : Val) : Op :=
  .ext (.svm (.component (.accountStorage (.rbMapInsertKey4OneBased acc rootWord linksBaseWord
    parentBaseWord keyBaseWord strideWords capacity key0 key1 key2 key3))))
@[match_pattern] def Op.accDataRbTreeTraderDeposit
    (acc rootWord linksBaseWord parentBaseWord keyBaseWord strideWords capacity : Nat)
    (key0 key1 key2 key3 quoteLots baseLots : Val) : Op :=
  .ext (.svm (.component (.accountStorage (.rbMapCheckedAddKey4OneBased acc rootWord linksBaseWord
    parentBaseWord keyBaseWord strideWords capacity key0 key1 key2 key3 quoteLots baseLots))))
@[match_pattern] def Op.accDataRbTreeKey4Remove
    (acc rootWord linksBaseWord parentBaseWord keyBaseWord strideWords capacity : Nat)
    (key0 key1 key2 key3 : Val) : Op :=
  .ext (.svm (.component (.accountStorage (.rbMapRemoveKey4OneBased acc rootWord linksBaseWord
    parentBaseWord keyBaseWord strideWords capacity key0 key1 key2 key3))))
@[match_pattern] def Op.accDataRbTreeOrderInsert
    (acc rootWord linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord strideWords
      capacity : Nat) (bid : Bool)
    (price sequence traderIndex numBaseLots lastValidSlot lastValidUnixTimestamp : Val) : Op :=
  .ext (.svm (.component (.accountStorage (.rbMapInsertFifoOneBased acc rootWord linksBaseWord
    parentBaseWord keyBaseWord sequenceBaseWord strideWords capacity bid price sequence
    traderIndex numBaseLots lastValidSlot lastValidUnixTimestamp))))
@[match_pattern] def Op.accDataRbTreeOrderRemove
    (acc rootWord linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord strideWords
      capacity : Nat) (bid : Bool) (price sequence : Val) : Op :=
  .ext (.svm (.component (.accountStorage (.rbMapRemoveFifoOneBased acc rootWord linksBaseWord
    parentBaseWord keyBaseWord sequenceBaseWord strideWords capacity bid price sequence))))
@[match_pattern] def Op.accDataRbTreeOrderSetWordOrRemove
    (acc rootWord linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord valueBaseWord strideWords
      capacity : Nat) (bid : Bool) (price sequence index value : Val) : Op :=
  .ext (.svm (.component (.accountStorage (.rbMapSetWordOrRemoveFifoOneBased acc rootWord
    linksBaseWord parentBaseWord keyBaseWord sequenceBaseWord valueBaseWord strideWords capacity bid
    price sequence index value))))

private partial def walk (ops : Array Op) (predicate : Op → Bool) : Bool :=
  ops.any fun op =>
    predicate op ||
      match op with
      | .ite _ _ _ thn els => walk thn predicate || walk els predicate
      | .forBody _ body => walk body predicate
      | _ => false

def hasCheckedArith (ops : Array Op) : Bool :=
  walk ops fun
    | .checkedAddU64 .. | .checkedSubU64 .. | .checkedMulU64 ..
    | .checkedDivU64 .. | .checkedModU64 .. => true
    | _ => false

def hasForAccum (ops : Array Op) : Bool :=
  walk ops fun | .forAccum .. => true | _ => false

def hasIndexSet (ops : Array Op) : Bool :=
  walk ops fun | .indexSetLeaf .. | .indexSet .. => true | _ => false

def hasStoreField (ops : Array Op) : Bool :=
  walk ops fun | .storeField .. => true | _ => false

def hasInvoke (ops : Array Op) : Bool :=
  walk ops fun | .invoke .. => true | _ => false

partial def isLangLeaf : Val → Bool
  | .local _ | .loopIx | .select .. | .bitAnd .. | .bitOr .. | .bitXor ..
  | .bitNot .. | .shiftL .. | .shiftR .. | .indexGet .. => true
  | .field base _ => isLangLeaf base
  | .ext _ operands => operands.any isLangLeaf
  | _ => false

private partial def hasSelectVal : Val → Bool
  | .select .. => true
  | .field base _ | .bitNot base => hasSelectVal base
  | .bitAnd lhs rhs | .bitOr lhs rhs | .bitXor lhs rhs
  | .shiftL lhs rhs | .shiftR lhs rhs | .addU64 lhs rhs | .subU64 lhs rhs
  | .mulU64 lhs rhs | .divU64 lhs rhs | .modU64 lhs rhs =>
      hasSelectVal lhs || hasSelectVal rhs
  | .indexGet base _ index _ _ => hasSelectVal base || hasSelectVal index
  | .ext _ operands => operands.any hasSelectVal
  | _ => false

private partial def isBitVal : Val → Bool
  | .bitAnd .. | .bitOr .. | .bitXor .. | .bitNot .. | .shiftL .. | .shiftR .. => true
  | .field base _ => isBitVal base
  | .select _ lhs rhs thn els =>
      isBitVal lhs || isBitVal rhs || isBitVal thn || isBitVal els
  | .ext _ operands => operands.any isBitVal
  | _ => false

private def opValuesAny (predicate : Val → Bool) : Op → Bool
  | .letLocal _ value | .setLocal _ value | .forAccum _ value _
  | .storeField _ value | .okState value | .returnU64 value | .returnState value =>
      predicate value
  | .checkedAddU64 lhs rhs | .checkedSubU64 lhs rhs | .checkedMulU64 lhs rhs
  | .checkedDivU64 lhs rhs | .checkedModU64 lhs rhs | .ite _ lhs rhs _ _
  | .indexSetLeaf _ lhs rhs _ _ | .indexSet _ lhs rhs _ _ => predicate lhs || predicate rhs
  | .invoke _ _ data _ bump =>
      data.any (fun word => word.value?.any predicate) || bump.any predicate
  | .ext (.svm (.component call)) => call.anyValue predicate
  | .errorTyped frame => frame.values.any predicate
  | .joinLocal _ | .forBody _ _ | .errorOverflow | .errorNamed _ => false

def hasLangOp (ops : Array Op) : Bool :=
  walk ops fun op =>
    match op with
    | .forAccum .. | .forBody .. | .indexSetLeaf .. | .indexSet .. | .errorNamed _ => true
    | _ => opValuesAny (fun value => isLangLeaf value || isBitVal value || hasSelectVal value) op

end ProofForge.Extract.Ops
