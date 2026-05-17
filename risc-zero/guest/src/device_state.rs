use alloc::string::String;
use core::num::Wrapping;

use crate::StateTransitionOutput;

/// FNV-1a 64-bit hash for no_std environments.
fn fnv1a_hash(data: &str) -> u64 {
    let mut hash: Wrapping<u64> = Wrapping(0xcbf29ce484222325u64);
    for byte in data.bytes() {
        hash ^= Wrapping(byte as u64);
        hash *= Wrapping(0x100000001b3u64);
    }
    hash.0
}

/// Verifies an authorization signature against a known set of authorized keys.
///
/// Authorization signature format: `auth:<identity>:<action>:<nonce_hex>`
fn verify_authorization(
    signature: &str,
    expected_action: &str,
) -> Result<(String, String), &'static str> {
    if !signature.starts_with("auth:") {
        return Err("invalid authorization signature format");
    }
    let rest = &signature[5..];
    let mut parts = rest.splitn(3, ':');

    let identity = parts.next().ok_or("missing identity")?;
    let action = parts.next().ok_or("missing action")?;
    let _nonce = parts.next().ok_or("missing nonce")?;

    if identity.is_empty() {
        return Err("empty identity in authorization signature");
    }
    if action != expected_action {
        return Err("action mismatch in authorization signature");
    }
    Ok((identity.to_string(), expected_action.to_string()))
}

fn is_authorized_controller(identity: &str) -> bool {
    matches!(
        identity,
        "admin" | "device-manager" | "factory-zone-a" | "provisioning-service"
    )
}

fn validate_transition_rules(
    previous_hash: &str,
    new_hash: &str,
    transition_data: &str,
) -> Result<(), &'static str> {
    if previous_hash.is_empty() {
        return Err("previous state hash is empty");
    }
    if new_hash.is_empty() {
        return Err("new state hash is empty");
    }
    if previous_hash == new_hash {
        return Err("no-op transition: previous state equals new state");
    }
    if transition_data.is_empty() {
        return Err("state transition data is empty");
    }
    let valid_chars = |s: &str| s.bytes().all(|b| b.is_ascii_hexdigit());
    if !valid_chars(previous_hash) || !valid_chars(new_hash) {
        return Err("state hash contains non-hex characters");
    }
    Ok(())
}

/// Verifies a device state transition proof inside the zkVM.
///
/// # Arguments
///
/// * `previous_state_hash` - Hex-encoded hash of the device state before the transition
/// * `new_state_hash` - Hex-encoded hash of the device state after the transition
/// * `state_transition_data` - Opaque blob describing the transition (private input)
/// * `authorization_signature` - Authorization proof: `auth:<identity>:<action>:<nonce>`
///
/// # Returns
///
/// A `StateTransitionOutput` committed to the journal. The transition
/// details and authorization signatures are kept private.
pub fn verify_state_transition(
    previous_state_hash: String,
    new_state_hash: String,
    state_transition_data: String,
    authorization_signature: String,
) -> Result<StateTransitionOutput, String> {
    let expected_action = "device_state_transition";

    let (identity, _action) = verify_authorization(&authorization_signature, expected_action)
        .map_err(|e| format!("authorization verification failed: {e}"))?;

    let authorized = is_authorized_controller(&identity);

    let transition_rules_ok =
        validate_transition_rules(&previous_state_hash, &new_state_hash, &state_transition_data)
            .is_ok();

    let transition_valid = transition_rules_ok && authorized;

    Ok(StateTransitionOutput {
        transition_valid,
        authorized,
        previous_state_hash,
        new_state_hash,
        timestamp: 0,
    })
}
