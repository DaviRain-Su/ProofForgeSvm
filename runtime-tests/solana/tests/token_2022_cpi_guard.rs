mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    mollusk_svm_programs_token::token2022,
    mollusk_svm_programs_token_2022::{
        create_account_for_mint_with_extensions, create_account_for_token_account_with_extensions,
        AccountState, CpiGuard, Mint, TokenAccount, TokenAccountExtension,
    },
    sha2::{Digest, Sha256},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_native_token::LAMPORTS_PER_SOL,
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
    spl_token_2022_interface::extension::BaseStateWithExtensions,
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
    let (program_id, mut mollusk) = common::harness("Token2022CpiGuard", "PF_TOKEN2022CPIGUARD_SO");
    token2022::add_program(&mut mollusk);
    (program_id, mollusk)
}

fn mint_account(authority: Pubkey) -> Account {
    create_account_for_mint_with_extensions(
        Mint {
            mint_authority: Some(authority).into(),
            supply: INITIAL,
            decimals: DECIMALS,
            is_initialized: true,
            freeze_authority: None.into(),
        },
        &[],
    )
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

/// Source account with the CpiGuard extension whose lock flag is `locked`.
fn guarded_source(mint: Pubkey, owner: Pubkey, locked: bool) -> Account {
    let mut account = create_account_for_token_account_with_extensions(
        token_state(mint, owner, INITIAL),
        &[TokenAccountExtension::CpiGuard(CpiGuard {
            lock_cpi: locked.into(),
        })],
    );
    // Sanity: the lock flag must be present in the serialized extension body.
    let state = spl_token_2022_interface::extension::StateWithExtensions::<
        spl_token_2022_interface::state::Account,
    >::unpack(&account.data)
    .expect("unpack source");
    let guard = state
        .get_extension::<spl_token_2022_interface::extension::cpi_guard::CpiGuard>()
        .expect("cpi guard extension");
    assert_eq!(bool::from(guard.lock_cpi), locked);
    account
}

fn build_ix(program_id: Pubkey, authority: Pubkey, source: Pubkey, mint: Pubkey, dest: Pubkey) -> Instruction {
    let disc = instruction_discriminator("transferGuarded", 1);
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
fn unlocked_guard_allows_transfer() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let ix = build_ix(program_id, authority, source, mint, dest);
    mollusk.process_and_validate_instruction(
        &ix,
        &[
            (
                common::dummy_state_key(&program_id),
                common::dummy_state_account(&program_id),
            ),
            (authority, funded()),
            (source, guarded_source(mint, authority, false)),
            (mint, mint_account(authority)),
            (dest, create_account_for_token_account_with_extensions(token_state(mint, authority, 0), &[])),
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
fn locked_guard_rejected_by_token_program() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let ix = build_ix(program_id, authority, source, mint, dest);
    mollusk.process_and_validate_instruction(
        &ix,
        &[
            (
                common::dummy_state_key(&program_id),
                common::dummy_state_account(&program_id),
            ),
            (authority, funded()),
            (source, guarded_source(mint, authority, true)),
            (mint, mint_account(authority)),
            (dest, create_account_for_token_account_with_extensions(token_state(mint, authority, 0), &[])),
            token2022::keyed_account(),
        ],
        &[
            // Token-2022 CpiGuardTransferBlocked = TokenError discriminant 42.
            Check::err(ProgramError::Custom(42)),
            Check::account(&source)
                .data_slice(64, &INITIAL.to_le_bytes())
                .build(),
        ],
    );
}