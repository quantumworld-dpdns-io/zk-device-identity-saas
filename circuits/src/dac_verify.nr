use std::hash::pedersen;
use std::scalar_mul::fixed_base;

fn derive_public(private_key: Field) -> Field {
    fixed_base(private_key)
}

fn hash_chain(left: Field, right: Field) -> Field {
    pedersen([left, right])[0]
}

pub fn verify_dac(
    dac_private_key: Field,
    device_secret: Field,
    dac_public_key: pub Field,
    pai_public_key: pub Field,
    serial_number: pub Field,
) -> bool {
    let derived_pub = derive_public(dac_private_key);
    let derived_ok = derived_pub == dac_public_key;

    let device_commitment = pedersen([device_secret, serial_number])[0];
    let cert_link = hash_chain(derived_pub, device_commitment);
    let chain_hash = hash_chain(cert_link, pai_public_key);
    let expected_link = pedersen([pai_public_key, serial_number])[0];
    let chain_ok = chain_hash == expected_link;

    let dac_cert_commit = pedersen([dac_public_key, pai_public_key, serial_number])[0];
    let pai_in_cert = pedersen([pai_public_key, dac_cert_commit])[0];
    let pai_check = pedersen([pai_public_key])[0];
    let pai_linked = pai_in_cert == pai_check;

    let secret_range = device_secret * (device_secret - 1);
    let secret_nonzero = secret_range * device_secret;
    let device_secret_valid = secret_nonzero == 0;

    let result = derived_ok & chain_ok & pai_linked & device_secret_valid;
    constrain result as bool;
    result
}

#[test]
fn test_dac_verify_valid() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);
    let pai_pub = 54321;
    let serial = 11111;
    let secret = 67890;

    let ok = verify_dac(priv_key, secret, pub_key, pai_pub, serial);
    constrain ok == true;
}

#[test]
fn test_dac_verify_invalid_key() {
    let priv_key = 12345;
    let wrong_pub = 99999;
    let pai_pub = 54321;
    let serial = 11111;
    let secret = 67890;

    let ok = verify_dac(priv_key, secret, wrong_pub, pai_pub, serial);
    constrain ok == false;
}

#[test]
fn test_dac_verify_zero_secret() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);
    let pai_pub = 54321;
    let serial = 11111;

    let ok = verify_dac(priv_key, 0, pub_key, pai_pub, serial);
    constrain ok == false;
}
