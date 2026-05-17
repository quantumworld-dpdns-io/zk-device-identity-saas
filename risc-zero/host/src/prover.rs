use anyhow::{Context, Result};
use risc0_zkvm::{default_prover, compute_image_id, ExecutorEnv, Receipt};
use serde::Serialize;
use serde::de::DeserializeOwned;

use crate::types::GuestResponse;

/// Configuration for the RISC Zero prover.
///
/// Holds the guest ELF binary and its pre-computed Image ID used
/// for both proving and verification.
pub struct ProverConfig {
    /// The compiled guest ELF bytes (RISC-V rv32im).
    pub elf: &'static [u8],
    /// The Image ID corresponding to the guest ELF.
    pub image_id: [u32; 8],
}

impl ProverConfig {
    /// Creates a new `ProverConfig` from a static ELF slice.
    ///
    /// The Image ID is computed from the ELF at construction time.
    pub fn new(elf: &'static [u8]) -> Result<Self> {
        let image_id = compute_image_id(elf).context("failed to compute Image ID from ELF")?;
        Ok(Self { elf, image_id })
    }
}

/// Generates a zero-knowledge proof for the given input by executing
/// the guest program inside the RISC Zero zkVM.
///
/// The input is serialized using RISC Zero's serde format and passed
/// to the guest via `ExecutorEnv`. The guest reads it with `env::read()`.
///
/// Returns a `Receipt` containing the public journal output and the
/// cryptographic seal (the proof).
pub fn generate_proof<T: Serialize>(
    config: &ProverConfig,
    input: &T,
) -> Result<Receipt> {
    let env = ExecutorEnv::builder()
        .write(input)
        .context("failed to write input to executor env")?
        .build()
        .context("failed to build executor env")?;

    let prover = default_prover();
    let prove_info = prover
        .prove(env, config.elf)
        .context("failed to execute guest program")?;

    Ok(prove_info.receipt)
}

/// Verifies a receipt against the expected Image ID and decodes the
/// public journal output.
///
/// # Type Parameters
///
/// * `T` - The expected output type (must match what the guest committed).
///   Use [`GuestResponse`] when the caller doesn't know which variant to expect.
///
/// # Returns
///
/// The deserialized journal output on success, or an error if the
/// receipt is invalid or the journal cannot be decoded.
pub fn verify_proof<T: DeserializeOwned>(
    receipt: &Receipt,
    image_id: &[u32; 8],
) -> Result<T> {
    receipt
        .verify(*image_id)
        .context("receipt verification failed")?;

    let output: T = receipt
        .journal
        .decode()
        .context("failed to decode journal output")?;

    Ok(output)
}

/// Convenience wrapper that verifies a receipt and decodes the journal
/// as a `GuestResponse`.
pub fn verify_receipt(receipt: &Receipt, image_id: &[u32; 8]) -> Result<GuestResponse> {
    verify_proof::<GuestResponse>(receipt, image_id)
}
