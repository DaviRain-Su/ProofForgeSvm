mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    mollusk_svm_programs_token::token2022,
    mollusk_svm_programs_token_2022::{
        create_account_for_mint_with_extensions, create_account_for_token_account_with_extensions,
        AccountState, Mint, MintExtension, TokenAccount, TokenAccountExtension,
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
    let digest = Sha256::digest(preimage.as_bytes());
    digest[..8].try_into().unwrap()
}

fn instruction_data(disc: &[u8; 8], params: &[u64]) -> Vec<u8> {
    let mut data = disc.to_vec();
    for p in params {
        data.extend_from_slice(&p.to_le_bytes());
    }
    data
}

fn harness() -> (Pubkey, Mollusk) {
    let (program_id, mut mollusk) = common::harness("Token2022Ext", "PF_TOKEN2022EXT_SO");
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

fn base_ix(
    program_id: Pubkey,
    name: &str,
    authority: Pubkey,
    source: Pubkey,
    mint: Pubkey,
    dest: Pubkey,
) -> Instruction {
    let disc = instruction_discriminator(name, 1);
    Instruction::new_with_bytes(
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
    )
}

#[test]
fn transfer_checked_immutable_owner_succeeds() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let ix = base_ix(program_id, "transferImmutable", authority, source, mint, dest);
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
                    &[TokenAccountExtension::ImmutableOwner],
                ),
            ),
            (mint, create_account_for_mint_with_extensions(mint_state(authority, INITIAL), &[])),
            (
                dest,
                create_account_for_token_account_with_extensions(
                    token_state(mint, authority, 0),
                    &[TokenAccountExtension::ImmutableOwner],
                ),
            ),
            token2022::keyed_account(),
        ],
        &[
            Check::success(),
            Check::account(&dest)
                .data_slice(64, &DELTA.to_le_bytes())
                .build(),
        ],
    );
}

#[test]
fn transfer_checked_non_transferable_rejected_by_token_program() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let ix = base_ix(program_id, "transferNonTransferable", authority, source, mint, dest);
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
                    &[TokenAccountExtension::NonTransferableAccount],
                ),
            ),
            (
                mint,
                create_account_for_mint_with_extensions(
                    mint_state(authority, INITIAL),
                    &[MintExtension::NonTransferable],
                ),
            ),
            (
                dest,
                create_account_for_token_account_with_extensions(
                    token_state(mint, authority, 0),
                    &[TokenAccountExtension::NonTransferableAccount],
                ),
            ),
            token2022::keyed_account(),
        ],
        &[
            Check::err(ProgramError::Custom(37)),
            Check::account(&source)
                .data_slice(64, &INITIAL.to_le_bytes())
                .build(),
        ],
    );
}

#[test]
fn set_authority_immutable_owner_rejected_by_token_program() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let account = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let new_owner = Pubkey::new_unique();
    let pad = Pubkey::new_unique();
    let disc = instruction_discriminator("setAuthorityImmutable", 0);
    let ix = Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(authority, true),
            AccountMeta::new(account, false),
            AccountMeta::new_readonly(new_owner, false),
            AccountMeta::new_readonly(token2022::ID, false),
            AccountMeta::new(pad, false),
        ],
    );
    mollusk.process_and_validate_instruction(
        &ix,
        &[
            (
                common::dummy_state_key(&program_id),
                common::dummy_state_account(&program_id),
            ),
            (authority, funded()),
            (
                account,
                create_account_for_token_account_with_extensions(
                    token_state(mint, authority, INITIAL),
                    &[TokenAccountExtension::ImmutableOwner],
                ),
            ),
            (new_owner, funded()),
            token2022::keyed_account(),
            (pad, funded()),
        ],
        &[Check::err(ProgramError::Custom(34))],
    );
}
