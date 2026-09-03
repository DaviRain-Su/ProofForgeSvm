mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    mollusk_svm_programs_token::token,
    sha2::{Digest, Sha256},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_native_token::LAMPORTS_PER_SOL,
    solana_pubkey::Pubkey,
    solana_rent::Rent,
    spl_token_interface::state::{Account as TokenAccount, AccountState, Mint},
};

const DISCRIMINATOR_DOMAIN: &str = "proof-forge-solana-v1:";
const DECIMALS: u8 = 6;
const INITIAL: u64 = 10_000_000;
const DELTA: u64 = 1_000_000;
const TOKEN_ACCOUNT_LEN: usize = 165;

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
    let (program_id, mut mollusk) = common::harness("TokenMintBurn", "PF_TOKENMINTBURN_SO");
    token::add_program(&mut mollusk);
    (program_id, mollusk)
}

fn mint_account(authority: Pubkey, supply: u64) -> Account {
    token::create_account_for_mint(Mint {
        mint_authority: Some(authority).into(),
        supply,
        decimals: DECIMALS,
        is_initialized: true,
        freeze_authority: None.into(),
    })
}

fn token_account(mint: Pubkey, owner: Pubkey, amount: u64) -> Account {
    token::create_account_for_token_account(TokenAccount {
        mint,
        owner,
        amount,
        delegate: None.into(),
        state: AccountState::Initialized,
        is_native: None.into(),
        delegated_amount: 0,
        close_authority: None.into(),
    })
}

fn uninitialized_token_account() -> Account {
    Account::new(
        Rent::default().minimum_balance(TOKEN_ACCOUNT_LEN),
        TOKEN_ACCOUNT_LEN,
        &token::ID,
    )
}

fn funded() -> Account {
    Account::new(LAMPORTS_PER_SOL, 0, &Pubkey::default())
}

fn minted_account_data(mint: Pubkey, owner: Pubkey, amount: u64) -> Vec<u8> {
    let mut account = token_account(mint, owner, amount);
    std::mem::take(&mut account.data)
}

#[test]
fn mint_to_increases_dest_and_supply() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let (token_id, token_acc) = token::keyed_account();
    let pad = Pubkey::new_unique();
    let disc = instruction_discriminator("mint", 1);
    let ix = Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[DELTA]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(authority, true),
            AccountMeta::new(mint, false),
            AccountMeta::new(dest, false),
            AccountMeta::new_readonly(token_id, false),
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
            (mint, mint_account(authority, 0)),
            (dest, token_account(mint, authority, 0)),
            (token_id, token_acc),
            (pad, funded()),
        ],
        &[
            Check::success(),
            Check::account(&dest)
                .data(&minted_account_data(mint, authority, DELTA))
                .build(),
            Check::account(&mint)
                .data(&{
                    let mut m = mint_account(authority, DELTA);
                    std::mem::take(&mut m.data)
                })
                .build(),
        ],
    );
}

#[test]
fn burn_decreases_source_and_supply() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let (token_id, token_acc) = token::keyed_account();
    let pad = Pubkey::new_unique();
    let disc = instruction_discriminator("burn", 1);
    let ix = Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[DELTA]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(authority, true),
            AccountMeta::new(source, false),
            AccountMeta::new(mint, false),
            AccountMeta::new_readonly(token_id, false),
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
            (source, token_account(mint, authority, INITIAL)),
            (mint, mint_account(authority, INITIAL)),
            (token_id, token_acc),
            (pad, funded()),
        ],
        &[
            Check::success(),
            Check::account(&source)
                .data(&minted_account_data(mint, authority, INITIAL - DELTA))
                .build(),
            Check::account(&mint)
                .data(&{
                    let mut m = mint_account(authority, INITIAL - DELTA);
                    std::mem::take(&mut m.data)
                })
                .build(),
        ],
    );
}

#[test]
fn open_acc2_initializes_with_owner_and_rent() {
    let (program_id, mollusk) = harness();
    let owner = Pubkey::new_unique();
    let account = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let (token_id, token_acc) = token::keyed_account();
    let (rent_id, rent_account) = mollusk.sysvars.keyed_account_for_rent_sysvar();
    let disc = instruction_discriminator("openAcc2", 0);
    let ix = Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(owner, true),
            AccountMeta::new(account, false),
            AccountMeta::new_readonly(mint, false),
            AccountMeta::new_readonly(rent_id, false),
            AccountMeta::new_readonly(token_id, false),
        ],
    );
    mollusk.process_and_validate_instruction(
        &ix,
        &[
            (
                common::dummy_state_key(&program_id),
                common::dummy_state_account(&program_id),
            ),
            (owner, funded()),
            (account, uninitialized_token_account()),
            (mint, mint_account(owner, 0)),
            (rent_id, rent_account),
            (token_id, token_acc),
        ],
        &[
            Check::success(),
            Check::account(&account)
                .data(&minted_account_data(mint, owner, 0))
                .build(),
        ],
    );
}
