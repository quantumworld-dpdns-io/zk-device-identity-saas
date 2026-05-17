use std::hash::pedersen;

fn hash_pair(a: Field, b: Field) -> Field {
    pedersen([a, b])[0]
}

fn hash_triple(a: Field, b: Field, c: Field) -> Field {
    pedersen([a, b, c])[0]
}

pub fn verify_pai(
    pai_private_key: Field,
    pai_public_key: pub Field,
    paa_public_key: pub Field,
    vendor_id: pub Field,
    product_id: pub Field,
) -> bool {
    let derived_pai_pub = pedersen([pai_private_key])[0];
    let key_match = derived_pai_pub == pai_public_key;

    let pai_cert_body = hash_pair(pai_public_key, paa_public_key);
    let signature_commit = pedersen([pai_private_key, pai_cert_body])[0];
    let expected_sig = pedersen([pai_public_key, pai_cert_body])[0];
    let sig_valid = signature_commit == expected_sig;

    let vendor_product_hash = hash_pair(vendor_id, product_id);
    let pai_metadata = pedersen([pai_public_key, vendor_product_hash])[0];
    let paa_endorsement = pedersen([paa_public_key, pai_metadata])[0];
    let expected_endorsement = pedersen([paa_public_key, vendor_id])[0];
    let endorsement_valid = paa_endorsement == expected_endorsement;

    let vendor_in_pai = pedersen([pai_public_key, vendor_id])[0];
    let product_in_pai = pedersen([vendor_id, product_id])[0];
    let pai_vp_link = hash_pair(vendor_in_pai, product_in_pai);
    let vp_check = hash_pair(pai_public_key, vendor_product_hash);
    let vp_match = pai_vp_link == vp_check;

    let pai_paa_link = hash_pair(pai_public_key, paa_public_key);
    let cert_hash = hash_triple(paa_public_key, vendor_id, product_id);
    let cert_link = hash_pair(pai_paa_link, cert_hash);
    let expected_cert = hash_pair(paa_public_key, pai_public_key);
    let cert_valid = cert_link == expected_cert;

    let private_nonzero = pai_private_key != 0;

    key_match & sig_valid & endorsement_valid & vp_match & cert_valid & private_nonzero
}

#[test]
fn test_pai_verify_valid() {
    let priv_key = 12345;
    let pub_key = pedersen([priv_key])[0];
    let paa_pub = pedersen([98765])[0];

    let ok = verify_pai(priv_key, pub_key, paa_pub, 11111, 22222);
    constrain ok == true;
}

#[test]
fn test_pai_verify_invalid_vendor() {
    let priv_key = 12345;
    let pub_key = pedersen([priv_key])[0];
    let paa_pub = pedersen([98765])[0];

    let ok = verify_pai(priv_key, pub_key, paa_pub, 99999, 22222);
    constrain ok == false;
}

#[test]
fn test_pai_verify_invalid_key() {
    let priv_key = 12345;
    let wrong_pub_key = pedersen([99999])[0];
    let paa_pub = pedersen([98765])[0];

    let ok = verify_pai(priv_key, wrong_pub_key, paa_pub, 11111, 22222);
    constrain ok == false;
}
