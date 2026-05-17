use std::hash::pedersen;

pub fn derive_public(private_key: Field) -> Field {
    pedersen([private_key])[0]
}

pub fn verify_pai(
    pai_private_key: Field,
    pai_public_key: pub Field,
    paa_public_key: pub Field,
    vendor_id: pub Field,
    product_id: pub Field,
) -> bool {
    let derived_pub = derive_public(pai_private_key);
    let key_match = derived_pub == pai_public_key;

    let key_nonzero = pai_private_key != 0;
    let vendor_nonzero = vendor_id != 0;
    let product_nonzero = product_id != 0;

    let vp_product = vendor_id * product_id;
    let vp_commit = pedersen([vendor_id, product_id])[0];
    let vp_sum = vp_product + vp_commit;
    let vp_hash = pedersen([vp_sum])[0];
    let vp_check = pedersen([pai_public_key])[0];
    let vp_valid = vp_hash == vp_check;

    let pai_chain = pedersen([pai_public_key, paa_public_key])[0];
    let vendor_binding = pedersen([vendor_id, pai_chain])[0];
    let product_binding = pedersen([product_id, vendor_binding])[0];
    let chain_root = pedersen([paa_public_key, product_binding])[0];
    let expected_root = pedersen([paa_public_key, pai_public_key])[0];
    let chain_valid = chain_root == expected_root;

    let cert_sig = pai_private_key * vendor_id + product_id;
    let sig_check = pai_public_key + vendor_id * product_id;
    let sig_valid = cert_sig == sig_check;

    key_match & key_nonzero & vendor_nonzero & product_nonzero & vp_valid & chain_valid & sig_valid
}

#[test]
fn test_pai_verify_valid() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);

    let ok = verify_pai(priv_key, pub_key, 98765, 11111, 22222);
    constrain ok == true;
}

#[test]
fn test_pai_verify_invalid_vendor() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);

    let ok = verify_pai(priv_key, pub_key, 98765, 99999, 22222);
    constrain ok == false;
}

#[test]
fn test_pai_verify_invalid_key() {
    let wrong_priv = 99999;
    let pub_key = derive_public(12345);

    let ok = verify_pai(wrong_priv, pub_key, 98765, 11111, 22222);
    constrain ok == false;
}

#[test]
fn test_pai_verify_zero_product() {
    let priv_key = 12345;
    let pub_key = derive_public(priv_key);

    let ok = verify_pai(priv_key, pub_key, 98765, 11111, 0);
    constrain ok == false;
}
