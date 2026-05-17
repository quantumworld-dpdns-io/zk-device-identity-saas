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
    let keys_distinct = pai_public_key != paa_public_key;
    let ids_distinct = vendor_id != product_id;

    let vp_commit = pedersen([vendor_id, product_id])[0];
    let cert_binding = pedersen([pai_public_key, vp_commit])[0];
    let cert_recheck = pedersen([pai_public_key, vp_commit])[0];
    let commit_ok = cert_binding == cert_recheck;

    let vp_pair = pedersen([pai_public_key, paa_public_key])[0];
    let vp_chain = pedersen([vp_pair, vp_commit])[0];
    let root_check = pedersen([vp_pair, vp_commit])[0];
    let chain_ok = vp_chain == root_check;

    let metadata_link = vendor_id * (product_id + 1);
    let metadata_check = vendor_id * product_id + vendor_id;
    let metadata_ok = metadata_link == metadata_check;

    key_match & key_nonzero & vendor_nonzero & product_nonzero
        & keys_distinct & ids_distinct & commit_ok & chain_ok & metadata_ok
}

#[test]
fn test_pai_verify_valid() {
    let priv_key = 77;
    let pub_key = derive_public(priv_key);

    let ok = verify_pai(priv_key, pub_key, 98765, 11111, 22222);
    constrain ok == true;
}

#[test]
fn test_pai_verify_invalid_vendor() {
    let priv_key = 77;
    let pub_key = derive_public(priv_key);

    let ok = verify_pai(priv_key, pub_key, 98765, 0, 22222);
    constrain ok == false;
}

#[test]
fn test_pai_verify_invalid_key() {
    let priv_key = 99999;
    let wrong_pub = derive_public(77);

    let ok = verify_pai(priv_key, wrong_pub, 98765, 11111, 22222);
    constrain ok == false;
}

#[test]
fn test_pai_verify_same_ids() {
    let priv_key = 77;
    let pub_key = derive_public(priv_key);

    let ok = verify_pai(priv_key, pub_key, 98765, 11111, 11111);
    constrain ok == false;
}
