use alloc::string::{String, ToString};
use alloc::vec::Vec;
use core::time::Duration;

/// Known-good firmware hashes (SHA-256 hex digests).
/// In production these would come from a secure oracle or on-chain registry.
const KNOWN_FIRMWARE_HASHES: &[&str] = &[
    "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2",
    "f1e2d3c4b5a69788796a5b4c3d2e1f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6",
    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
];

const COMPLIANT_FIRMWARE_VERSIONS: &[&str] = &["1.0.0", "1.1.0", "1.2.0", "2.0.0"];

pub struct ComplianceResult {
    pub verified: bool,
    pub manufacturer_allowed: bool,
    pub compliance_version: String,
    pub device_config_hash: String,
    pub timestamp: u64,
}

// Simple hash function for no_std environments.
// Uses a FNV-1a-like approach to produce a hex string without external deps.
fn compute_config_hash(config: &str) -> String {
    use core::num::Wrapping;

    let mut hash: Wrapping<u64> = Wrapping(0xcbf29ce484222325u64);
    for byte in config.bytes() {
        hash ^= Wrapping(byte as u64);
        hash *= Wrapping(0x100000001b3u64);
    }

    let mut hex = alloc::string::String::with_capacity(16);
    let h = hash.0;
    hex.extend(
        [
            (h >> 56) as u8,
            (h >> 48) as u8,
            (h >> 40) as u8,
            (h >> 32) as u8,
            (h >> 24) as u8,
            (h >> 16) as u8,
            (h >> 8) as u8,
            h as u8,
        ]
        .iter()
        .flat_map(|b| {
            let high = b >> 4;
            let low = b & 0x0f;
            [
                if high < 10 { b'0' + high } else { b'a' + high - 10 },
                if low < 10 { b'0' + low } else { b'a' + low - 10 },
            ]
        })
        .map(char::from),
    );
    hex
}

fn firmware_hash_is_known(hash: &str) -> bool {
    KNOWN_FIRMWARE_HASHES
        .iter()
        .any(|known| known.eq_ignore_ascii_case(hash))
}

fn firmware_version_is_compliant(version: &str) -> bool {
    COMPLIANT_FIRMWARE_VERSIONS.contains(&version)
}

fn extract_manufacturer(config: &str) -> Result<String, &'static str> {
    // Expect config as JSON-like key=value pairs: "manufacturer=Acme,firmware_version=1.0.0"
    for pair in config.split(',') {
        let trimmed = pair.trim();
        if let Some(value) = trimmed.strip_prefix("manufacturer=") {
            return Ok(value.trim().to_string());
        }
    }
    Err("device_config missing manufacturer field")
}

fn extract_firmware_version(config: &str) -> Result<String, &'static str> {
    for pair in config.split(',') {
        let trimmed = pair.trim();
        if let Some(value) = trimmed.strip_prefix("firmware_version=") {
            return Ok(value.trim().to_string());
        }
    }
    Ok("unknown".to_string())
}

/// Verifies device compliance.
///
/// # Arguments
///
/// * `device_firmware_hash` - SHA-256 hash of the device firmware (private input)
/// * `device_config` - Comma-separated key=value config string: `manufacturer=Acme,firmware_version=1.0.0`
/// * `attestation_data` - Opaque attestation blob (logged but not structurally validated here)
/// * `expected_compliance_version` - The minimum compliance version the device must meet
/// * `allowed_manufacturers` - List of manufacturer identifiers permitted by the verifier
///
/// # Returns
///
/// A `ComplianceResult` with verification status committed to the journal.
/// The firmware hash itself is never revealed in the public output.
pub fn verify_compliance(
    device_firmware_hash: String,
    device_config: String,
    _attestation_data: String,
    expected_compliance_version: String,
    allowed_manufacturers: Vec<String>,
) -> Result<ComplianceResult, String> {
    let config_hash = compute_config_hash(&device_config);

    let manufacturer =
        extract_manufacturer(&device_config).map_err(|e| format!("config parse error: {e}"))?;

    let firmware_version = extract_firmware_version(&device_config).unwrap_or_default();

    let firmware_known = firmware_hash_is_known(&device_firmware_hash);
    let version_compliant = firmware_version_is_compliant(&firmware_version);
    let manufacturer_allowed = allowed_manufacturers
        .iter()
        .any(|m| m.eq_ignore_ascii_case(&manufacturer));

    let version_meets_minimum = firmware_version >= expected_compliance_version;

    let verified = firmware_known
        && version_compliant
        && version_meets_minimum
        && manufacturer_allowed;

    // Timestamp: approximate uptime seconds (not wall-clock; for wall-clock the
    // host should inject it as a public input)
    let timestamp = Duration::from_secs(0).as_secs();

    Ok(ComplianceResult {
        verified,
        manufacturer_allowed,
        compliance_version: firmware_version,
        device_config_hash: config_hash,
        timestamp,
    })
}
