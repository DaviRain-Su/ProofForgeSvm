mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    mollusk_svm_programs_token::token,
    sha2::{Digest, Sha256},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_native_token::LAMPORTS_PER_SOL,
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
    spl_token_interface::state::{Account as TokenAccount, AccountState, Multisig},
};

const DISCRIMINATOR_DOMAIN: &str = "proof-forge-solana-v1:";
const DECIMALS: u8 = 6;
const INITIAL: u64 = 10_000_000;
const DELTA: u64 = 1_000_000;
const MULTISIG_LEN: usize = 355;

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
    let (program_id, mut mollusk) = common::harness("TokenMultisig", "PF_TOKENMULTISIG_SO");
    token::add_program(&mut mollusk);
    (program_id, mollusk)
}

fn multisig_account(m: u8, signers: &[Pubkey]) -> Account {
    let mut data = vec![0u8; MULTISIG_LEN];
    data[0] = m;
    data[1] = signers.len() as u8;
    data[2] = 1;
    for (i, signer) in signers.iter().enumerate() {
        data[3 + 32 * i..3 + 32 * (i + 1)].copy_from_slice(signer.as_ref());
    }
    let mut account = Account::new(LAMPORTS_PER_SOL, MULTISIG_LEN, &token::ID);
    account.data = data;
    account
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

fn mint_account(authority: Pubkey, supply: u64) -> Account {
    token::create_account_for_mint(spl_token_interface::state::Mint {
        mint_authority: Some(authority).into(),
        supply,
        decimals: DECIMALS,
        is_initialized: true,
        freeze_authority: None.into(),
    })
}

fn funded() -> Account {
    Account::new(LAMPORTS_PER_SOL, 0, &Pubkey::default())
}

fn account_data(account: &Account) -> &Vec<u8> {
    &account.data
}

fn build_ix(
    program_id: Pubkey,
    name: &str,
    signers: (&Pubkey, &Pubkey, bool),
    multisig: Pubkey,
    acc3: Pubkey,
    acc4: Pubkey,
    acc5: Pubkey,
    token_id: Pubkey,
) -> Instruction {
    let (s0, s1, both_sign) = signers;
    let disc = instruction_discriminator(name, 1);
    Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[DELTA]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(*s0, both_sign),
            AccountMeta::new(*s1, both_sign),
            AccountMeta::new_readonly(multisig, false),
            AccountMeta::new(acc3, false),
            AccountMeta::new_readonly(acc4, false),
            AccountMeta::new(acc5, false),
            AccountMeta::new_readonly(token_id, false),
        ],
    )
}

fn base_accounts(
    program_id: &Pubkey,
    s0: Pubkey,
    s1: Pubkey,
    multisig: Pubkey,
    signers: &[Pubkey],
    acc3: Pubkey,
    acc4: Pubkey,
    acc5: Pubkey,
    token_id: Pubkey,
    token_acc: Account,
    mint: Pubkey,
    source_amount: u64,
) -> Vec<(Pubkey, Account)> {
    vec![
        (
            common::dummy_state_key(program_id),
            common::dummy_state_account(program_id),
        ),
        (s0, funded()),
        (s1, funded()),
        (multisig, multisig_account(2, signers)),
        (acc3, token_account(mint, multisig, source_amount)),
        (acc4, mint_account(multisig, INITIAL)),
        (acc5, token_account(mint, s0, 0)),
        (token_id, token_acc),
    ]
}

#[test]
fn transfer_checked_ms2_moves_amount_with_two_signers() {
    let (program_id, mollusk) = harness();
    let s0 = Pubkey::new_unique();
    let s1 = Pubkey::new_unique();
    let multisig = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let (token_id, token_acc) = token::keyed_account();
    let ix = build_ix(
        program_id,
        "transferMs2",
        (&s0, &s1, true),
        multisig,
        source,
        mint,
        dest,
        token_id,
    );
    let dest_data = token_account(mint, s0, DELTA);
    mollusk.process_and_validate_instruction(
        &ix,
        &base_accounts(
            &program_id, s0, s1, multisig, &[s0, s1], source, mint, dest, token_id, token_acc,
            mint, INITIAL,
        ),
        &[
            Check::success(),
            Check::account(&dest).data(account_data(&dest_data)).build(),
        ],
    );
}

#[test]
fn transfer_checked_ms2_rejects_single_signer() {
    let (program_id, mollusk) = harness();
    let s0 = Pubkey::new_unique();
    let s1 = Pubkey::new_unique();
    let multisig = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let (token_id, token_acc) = token::keyed_account();
    let ix = build_ix(
        program_id,
        "transferMs2",
        (&s0, &s1, false),
        multisig,
        source,
        mint,
        dest,
        token_id,
    );
    mollusk.process_and_validate_instruction(
        &ix,
        &base_accounts(
            &program_id, s0, s1, multisig, &[s0, s1], source, mint, dest, token_id, token_acc,
            mint, INITIAL,
        ),
        &[Check::err(ProgramError::Custom(1))],
    );
}

#[test]
fn approve_checked_ms2_sets_delegate() {
    let (program_id, mollusk) = harness();
    let s0 = Pubkey::new_unique();
    let s1 = Pubkey::new_unique();
    let multisig = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let delegate = Pubkey::new_unique();
    let (token_id, token_acc) = token::keyed_account();
    let ix = build_ix(
        program_id,
        "approveMs2",
        (&s0, &s1, true),
        multisig,
        source,
        mint,
        delegate,
        token_id,
    );
    let expected = token::create_account_for_token_account(TokenAccount {
        mint,
        owner: multisig,
        amount: INITIAL,
        delegate: Some(delegate).into(),
        state: AccountState::Initialized,
        is_native: None.into(),
        delegated_amount: DELTA,
        close_authority: None.into(),
    });
    mollusk.process_and_validate_instruction(
        &ix,
        &base_accounts(
            &program_id, s0, s1, multisig, &[s0, s1], source, mint, delegate, token_id, token_acc,
            mint, INITIAL,
        ),
        &[
            Check::success(),
            Check::account(&source).data(account_data(&expected)).build(),
        ],
    );
}
