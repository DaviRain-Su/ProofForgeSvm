# Token-2022 Extension Map & Ecosystem Program Set — Reference Report

Research for ProofForgeSvm (Lean 4 → Solana sBPF compiler; SDK = `ProofForge/Svm/**`).
Grounded in source: `solana-program/token-2022` @ commit `cd155ac7644c045454a835d99eba90fab20f7d54`
(crate versions: `spl-token-2022-interface` **3.1.1**, program crate `spl-token-2022` **11.0.0** per `Cargo.lock`),
`solana-program/address-lookup-table`, `anza-xyz/agave` (`programs/compute-budget`, `program-binaries`),
and the pinned interface crates `solana-compute-budget-interface 3.0.0`,
`solana-address-lookup-table-interface 3.1.0`, `solana-loader-v3-interface 6.1.1`,
`solana-loader-v4-interface 3.1.0`, `spl-token-metadata-interface 1.0.1`, `spl-token-group-interface 0.7.2`,
`spl-transfer-hook-interface 2.1.0`, `solana-zk-sdk-pod 0.1.2`.

All byte sizes below were **verified empirically** by compiling the checked-out `spl-token-2022-interface`
against the repo's own `ExtensionType::try_calculate_account_len` (probe output reproduced in §1.3).

All paths cited are relative to the named repo. File paths in `interface/src/...` are from
`solana-program/token-2022`; `program/src/...` likewise; `solana-program/address-lookup-table` paths are
prefixed `alt/`.

---

## 1. TLV layout model (shared by every extension)

Source: `interface/src/extension/mod.rs` (lines ~95–150, ~1073–1340), `interface/src/extension/account_len.rs`.

- Base states (source `interface/src/state.rs`):
  - `Mint::LEN = 82` bytes (`mint_authority: COption<Address>` 36, `supply: u64` 8, `decimals: u8` 1,
    `is_initialized: bool` 1, `freeze_authority: COption<Address>` 36).
  - `Account::LEN = 165` bytes.
  - `Multisig::LEN = 355` bytes.
- With extensions, the account layout is `[base state][AccountType: u8][TLV entries]`.
  `BASE_ACCOUNT_AND_TYPE_LENGTH = BaseState::LEN + 1` (`interface/src/extension/mod.rs:311–314`):
  **Mint TLV region starts at absolute offset 83; Account TLV region at absolute offset 166.**
- Each TLV entry: `type: u16 (LE ExtensionType ordinal)` + `length: u16 (LE)` + `value`.
  Header overhead = **4 bytes** (`add_type_and_length_to_len`, `interface/src/extension/mod.rs:138–143`).
- Account sizing rule: `adjust_len_for_multisig` — if the computed length equals `Multisig::LEN` (355),
  2 bytes (`size_of::<ExtensionType>`) are added so extension accounts can never be confused with a
  legacy multisig (`interface/src/extension/mod.rs:126–134`).
- `TlvLenAccumulator` dedupes extension types via a `u64` bitset keyed on the ordinal
  (`interface/src/extension/account_len.rs:17–44`); each extension appears **at most once**.
- Length field is `u16` ⇒ every extension value ≤ 65,535 bytes, but the whole TLV block for a given
  entry must fit one `u16` length.

### 1.1 Empirically verified account lengths (this repo's code, not paraphrased)

Probe run against `spl-token-2022-interface 3.1.1` calling
`ExtensionType::try_calculate_account_len::<PodMint>(&[t])` / `::<PodAccount>(&[t])` (single extension
each). `PodMint` base+type = 83, `PodAccount` base+type = 166. Body size = `mint_len − 83 − 4`
(i.e. subtract 4-byte header). `PodAccount` and `PodMint` share `SIZE_OF`-only differences of 83 vs 166,
so a body-size column is derived as `account_len − (base + 4)`:

| Extension | account_len (Mint) | account_len (Account) | **body bytes** |
|---|---:|---:|---:|
| Uninitialized | 170* | 170* | 0 |
| TransferFeeConfig | 278 | — | **108** |
| TransferFeeAmount | — | 178 | **8** |
| MintCloseAuthority | 202 | — | **32** |
| ConfidentialTransferMint | 235 | — | **65** |
| ConfidentialTransferAccount | — | 465 | **295** |
| DefaultAccountState | 171 | — | **1** |
| ImmutableOwner | — | 170 | **0** (marker) |
| MemoTransfer | — | 171 | **1** |
| NonTransferable | 170 | — | **0** (marker) |
| InterestBearingConfig | 222 | — | **52** |
| CpiGuard | — | 171 | **1** |
| PermanentDelegate | 202 | — | **32** |
| NonTransferableAccount | — | 170 | **0** (marker) |
| TransferHook | 234 | — | **64** |
| TransferHookAccount | — | 171 | **1** |
| ConfidentialTransferFeeConfig | 299 | — | **129** |
| ConfidentialTransferFeeAmount | — | 234 | **64** |
| MetadataPointer | 234 | — | **64** |
| GroupPointer | 234 | — | **64** |
| TokenGroup | 250 | — | **80** |
| GroupMemberPointer | 234 | — | **64** |
| TokenGroupMember | — | 242 | **72** |
| ConfidentialMintBurn | 366 | — | **196** |
| ScaledUiAmount | 226 | — | **56** |
| Pausable | 203 | — | **33** |
| PausableAccount | — | 170 | **0** (marker) |
| PermissionedBurn | 202 | — | **32** |

Extension mints are padded to match account geometry: `82 (base) + 83 (padding) + 1 (type byte) = 166`
before the TLV region — exactly the documented allocation in `InitializeMintCloseAuthority`
(`interface/src/instruction.rs:567–571`) and matching the Token-2022 TLV region start of absolute
offset **166** for both mint and account (the repo's `ProofForge/Svm/Cpi/TokenTlv.lean` states this
correctly). Probe cross-check: `size_of::<TransferFeeConfig>() == 108`, `size_of::<ConfidentialTransferMint>() == 65`,
`size_of::<ConfidentialMintBurn>() == 196` — each equals `account_len − 170` exactly, so body bytes are
`account_len − (166 + 4)` for every entry.

### 1.2 Fixed vs variable (the compile-time-capacity question)

`ExtensionType::sized()` (`interface/src/extension/mod.rs:1099–1107`):
**only `TokenMetadata` is variable-length in production.** All other 27 extensions are fixed-size
`Pod` structs, fully decidable at compile time. This is the key fact for our bounded policy:

- **Fixed-size bodies (bounded-capacity friendly):** all of the table in §1.1 except `TokenMetadata`.
- **Variable-length (fail-closed candidates):** `TokenMetadata` (2, ordinal), plus the two test-only
  types `VariableLenMintTest = u16::MAX − 2`, `AccountPaddingTest`, `MintPaddingTest`.
- Even "fixed" extensions can have unbounded *combinations*: account length grows with each distinct
  extension, and `Reallocate` grows accounts at runtime. A compile-time capacity policy must therefore
  bound (a) the set of *recognized* ordinals and (b) the total TLV byte budget, not just per-entry sizes.

### 1.3 Ordinals, state placement, and body composition

Ordinals are the `u16` LE TLV type tags = declaration order starting at 0
(`interface/src/extension/mod.rs:1073–1137`). `get_account_type()`
(`interface/src/extension/mod.rs:1254–1292`) fixes mint-vs-account placement:

| # | ExtensionType | State | Body source (struct) | Bytes |
|---:|---|---|---|---:|
| 0 | Uninitialized | (padding) | — | 0 |
| 1 | TransferFeeConfig | Mint | `transfer_fee/mod.rs:135` | 108 |
| 2 | TransferFeeAmount | Account | `transfer_fee/mod.rs:178` | 8 |
| 3 | MintCloseAuthority | Mint | `mint_close_authority.rs:18` | 32 |
| 4 | ConfidentialTransferMint | Mint | `confidential_transfer/mod.rs:39` | 65 |
| 5 | ConfidentialTransferAccount | Account | `confidential_transfer/mod.rs:66` | 295 |
| 6 | DefaultAccountState | Mint | `default_account_state/mod.rs:16` | 1 |
| 7 | ImmutableOwner | Account | `immutable_owner.rs:13` | 0 |
| 8 | MemoTransfer | Account | `memo_transfer/mod.rs:17` | 1 |
| 9 | NonTransferable | Mint | `non_transferable.rs:13` | 0 |
| 10 | InterestBearingConfig | Mint | `interest_bearing_mint/mod.rs:44` | 52 |
| 11 | CpiGuard | Account | `cpi_guard/mod.rs:20` | 1 |
| 12 | PermanentDelegate | Mint | `permanent_delegate.rs:18` | 32 |
| 13 | NonTransferableAccount | Account | `non_transferable.rs:21` | 0 |
| 14 | TransferHook | Mint | `transfer_hook/mod.rs:30` | 64 |
| 15 | TransferHookAccount | Account | `transfer_hook/mod.rs:45` | 1 |
| 16 | ConfidentialTransferFeeConfig | Mint | `confidential_transfer_fee/mod.rs:26` | 129 |
| 17 | ConfidentialTransferFeeAmount | Account | `confidential_transfer_fee/mod.rs:53` | 64 |
| 18 | MetadataPointer | Mint | `metadata_pointer/mod.rs:21` | 64 |
| 19 | TokenMetadata | Mint (**variable**) | `spl-token-metadata-interface-1.0.1/src/state.rs:28` | var |
| 20 | GroupPointer | Mint | `group_pointer/mod.rs:21` | 64 |
| 21 | TokenGroup | Mint | `spl-token-group-interface-0.7.2/src/state.rs:17` | 80 |
| 22 | GroupMemberPointer | Mint | `group_member_pointer/mod.rs:21` | 64 |
| 23 | TokenGroupMember | Account | `spl-token-group-interface-0.7.2/src/state.rs:68` | 72 |
| 24 | ConfidentialMintBurn | Mint | `confidential_mint_burn/mod.rs:20` | 196 |
| 25 | ScaledUiAmount | Mint | `scaled_ui_amount/mod.rs:53` | 56 |
| 26 | Pausable | Mint | `pausable/mod.rs:22` | 33 |
| 27 | PausableAccount | Account | `pausable/mod.rs:35` | 0 |
| 28 | PermissionedBurn | Mint | `permissioned_burn/mod.rs:21` | 32 |
| 65534 | VariableLenMintTest (cfg test) | Mint | — | var |
| 65535 | AccountPaddingTest (cfg test) | Account | — | — |
| 65534+1 | MintPaddingTest (cfg test) | Mint | — | — |

Body compositions worth noting (all LE, `MaybeNull<T>` = `T` with an all-zeros "null" sentinel,
`solana-nullable-1.3.0/src/maybe_null.rs:29–43`, no extra tag byte):

- `TransferFeeConfig` (108, probed) = `transfer_fee_config_authority: MaybeNull<Address>` (32) +
  `withdraw_withheld_authority` (32) + `withheld_amount: U64` (8) + two `TransferFee`s
  (`transfer_fee/mod.rs:35–55`: each `TransferFee` = `epoch: U64` 8 + `maximum_fee: U64` 8 +
  `transfer_fee_basis_points: U16` 2 = 18) = 32+32+8+18+18 = 108, matching
  `size_of::<TransferFeeConfig>() == 108` exactly — no hidden padding.
- `ConfidentialTransferMint` (65) = `authority` 32 + `auto_approve_new_accounts: Bool` 1 +
  `auditor_elgamal_pubkey` 32 (`confidential_transfer/mod.rs:39–57`).
- `ConfidentialTransferAccount` (295) = `approved: Bool` 1 + `elgamal_pubkey` 32 +
  `pending_balance_lo` 64 + `pending_balance_hi` 64 + `available_balance` 64 +
  `decryptable_available_balance` 36 (`PodAeCiphertext = [u8; 36]`,
  `solana-zk-sdk-pod-0.1.2/src/encryption/mod.rs:13`) + 2 bools + 4 × `U64` counters — probed 295
  (`confidential_transfer/mod.rs:66–116`). ElGamal ciphertext = 64 bytes
  (`ELGAMAL_CIPHERTEXT_LEN = PEDERSEN_COMMITMENT_LEN + DECRYPT_HANDLE_LEN = 32 + 32`).
- `ConfidentialMintBurn` (196) = `confidential_supply` 64 + `decryptable_supply` 36 +
  `supply_elgamal_pubkey` 32 + `pending_burn` 64 (probed; `confidential_mint_burn/mod.rs:20–29`).
- `InterestBearingConfig` (52) = `rate_authority` 32 + `initialization_timestamp` 8 +
  `pre_update_average_rate: i16` 2 + `last_update_timestamp` 8 + `current_rate: i16` 2 (probed 52;-ish (`initialization_timestamp`,
  `pre_update_average_rate: i16`, `last_update_timestamp`, `current_rate: i16`)
  (`interest_bearing_mint/mod.rs:44–56`).
- `ScaledUiAmountConfig` (56) = `authority` 32 + `multiplier: PodF64` 8 +
  `new_multiplier_effective_timestamp` 8 + `new_multiplier` 8 (`scaled_ui_amount/mod.rs:53–63`).
- `PausableConfig` (33) = `authority` 32 + `paused: Bool` 1 (`pausable/mod.rs:22–28`).
- `ConfidentialTransferFeeConfig` (129) = `authority` 32 + `withdraw_withheld_authority_elgamal_pubkey`
  32 + `harvest_to_mint_enabled: Bool` 1 + `withheld_amount` 64 (`confidential_transfer_fee/mod.rs:26–50`).
- `TokenGroup` (80) = `update_authority` 32 + `mint` 32 + `size: U64` 8 + `max_size: U64` 8
  (`spl-token-group-interface-0.7.2/src/state.rs:17–27`).
- `TokenGroupMember` (72) = `mint` 32 + `group` 32 + `member_number` 8 (same file, `:68–76`).
- `PermissionedBurnConfig` (32) = `authority: MaybeNull<Address>` (`permissioned_burn/mod.rs:21–25`).
- Pointers (`MetadataPointer`, `GroupPointer`, `GroupMemberPointer`, `TransferHook`) are all
  `MaybeNull<Address>` ×2 = 64 bytes.

### 1.4 Required companion extensions on `InitializeAccount`

`ExtensionType::required_init_account_extensions`
(`interface/src/extension/mod.rs:1275–1300`):

- `TransferFeeConfig` ⇒ account must also init `TransferFeeAmount`
- `NonTransferable` ⇒ `NonTransferableAccount` **and** `ImmutableOwner`
- `TransferHook` ⇒ `TransferHookAccount`
- `Pausable` ⇒ `PausableAccount`

An SDK sizing accounts must include these automatically
(`try_calculate_account_len_from_mint_data`, `interface/src/extension/account_len.rs:79–105`).

### 1.5 Mainnet-active vs pending

There is **no per-extension runtime feature gate**: extensions are opted into per mint at creation
time by initializing them before `InitializeMint`; once the Token-2022 program (deployed program,
`TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`) is upgraded to include a given processor, any mint may
use it. Verified in `program/src/processor.rs:2160–2250` — every extension prefix dispatches without a
feature check. Status as of this source (Sep 2026):

- **Long-shipped (safe to assume on any current mainnet Token-2022 deployment):** TransferFee,
  MintCloseAuthority, ConfidentialTransfer(+Fee), DefaultAccountState, ImmutableOwner, MemoTransfer,
  NonTransferable, InterestBearing, CpiGuard, PermanentDelegate, TransferHook, MetadataPointer,
  TokenMetadata, GroupPointer/TokenGroup/GroupMemberPointer/TokenGroupMember.
- **Newer (2024–2025 era, present in current mainnet program binary):** MetadataPointer-era additions —
  ConfidentialMintBurn, ScaledUiAmount, Pausable(+PausableAccount), PermissionedBurn.
- **Pending / gated at the instruction level:** `Batch` (tag 255) exists in the current interface and
  program source but is **rejected by the current on-chain processor**
  (`program/src/processor.rs:2250`: `PodTokenInstruction::Batch => Err(TokenError::InvalidInstruction)`);
  it ships with a deployed-program upgrade. `zk-ops` is a compile-time `Cargo` feature pending syscall
  release on all networks (`program/Cargo.toml:17–18`), affecting confidential-transfer proof paths.
- `UnwrapLamports` (tag 45) and `WithdrawExcessLamports` (tag 38) are in the current processor dispatch.

---

## 2. Instruction set: token-2022 vs classic Token program

Wire encoding: first byte = instruction tag (`u8`), then borsh-ish fixed LE data
(`interface/src/instruction.rs:804–984`, `program/src/pod_instruction.rs:59–110`).

### 2.1 Tags 0–24 (identical to classic SPL Token)

| Tag | Instruction | Notes vs classic |
|---:|---|---|
| 0 | `InitializeMint` | same |
| 1 | `InitializeAccount` | same |
| 2 | `InitializeMultisig` | same |
| 3 | `Transfer` (deprecated) | **fails if TransferFeeAmount present** (`interface/src/instruction.rs:137–145`) |
| 4 | `Approve` | same |
| 5 | `Revoke` | same |
| 6 | `SetAuthority` | extra `AuthorityType` variants (see 2.3) |
| 7 | `MintTo` | same |
| 8 | `Burn` | same |
| 9 | `CloseAccount` | extended close conditions (see §3) |
| 10 | `FreezeAccount` | same |
| 11 | `ThawAccount` | same |
| 12 | `TransferChecked` | same |
| 13 | `ApproveChecked` | same |
| 14 | `MintToChecked` | same |
| 15 | `BurnChecked` | same |
| 16 | `InitializeAccount2` | same |
| 17 | `SyncNative` | same |
| 18 | `InitializeAccount3` | same |
| 19 | `InitializeMultisig2` | same |
| 20 | `InitializeMint2` | same |
| 21 | `GetAccountDataSize` | returns `u64` LE via return data |
| 22 | `InitializeImmutableOwner` | **token-2022 only** |
| 23 | `AmountToUiAmount` | f64-based; nondeterministic warning |
| 24 | `UiAmountToAmount` | same caveat |

### 2.2 Tags 25–46, 255 (token-2022 only — all differ from classic)

| Tag | Instruction | Body after tag |
|---:|---|---|
| 25 | `InitializeMintCloseAuthority` | `COption<Address>` (4-byte tag + 32) |
| 26 | `TransferFeeExtension` prefix | sub-tag `u8` (§2.4) |
| 27 | `ConfidentialTransferExtension` prefix | sub-tag `u8` |
| 28 | `DefaultAccountStateExtension` prefix | sub-tag `u8` |
| 29 | `Reallocate` | `Vec<ExtensionType>` (u16 LE each) |
| 30 | `MemoTransferExtension` prefix | sub-tag `u8` (`Enable`=0/`Disable`=1) |
| 31 | `CreateNativeMint` | none |
| 32 | `InitializeNonTransferableMint` | none |
| 33 | `InterestBearingMintExtension` prefix | sub-tag `u8` (`Initialize`=0, `UpdateRate`=1) |
| 34 | `CpiGuardExtension` prefix | sub-tag `u8` (`Enable`=0, `Disable`=1) |
| 35 | `InitializePermanentDelegate` | `Address` (32) |
| 36 | `TransferHookExtension` prefix | sub-tag `u8` (`Initialize`=0, `Update`=1) |
| 37 | `ConfidentialTransferFeeExtension` prefix | sub-tag `u8` |
| 38 | `WithdrawExcessLamports` | none |
| 39 | `MetadataPointerExtension` prefix | sub-tag `u8` (`Initialize`=0, `Update`=1) |
| 40 | `GroupPointerExtension` prefix | sub-tag `u8` (`Initialize`=0, `Update`=1) |
| 41 | `GroupMemberPointerExtension` prefix | sub-tag `u8` (`Initialize`=0, `Update`=1) |
| 42 | `ConfidentialMintBurnExtension` prefix | sub-tag `u8` |
| 43 | `ScaledUiAmountExtension` prefix | sub-tag `u8` (`Initialize`=0, `UpdateMultiplier`=1) |
| 44 | `PausableExtension` prefix | sub-tag `u8` (`Initialize`=0, `Pause`=1, `Resume`=2) |
| 45 | `UnwrapLamports` | `COption<u64>` |
| 46 | `PermissionedBurnExtension` prefix | sub-tag `u8` (`Initialize`=0, `Burn`=1, `BurnChecked`=2, `ConfidentialBurn`=3) |
| 255 | `Batch` | packed sub-instructions; **not yet live in processor** |

Sub-tag ordinals are `num_enum` declaration order (`#[repr(u8)] TryFromPrimitive`), e.g.
`interface/src/extension/transfer_fee/instruction.rs:24` with explicit `buf.push(0..5)` mapping at
lines 215–242: `InitializeTransferFeeConfig`=0, `TransferCheckedWithFee`=1,
`WithdrawWithheldTokensFromMint`=2, `WithdrawWithheldTokensFromAccounts`=3,
`HarvestWithheldTokensToMint`=4, `SetTransferFee`=5.
`ConfidentialTransferInstruction` (`confidential_transfer/instruction.rs:34–465`) sub-tags in order:
`InitializeMint`=0, `UpdateMint`=1, `ConfigureAccount`=2, `ApproveAccount`=3, `EmptyAccount`=4,
`Deposit`=5, `Withdraw`=6, `Transfer`=7, `ApplyPendingBalance`=8, `EnableConfidentialCredits`=9,
`DisableConfidentialCredits`=10, `EnableNonConfidentialCredits`=11, `DisableNonConfidentialCredits`=12,
`TransferWithFee`=13.
`ConfidentialTransferFeeInstruction`: `InitializeConfidentialTransferFeeConfig`=0,
`WithdrawWithheldTokensFromMint`=1, `WithdrawWithheldTokensFromAccounts`=2,
`HarvestWithheldTokensToMint`=3, `EnableHarvestToMint`=4, `DisableHarvestToMint`=5.
`ConfidentialMintBurnInstruction`: `InitializeMint`=0, `RotateSupplyElGamalPubkey`=1,
`UpdateDecryptableSupply`=2, `Mint`=3, `Burn`=4, `ApplyPendingBurn`=5.
`DefaultAccountStateInstruction`: `Initialize`=0, `Update`=1.
`PermissionedBurnInstruction`: `Initialize`=0, `Burn`=1, `BurnChecked`=2, `ConfidentialBurn`=3.
`ScaledUiAmountMintInstruction`: `Initialize`=0, `UpdateMultiplier`=1.
`PausableInstruction`: `Initialize`=0, `Pause`=1, `Resume`=2.

**Exception — `TokenMetadata` and `TokenGroup` use 8-byte borsh discriminators, not the u8-prefix
scheme** (`program/src/processor.rs:2246–2251`): the processor first tries `TokenInstruction::unpack`,
then `TokenMetadataInstruction::unpack` (discriminator `112,132,90,90,11,88,157,87` —
`spl-token-metadata-interface-1.0.1/src/state.rs:44–48`; instruction variants `Initialize`,
`UpdateField`, `RemoveKey`, `UpdateAuthority`, `Emit`), then `TokenGroupInstruction::unpack`
(`spl-token-group-interface-0.7.2/src/instruction.rs:51–92`: `InitializeGroup`,
`UpdateGroupMaxSize`, `UpdateGroupAuthority`, `InitializeMember`, each with `SplDiscriminate` 8-byte
hash discriminators). Transfer-hook *hook-program* instructions likewise use 8-byte discriminators
(`Execute` = hash of `"spl-transfer-hook-interface:execute"`,
`spl-transfer-hook-interface-2.1.0/src/instruction.rs:64–78`).

### 2.3 Extra `AuthorityType` variants

`interface/src/instruction.rs:1242–1277` — classic set (`MintTokens`, `FreezeAccount`, `AccountOwner`,
`CloseAccount`, `TransferFeeConfig`, `WithheldWithdraw`) plus token-2022-only:
`CloseMint`, `InterestRate`, `PermanentDelegate`, `ConfidentialTransferMint`, `TransferHookProgramId`,
`ConfidentialTransferFeeConfig`, `MetadataPointer`, `GroupPointer`, `GroupMemberPointer`,
`ScaledUiAmount`, `Pause`, `PermissionedBurn`.

### 2.4 Per-extension CPI semantics for transfers

All from `program/src/processor.rs:335–583` (`process_transfer`):

- **TransferFee**: `Transfer` (tag 3) hard-fails on any mint with `TransferFeeConfig`
  (`interface/src/instruction.rs:140–143`); clients must use `TransferChecked` (12) or
  `TransferCheckedWithFee` (26/1). Fee is computed off the mint's current-epoch `TransferFee`
  (`transfer_fee/mod.rs:57–105`), the caller-provided `fee` must equal the computed fee else
  `FeeMismatch` (`processor.rs:439–446`); fee is withheld in the **destination** account's
  `TransferFeeAmount.withheld_amount` (`processor.rs:545–556`).
- **TransferHook**: if mint carries `TransferHook`, the processor sets `transferring=true` on both
  accounts, CPIs the hook program's `Execute` (8-byte discriminator) via
  `spl_transfer_hook_interface::onchain::invoke_execute`, then unsets the flag
  (`processor.rs:559–580`). Omitting the mint in a checked transfer ⇒ `MintRequiredForTransfer`.
  Hook extra accounts come from the hook program's `ExtraAccountMetaList` PDA
  (seeds `"extra-account-metas"`, mint) under the *hook program id*.
- **CpiGuard**: when `lock_cpi` is set, any transfer/mint-to/burn where the owner is the signing
  authority **and** `in_cpi()` (`sol_get_stack_height() > TRANSACTION_LEVEL_STACK_HEIGHT`,
  `program/src/extension/cpi_guard/mod.rs:14–25`) fails (`CpiGuardTransferBlocked`,
  `processor.rs:452–463`).
- **MemoTransfer**: `memo_required` checks source *and* destination and demands a preceding sibling
  memo instruction (`processor.rs:489–505`, `memo_transfer/mod.rs:146–151`).
- **Pausable**: `paused` on the mint blocks transfers/mints/burns (`processor.rs:400–405`).
- **PermanentDelegate**: delegate authority path validated first; can transfer/burn anyone's tokens
  (`processor.rs:463–472`).
- **NonTransferable**: rejected earlier in the instruction preamble (account carries
  `NonTransferableAccount`).
- **ConfidentialTransfer**: base `Transfer` is refused unless the destination's
  `ConfidentialTransferAccount.non_confidential_transfer_allowed()` passes
  (`processor.rs:519–525`); confidential movement goes through tags 27/*.

---

## 3. Recommended implementation order under a bounded compile-time capacity policy

Design constraints recap (from `ProofForge/Svm/Cpi/TokenTlv.lean`): forward-only bounded TLV cursor,
unknown extensions rejected atomically, capacity computed at compile time, fail-closed.

### Tier 0 — already landed
`MintCloseAuthority` (ordinal 3, 32-byte body) — done in `TokenTlv.lean` / `Sdk/Token2022.lean`.

### Tier 1 — zero/one-byte markers and fixed small bodies (highest value/effort ratio)
All bodies are ≤ 8 bytes, fully static, and their semantics are pure predicates over base state:

1. **ImmutableOwner** (#7, 0 bytes) — marker; account-level policy: reject `SetAuthority(AccountOwner)`.
2. **NonTransferable** (#9, 0) + **NonTransferableAccount** (#13, 0) — pair; policy: reject every
   transfer path. Required companion pair (§1.4) makes them a single slice.
3. **DefaultAccountState** (#6, 1 byte) — one `PodAccountState` byte; drives account-init policy.
4. **MemoTransfer** (#8, 1) and **CpiGuard** (#11, 1) — boolean flags; CPI lowering is a pure
   `if flag then fail` rule, ideal for Lean proofs.
5. **TransferFeeAmount** (#2, 8 bytes) — withheld `U64`; affects close-account predicate
   (`closable()` = withheld == 0, `transfer_fee/mod.rs:185–195`).

### Tier 2 — fixed 32–64-byte bodies with pure data semantics
6. **TransferHook** (#14, 64) + **TransferHookAccount** (#15, 1) — typed body (two `MaybeNull<Address>`).
   CPI semantics demand the hook `Execute` CPI with dynamic extra accounts ⇒ the *hook invocation*
   must be fail-closed (variable account list), but the *mint-side policy* (read program id, refuse
   unknown hook programs) is static. Recommend: type the mint extension; reject account-level
   `TransferHookAccount.transferring` flag transitions in the SDK's bounded model.
7. **MetadataPointer / GroupPointer / GroupMemberPointer** (#18/20/22, 64 each) — identical shape;
   one generic pointer-decoder covers all three. Static: pointer targets are read-only data for a
   CPI-ing SDK; the `spl-token-metadata-interface`/`spl-token-group-interface` instruction sets
   (8-byte discriminators) can be typed later.
8. **Pausable** (#26, 33) + **PausableAccount** (#27, 0) — one flag + authority; companion pair.
9. **PermissionedBurn** (#28, 32) — single authority; `Burn`/`BurnChecked` need an extra signer.
10. **PermanentDelegate** (#12, 32) — single address; affects transfer authority resolution only.
11. **TransferFeeConfig** (#1, 108) — fixed but large; epoch-dependent fee math (`U64`×2+`U16`×2
    inside two `TransferFee`s). Worth typed support for `TransferCheckedWithFee`; the fee
    computation is pure (`calculate_fee`, ceiling division, `transfer_fee/mod.rs:66–79`) and provable.

### Tier 3 — heavy fixed bodies, likely defer or fail-closed
12. **InterestBearingConfig** (#10, 54) — f64 exponent math (`pre_update_exp`,
    `interest_bearing_mint/mod.rs:62–67`); floating-point semantics are hostile to bounded proofs.
13. **ScaledUiAmount** (#26→#25, 56) — also f64. Fail-closed in the SDK is acceptable: refuse CPIs
    into mints carrying these unless the user opts in with a float-mode flag.
14. **TokenGroup** (#21, 84) / **TokenGroupMember** (#23, 72) — fixed and pure; type them after
    pointers, they're only needed for group/NFT SDK flows.
15. **ConfidentialTransferMint** (#4, 64) / **ConfidentialTransferAccount** (#5, 295) /
    **ConfidentialTransferFee*** (#16, 129; #17, 64) / **ConfidentialMintBurn** (#24, 196) —
    fixed-size but require ElGamal/zk proof instructions (`zk-ops` feature still pending syscall
    release, `program/Cargo.toml:17`). Recommend fail-closed: reject any account/mint carrying these
    ordinals until a dedicated confidential slice exists.

### Tier 4 — runtime-variable, permanently fail-closed under bounded policy
- **TokenMetadata** (#2) — the only `sized()==false` production extension. `UpdateField`/`RemoveKey`
  reallocate the TLV entry; length is unbounded (`u16` cap). Policy: reject at parse time.
- **Reallocate** (tag 29), **Batch** (tag 255) — variable instruction bodies; Batch additionally not
  yet live in the processor.
- Variable account lists (multisig signers, transfer-hook extra accounts,
  `WithdrawWithheldTokensFromAccounts { num_token_accounts }`) — bound at compile time to a fixed
  max or reject.

### Sizing formula the SDK should mirror (compile-time)

`account_len = 82 + 83 (mint padding) + 1 (AccountType) + Σ over distinct ordinals (4 + body_len)`
for mints (= `166 + Σ`), and `165 + 1 + Σ` for accounts (also `166 + Σ`), then
`if == 355 then 357` (`adjust_len_for_multisig`). Everything in this formula is a constant
expression given a fixed ordinal set — a perfect fit for Lean compile-time capacity checks; the
`TlvLenAccumulator` dedup bitset (`interface/src/extension/account_len.rs:17–44`) is the exact
semantics to reproduce.

---

## 4. Ecosystem program set worth supporting

### 4.1 ComputeBudget program (`ComputeBudget111111111111111111111111111111`)

Source: `solana-compute-budget-interface-3.0.0/src/lib.rs:24–70` (crate used by agave
`compute-budget-instruction/src/compute_budget_instruction_details.rs:137–163`).

Wire: `data[0] = tag`, then LE integer; **no accounts**. `RequestUnits` (old `RequestUnitsDeprecated`)
is gone from the current interface enum; enum starts with a reserved `Unused = 0`:

| Tag | Instruction | Data | Sanitize |
|---:|---|---|---|
| 0 | (reserved `Unused`) | — | invalid |
| 1 | `RequestHeapFrame` | `u32` LE | bytes ∈ [MIN_HEAP_FRAME..MAX_HEAP_FRAME], multiple of 1024 |
| 2 | `SetComputeUnitLimit` | `u32` LE | capped at `MAX_COMPUTE_UNIT_LIMIT` |
| 3 | `SetComputeUnitPrice` | `u64` LE | micro-lamports |
| 4 | `SetLoadedAccountsDataSizeLimit` | `u32` LE | must be nonzero |

Duplicates of the same tag in one transaction ⇒ `TransactionError::DuplicateInstruction`
(`compute_budget_instruction_details.rs:144–160` in agave). An SDK lowering this program only needs
a fixed 5-byte/9-byte instruction builder — trivially bounded.

### 4.2 Address Lookup Table program (`AddressLookupTab1e1111111111111111111111111`)

Sources: `solana-program/address-lookup-table` `program/src/instruction.rs` (Core BPF program, migrated
from the agave builtin — `anza-xyz/agave` `program-binaries/src/lib.rs:60–64` records
`core_bpf_address_lookup_table-3.0.0.so` owned by `bpf_loader_upgradeable`, no feature gate), and
interface `solana-address-lookup-table-interface-3.1.0/src/instruction.rs:19–68`
(`ProgramInstruction`). **Wire encoding is borsh enum order = declaration order** via
`Instruction::new_with_bincode` (`instruction.rs:99,153,196,219,249`):

| Tag | Instruction | Data | Accounts |
|---:|---|---|---|
| 0 | `CreateLookupTable` | `recent_slot: u64`, `bump_seed: u8` | 0 `[w]` table (PDA of authority+recent_slot), 1 `[s]` authority, 2 `[s,w]` payer, 3 `[]` system program |
| 1 | `FreezeLookupTable` | — | 0 `[w]` table, 1 `[s]` authority |
| 2 | `ExtendLookupTable` | borsh `Vec<Pubkey>` (u32 len + 32×n) | 0 `[w]` table, 1 `[s]` authority, 2 `[s,w] opt` payer, 3 `[] opt` system program |
| 3 | `DeactivateLookupTable` | — | 0 `[w]` table, 1 `[s]` authority |
| 4 | `CloseLookupTable` | — | 0 `[w]` table, 1 `[s]` authority, 2 `[w]` recipient |

Bounded-capacity notes (from `alt/program/src/processor.rs:76–107`): max input 1232 bytes;
`ExtendLookupTable` caps `new_addresses` at `MAX_NEW_KEYS_VECTOR_LEN = (1232−4−8)/32 = 37`;
tables deactivate with a one-slot-hash cool-down (~`MAX_ENTRIES` slots) before `CloseLookupTable`
succeeds; table address is a PDA of `[authority, recent_slot.to_le_bytes()]`
(`instruction.rs:70–77`). A compile-time cap of 37 keys per extend is exactly the runtime limit.

### 4.3 Loader-v3 (bpf_loader_upgradeable) typed lifecycle scope

Sources: `solana-loader-v3-interface-6.1.1/src/instruction.rs:26–220` (`#[repr(u8)]`
`UpgradeableLoaderInstruction` — **tags are explicit ordinals**, data is borsh after the tag via
`Instruction::new_with_bincode`):

| Tag | Instruction | Data | Accounts |
|---:|---|---|---|
| 0 | `InitializeBuffer` | — | 0 `[w]` buffer, 1 `[] opt` authority |
| 1 | `Write` | `offset: u32`, `bytes: Vec<u8>` | 0 `[w]` buffer, 1 `[s]` authority |
| 2 | `DeployWithMaxDataLen` | `max_data_len: usize(u64 borsh)` | 0 `[w]` program, 1 `[w]` programdata, 2 `[w]` buffer, 3 `[w]` payer, 4 `[]` rent sysvar, 5 `[] opt` clock sysvar, 6 `[] opt` authority |
| 3 | `Upgrade` | — | 0 `[w]` programdata, 1 `[w]` program, 2 `[w]` buffer, 3 `[w]` spill, 4 `[]` rent, 5 `[]` clock, 6 `[s]` authority |
| 4 | `SetAuthority` | borsh `COption<Pubkey>` | 0 `[w]` buffer/programdata, 1 `[s]` authority, 2 `[] opt` new authority |
| 5 | `Close` | — | 0 `[w]` closee, 1 `[w]` recipient, 2 `[s]` authority, 3 `[w]` program (if closing programdata) |
| 6 | `ExtendProgram` | `additional_bytes: u32` | 0 `[w]` programdata, 1 `[w]` program, 2 `[] opt` system, 3 `[s,w] opt` payer (SIMD-0431: `additional_bytes ≥ 10_240` unless near 10 MiB cap — `instruction.rs:16–19`) |
| 7 | `SetAuthorityChecked` | borsh `COption<Pubkey>` | 0 `[w]` target, 1 `[s]` authority, 2 `[s]` new authority |
| 8 | `Migrate` | — | 0 `[w]` programdata, 1 `[w]` program, 2 `[s]` authority (migrates to loader-v4) |
| 9 | `ExtendProgramChecked` | `additional_bytes: u32` | 0 `[w]` programdata, 1 `[w]` program, 2 `[s]` authority, 3 `[] opt` system, 4 `[s,w] opt` payer |

SDK scope recommendation: type **`Upgrade` (3)**, **`SetAuthority`/`SetAuthorityChecked` (4/7)**,
**`Close` (5)**, **`Migrate` (8)** — fixed account ordering, fixed or zero data, trivially bounded.
`Write`/`DeployWithMaxDataLen`/`ExtendProgram*` carry variable `Vec<u8>` or payer-dependent account
lists — bounded only with an explicit max-ELF-size constant, else fail-closed.

Loader-v4 (`solana-loader-v4-interface-3.1.0/src/instruction.rs:15–60`), tags are `#[repr(u8)]`
ordinals 0–6 with explicit byte checks (`instruction.rs:126–147`): `Write`=0, `Copy`=1,
`SetProgramLength`=2, `Deploy`=3, `Retract`=4, `TransferAuthority`=5, `Finalize`=6; all borsh data,
single program account + authority (+ optional source/recipient). Include only if surfpool tests
require v4 deployments; `Migrate` from v3 lands programs here.

---

## 5. Caveats for the ProofForge implementation

- The 4-byte TLV header means even 0-byte extensions cost 4 bytes in the account; the
  `adjust_len_for_multisig` 355→357 bump must be mirrored or account sizing will disagree with the
  program's `GetAccountDataSize`.
- Sub-instruction ordinals for pointer/cpi-guard/memo/pausable-style extensions are num-enum
  declaration order (0-based), **except** `TransferFeeInstruction` which pushes explicit values
  (0–5) and `ConfidentialTransferInstruction` (0–12) — both happen to match declaration order, but
  `DefaultAccountStateInstruction`, `PausableInstruction` etc. rely on the derive; keep one table.
- `TokenMetadata`/`TokenGroup`/hook-`Execute` use 8-byte hash discriminators — a different dispatch
  family than the u8 prefix; our TLV policy must recognize both dispatch forms.
- `Batch` (255) currently errors in the deployed processor; do not emit it.
- CPI-Guard semantics depend on `sol_get_stack_height` — in an SVM host (Mollusk/Surfpool) stack
  height emulation must match agave or guard behavior diverges.
- Instruction-account ordering for extension prefixes: single mint/account first, then authority
  signers; `WithdrawWithheldTokensFromAccounts` is `(mint, destination, authority, N signers…)`
  with `num_token_accounts` u8 (`transfer_fee/instruction.rs:155–172, 230–236`).
