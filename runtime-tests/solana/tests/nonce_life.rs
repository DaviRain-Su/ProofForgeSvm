mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    sha2::{Digest, Sha256},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_native_token::LAMPORTS_PER_SOL,
    solana_pubkey::Pubkey,
    std::{env, fs, path::PathBuf},
};

const DISCRIMINATOR_DOMAIN: &str = "proof-forge-solana-v1:";
const BASE_LAMPORTS: u64 = 10 * LAMPORTS_PER_SOL;
const NONCE_LEN: usize = 80;
const NONCE_RENT: u64 = 1_447_680; // Rent::default().minimum_balance(80) with the live sysvar

fn system_id() -> Pubkey {
    Pubkey::new_from_array([0u8; 32])
}

fn rent_id() -> Pubkey {
    use std::str::FromStr;
    Pubkey::from_str("SysvarRent111111111111111111111111111111111").expect("rent sysvar id")
}

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

fn so_path() -> PathBuf {
    PathBuf::from(env::var("PF_NONCELIFE_SO").unwrap_or_else(|_| {
        format!(
            "{}/build/sbpf/NonceLife.so",
            env::var("CARGO_MANIFEST_DIR")
                .map(|p| format!("{p}/../.."))
                .unwrap_or_else(|_| ".".into())
        )
    }))
}

fn harness() -> (Pubkey, Mollusk) {
    let program_id = Pubkey::new_unique();
    let elf = fs::read(so_path()).unwrap_or_else(|e| panic!("read NonceLife.so: {e}"));
    let mut mollusk = Mollusk::default();
    mollusk.add_program_with_loader_and_elf(
        &program_id,
        &mollusk_svm::program::loader_keys::LOADER_V3,
        &elf,
    );
    (program_id, mollusk)
}

fn funded(lamports: u64) -> Account {
    Account::new(lamports, 0, &Pubkey::default())
}

fn system_keyed() -> (Pubkey, Account) {
    mollusk_svm::program::keyed_account_for_system_program()
}

/// Pad an instruction's metas + accounts to `total` accounts with readonly funds accounts.
/// Every entry in this program shares the program-wide account gate (max across methods),
/// so each fixture must supply the full account count.
fn pad_to(
    mut metas: Vec<AccountMeta>,
    mut accounts: Vec<(Pubkey, Account)>,
    total: usize,
) -> (Vec<AccountMeta>, Vec<(Pubkey, Account)>) {
    while metas.len() < total {
        let pad = Pubkey::new_unique();
        metas.push(AccountMeta::new_readonly(pad, false));
        accounts.push((pad, funded(0)));
    }
    (metas, accounts)
}

/// `openNonce` outer: state(0 w), payer(1 s+w), new(2 s+w), System(3 r), pad(4 r).
fn open_ix(program_id: Pubkey, payer: Pubkey, new_acc: Pubkey, pad: Pubkey) -> Instruction {
    let disc = instruction_discriminator("openNonce", 0);
    let (system, _) = system_keyed();
    Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(payer, true),
            AccountMeta::new(new_acc, true),
            AccountMeta::new_readonly(system, false),
            AccountMeta::new_readonly(pad, false),
        ],
    )
}

#[test]
fn open_creates_rent_exempt_account() {
    let (program_id, mollusk) = harness();
    let payer = Pubkey::new_unique();
    let new_acc = Pubkey::new_unique();
    let pad = Pubkey::new_unique();
    let ix = open_ix(program_id, payer, new_acc, pad);
    let (system, system_acc) = system_keyed();
    let (metas, accounts) = pad_to(
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(payer, true),
            AccountMeta::new(new_acc, true),
            AccountMeta::new_readonly(system, false),
            AccountMeta::new_readonly(pad, false),
        ],
        vec![
            (common::dummy_state_key(&program_id), common::dummy_state_account(&program_id)),
            (payer, funded(BASE_LAMPORTS)),
            (new_acc, funded(0)),
            (system, system_acc),
            (pad, funded(0)),
        ],
        7,
    );
    let ix = Instruction::new_with_bytes(program_id, &ix.data, metas);
    mollusk.process_and_validate_instruction(
        &ix,
        &accounts,
        &[
            Check::success(),
            Check::account(&new_acc)
                .lamports(1_447_680)
                .space(NONCE_LEN)
                .owner(&program_id)
                .build(),
        ],
    );
}

/// `initNonce` outer: state(0), nonce(1 writable), recent(2 r), rent(3 r), System(4 r).
fn init_ix(program_id: Pubkey, nonce: Pubkey, recent: Pubkey, rent: Pubkey) -> Instruction {
    let disc = instruction_discriminator("initNonce", 0);
    let (system, _) = system_keyed();
    Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(nonce, false),
            AccountMeta::new_readonly(recent, false),
            AccountMeta::new_readonly(rent, false),
            AccountMeta::new_readonly(system, false),
        ],
    )
}

#[test]
fn init_initializes_funded_nonce() {
    let (program_id, mut mollusk) = harness();
    // Populate the recent-blockhashes sysvar cache so System's InitializeNonceAccount
    // finds a non-empty list (it rejects with NonceNoRecentBlockhashes otherwise).
    mollusk.sysvars.recent_blockhashes = solana_sysvar::recent_blockhashes::RecentBlockhashes::from_iter([
        solana_sysvar::recent_blockhashes::IterItem(0, &solana_hash::Hash::new_unique(), 5000),
    ]);
    let nonce = Pubkey::new_unique();
    let rent = rent_id();
    let recent = {
        use std::str::FromStr;
        Pubkey::from_str("SysvarRecentB1ockHashes11111111111111111111").expect("recent blockhashes sysvar id")
    };
    let base_ix = init_ix(program_id, nonce, recent, rent);
    let (system, system_acc) = system_keyed();
    let (metas, accounts) = pad_to(
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(nonce, false),
            AccountMeta::new_readonly(recent, false),
            AccountMeta::new_readonly(rent, false),
            AccountMeta::new_readonly(system, false),
        ],
        vec![
            (common::dummy_state_key(&program_id), common::dummy_state_account(&program_id)),
            (nonce, Account::new(NONCE_RENT, NONCE_LEN, &system_id())),
            (recent, funded(0)),
            (rent, Account::new(1, 0, &system_id())),
            (system, system_acc),
        ],
        7,
    );
    let ix = Instruction::new_with_bytes(program_id, &base_ix.data, metas);
    let result = mollusk.process_instruction(&ix, &accounts);
    assert_eq!(
        result.program_result,
        mollusk_svm::result::ProgramResult::Success,
        "initNonce CPI failed: {:?}",
        result.program_result
    );
    let nonce_result = result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == nonce)
        .map(|(_, a)| a.data.clone())
        .expect("nonce account present");
    assert_eq!(u32::from_le_bytes(nonce_result[..4].try_into().unwrap()), 1, "version");
    assert_eq!(u32::from_le_bytes(nonce_result[4..8].try_into().unwrap()), 1, "initialized state");
}

/// Construct an 80-byte `Versions::Current(State::Initialized(Data{authority, ...}))`
/// nonce account with the given authority.
fn initialized_nonce(authority: Pubkey, recent_blockhash: &solana_hash::Hash) -> Vec<u8> {
    use solana_nonce::{state::{Data, State}, versions::Versions};
    use solana_nonce::state::DurableNonce;
    let data = Data::new(
        authority,
        DurableNonce::from_blockhash(recent_blockhash),
        5000,
    );
    let versions = Versions::new(State::Initialized(data));
    bincode::serialize(&versions).expect("bincode nonce state")
}

/// `reauthNonce` outer: state(0), current_authority(1 signer), nonce(2 writable),
/// new_authority(3 readonly key source), System(4).
fn reauth_ix(program_id: Pubkey, nonce: Pubkey, current_auth: Pubkey, new_auth: Pubkey) -> Instruction {
    let disc = instruction_discriminator("reauthNonce", 0);
    let (system, _) = system_keyed();
    Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(current_auth, true),
            AccountMeta::new(nonce, false),
            AccountMeta::new_readonly(new_auth, false),
            AccountMeta::new_readonly(system, false),
        ],
    )
}

#[test]
fn reauth_updates_nonce_authority() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let nonce = Pubkey::new_unique();
    let new_authority = Pubkey::new_unique();
    let blockhash = solana_hash::Hash::new_unique();
    let base_ix = reauth_ix(program_id, nonce, authority, new_authority);
    let (system, system_acc) = system_keyed();
    let mut nonce_account = Account::new(NONCE_RENT, NONCE_LEN, &system_id());
    nonce_account.data = initialized_nonce(authority, &blockhash);
    let (metas, accounts) = pad_to(
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(authority, true),
            AccountMeta::new(nonce, false),
            AccountMeta::new_readonly(new_authority, false),
            AccountMeta::new_readonly(system, false),
        ],
        vec![
            (common::dummy_state_key(&program_id), common::dummy_state_account(&program_id)),
            (authority, funded(0)),
            (nonce, nonce_account),
            (new_authority, funded(0)),
            (system, system_acc),
        ],
        7,
    );
    let ix = Instruction::new_with_bytes(program_id, &base_ix.data, metas);
    let result = mollusk.process_instruction(&ix, &accounts);
    assert_eq!(
        result.program_result,
        mollusk_svm::result::ProgramResult::Success,
        "reauthNonce CPI failed: {:?}",
        result.program_result
    );
}

/// Construct an 80-byte `Versions::Legacy(State::Initialized(Data))` nonce account.
fn legacy_nonce(authority: Pubkey, recent_blockhash: &solana_hash::Hash) -> Vec<u8> {
    use solana_nonce::{state::{Data, State}, versions::Versions};
    use solana_nonce::state::DurableNonce;
    let data = Data::new(
        authority,
        DurableNonce::from_blockhash(recent_blockhash),
        5000,
    );
    let versions = Versions::Legacy(Box::new(State::Initialized(data)));
    bincode::serialize(&versions).expect("bincode legacy nonce state")
}

/// `upgradeNonce` outer: state(0), nonce(1 writable), System(2), pad(3), pad(4).
fn upgrade_ix(program_id: Pubkey, nonce: Pubkey, pad1: Pubkey, pad2: Pubkey) -> Instruction {
    let disc = instruction_discriminator("upgradeNonce", 0);
    let (system, _) = system_keyed();
    Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(nonce, false),
            AccountMeta::new_readonly(system, false),
            AccountMeta::new_readonly(pad1, false),
            AccountMeta::new_readonly(pad2, false),
        ],
    )
}

#[test]
fn upgrade_legacy_nonce_to_current() {
    let (program_id, mollusk) = harness();
    let authority = Pubkey::new_unique();
    let nonce = Pubkey::new_unique();
    let blockhash = solana_hash::Hash::new_unique();
    let pad1 = Pubkey::new_unique();
    let pad2 = Pubkey::new_unique();
    let base_ix = upgrade_ix(program_id, nonce, pad1, pad2);
    let (system, system_acc) = system_keyed();
    let mut nonce_account = Account::new(NONCE_RENT, NONCE_LEN, &system_id());
    nonce_account.data = legacy_nonce(authority, &blockhash);
    let (metas, accounts) = pad_to(
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(nonce, false),
            AccountMeta::new_readonly(system, false),
            AccountMeta::new_readonly(pad1, false),
            AccountMeta::new_readonly(pad2, false),
        ],
        vec![
            (common::dummy_state_key(&program_id), common::dummy_state_account(&program_id)),
            (nonce, nonce_account),
            (system, system_acc),
            (pad1, funded(0)),
            (pad2, funded(0)),
        ],
        7,
    );
    let ix = Instruction::new_with_bytes(program_id, &base_ix.data, metas);
    let result = mollusk.process_instruction(&ix, &accounts);
    assert_eq!(
        result.program_result,
        mollusk_svm::result::ProgramResult::Success,
        "upgradeNonce CPI failed: {:?}",
        result.program_result
    );
}

/// `withdrawNonce` outer: state(0), authority(1 signer), nonce(2 writable), dest(3 writable),
/// recent(4 r), rent(5 r), System(6).
fn withdraw_ix(
    program_id: Pubkey,
    nonce: Pubkey,
    authority: Pubkey,
    dest: Pubkey,
    recent: Pubkey,
    rent: Pubkey,
    lamports: u64,
) -> Instruction {
    let disc = instruction_discriminator("withdrawNonce", 1);
    let (system, _) = system_keyed();
    Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[lamports]),
        vec![
            AccountMeta::new(common::dummy_state_key(&program_id), false),
            AccountMeta::new(authority, true),
            AccountMeta::new(nonce, false),
            AccountMeta::new(dest, false),
            AccountMeta::new_readonly(recent, false),
            AccountMeta::new_readonly(rent, false),
            AccountMeta::new_readonly(system, false),
        ],
    )
}

#[test]
fn withdraw_from_nonce_moves_lamports() {
    let (program_id, mut mollusk) = harness();
    // Populate recent-blockhashes so System's WithdrawNonceAccount sysvar check passes.
    mollusk.sysvars.recent_blockhashes = solana_sysvar::recent_blockhashes::RecentBlockhashes::from_iter([
        solana_sysvar::recent_blockhashes::IterItem(0, &solana_hash::Hash::new_unique(), 5000),
    ]);
    let authority = Pubkey::new_unique();
    let nonce = Pubkey::new_unique();
    let dest = Pubkey::new_unique();
    let recent = {
        use std::str::FromStr;
        Pubkey::from_str("SysvarRecentB1ockHashes11111111111111111111").expect("recent blockhashes sysvar id")
    };
    let rent = rent_id();
    let blockhash = solana_hash::Hash::new_unique();
    let withdraw_amt = 100_000;
    let ix = withdraw_ix(program_id, nonce, authority, dest, recent, rent, withdraw_amt);
    let (system, system_acc) = system_keyed();
    // The nonce account must hold more than withdraw_amt + rent_minimum so the partial
    // withdraw leaves it rent-exempt.
    let mut nonce_account = Account::new(NONCE_RENT + withdraw_amt, NONCE_LEN, &system_id());
    nonce_account.data = initialized_nonce(authority, &blockhash);
    let result = mollusk.process_instruction(
        &ix,
        &[
            (common::dummy_state_key(&program_id), common::dummy_state_account(&program_id)),
            (authority, funded(0)),
            (nonce, nonce_account),
            (dest, funded(0)),
            (recent, funded(0)),
            (rent, Account::new(1, 0, &system_id())),
            (system, system_acc),
        ],
    );
    assert_eq!(
        result.program_result,
        mollusk_svm::result::ProgramResult::Success,
        "withdrawNonce CPI failed: {:?}",
        result.program_result
    );
    let dest_result = result
        .resulting_accounts
        .iter()
        .find(|(k, _)| *k == dest)
        .map(|(_, a)| a.lamports)
        .expect("dest account present");
    assert_eq!(dest_result, withdraw_amt, "dest received the withdrawn lamports");
}
