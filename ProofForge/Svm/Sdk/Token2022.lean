import ProofForge.Attr
import ProofForge.Svm.Cpi.TokenTlv
import ProofForge.Svm.Runtime

/-!
# SVM SDK Token-2022 extension facade

Source-facing names for the first typed Token-2022 extension slice: official
`MintCloseAuthority` (ordinal 3, 32-byte body). CPI lowering reuses the target-owned
`TokenTlv` mint-close policy; host-side parsing builds a `TokenTlv.View` over raw bytes and
runs `evaluatePolicy`. Unknown and unmodeled extensions stay fail closed.
-/

namespace ProofForge.Svm.Sdk.Token2022

/-- Official `ExtensionType::MintCloseAuthority` ordinal. -/
def mintCloseAuthorityType : UInt64 :=
  ProofForge.Svm.Cpi.TokenTlv.mintCloseAuthorityType

/-- Official `MintCloseAuthority` payload size. -/
def mintCloseAuthorityBodyLen : UInt64 :=
  ProofForge.Svm.Cpi.TokenTlv.mintCloseAuthorityBodyLen

/-- Closed CPI policy for a mint that may carry exactly one `MintCloseAuthority`. -/
def mintClosePolicy : ProofForge.Svm.Cpi.TokenTlv.Policy :=
  .token2022MintClose

/--
Token-2022 `TransferChecked` whose mint may carry exactly one official `MintCloseAuthority`
extension. Source and destination accounts remain on the closed base TLV policy.
-/
@[pf_inline] def transferCheckedMintClose (amount decimals : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.token2022TransferCheckedMintClose amount decimals

/--
Token-2022 `TransferChecked` whose source/destination accounts may each carry exactly one
official `ImmutableOwner` marker; the mint stays on the closed base policy.
-/
@[pf_inline] def transferCheckedImmutable (amount decimals : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.token2022TransferCheckedImmutable amount decimals

/--
Token-2022 `TransferChecked` over an official NonTransferable mint/account pair; the token
program owns the on-chain rejection of the transfer itself.
-/
@[pf_inline] def transferCheckedNonTransferable (amount decimals : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.token2022TransferCheckedNonTransferable amount decimals

/--
Token-2022 `SetAuthority` (`AccountOwner`) over an `ImmutableOwner` account; the token program
owns the on-chain rejection. The new owner is the public key of external account 2.
-/
@[pf_inline] def setAccountAuthorityImmutable : UInt64 :=
  ProofForge.Svm.Runtime.token2022SetAccountAuthorityImmutable

/--
Token-2022 `TransferChecked` over a transfer-fee mint: the mint must carry exactly one official
`TransferFeeConfig` entry; source/destination stay on the closed base policy. The token program
charges the fee over the CPI boundary; this facade only guards admission.
-/
@[pf_inline] def transferCheckedTransferFee (amount decimals : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.token2022TransferCheckedTransferFee amount decimals

/--
Token-2022 `TransferChecked` over a pausable mint: the mint must carry exactly one official
`Pausable` entry; the token program owns the paused/rejection semantics over the CPI.
-/
@[pf_inline] def transferCheckedPausable (amount decimals : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.token2022TransferCheckedPausable amount decimals

/--
Token-2022 `TransferChecked` whose source carries exactly one official `CpiGuard` entry;
the token program owns the lock semantics over the CPI boundary and rejects locked,
owner-signed in-CPI transfers.
-/
@[pf_inline] def transferCheckedCpiGuard (amount decimals : UInt64) : UInt64 :=
  ProofForge.Svm.Runtime.token2022TransferCheckedCpiGuard amount decimals


/-- Host-side view of a successfully parsed mint-close authority pubkey (32 raw bytes). -/
structure MintCloseAuthority where
  bytes : Array UInt8
  deriving BEq, Repr, Inhabited

def MintCloseAuthority.wellFormed (view : MintCloseAuthority) : Bool :=
  view.bytes.size == 32

/-- Build a `TokenTlv.View` over a host byte buffer. -/
def viewOf (data : Array UInt8) : ProofForge.Svm.Cpi.TokenTlv.View where
  dataLen := UInt64.ofNat data.size
  readByte := fun off =>
    let i := off.toNat
    if h : i < data.size then some data[i] else none

/--
Host-side mint-close parse: accept only when the mint-close CPI policy accepts the buffer, then
project the 32-byte authority body at absolute offset `tlvStart + 4`. Classic base mints (no TLV)
return `none`.
-/
def parseMintCloseAuthority (data : Array UInt8) : Option MintCloseAuthority :=
  let view := viewOf data
  match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy mintClosePolicy view with
  | .reject _ => none
  | .accept =>
    if data.size == ProofForge.Svm.Cpi.TokenTlv.mintBaseLen then none
    else
      let start := ProofForge.Svm.Cpi.TokenTlv.tlvStart + 4
      if data.size < start + 32 then none
      else
        let bytes := (List.range 32).foldl (init := #[]) fun acc i =>
          acc.push data[start + i]!
        let out := { bytes := bytes : MintCloseAuthority }
        if out.wellFormed then some out else none

/-- Host-side check: the account buffer parses as extension form carrying exactly the official
`ImmutableOwner` marker under the closed policy. Classic 165-byte accounts return `false`. -/
def accountHasImmutableOwner (data : Array UInt8) : Bool :=
  data.size > ProofForge.Svm.Cpi.TokenTlv.accountBaseLen &&
    match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022ImmutableOwner (viewOf data) with
    | .accept => true
    | .reject _ => false

/-- Host-side check: the account buffer parses as extension form carrying exactly the official
`NonTransferableAccount` marker under the closed policy. -/
def accountHasNonTransferable (data : Array UInt8) : Bool :=
  data.size > ProofForge.Svm.Cpi.TokenTlv.accountBaseLen &&
    match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022NonTransferableAccount (viewOf data) with
    | .accept => true
    | .reject _ => false

/-- Host-side check: the mint buffer parses as extension form carrying exactly the official
`NonTransferable` marker under the closed policy. -/
def mintHasNonTransferable (data : Array UInt8) : Bool :=
  data.size > ProofForge.Svm.Cpi.TokenTlv.mintBaseLen + ProofForge.Svm.Cpi.TokenTlv.mintPaddingBytes + 1 &&
    match ProofForge.Svm.Cpi.TokenTlv.evaluatePolicy .token2022NonTransferableMint (viewOf data) with
    | .accept => true
    | .reject _ => false


end ProofForge.Svm.Sdk.Token2022
