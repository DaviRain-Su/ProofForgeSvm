mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    mollusk_svm_programs_token::token2022,
    mollusk_svm_programs_token_2022::{
        create_account_for_mint_with_extensions, create_account_for_token_account_with_extensions,
        required_account_extensions_for_mint, AccountState, Mint, MintExtension, TokenAccount,
        TransferFeeConfig,
    },
    sha2::{Digest, Sha256},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_native_token::LAMPORTS_PER_SOL,
    solana_program_error::ProgramError,
    solana_pubkey::Pubkey,
    spl_token_2022_interface::extension::transfer_fee::TransferFee,
};

const DISCRIMINATOR_DOMAIN: &str = "proof-forge-solana-v1:";
const DECIMALS: u8 = 6;
const INITIAL: u64 = 10_000_000;
const DELTA: u64 = 1_000_000;
/// 1% fee capped at 5_000 tokens: ceil(1_000_000 * 100 / 10_000) = 10_000 > 5_000.
const MAX_FEE: u64 = 5_000;
/// Same schedule but the 1% raw fee stays under the cap: ceil(40_000 * 100 / 10_000) = 400.
const SMALL_DELTA: u64 = 40_000;
const SMALL_FEE: u64 = 400;

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
    let (program_id, mut mollusk) = common::harness("Token2022Tfee", "PF_TOKEN2022TFEE_SO");
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

fn fee_config(authority: Pubkey, epoch: u64) -> TransferFeeConfig {
    let fee = TransferFee {
        epoch: epoch.into(),
        maximum_fee: MAX_FEE.into(),
        transfer_fee_basis_points: 100.into(),
    };
    TransferFeeConfig {
        transfer_fee_config_authority: Some(authority).try_into().unwrap(),
        withdraw_withheld_authority: Some(authority).try_into().unwrap(),
        withheld_amount: 0.into(),
        older_transfer_fee: fee,
        newer_transfer_fee: fee,
    }
}

fn tfee_mint(authority: Pubkey, schedule_epoch: u64) -> Account {
    create_account_for_mint_with_extensions(
        mint_state(authority, INITIAL),
        &[MintExtension::TransferFeeConfig(fee_config(
            authority,
            schedule_epoch,
        ))],
    )
}

fn build_ix(
    program_id: Pubkey,
    name: &str,
    authority: Pubkey,
    source: Pubkey,
    mint: Pubkey,
    dest: Pubkey,
    amount: u64,
) -> Instruction {
    let disc = instruction_discriminator(name, 1);
    Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[amount]),
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

fn tfee_accounts(
    authority: Pubkey,
    source: Pubkey,
    mint: Pubkey,
    dest: Pubkey,
    schedule_epoch: u64,
    program_id: &Pubkey,
) -> Vec<(Pubkey, Account)> {
    let required = required_account_extensions_for_mint(&tfee_mint(authority, schedule_epoch).data);
    vec![
        (
            common::dummy_state_key(program_id),
            common::dummy_state_account(program_id),
        ),
        (authority, funded()),
        (
            source,
            create_account_for_token_account_with_extensions(
                token_state(mint, authority, INITIAL),
                &required,
            ),
        ),
        (mint, tfee_mint(authority, schedule_epoch)),
        (
            dest,
            create_account_for_token_account_with_extensions(
                token_state(mint, authority, 0),
                &required,
            ),
        ),
        token2022::keyed_account(),
    ]
}

#[test]
fn transfer_fee_charged_at_current_epoch() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    // Schedule epoch 0 is active at the default clock epoch 0.
    let ix = build_ix(
        program_id,
        "transferTfee",
        authority,
        source,
        mint,
        dest,
        DELTA,
    );
    mollusk.process_and_validate_instruction(
        &ix,
        &tfee_accounts(authority, source, mint, dest, 0, &program_id),
        &[
            Check::success(),
            Check::account(&source)
                .data_slice(64, &(INITIAL - DELTA).to_le_bytes())
                .build(),
            Check::account(&dest)
                .data_slice(64, &(DELTA - MAX_FEE).to_le_bytes())
                .build(),
        ],
    );
}

#[test]
fn transfer_fee_under_cap_is_proportional() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let ix = build_ix(
        program_id,
        "transferTfee",
        authority,
        source,
        mint,
        dest,
        SMALL_DELTA,
    );
    mollusk.process_and_validate_instruction(
        &ix,
        &tfee_accounts(authority, source, mint, dest, 0, &program_id),
        &[
            Check::success(),
            Check::account(&source)
                .data_slice(64, &(INITIAL - SMALL_DELTA).to_le_bytes())
                .build(),
            Check::account(&dest)
                .data_slice(64, &(SMALL_DELTA - SMALL_FEE).to_le_bytes())
                .build(),
        ],
    );
}

#[test]
fn transfer_fee_uses_older_schedule_before_epoch() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    // Both schedules identical here; the point is that epoch 1 (newer) is NOT active at
    // clock epoch 0, so the transfer must still succeed through the older schedule.
    let ix = build_ix(
        program_id,
        "transferTfee",
        authority,
        source,
        mint,
        dest,
        DELTA,
    );
    mollusk.process_and_validate_instruction(
        &ix,
        &tfee_accounts(authority, source, mint, dest, 1, &program_id),
        &[
            Check::success(),
            Check::account(&dest)
                .data_slice(64, &(DELTA - MAX_FEE).to_le_bytes())
                .build(),
        ],
    );
}

#[test]
fn transfer_fee_future_schedule_only_reaches_newer_fee() {
    let (program_id, mut mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    // Advance the clock epoch to 5 so the newer schedule (epoch 5) is active.
    mollusk.sysvars.clock.epoch = 5;
    let ix = build_ix(
        program_id,
        "transferTfee",
        authority,
        source,
        mint,
        dest,
        DELTA,
    );
    mollusk.process_and_validate_instruction(
        &ix,
        &tfee_accounts(authority, source, mint, dest, 5, &program_id),
        &[
            Check::success(),
            Check::account(&dest)
                .data_slice(64, &(DELTA - MAX_FEE).to_le_bytes())
                .build(),
        ],
    );
}

#[test]
fn missing_signer_fails_closed() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let source = Pubkey::new_unique();
    let mint = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    // The recipe requires external account 0 to sign; drop the signer flag so the runtime's
    // signer walk fails before any CPI.
    let ix = {
        let disc = instruction_discriminator("transferTfee", 1);
        Instruction::new_with_bytes(
            program_id,
            &instruction_data(&disc, &[DELTA]),
            vec![
                AccountMeta::new(common::dummy_state_key(&program_id), false),
                AccountMeta::new(authority, false),
                AccountMeta::new(source, false),
                AccountMeta::new_readonly(mint, false),
                AccountMeta::new(dest, false),
                AccountMeta::new_readonly(token2022::ID, false),
            ],
        )
    };
    let accounts = tfee_accounts(authority, source, mint, dest, 0, &program_id);
    mollusk.process_and_validate_instruction(
        &ix,
        &accounts,
        &[
            Check::err(ProgramError::Custom(1)),
            Check::account(&source)
                .data_slice(64, &INITIAL.to_le_bytes())
                .build(),
        ],
    );
}