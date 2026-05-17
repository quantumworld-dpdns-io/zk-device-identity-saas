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
    constrain selector == SELECTOR_DAC or selector == SELECTOR_PAI
        or selector == SELECTOR_PAA or selector == SELECTOR_DEVICE_IDENTITY
        or selector == SELECTOR_COMPLIANCE;

    if selector == SELECTOR_DAC {
        verify_dac(dac_private_key, device_secret, dac_public_key, pai_public_key, serial_number);
    }

    if selector == SELECTOR_PAI {
        verify_pai(pai_private_key, pai_public_key, paa_public_key, vendor_id, product_id);
    }

    if selector == SELECTOR_PAA {
        verify_paa(paa_public_key, paa_serial_number, trusted_root_hash);
    }

    if selector == SELECTOR_DEVICE_IDENTITY {
        prove_device_identity(device_secret, hw_fingerprint, device_public_key, device_type, firmware_version);
    }

    if selector == SELECTOR_COMPLIANCE {
        prove_compliance(firmware_hash, compliance_data, compliance_version, matter_spec_version, is_compliant);
    }
}

#[test]
fn test_selector_dac() {
    main(
        SELECTOR_DAC,
        12345,
        67890,
        98765,
        54321,
        11111,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    );
}

#[test]
fn test_selector_pai() {
    main(
        SELECTOR_PAI,
        0, 0, 0, 0, 0,
        12345,
        98765,
        11111,
        22222,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    );
}

#[test]
fn test_selector_device_identity() {
    main(
        SELECTOR_DEVICE_IDENTITY,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0,
        12345,
        1,
        3,
        67890,
        0, 0, 0, 0,
    );
}

#[test]
fn test_selector_compliance() {
    main(
        SELECTOR_COMPLIANCE,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0,
        12345,
        1,
        2,
        0,
    );
}

#[test]
fn test_invalid_selector() {
    main(
        255,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    );
}
