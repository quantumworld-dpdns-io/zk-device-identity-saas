*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    ../../../libraries/ZkDeviceLibrary.py
Resource    ../../../resources/common.resource
Resource    ../../../resources/api_keywords.resource
Resource    ../../../resources/auth_keywords.resource

Suite Setup    Create Admin Session
Suite Teardown    Cleanup Integrity Test Devices

*** Variables ***
@{INTEGRITY_DEVICE_IDS}      ${EMPTY}

*** Keywords ***
Cleanup Integrity Test Devices
    ${headers}    Create Admin Session
    FOR    ${dev_id}    IN    @{INTEGRITY_DEVICE_IDS}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${headers}    expected_status=204
    END

Create Device For Integrity Test
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=IntegrityTest
    ...    model=INTEG-500
    ...    firmware_version=1.0.0
    ...    tenant_id=tenant-a
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${INTEGRITY_DEVICE_IDS}    ${device_id}
    RETURN    ${device_id}

*** Test Cases ***
Unsigned Attestation Data Rejected
    [Documentation]    Verify attestation without signature is rejected
    [Tags]    owasp    A08    integrity    attestation    security
    ${device_id}    Create Device For Integrity Test
    ${headers}    Create Admin Session
    ${attest_data}    Create Dictionary
    ...    device_id=${device_id}
    ...    attestation_type=dac
    ...    certificate_chain=["-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----"]
    ...    firmware_hash=abc123
    ...    timestamp=1000000
    ${response}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error
    ${error}    Get From Dictionary    ${json}    error
    Should Contain    ${error}    signature    Unsigned data not detected!

Tampered Proof Data Detected
    [Documentation]    Verify tampered proof data is detected and rejected
    [Tags]    owasp    A08    integrity    proof    security
    ${tampered_proof}    Set Variable    {"proof": "AAAA", "public_inputs": {"device_id": "fake"}}
    ${headers}    Create Admin Session
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}/proofs/verify
    ...    json=${tampered_proof}
    ...    headers=${headers}
    ...    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Csrf Protection On State Changing Endpoints
    [Documentation]    Verify CSRF protection on POST/PUT/DELETE endpoints
    [Tags]    owasp    A08    integrity    csrf    security
    ${headers_no_csrf}    Create Dictionary    Content-Type=${CONTENT_TYPE_JSON}
    ${device_data}    Create Dictionary
    ...    serial_number=CSRF-TEST-${RANDOM}
    ...    device_type=matter_controller
    ...    manufacturer=CSRFTest
    ...    model=Test
    ...    firmware_version=1.0.0
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    json=${device_data}
    ...    headers=${headers_no_csrf}
    ...    expected_status=401
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Certificate Chain Validation Failure
    [Documentation]    Verify invalid certificate chain is rejected during attestation
    [Tags]    owasp    A08    integrity    certificate    security
    ${device_id}    Create Device For Integrity Test
    ${headers}    Create Admin Session
    ${attest_data}    Create Dictionary
    ...    device_id=${device_id}
    ...    attestation_type=dac
    ...    certificate_chain=["not-a-valid-cert"]
    ...    firmware_hash=abc123
    ...    timestamp=${RANDOM}
    ...    signature=test_sig
    ${response}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Incomplete Cert Chain Rejected
    [Documentation]    Verify incomplete certificate chain is rejected
    [Tags]    owasp    A08    integrity    certificate    security
    ${device_id}    Create Device For Integrity Test
    ${headers}    Create Admin Session
    ${attest_data}    Create Dictionary
    ...    device_id=${device_id}
    ...    attestation_type=dac
    ...    certificate_chain=${EMPTY_LIST}
    ...    firmware_hash=abc123
    ...    timestamp=${RANDOM}
    ...    signature=test_sig
    ${response}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Tampered Firmware Hash Detected
    [Documentation]    Verify attestation with tampered firmware hash is detected
    [Tags]    owasp    A08    integrity    firmware    security
    ${device_id}    Create Device For Integrity Test
    ${headers}    Create Admin Session
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=HashTest
    ...    model=Test
    ...    firmware_version=1.0.0
    ...    firmware_hash=original_hash
    ${create_resp}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${new_device_id}    Get From Dictionary    ${create_resp.json()}    id
    Append To List    ${INTEGRITY_DEVICE_IDS}    ${new_device_id}
    ${attest_data}    Create Dictionary
    ...    device_id=${new_device_id}
    ...    attestation_type=dac
    ...    certificate_chain=["-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----"]
    ...    firmware_hash=tampered_hash
    ...    timestamp=${RANDOM}
    ...    signature=test_sig
    ${response}    Submit Attestation    ${new_device_id}    ${attest_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Data Integrity On Device Update
    [Documentation]    Verify device update maintains data integrity
    [Tags]    owasp    A08    integrity    device    security
    ${device_id}    Create Device For Integrity Test
    ${headers}    Create Admin Session
    ${get_resp}    Get Device    ${device_id}    ${headers}    expected_status=200
    ${original_data}    Set Variable    ${get_resp.json()}
    ${update_data}    Create Dictionary    firmware_version=3.0.0
    ${update_resp}    Update Device    ${device_id}    ${update_data}    ${headers}    expected_status=200
    ${get_resp2}    Get Device    ${device_id}    ${headers}    expected_status=200
    ${updated_data}    Set Variable    ${get_resp2.json()}
    Should Be Equal    ${original_data}[serial_number]    ${updated_data}[serial_number]
    Should Be Equal    ${updated_data}[firmware_version]    3.0.0

Replay Attestation Rejected
    [Documentation]    Verify replaying the same attestation is rejected
    [Tags]    owasp    A08    integrity    replay    security
    ${device_id}    Create Device For Integrity Test
    ${headers}    Create Admin Session
    ${timestamp}    Get Current Date    result_format=epoch
    ${attest_data}    Create Dictionary
    ...    device_id=${device_id}
    ...    attestation_type=dac
    ...    certificate_chain=["-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----"]
    ...    firmware_hash=abc123
    ...    timestamp=${timestamp}
    ...    signature=test_replay_signature
    ${first_resp}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=201
    ${second_resp}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${second_resp.json()}
    Dictionary Should Contain Key    ${json}    error
