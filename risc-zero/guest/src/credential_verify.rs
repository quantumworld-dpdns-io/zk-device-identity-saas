use alloc::string::String;

use crate::CredentialOutput;

/// A simplified proof-of-possession check using a prefix pattern.
/// In production this would use ECDSA, Schnorr, or BLS signature verification.
fn verify_possession_proof(credential: &str, proof: &str) -> bool {
    if !proof.starts_with("pop:") {
        return false;
    }
    let payload = &proof[4..];
    if payload.len() < 16 {
        return false;
    }

    let cred_fingerprint: String = credential
        .bytes()
        .take(16)
        .flat_map(|b| {
            let high = b >> 4;
            let low = b & 0x0f;
            [
                if high < 10 {
                    b'0' + high
                } else {
                    b'a' + high - 10
                },
                if low < 10 {
                    b'0' + low
                } else {
                    b'a' + low - 10
                },
            ]
        })
        .map(char::from)
        .collect();

    payload.eq_ignore_ascii_case(&cred_fingerprint)
}

fn validate_credential_format(credential: &str) -> bool {
    if credential.len() < 32 {
        return false;
    }
    credential
        .bytes()
        .all(|b| b.is_ascii_hexdigit() || b == b':')
}

/// Verifies device credentials without revealing them.
///
/// # Arguments
///
/// * `device_credential` - Opaque device credential blob (private input)
/// * `proof_of_possession` - Cryptographic proof that the device holds the
///   private key corresponding to the credential
/// * `verification_window_start` - Unix timestamp (seconds) when the window opens
/// * `verification_window_end` - Unix timestamp (seconds) when the window closes
///
/// # Returns
///
/// A `CredentialOutput` committed to the journal. The credential and
/// proof of possession are never disclosed in the public output.
pub fn verify_credential(
    device_credential: String,
    proof_of_possession: String,
    verification_window_start: u64,
    verification_window_end: u64,
) -> Result<CredentialOutput, String> {
    if verification_window_start >= verification_window_end {
        return Err("verification window is invalid: start >= end".into());
    }

    let credential_valid = validate_credential_format(&device_credential);
    let possession_proven = verify_possession_proof(&device_credential, &proof_of_possession);

    let verified_at: u64 = 0;
    let within_verification_window = verified_at >= verification_window_start
        && verified_at <= verification_window_end;

    Ok(CredentialOutput {
        credential_valid,
        possession_proven,
        within_verification_window,
        verified_at,
    })
}
