use std::hash::pedersen;

pub fn prove_compliance(
    firmware_hash: Field,
    compliance_data: Field,
    compliance_version: pub Field,
    matter_spec_version: pub Field,
    is_compliant: pub Field,
) -> bool {
    let fw_nonzero = firmware_hash != 0;
    let cd_nonzero = compliance_data != 0;
    let cv_nonzero = compliance_version != 0;
    let mv_nonzero = matter_spec_version != 0;

    let fw_match = firmware_hash == compliance_data;

    let hash_commit = pedersen([firmware_hash, compliance_version])[0];
    let hash_recompute = pedersen([firmware_hash, compliance_version])[0];
    let commit_ok = hash_commit == hash_recompute;

    let data_commit = pedersen([compliance_data, matter_spec_version])[0];
    let data_recompute = pedersen([compliance_data, matter_spec_version])[0];
    let data_ok = data_commit == data_recompute;

    let combined = pedersen([hash_commit, data_commit])[0];
    let combined_check = pedersen([hash_commit, data_commit])[0];
    let combined_ok = combined == combined_check;

    let spec_poly = compliance_version * 2 + matter_spec_version;
    let spec_base = matter_spec_version * compliance_version;
    let spec_link = spec_poly + spec_base;
    let spec_expected = spec_base + spec_poly;
    let spec_ok = spec_link == spec_expected;

    let all_checks = fw_nonzero & cd_nonzero & cv_nonzero & mv_nonzero
        & fw_match & commit_ok & data_ok & combined_ok & spec_ok;
    let compliant_field: Field = if all_checks { 1 } else { 0 };
    let claim_valid = compliant_field == is_compliant;

    claim_valid
}

#[test]
fn test_compliance_valid_compliant() {
    let fw_hash = 42;
    let cd = 42;
    let cv = 2;
    let mv = 1;

    let ok = prove_compliance(fw_hash, cd, cv, mv, 1);
    constrain ok == true;
}

#[test]
fn test_compliance_valid_noncompliant() {
    let fw_hash = 42;
    let cd = 99;
    let cv = 0;
    let mv = 0;

    let ok = prove_compliance(fw_hash, cd, cv, mv, 0);
    constrain ok == true;
}

#[test]
fn test_compliance_mismatched_claim() {
    let fw_hash = 42;
    let cd = 42;
    let cv = 2;
    let mv = 1;

    let ok = prove_compliance(fw_hash, cd, cv, mv, 0);
    constrain ok == false;
}

#[test]
fn test_compliance_honest_noncompliant_wrong_claim() {
    let fw_hash = 42;
    let cd = 99;
    let cv = 0;
    let mv = 0;

    let ok = prove_compliance(fw_hash, cd, cv, mv, 1);
    constrain ok == false;
}
