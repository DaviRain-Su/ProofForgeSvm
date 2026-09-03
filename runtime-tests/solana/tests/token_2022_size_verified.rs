mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    mollusk_svm_programs_token::{token, token2022},
    sha2::{Digest, Sha256},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_native_token::LAMPORTS_PER_SOL,
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
    spl_token_interface::state::Mint,
};

const DISCRIMINATOR_DOMAIN: &str = "proof-forge-solana-v1:";
const DECIMALS: u8 = 6;
const TOKEN_ACCOUNT_LEN: u64 = 165;

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
    let (program_id, mut mollusk) =
        common::harness("Token2022SizeVerified", "PF_TOKEN2022SIZE_VERIFIED_SO");
    token::add_program(&mut mollusk);
    token2022::add_program(&mut mollusk);
    (program_id, mollusk)
}

fn mint_account(authority: Pubkey) -> Account {
    token::create_account_for_mint(Mint {
        mint_authority: Some(authority).into(),
        supply: 0,
        decimals: DECIMALS,
        is_initialized: true,
        freeze_authority: None.into(),
    })
}

fn mint_2022_account(authority: Pubkey) -> Account {
    token2022::create_account_for_mint(Mint {
        mint_authority: Some(authority).into(),
        supply: 0,
        decimals: DECIMALS,
        is_initialized: true,
        freeze_authority: None.into(),
    })
}

fn funded() -> Account {
    Account::new(LAMPORTS_PER_SOL, 0, &Pubkey::default())
}

fn build_ix(
    program_id: Pubkey,
    dummy: Pubkey,
    mint: Pubkey,
    token_id: Pubkey,
    dummy_signer: bool,
) -> Instruction {
    let disc = instruction_discriminator("size", 0);
    Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(dummy, dummy_signer),
            AccountMeta::new_readonly(mint, false),
            AccountMeta::new_readonly(token_id, false),
        ],
    )
}

#[test]
fn verified_2022_size_accepts_token_2022_setter() {
    let (program_id, mollusk) = harness();
    let dummy = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let (token_id, token_acc) = token2022::keyed_account();
    let ix = build_ix(program_id, dummy, mint, token_id, true);
    mollusk.process_and_validate_instruction(
        &ix,
        &[
            (
                common::dummy_state_key(&program_id),
                common::dummy_state_account(&program_id),
            ),
            (dummy, funded()),
            (mint, mint_2022_account(dummy)),
            (token_id, token_acc),
        ],
        &[
            Check::success(),
            Check::return_data(&TOKEN_ACCOUNT_LEN.to_le_bytes()),
        ],
    );
}

#[test]
fn verified_2022_size_rejects_classic_token_setter() {
    let (program_id, mollusk) = harness();
    let dummy = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let (token_id, token_acc) = token::keyed_account();
    let ix = build_ix(program_id, dummy, mint, token_id, true);
    mollusk.process_and_validate_instruction(
        &ix,
        &[
            (
                common::dummy_state_key(&program_id),
                common::dummy_state_account(&program_id),
            ),
            (dummy, funded()),
            (mint, mint_account(dummy)),
            (token_id, token_acc),
        ],
        &[Check::err(ProgramError::Custom(1))],
    );
}
