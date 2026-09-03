mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    sha2::{Digest, Sha256},
    sha3::Keccak256,
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_pubkey::Pubkey,
};

const DISCRIMINATOR_DOMAIN: &str = "proof-forge-solana-v1:";
const LAYOUT_DOMAIN: &str = "proof-forge-solana-layout-v1:";
const BASE_LAMPORTS: u64 = 5_000_000_000;

fn instruction_discriminator(name: &str, param_count: usize) -> [u8; 8] {
    let params = vec!["u64"; param_count].join(",");
    let preimage = format!("{DISCRIMINATOR_DOMAIN}{name}({params})");
    let digest = Sha256::digest(preimage.as_bytes());
    digest[..8].try_into().unwrap()
}

fn layout_marker() -> u64 {
    let layout_sig = "1|0:dummy:0:8:8:u64-le";
    let digest = Sha256::digest(format!("{LAYOUT_DOMAIN}{layout_sig}").as_bytes());
    let mut value: u64 = 0;
    for &b in &digest[..8] {
        value = (value << 8) | u64::from(b);
    }
    value
}

fn hash_state() -> Vec<u8> {
    let mut data = vec![0u8; 16];
    data[..8].copy_from_slice(&layout_marker().to_le_bytes());
    data
}

fn harness() -> (Pubkey, Mollusk) {
    common::harness("HashWords", "PF_HASHWORDS_SO")
}

fn state_account(program_id: &Pubkey, data: Vec<u8>) -> Account {
    let mut account = Account::new(BASE_LAMPORTS, data.len(), program_id);
    account.data = data;
    account
}

fn build_ix(program_id: Pubkey, state_key: Pubkey, disc: &[u8; 8]) -> Instruction {
    Instruction::new_with_bytes(
        program_id,
        disc,
        vec![AccountMeta::new_readonly(state_key, false)],
    )
}

fn host_sha_word(seed: &[u8], word: usize) -> u64 {
    let digest = Sha256::digest(seed);
    u64::from_le_bytes(digest[8 * word..8 * (word + 1)].try_into().expect("8"))
}

fn host_keccak_word(seed: &[u8], word: usize) -> u64 {
    let digest = Keccak256::digest(seed);
    u64::from_le_bytes(digest[8 * word..8 * (word + 1)].try_into().expect("8"))
}

fn assert_digest_word(ix_name: &str, expected: u64) {
    let (program_id, mollusk) = harness();
    let state_key = Pubkey::new_unique();
    let disc = instruction_discriminator(ix_name, 0);
    let ix = build_ix(program_id, state_key, &disc);
    let account = state_account(&program_id, hash_state());
    mollusk.process_and_validate_instruction(
        &ix,
        &[(state_key, account)],
        &[Check::success(), Check::return_data(&expected.to_le_bytes())],
    );
}

#[test]
fn sha256_vault_words_match_host() {
    for (i, name) in ["shaW0", "shaW1", "shaW2", "shaW3"].iter().enumerate() {
        assert_digest_word(name, host_sha_word(b"vault", i));
    }
}

#[test]
fn keccak256_vault_words_match_host() {
    for (i, name) in ["keccakW0", "keccakW1", "keccakW2", "keccakW3"].iter().enumerate() {
        assert_digest_word(name, host_keccak_word(b"vault", i));
    }
}
