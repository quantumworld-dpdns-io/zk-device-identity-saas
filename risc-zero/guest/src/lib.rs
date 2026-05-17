#![no_std]
extern crate alloc;

mod compliance_check;
mod credential_verify;
mod device_state;

use alloc::string::String;
use alloc::vec::Vec;
use risc0_zkvm::guest::env;
use serde::{Deserialize, Serialize};

// ── Shared input/output types ──────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceInput {
    pub device_firmware_hash: String,
    pub device_config: String,
    pub attestation_data: String,
    pub expected_compliance_version: String,
    pub allowed_manufacturers: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceOutput {
    pub verified: bool,
    pub manufacturer_allowed: bool,
    pub compliance_version: String,
    pub device_config_hash: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CredentialInput {
    pub device_credential: String,
    pub proof_of_possession: String,
    pub verification_window_start: u64,
    pub verification_window_end: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CredentialOutput {
    pub credential_valid: bool,
    pub possession_proven: bool,
    pub within_verification_window: bool,
    pub verified_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateTransitionInput {
    pub previous_state_hash: String,
    pub new_state_hash: String,
    pub state_transition_data: String,
    pub authorization_signature: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateTransitionOutput {
    pub transition_valid: bool,
    pub authorized: bool,
    pub previous_state_hash: String,
    pub new_state_hash: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum GuestRequest {
    ComplianceCheck(ComplianceInput),
    CredentialVerify(CredentialInput),
    DeviceStateTransition(StateTransitionInput),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum GuestResponse {
    ComplianceResult(ComplianceOutput),
    CredentialResult(CredentialOutput),
    DeviceStateResult(StateTransitionOutput),
}

// ── Entry point ───────────────────────────────────────────────

risc0_zkvm::guest::entry!(main);

fn main() {
    let request: GuestRequest = env::read();

    let response = match request {
        GuestRequest::ComplianceCheck(input) => {
            match compliance_check::verify_compliance(
                input.device_firmware_hash,
                input.device_config,
                input.attestation_data,
                input.expected_compliance_version,
                input.allowed_manufacturers,
            ) {
                Ok(output) => GuestResponse::ComplianceResult(output),
                Err(e) => panic!("Compliance check failed: {e}"),
            }
        }
        GuestRequest::CredentialVerify(input) => {
            match credential_verify::verify_credential(
                input.device_credential,
                input.proof_of_possession,
                input.verification_window_start,
                input.verification_window_end,
            ) {
                Ok(output) => GuestResponse::CredentialResult(output),
                Err(e) => panic!("Credential verification failed: {e}"),
            }
        }
        GuestRequest::DeviceStateTransition(input) => {
            match device_state::verify_state_transition(
                input.previous_state_hash,
                input.new_state_hash,
                input.state_transition_data,
                input.authorization_signature,
            ) {
                Ok(output) => GuestResponse::DeviceStateResult(output),
                Err(e) => panic!("State transition verification failed: {e}"),
            }
        }
    };

    env::commit(&response);
}
