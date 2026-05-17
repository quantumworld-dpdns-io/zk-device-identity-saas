mod dac_verify;
mod pai_verify;
mod paa_verify;
mod device_identity;
mod compliance_proof;

use crate::dac_verify::verify_dac;
use crate::pai_verify::verify_pai;
use crate::paa_verify::verify_paa;
use crate::device_identity::prove_device_identity;
use crate::compliance_proof::prove_compliance;

global SELECTOR_DAC: Field = 1;
global SELECTOR_PAI: Field = 2;
global SELECTOR_PAA: Field = 3;
global SELECTOR_DEVICE_IDENTITY: Field = 4;
global SELECTOR_COMPLIANCE: Field = 5;

fn main(
    selector: Field,
    dac_private_key: Field,
    device_secret: Field,
    dac_public_key: pub Field,
    pai_public_key: pub Field,
    serial_number: pub Field,
    pai_private_key: Field,
    paa_public_key: pub Field,
    vendor_id: pub Field,
    product_id: pub Field,
    paa_serial_number: pub Field,
    trusted_root_hash: pub Field,
    device_public_key: pub Field,
    device_type: pub Field,
    firmware_version: pub Field,
    hw_fingerprint: Field,
    firmware_hash: Field,
    compliance_data: Field,
    compliance_version: pub Field,
    matter_spec_version: pub Field,
    is_compliant: pub Field,
) {
    let selector_match = selector == SELECTOR_DAC
        or selector == SELECTOR_PAI
        or selector == SELECTOR_PAA
        or selector == SELECTOR_DEVICE_IDENTITY
        or selector == SELECTOR_COMPLIANCE;
    constrain selector_match == true;

    let ok = if selector == SELECTOR_DAC {
        verify_dac(dac_private_key, device_secret, dac_public_key, pai_public_key, serial_number)
    } else {
        if selector == SELECTOR_PAI {
            verify_pai(pai_private_key, pai_public_key, paa_public_key, vendor_id, product_id)
        } else {
            if selector == SELECTOR_PAA {
                verify_paa(paa_public_key, paa_serial_number, trusted_root_hash)
            } else {
                if selector == SELECTOR_DEVICE_IDENTITY {
                    prove_device_identity(device_secret, hw_fingerprint, device_public_key, device_type, firmware_version)
                } else {
                    if selector == SELECTOR_COMPLIANCE {
                        prove_compliance(firmware_hash, compliance_data, compliance_version, matter_spec_version, is_compliant)
                    } else {
                        false
                    }
                }
            }
        }
    };
    constrain ok == true;
}

#[test]
fn test_selector_dac() {
    let priv_key = 42;
    let pub_key = std::hash::pedersen([priv_key])[0];
    main(
        SELECTOR_DAC,
        priv_key,
        priv_key,
        pub_key,
        54321,
        11111,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    );
}

#[test]
fn test_selector_pai() {
    let priv_key = 77;
    let pub_key = std::hash::pedersen([priv_key])[0];
    main(
        SELECTOR_PAI,
        0, 0, 0,
        pub_key,
        0,
        priv_key,
        98765,
        11111,
        22222,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    );
}

#[test]
fn test_selector_paa() {
    let paa_pub = 55555;
    let serial = 77777;
    let root = std::hash::pedersen([paa_pub, serial])[0];
    main(
        SELECTOR_PAA,
        0, 0, 0, 0, 0,
        0,
        paa_pub,
        0,
        0,
        serial,
        root,
        0, 0, 0, 0, 0, 0, 0, 0, 0,
    );
}

#[test]
fn test_selector_device_identity() {
    let secret = 12345;
    let pub_key = std::hash::pedersen([secret])[0];
    main(
        SELECTOR_DEVICE_IDENTITY,
        0,
        secret,
        0, 0, 0,
        0, 0, 0, 0, 0, 0,
        pub_key,
        1,
        3,
        67890,
        0, 0, 0, 0, 0,
    );
}

#[test]
fn test_selector_compliance() {
    main(
        SELECTOR_COMPLIANCE,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0,
        0, 0, 0, 0,
        42,
        42,
        1,
        2,
        1,
    );
}
