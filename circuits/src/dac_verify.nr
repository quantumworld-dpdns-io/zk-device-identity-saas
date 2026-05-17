use std::hash::pedersen;

pub fn derive_public(private_key: Field) -> Field {
    pedersen([private_key])[0]
}

pub fn verify_dac(
    dac_private_key: Field,
    device_secret: Field,
    dac_public_key: pub Field,
    pai_public_key: pub Field,
    serial_number: pub Field,
) -> bool {
    let derived_pub = derive_public(dac_private_key);
    let key_match = derived_pub == dac_public_key;

    let secret_nonzero = device_secret != 0;
    let serial_nonzero = serial_number != 0;
    let key_nonzero = dac_private_key != 0;

    let pai_check = pedersen([pai_public_key])[0];
    let chain_left = pedersen([derived_pub, pai_check])[0];
    let chain_right = pedersen([dac_public_key, pedersen([pai_public_key])[0]])[0];
    let chain_match = chain_left == chain_right;

    let auth_field = device_secret + dac_private_key;
    let auth_commit = pedersen([auth_field, serial_number])[0];
    let auth_expected = pedersen([device_secret, dac_public_key])[0];
    let auth_verify = auth_commit == auth_expected;

    key_match & secret_nonzero & serial_nonzero & key_nonzero & chain_match & auth_verify
}

#[test]
fn test_dac_verify_valid() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);

    let ok = verify_dac(priv_key, 67890, pub_key, 54321, 11111);
    constrain ok == true;
}

#[test]
fn test_dac_verify_invalid_key() {
    let priv_key = 12345;
    let wrong_pub = 99999;

    let ok = verify_dac(priv_key, 67890, wrong_pub, 54321, 11111);
    constrain ok == false;
}

#[test]
fn test_dac_verify_zero_secret() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);

    let ok = verify_dac(priv_key, 0, pub_key, 54321, 11111);
    constrain ok == false;
}

#[test]
fn test_dac_verify_zero_key() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);

    let ok = verify_dac(0, 67890, pub_key, 54321, 11111);
    constrain ok == false;
}
