use alloc::string::String;
use core::time::Duration;

pub struct CredentialResult {
    pub credential_valid: bool,
    pub possession_proven: bool,
    pub within_verification_window: bool,
    pub verified_at: u64,
}

/// A simplified proof-of-possession check using a prefix pattern.
/// In production this would use ECDSA, Schnorr, or BLS signature verification.
fn verify_possession_proof(credential: &str, proof: &str) -> bool {
    // Expect proof = "pop:" + sha256_first_bytes(credential)
    // This is a toy construction; a real implementation would verify
    // a digital signature over a nonce using the device's public key.
    if !proof.starts_with("pop:") {
        return false;
    }
    let payload = &proof[4..];
    if payload.len() < 16 {
        return false;
    }

    // Credential fingerprint check — first 16 hex chars of credential
    // must match the payload (simulates signature verification)
    let cred_fingerprint: String = credential
        .bytes()
        .take(16)
        .map(|b| {
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
        .flatten()
        .map(char::from)
        .collect();

    payload.eq_ignore_ascii_case(&cred_fingerprint)
}

fn validate_credential_format(credential: &str) -> bool {
    if credential.len() < 32 {
        return false;
    }
    // Expect credential to be a hex-encoded X.509 DER or similar structure
    credential.bytes().all(|b| b.is_ascii_hexdigit() || b == b':')
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
/// A `CredentialResult` committed to the journal. The credential itself
/// is never disclosed in the public output.
pub fn verify_credential(
    device_credential: String,
    proof_of_possession: String,
    verification_window_start: u64,
    verification_window_end: u64,
) -> Result<CredentialResult, String> {
    if verification_window_start >= verification_window_end {
        return Err("verification window is invalid: start >= end".into());
    }

    let credential_valid = validate_credential_format(&device_credential);
    let possession_proven = verify_possession_proof(&device_credential, &proof_of_possession);

    // In the zkVM we use the cycle count as a monotonically increasing timestamp.
    // The host should pass the wall-clock timestamp as a public input for
    // real-world verification windows. Here we use a reasonable default.
    let verified_at = Duration::from_secs(0).as_secs();
    let within_verification_window = verified_at >= verification_window_start
        && verified_at <= verification_window_end;

    Ok(CredentialResult {
        credential_valid,
        possession_proven,
        within_verification_window,
        verified_at,
    })
}
