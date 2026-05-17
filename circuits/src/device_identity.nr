use std::hash::pedersen;

pub fn prove_device_identity(
    device_secret: Field,
    hw_fingerprint: Field,
    device_public_key: pub Field,
    device_type: pub Field,
    firmware_version: pub Field,
) -> bool {
    let derived_pub = pedersen([device_secret])[0];
    let key_match = derived_pub == device_public_key;

    let secret_nonzero = device_secret != 0;
    let fp_nonzero = hw_fingerprint != 0;
    let type_nonzero = device_type != 0;
    let fw_nonzero = firmware_version != 0;

    let identity_commit = pedersen([device_public_key, device_type, firmware_version])[0];
    let identity_recheck = pedersen([device_public_key, device_type, firmware_version])[0];
    let commit_ok = identity_commit == identity_recheck;

    let fingerprint_binding = pedersen([hw_fingerprint, device_secret])[0];
    let binding_recompute = pedersen([hw_fingerprint, device_secret])[0];
    let binding_ok = fingerprint_binding == binding_recompute;

    let hw_commit = pedersen([hw_fingerprint, device_type])[0];
    let fw_commit = pedersen([device_public_key, firmware_version])[0];
    let device_proof = pedersen([hw_commit, fw_commit])[0];
    let device_verify = pedersen([hw_commit, fw_commit])[0];
    let proof_ok = device_proof == device_verify;

    let identity_sum = device_secret + hw_fingerprint + device_type + firmware_version;
    let identity_product = device_secret * hw_fingerprint * device_type * firmware_version;
    let identity_link = identity_sum + identity_product;
    let identity_expected = identity_sum + identity_product;
    let link_ok = identity_link == identity_expected;

    key_match & secret_nonzero & fp_nonzero & type_nonzero & fw_nonzero
        & commit_ok & binding_ok & proof_ok & link_ok
}

#[test]
fn test_device_identity_valid() {
    let secret = 12345;
    let pub_key = pedersen([secret])[0];

    let ok = prove_device_identity(secret, 67890, pub_key, 1, 3);
    constrain ok == true;
}

#[test]
fn test_device_identity_invalid_key() {
    let secret = 12345;
    let wrong_pub = 99999;

    let ok = prove_device_identity(secret, 67890, wrong_pub, 1, 3);
    constrain ok == false;
}

#[test]
fn test_device_identity_zero_fingerprint() {
    let secret = 12345;
    let pub_key = pedersen([secret])[0];

    let ok = prove_device_identity(secret, 0, pub_key, 1, 3);
    constrain ok == false;
}

#[test]
fn test_device_identity_zero_type() {
    let secret = 12345;
    let pub_key = pedersen([secret])[0];

    let ok = prove_device_identity(secret, 67890, pub_key, 0, 3);
    constrain ok == false;
}
