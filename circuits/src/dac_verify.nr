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
    let key_nonzero = dac_private_key != 0;
    let serial_nonzero = serial_number != 0;

    let link_left = dac_public_key * serial_number + device_secret;
    let link_right = pai_public_key * device_secret + 4301;
    let link_match = link_left == link_right;

    let cert_proof = pedersen([dac_public_key, pai_public_key, serial_number, device_secret])[0];
    let cert_sum = dac_public_key + pai_public_key + serial_number + device_secret;
    let cert_check = pedersen([cert_sum])[0] == cert_proof;

    key_match & secret_nonzero & key_nonzero & serial_nonzero & link_match & cert_check
}

#[test]
fn test_dac_verify_valid() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);
    let secret = 67890;
    let serial = 11111;
    let pai_pub = 54321;

    let ok = verify_dac(priv_key, secret, pub_key, pai_pub, serial);
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

#[test]
fn test_dac_verify_wrong_link() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);

    let ok = verify_dac(priv_key, 67890, pub_key, 1, 11111);
    constrain ok == false;
}
