use std::hash::pedersen;

fn derive_public(private_key: Field) -> Field {
    pedersen([private_key])[0]
}

fn hash_pair(a: Field, b: Field) -> Field {
    pedersen([a, b])[0]
}

pub fn verify_dac(
    dac_private_key: Field,
    device_secret: Field,
    dac_public_key: pub Field,
    pai_public_key: pub Field,
    serial_number: pub Field,
) -> bool {
    let derived_pub = derive_public(dac_private_key);
    let key_derived = derived_pub == dac_public_key;

    let device_commit = pedersen([device_secret, serial_number])[0];
    let cert_body = hash_pair(derived_pub, device_commit);
    let cert_chain = pedersen([cert_body, pai_public_key])[0];
    let expected_chain = pedersen([pai_public_key, serial_number])[0];
    let chain_valid = cert_chain == expected_chain;

    let pai_binding = pedersen([dac_public_key, pai_public_key, serial_number])[0];
    let pai_check = pedersen([pai_public_key, pai_binding])[0];
    let pai_hash = pedersen([pai_public_key])[0];
    let pai_linked = pai_check == pai_hash;

    let secret_positive = device_secret * (device_secret - 1);
    let secret_range = secret_positive * device_secret;
    let secret_valid = secret_range == 0;

    key_derived & chain_valid & pai_linked & secret_valid
}

#[test]
fn test_dac_verify_valid() {
    let priv_key = 12345;
    let pub_key = pedersen([priv_key])[0];
    let pai_pub = pedersen([54321])[0];
    let serial = 11111;
    let secret = 67890;

    let ok = verify_dac(priv_key, secret, pub_key, pai_pub, serial);
    constrain ok == true;
}

#[test]
fn test_dac_verify_invalid_key() {
    let priv_key = 12345;
    let wrong_pub = 99999;
    let pai_pub = pedersen([54321])[0];
    let serial = 11111;
    let secret = 67890;

    let ok = verify_dac(priv_key, secret, wrong_pub, pai_pub, serial);
    constrain ok == false;
}

#[test]
fn test_dac_verify_zero_secret() {
    let priv_key = 12345;
    let pub_key = pedersen([priv_key])[0];
    let pai_pub = pedersen([54321])[0];
    let serial = 11111;

    let ok = verify_dac(priv_key, 0, pub_key, pai_pub, serial);
    constrain ok == false;
}
