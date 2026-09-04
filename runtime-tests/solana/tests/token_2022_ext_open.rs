mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    mollusk_svm_programs_token::token2022,
    mollusk_svm_programs_token_2022::{
        create_account_for_mint_with_extensions, create_account_for_token_account_with_extensions,
        required_account_extensions_for_mint, AccountState, CpiGuard, DefaultAccountState,
        GroupPointer, GroupMemberPointer, MemoTransfer, MetadataPointer, Mint, MintExtension,
        TokenAccount, TokenAccountExtension, TokenGroup, TokenGroupMember, TransferHook,
        TransferHookAccount,
    },
    sha2::{Digest, Sha256},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_native_token::LAMPORTS_PER_SOL,
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
};

const DISCRIMINATOR_DOMAIN: &str = "proof-forge-solana-v1:";
const DECIMALS: u8 = 6;
const INITIAL: u64 = 10_000_000;
const DELTA: u64 = 1_000_000;

fn instruction_discriminator(name: &str, param_count: usize) -> [u8; 8] {
    let params = vec!["u64"; param_count].join(",");
    let preimage = format!("{DISCRIMINATOR_DOMAIN}{name}({params})");
    Sha256::digest(preimage.as_bytes())[..8].try_into().unwrap()
}

fn instruction_data(disc: &[u8; 8], params: &[u64]) -> Vec<u8> {
    let mut data = disc.to_vec();
    for p in params {
        data.extend_from_slice(&p.to_le_bytes());
    }
    data
}

fn harness() -> (Pubkey, Mollusk) {
    let (program_id, mut mollusk) = common::harness("Token2022ExtOpen", "PF_TOKEN2022EXTOPEN_SO");
    token2022::add_program(&mut mollusk);
    (program_id, mollusk)
}

fn mint_state(authority: Pubkey, supply: u64) -> Mint {
    Mint {
        mint_authority: Some(authority).into(),
        supply,
        decimals: DECIMALS,
        is_initialized: true,
        freeze_authority: None.into(),
    }
}

fn token_state(mint: Pubkey, owner: Pubkey, amount: u64) -> TokenAccount {
    TokenAccount {
        mint,
        owner,
        amount,
        delegate: None.into(),
        state: AccountState::Initialized,
        is_native: None.into(),
        delegated_amount: 0,
        close_authority: None.into(),
    }
}

fn funded() -> Account {
    Account::new(LAMPORTS_PER_SOL, 0, &Pubkey::default())
}

enum MintExt {
    Memo,
    Hook,
    Das,
    MdPtr,
    GrpPtr,
    GrpMemPtr,
    TGrp,
    TGrpMem,
}

fn mint_with(extension: &MintExt, authority: Pubkey) -> (Account, Vec<TokenAccountExtension>) {
    match extension {
        MintExt::Memo => (
            create_account_for_mint_with_extensions(mint_state(authority, INITIAL), &[]),
            vec![TokenAccountExtension::MemoTransfer(MemoTransfer {
                require_incoming_transfer_memos: true.into(),
            })],
        ),
        MintExt::Hook => (
            create_account_for_mint_with_extensions(
                mint_state(authority, INITIAL),
                &[MintExtension::TransferHook(TransferHook {
                    authority: Some(authority).try_into().unwrap(),
                    program_id: Some(Pubkey::new_unique()).try_into().unwrap(),
                })],
            ),
            vec![],
        ),
        MintExt::Das => (
            create_account_for_mint_with_extensions(
                mint_state(authority, INITIAL),
                &[MintExtension::DefaultAccountState(DefaultAccountState {
                    state: spl_token_2022_interface::state::AccountState::Initialized.into(),
                })],
            ),
            vec![],
        ),
        MintExt::MdPtr => (
            create_account_for_mint_with_extensions(
                mint_state(authority, INITIAL),
                &[MintExtension::MetadataPointer(MetadataPointer {
                    authority: Some(authority).try_into().unwrap(),
                    metadata_address: Some(Pubkey::new_unique()).try_into().unwrap(),
                })],
            ),
            vec![],
        ),
        MintExt::GrpPtr => (
            create_account_for_mint_with_extensions(
                mint_state(authority, INITIAL),
                &[MintExtension::GroupPointer(GroupPointer {
                    authority: Some(authority).try_into().unwrap(),
                    group_address: Some(Pubkey::new_unique()).try_into().unwrap(),
                })],
            ),
            vec![],
        ),
        MintExt::GrpMemPtr => (
            create_account_for_mint_with_extensions(
                mint_state(authority, INITIAL),
                &[MintExtension::GroupMemberPointer(GroupMemberPointer {
                    authority: Some(authority).try_into().unwrap(),
                    member_address: Some(Pubkey::new_unique()).try_into().unwrap(),
                })],
            ),
            vec![],
        ),
        MintExt::TGrp => (
            create_account_for_mint_with_extensions(
                mint_state(authority, INITIAL),
                &[MintExtension::TokenGroup(TokenGroup {
                    update_authority: Some(authority).try_into().unwrap(),
                    mint: Pubkey::new_unique(),
                    size: 0.into(),
                    max_size: u64::MAX.into(),
                })],
            ),
            vec![],
        ),
        MintExt::TGrpMem => (
            create_account_for_mint_with_extensions(
                mint_state(authority, INITIAL),
                &[MintExtension::TokenGroupMember(TokenGroupMember {
                    mint: Pubkey::new_unique(),
                    group: Pubkey::new_unique(),
                    member_number: 1.into(),
                })],
            ),
            vec![],
        ),
    }
}

fn run(
    extension: &MintExt,
    entry: &str,
    expect_success: bool,
    expected_err: Option<ProgramError>,
) {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let (mint_acct, dest_ext) = mint_with(extension, authority);

    let disc = instruction_discriminator(entry, 1);
    let ix = Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[DELTA]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(authority, true),
            AccountMeta::new(source, false),
            AccountMeta::new_readonly(mint, false),
            AccountMeta::new(dest, false),
            AccountMeta::new_readonly(token2022::ID, false),
        ],
    );

    let mut dest_exts = dest_ext;
    let required = required_account_extensions_for_mint(&mint_acct.data);
    for ext in required {
        if !dest_exts
            .iter()
            .any(|e| std::mem::discriminant(e) == std::mem::discriminant(&ext))
        {
            dest_exts.push(ext);
        }
    }
    let required_source = required_account_extensions_for_mint(&mint_acct.data);

    let delta_bytes = DELTA.to_le_bytes();
    let success_check = Check::success();
    let move_check = Check::account(&dest).data_slice(64, &delta_bytes).build();
    let mut checks: Vec<Check> = Vec::new();
    if expect_success {
        checks.push(success_check);
        checks.push(move_check);
    } else {
        checks.push(Check::err(expected_err.unwrap()));
    }

    mollusk.process_and_validate_instruction(
        &ix,
        &[
            (
                common::dummy_state_key(&program_id),
                common::dummy_state_account(&program_id),
            ),
            (authority, funded()),
            (
                source,
                create_account_for_token_account_with_extensions(
                    token_state(mint, authority, INITIAL),
                    &required_source,
                ),
            ),
            (mint, mint_acct),
            (
                dest,
                create_account_for_token_account_with_extensions(
                    token_state(mint, authority, 0),
                    &dest_exts,
                ),
            ),
            token2022::keyed_account(),
        ],
        &checks,
    );
}

#[test]
fn memo_transfer_required_no_memo_rejected() {
    // Destination requires an incoming memo; this fixture sends none, so the token
    // program rejects with the official NoMemo terminal (Custom 36).
    run(
        &MintExt::Memo,
        "transferMemo",
        false,
        Some(ProgramError::Custom(36)),
    );
}

#[test]
fn transfer_hook_undeployed_program_fails_closed() {
    // The mint declares an undeployed hook program; the CPI fails at the runtime level
    // and the destination stays unchanged.
    run(&MintExt::Hook, "transferHook", false, Some(ProgramError::Custom(1)));
}

#[test]
fn default_account_state_mint_transfer_succeeds() {
    run(&MintExt::Das, "transferDas", true, None);
}

#[test]
fn metadata_pointer_mint_transfer_succeeds() {
    run(&MintExt::MdPtr, "transferMdptr", true, None);
}

#[test]
fn group_pointer_mint_transfer_succeeds() {
    run(&MintExt::GrpPtr, "transferGptr", true, None);
}

#[test]
fn group_member_pointer_mint_transfer_succeeds() {
    run(&MintExt::GrpMemPtr, "transferGmptr", true, None);
}

#[test]
fn token_group_mint_transfer_succeeds() {
    run(&MintExt::TGrp, "transferTgrp", true, None);
}

#[test]
fn token_group_member_mint_transfer_succeeds() {
    run(&MintExt::TGrpMem, "transferTgmem", true, None);
}