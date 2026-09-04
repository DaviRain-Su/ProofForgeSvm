mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    sha2::{Digest, Sha256},
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_instruction::error::InstructionError,
    solana_native_token::LAMPORTS_PER_SOL,
    solana_pubkey::Pubkey,
    std::fs,
};

const DISCRIMINATOR_DOMAIN: &str = "proof-forge-solana-v1:";
const LAYOUT_DOMAIN: &str = "proof-forge-solana-layout-v1:";
const BASE_LAMPORTS: u64 = 10 * LAMPORTS_PER_SOL;
const DATA_LEN: usize = 16;

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

fn layout_marker() -> u64 {
    let layout_sig = "1|0:dummy:0:8:8:u64-le";
    let digest = Sha256::digest(format!("{LAYOUT_DOMAIN}{layout_sig}").as_bytes());
    digest[..8].iter().fold(0u64, |acc, b| (acc << 8) | u64::from(*b))
}

fn state_data(initialized: bool, dummy: u64) -> Vec<u8> {
    let mut data = vec![0u8; DATA_LEN];
    if initialized {
        data[..8].copy_from_slice(&layout_marker().to_le_bytes());
    }
    data[8..16].copy_from_slice(&dummy.to_le_bytes());
    data
}

fn harness() -> (Pubkey, Mollusk) {
    let program_id = Pubkey::new_unique();
    let elf_path = std::env::var("PF_HALTLOG_SO").unwrap_or_else(|_| {
        format!(
            "{}/build/sbpf/HaltLog.so",
            std::env::var("CARGO_MANIFEST_DIR")
                .map(|p| format!("{p}/../.."))
                .unwrap_or_else(|_| ".".into())
        )
    });
    let elf = fs::read(&elf_path).unwrap_or_else(|e| panic!("read {elf_path}: {e}"));
    let mut mollusk = Mollusk::default();
    mollusk.add_program_with_loader_and_elf(
        &program_id,
        &mollusk_svm::program::loader_keys::LOADER_V3,
        &elf,
    );
    (program_id, mollusk)
}

fn harness_logged() -> (Pubkey, Mollusk) {
    let (program_id, mut mollusk) = harness();
    mollusk.logger = Some(std::rc::Rc::new(std::cell::RefCell::new(
        solana_svm_log_collector::LogCollector::default(),
    )));
    (program_id, mollusk)
}

fn logs_of(mollusk: &Mollusk) -> String {
    mollusk
        .logger
        .as_ref()
        .map(|l| l.borrow().messages.join("
"))
        .unwrap_or_default()
}

fn state_account(program_id: &Pubkey, initialized: bool, dummy: u64) -> Account {
    let mut account = Account::new(BASE_LAMPORTS, DATA_LEN, program_id);
    account.data = state_data(initialized, dummy);
    account
}

#[test]
fn announce_logs_and_returns_value() {
    let (program_id, mollusk) = harness_logged();
    let state_key = Pubkey::new_unique();
    let disc = instruction_discriminator("announce", 0);
    let ix = Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![AccountMeta::new(state_key, false)],
    );
    let result = mollusk.process_instruction(&ix, &[(
        state_key,
        state_account(&program_id, true, 0),
    )]);
    assert_eq!(result.return_data, 7u64.to_le_bytes().to_vec());
    let logs = logs_of(&mollusk);
    assert!(
        logs.contains("halt-log: announce"),
        "expected sol_log_ payload in logs, got: {logs}"
    );
}

#[test]
fn boom_halts_with_panic() {
    let (program_id, mollusk) = harness();
    let state_key = Pubkey::new_unique();
    let disc = instruction_discriminator("boom", 0);
    let ix = Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![AccountMeta::new(state_key, false)],
    );
    mollusk.process_and_validate_instruction(
        &ix,
        &[(state_key, state_account(&program_id, true, 0))],
        &[Check::instruction_err(InstructionError::ProgramFailedToComplete)],
    );
}

#[test]
fn crash_aborts() {
    let (program_id, mollusk) = harness();
    let state_key = Pubkey::new_unique();
    let disc = instruction_discriminator("crash", 0);
    let ix = Instruction::new_with_bytes(
        program_id,
        &instruction_data(&disc, &[]),
        vec![AccountMeta::new(state_key, false)],
    );
    mollusk.process_and_validate_instruction(
        &ix,
        &[(state_key, state_account(&program_id, true, 0))],
        &[Check::instruction_err(InstructionError::ProgramFailedToComplete)],
    );
}