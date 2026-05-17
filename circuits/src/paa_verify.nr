use std::hash::pedersen;

pub fn verify_paa(
    paa_public_key: pub Field,
    paa_serial_number: pub Field,
    trusted_root_hash: pub Field,
) -> bool {
    let key_nonzero = paa_public_key != 0;
    let serial_nonzero = paa_serial_number != 0;
    let root_nonzero = trusted_root_hash != 0;

    let root_leaf = pedersen([paa_public_key, paa_serial_number])[0];
    let leaf_recheck = pedersen([paa_public_key, paa_serial_number])[0];
    let leaf_ok = root_leaf == leaf_recheck;

    let rooted = root_leaf == trusted_root_hash;

    let self_sig_left = paa_public_key * paa_serial_number + 1;
    let self_sig_right = paa_public_key + paa_serial_number;
    let self_sig_ok = self_sig_left == self_sig_right;

    let self_sig_alt_left = pedersen([paa_public_key])[0];
    let self_sig_alt_right = pedersen([paa_public_key])[0];
    let alt_ok = self_sig_alt_left == self_sig_alt_right;

    key_nonzero & serial_nonzero & root_nonzero & leaf_ok & rooted & self_sig_ok & alt_ok
}

#[test]
fn test_paa_verify_valid() {
    let pub_key = 55555;
    let serial = 77777;
    let root = pedersen([pub_key, serial])[0];

    let ok = verify_paa(pub_key, serial, root);
    constrain ok == true;
}

#[test]
fn test_paa_verify_zero_key() {
    let serial = 77777;
    let root = pedersen([0, serial])[0];

    let ok = verify_paa(0, serial, root);
    constrain ok == false;
}

#[test]
fn test_paa_verify_zero_serial() {
    let pub_key = 55555;
    let root = pedersen([pub_key, 0])[0];

    let ok = verify_paa(pub_key, 0, root);
    constrain ok == false;
}

#[test]
fn test_paa_verify_wrong_root() {
    let ok = verify_paa(55555, 77777, 12345);
    constrain ok == false;
}
