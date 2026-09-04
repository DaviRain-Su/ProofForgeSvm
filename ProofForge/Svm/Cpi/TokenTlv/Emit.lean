import ProofForge.Svm.Cpi.TokenTlv

/-!
# Emitter for the bounded Token-2022 TLV account-data policy

Lowers a closed `TokenTlv.Policy` to the sBPF preflight that runs before Token-2022
`TransferChecked`. Two straight-line specializations are owned here:

* `token2022Base` — classic base layout or TLV region that starts with an official end/padding
  form; every other extension rejects (`evaluate_closed_eq_straightline`).
* `token2022MintClose` — mint-only path that accepts exactly one official `MintCloseAuthority`
  (type 3, length 32) followed by an end marker; every other extension rejects.

Scalar registers only: no heap object, no pointer beyond the live account header, no
runtime-selected geometry.
-/

namespace ProofForge.Svm.Cpi.TokenTlv.Emit

structure Context where
  headerStack : Nat → Nat

/-- Account header layout: data length at +80, data bytes at +88. -/
def dataLenOffset : Nat := 80

def dataPtrOffset : Nat := 88

private def emitBase (src err next : String) (plan : Plan) : String :=
  let padding :=
    (List.range plan.paddingBytes).foldl (init := "") fun out i =>
      out ++ s!"  ldxb r4, [r3 + {plan.baseLen + i}]\n  jne r4, 0, {err}\n"
  s!"\
  ldxdw r1, [r10 - {src}]
  ldxdw r2, [r1 + {dataLenOffset}]
  ; the account data bytes follow the fixed 88-byte header inline, so the data pointer is
  ; computed, never loaded (there is no pointer field in the serialized input)
  mov64 r3, r1
  add64 r3, {dataPtrOffset}
  ; official Multisig::LEN is never an extension-bearing mint/account
  jeq r2, {multisigLen}, {err}
  ; base state span
  jlt r2, {plan.baseLen}, {err}
  jeq r2, {plan.baseLen}, {next}
  ; extension form carries the full base+padding+type-byte span
  jlt r2, {tlvStart}, {err}
{padding}  ; AccountType byte must match the constrained base state
  ldxb r4, [r3 + {typeByteOffset}]
  jne r4, {plan.typeByte}, {err}
"

/-- Closed classifier: first TLV entry must be end/padding. -/
private def emitClosedTlv (err next okFull : String) : String :=
  s!"\
  ; forward-only bounded TLV cursor, first entry: every non-end entry rejects
  mov64 r4, r2
  sub64 r4, {tlvStart}
  jeq r4, 0, {next}
  jeq r4, 1, {next}
  ; rem ≥ 2 proves both type bytes are inside data_len; rem ≥ 4 proves the full header
  ldxb r5, [r3 + {tlvStart}]
  jne r5, 0, {err}
  ldxb r5, [r3 + {tlvStart + 1}]
  jgt r4, 3, {okFull}
  ; two or three trailing bytes: only the Uninitialized(0) type is official
  jne r5, 0, {err}
  ja {next}
{okFull}:
  ; Uninitialized(0) ends the region; everything after is ignored, as on-chain
  jne r5, 0, {err}
  ja {next}
"

/--
Mint-close specialization: accept type=3/len=32 once, then require end (or no further bytes).
-/
private def emitMintCloseTlv (err next endCheck afterClose : String) : String :=
  let afterBody := tlvStart + 4 + 32
  s!"\
  ; mint-close TLV: allow MintCloseAuthority(3,32) then end, or end alone
  mov64 r4, r2
  sub64 r4, {tlvStart}
  jeq r4, 0, {next}
  jeq r4, 1, {next}
  ldxb r5, [r3 + {tlvStart}]
  ldxb r6, [r3 + {tlvStart + 1}]
  jne r6, 0, {err}
  jeq r5, 0, {endCheck}
  jne r5, {mintCloseAuthorityType.toNat}, {err}
  ; need full header + 32-byte body
  jlt r4, {4 + 32}, {err}
  ldxb r5, [r3 + {tlvStart + 2}]
  jne r5, {mintCloseAuthorityBodyLen.toNat}, {err}
  ldxb r5, [r3 + {tlvStart + 3}]
  jne r5, 0, {err}
  ; after body: require end/padding
  mov64 r4, r2
  sub64 r4, {afterBody}
  jeq r4, 0, {next}
  jeq r4, 1, {next}
  ldxb r5, [r3 + {afterBody}]
  jne r5, 0, {err}
  ldxb r5, [r3 + {afterBody + 1}]
  jne r5, 0, {err}
  ja {next}
{endCheck}:
  jgt r4, 3, {afterClose}
  ja {next}
{afterClose}:
  ; Uninitialized(0) ends the region
  jne r6, 0, {err}
  ja {next}
"

/--
Transfer-fee specialization: accept type=1 (`TransferFeeConfig`) with the full official
108-byte body once, then require end (or no further bytes). Same header discipline as the
other one-entry specializations.
-/
private def emitTransferFeeTlv (err next endCheck afterClose : String) : String :=
  let afterBody := tlvStart + 4 + transferFeeBodyLen.toNat
  s!"\
  ; transfer-fee TLV: allow TransferFeeConfig(1,{transferFeeBodyLen.toNat}) then end, or end alone
  mov64 r4, r2
  sub64 r4, {tlvStart}
  jeq r4, 0, {next}
  jeq r4, 1, {next}
  ldxb r5, [r3 + {tlvStart}]
  ldxb r6, [r3 + {tlvStart + 1}]
  jne r6, 0, {err}
  jeq r5, 0, {endCheck}
  jne r5, {transferFeeConfigType.toNat}, {err}
  ; need full header + {transferFeeBodyLen.toNat}-byte body
  jlt r4, {4 + transferFeeBodyLen.toNat}, {err}
  ldxb r5, [r3 + {tlvStart + 2}]
  jne r5, {transferFeeBodyLen.toNat}, {err}
  ldxb r5, [r3 + {tlvStart + 3}]
  jne r5, 0, {err}
  ; after body: require end/padding
  mov64 r4, r2
  sub64 r4, {afterBody}
  jeq r4, 0, {next}
  jeq r4, 1, {next}
  ldxb r5, [r3 + {afterBody}]
  jne r5, 0, {err}
  ldxb r5, [r3 + {afterBody + 1}]
  jne r5, 0, {err}
  ja {next}
{endCheck}:
  jgt r4, 3, {afterClose}
  ja {next}
{afterClose}:
  jne r6, 0, {err}
  ja {next}
"

/--
Body-length marker specialization: accept the given extension type with the given body length
once, then require end (or no further bytes). Shared by zero-byte markers
(ImmutableOwner/NonTransferable) and the 8-byte `TransferFeeAmount`.
-/
private def emitMarkerTlv (err next endCheck afterClose : String) (markerType : Nat)
    (bodyLen : Nat := 0) : String :=
  let afterHeader := tlvStart + 4
  let afterBody := afterHeader + bodyLen
  s!"\
  ; marker TLV: allow type={markerType} with {bodyLen}-byte body once, then end, or end alone
  mov64 r4, r2
  sub64 r4, {tlvStart}
  jeq r4, 0, {next}
  jeq r4, 1, {next}
  ldxb r5, [r3 + {tlvStart}]
  ldxb r6, [r3 + {tlvStart + 1}]
  jne r6, 0, {err}
  jeq r5, 0, {endCheck}
  jne r5, {markerType}, {err}
  ; body length field must be {bodyLen}
  ldxb r5, [r3 + {tlvStart + 2}]
  jne r5, {bodyLen}, {err}
  ldxb r5, [r3 + {tlvStart + 3}]
  jne r5, 0, {err}
  ; after body: require end/padding
  mov64 r4, r2
  sub64 r4, {afterBody}
  jeq r4, 0, {next}
  jeq r4, 1, {next}
  ldxb r5, [r3 + {afterBody}]
  jne r5, 0, {err}
  ldxb r5, [r3 + {afterBody + 1}]
  jne r5, 0, {err}
  ja {next}
{endCheck}:
  jgt r4, 3, {afterClose}
  ja {next}
{afterClose}:
  jne r6, 0, {err}
  ja {next}
"

/--
Emit the TLV policy preflight for the account at physical index `physical`. All rejection paths
jump to the shared `cpi_data_len_err_{label}` exit; the accept path falls through to
`cpi_data_len_next_{label}_p{physical}` then onward.
-/
def emitPreflight (ctx : Context) (label : String) (physical : Nat) (policy : Policy) :
    Except String String := do
  let plan ← match planFor policy with
    | .error reason => throw reason
    | .ok plan => pure plan
  unless plan.wellFormed do
    throw "extract/unsupported: malformed Token-2022 TLV account-data plan"
  let err := s!"cpi_data_len_err_{label}"
  let next := s!"cpi_data_len_next_{label}_p{physical}"
  let src := toString (ctx.headerStack physical)
  let base := emitBase src err next plan
  match policy with
  | .token2022Base _ =>
    let okFull := s!"cpi_data_len_ok_{label}_p{physical}_full"
    return s!"\
  ; token-2022 TLV account-data policy ({repr plan.kind}) for physical account {physical}
{base}{emitClosedTlv err next okFull}{next}:
"
  | .token2022MintClose =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV mint-close policy for physical account {physical}
{base}{emitMintCloseTlv err next endCheck afterClose}{next}:
"
  | .token2022ImmutableOwner =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV immutable-owner policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat immutableOwnerType)}{next}:
"
  | .token2022NonTransferableAccount =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV non-transferable-account policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat nonTransferableAccountType)}{next}:
"
  | .token2022NonTransferableMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV non-transferable-mint policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat nonTransferableType)}{next}:
"
  | .token2022TransferFeeConfigMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV transfer-fee-mint policy for physical account {physical}
{base}{emitTransferFeeTlv err next endCheck afterClose}{next}:
"
  | .token2022TransferFeeAmountAccount =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV transfer-fee-amount policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat transferFeeAmountType) (UInt64.toNat transferFeeAmountBodyLen)}{next}:
"
  | .token2022PausableMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV pausable-mint policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat pausableType) (UInt64.toNat pausableBodyLen)}{next}:
"
  | .token2022CpiGuardAccount =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV cpi-guard policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat cpiGuardType) (UInt64.toNat cpiGuardBodyLen)}{next}:
"
  | .token2022MemoTransferAccount =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV memo-transfer policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat memoTransferType) (UInt64.toNat memoTransferBodyLen)}{next}:
"
  | .token2022TransferHookAccount =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV transfer-hook-account policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat transferHookAccountType) (UInt64.toNat transferHookAccountBodyLen)}{next}:
"
  | .token2022TransferHookMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV transfer-hook-mint policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat transferHookType) (UInt64.toNat transferHookBodyLen)}{next}:
"
  | .token2022DefaultAccountStateMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV default-account-state policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat defaultAccountStateType) (UInt64.toNat defaultAccountStateBodyLen)}{next}:
"
  | .token2022MetadataPointerMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV metadata-pointer policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat metadataPointerType) (UInt64.toNat metadataPointerBodyLen)}{next}:
"
  | .token2022GroupPointerMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV group-pointer policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat groupPointerType) (UInt64.toNat groupPointerBodyLen)}{next}:
"
  | .token2022GroupMemberPointerMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV group-member-pointer policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat groupMemberPointerType) (UInt64.toNat groupMemberPointerBodyLen)}{next}:
"
  | .token2022TokenGroupMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV token-group policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat tokenGroupType) (UInt64.toNat tokenGroupBodyLen)}{next}:
"
  | .token2022TokenGroupMemberMint =>
    let endCheck := s!"cpi_data_len_ok_{label}_p{physical}_end"
    let afterClose := s!"cpi_data_len_ok_{label}_p{physical}_after_close"
    return s!"\
  ; token-2022 TLV token-group-member policy for physical account {physical}
{base}{emitMarkerTlv err next endCheck afterClose (UInt64.toNat tokenGroupMemberType) (UInt64.toNat tokenGroupMemberBodyLen)}{next}:
"

end ProofForge.Svm.Cpi.TokenTlv.Emit
