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

    let key_nonzero = dac_private_key != 0;
    let secret_nonzero = device_secret != 0;
    let serial_nonzero = serial_number != 0;
    let keys_distinct = dac_public_key != pai_public_key;

    let cert_pair = pedersen([dac_public_key, pai_public_key])[0];
    let device_binding = pedersen([device_secret, serial_number])[0];
    let cert_commit = pedersen([cert_pair, device_binding])[0];
    let cert_check = pedersen([cert_pair, device_binding])[0];
    let commit_ok = cert_commit == cert_check;

    let auth_left = dac_private_key + serial_number;
    let auth_right = device_secret + serial_number;
    let auth_link = auth_left == auth_right;

    key_match & key_nonzero & secret_nonzero & serial_nonzero & keys_distinct & commit_ok & auth_link
}

#[test]
fn test_dac_verify_valid() {
    let priv_key = 42;
    let pub_key = derive_public(priv_key);
    let secret = 42;

    let ok = verify_dac(priv_key, secret, pub_key, 54321, 11111);
    constrain ok == true;
}

#[test]
fn test_dac_verify_invalid_key() {
    let priv_key = 42;
    let wrong_pub = 99999;

    let ok = verify_dac(priv_key, 67890, wrong_pub, 54321, 11111);
    constrain ok == false;
}

#[test]
fn test_dac_verify_zero_secret() {
    let priv_key = 42;
    let pub_key = derive_public(priv_key);

    let ok = verify_dac(priv_key, 0, pub_key, 54321, 11111);
    constrain ok == false;
}

#[test]
fn test_dac_verify_zero_key() {
    let priv_key = 42;
    let pub_key = derive_public(priv_key);

    let ok = verify_dac(0, 67890, pub_key, 54321, 11111);
    constrain ok == false;
}

#[test]
fn test_dac_verify_same_as_pai() {
    let priv_key = 42;
    let pub_key = derive_public(priv_key);

    let ok = verify_dac(priv_key, 67890, pub_key, pub_key, 11111);
    constrain ok == false;
}
