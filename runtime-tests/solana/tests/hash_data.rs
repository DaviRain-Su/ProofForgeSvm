mod common;

use {
    mollusk_svm::{result::Check, Mollusk},
    sha2::{Digest, Sha256},
    sha3::Keccak256,
    solana_account::Account,
    solana_instruction::{AccountMeta, Instruction},
    solana_program_error::ProgramError,
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

fn data_bytes() -> Vec<u8> {
    (0u8..40).map(|i| i.wrapping_mul(7).wrapping_add(3)).collect()
}

fn host_sha_word(data: &[u8], word: usize) -> u64 {
    let digest = Sha256::digest(data);
    u64::from_le_bytes(digest[8 * word..8 * (word + 1)].try_into().expect("8"))
}

fn host_keccak_word(data: &[u8], word: usize) -> u64 {
    let digest = Keccak256::digest(data);
    u64::from_le_bytes(digest[8 * word..8 * (word + 1)].try_into().expect("8"))
}

fn data_account(bytes: &[u8]) -> Account {
    let mut account = Account::new(BASE_LAMPORTS, bytes.len(), &Pubkey::default());
    account.data = bytes.to_vec();
    account
}

fn build_ix(program_id: Pubkey, state_key: Pubkey, data_key: Pubkey, disc: &[u8; 8]) -> Instruction {
    Instruction::new_with_bytes(
        program_id,
        disc,
        vec![
            AccountMeta::new_readonly(state_key, false),
            AccountMeta::new_readonly(data_key, false),
        ],
    )
}

fn assert_word(
    program_file: &str,
    env_name: &str,
    ix_name: &str,
    bytes: &[u8],
    checks: Vec<Check>,
) {
    let (program_id, mollusk) = common::harness(program_file, env_name);
    let state_key = Pubkey::new_unique();
    let data_key = Pubkey::new_unique();
    let disc = instruction_discriminator(ix_name, 0);
    let ix = build_ix(program_id, state_key, data_key, &disc);
    mollusk.process_and_validate_instruction(
        &ix,
        &[
            (state_key, {
                let mut account = Account::new(BASE_LAMPORTS, 16, &program_id);
                account.data = hash_state();
                account
            }),
            (data_key, data_account(bytes)),
        ],
        &checks,
    );
}

#[test]
fn sha256_data_words_match_host() {
    let bytes = data_bytes();
    for (i, name) in ["dataW0", "dataW1", "dataW2", "dataW3"].iter().enumerate() {
        assert_word(
            "HashDataSha",
            "PF_HASHDATASHA_SO",
            name,
            &bytes,
            vec![
                Check::success(),
                Check::return_data(&host_sha_word(&bytes[..32], i).to_le_bytes()),
            ],
        );
    }
}

#[test]
fn sha256_slice_word_matches_host() {
    let bytes = data_bytes();
    assert_word(
        "HashDataSha",
        "PF_HASHDATASHA_SO",
        "sliceW0",
        &bytes,
        vec![
            Check::success(),
            Check::return_data(&host_sha_word(&bytes[4..36], 0).to_le_bytes()),
        ],
    );
}

#[test]
fn sha256_slice_rejects_short_account() {
    let bytes = data_bytes();
    assert_word(
        "HashDataSha",
        "PF_HASHDATASHA_SO",
        "sliceW0",
        &bytes[..16],
        vec![Check::err(ProgramError::Custom(1))],
    );
}

#[test]
fn keccak_data_words_match_host() {
    let bytes = data_bytes();
    for (i, name) in ["dataW0", "dataW1", "dataW2", "dataW3"].iter().enumerate() {
        assert_word(
            "HashDataKeccak",
            "PF_HASHDATAKECCAK_SO",
            name,
            &bytes,
            vec![
                Check::success(),
                Check::return_data(&host_keccak_word(&bytes[..32], i).to_le_bytes()),
            ],
        );
    }
}

#[test]
fn keccak_slice_word_matches_host() {
    let bytes = data_bytes();
    assert_word(
        "HashDataKeccak",
        "PF_HASHDATAKECCAK_SO",
        "sliceW0",
        &bytes,
        vec![
            Check::success(),
            Check::return_data(&host_keccak_word(&bytes[4..36], 0).to_le_bytes()),
        ],
    );
}

#[test]
fn keccak_slice_rejects_short_account() {
    let bytes = data_bytes();
    assert_word(
        "HashDataKeccak",
        "PF_HASHDATAKECCAK_SO",
        "sliceW0",
        &bytes[..16],
        vec![Check::err(ProgramError::Custom(1))],
    );
}
