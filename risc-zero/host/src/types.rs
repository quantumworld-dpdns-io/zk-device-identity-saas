use serde::{Deserialize, Serialize};

// ── Shared input/output types (mirror of guest/src/lib.rs) ─────

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
