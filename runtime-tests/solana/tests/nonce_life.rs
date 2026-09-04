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
    mollusk.process_and_validate_instruction(
        &ix,
        &[
            (common::dummy_state_key(&program_id), common::dummy_state_account(&program_id)),
            (payer, funded(BASE_LAMPORTS)),
            (new_acc, funded(0)),
            (system, system_acc),
            (pad, funded(0)),
        ],
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
