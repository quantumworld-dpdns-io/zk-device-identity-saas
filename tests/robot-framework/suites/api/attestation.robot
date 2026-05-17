*** Settings ***
Library    Collections
Library    RequestsLibrary
Resource    ../../resources/common.resource
Resource    ../../resources/api_keywords.resource
Resource    ../../resources/auth_keywords.resource

Suite Setup    Create Admin Session
Suite Teardown    Delete Test Artifacts

*** Variables ***
@{TEST_DEVICE_IDS}           ${EMPTY}
@{TEST_ATTESTATION_IDS}      ${EMPTY}

*** Keywords ***
Delete Test Artifacts
    ${headers}    Create Admin Session
    FOR    ${dev_id}    IN    @{TEST_DEVICE_IDS}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${headers}    expected_status=204
    END
    Log    Cleaned up test devices

Create Test Device For Attestation
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=AttestationTest
    ...    model=ATT-1000
    ...    firmware_version=1.0.0
    ...    tenant_id=tenant-a
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${TEST_DEVICE_IDS}    ${device_id}
    RETURN    ${device_id}

Generate Sample Attestation Data
    [Arguments]    ${device_id}
    ${timestamp}    Get Current Date    result_format=epoch
    ${attestation_data}    Create Dictionary
    ...    device_id=${device_id}
    ...    attestation_type=dac
    ...    certificate_chain=["-----BEGIN CERTIFICATE-----\nMIIC...\n-----END CERTIFICATE-----"]
    ...    firmware_hash=abc123def456
    ...    timestamp=${timestamp}
    ...    signature=test_signature_placeholder
    RETURN    ${attestation_data}

*** Test Cases ***
Submit Valid Attestation Returns 201
    [Documentation]    Verify submitting a valid device attestation succeeds
    [Tags]    attestation    smoke    api
    ${device_id}    Create Test Device For Attestation
    ${attest_data}    Generate Sample Attestation Data    ${device_id}
    ${headers}    Create Admin Session
    ${response}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=201
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    id
    Dictionary Should Contain Key    ${json}    status
    ${attest_id}    Get From Dictionary    ${json}    id
    Append To List    ${TEST_ATTESTATION_IDS}    ${attest_id}

Submit Attestation With Invalid Cert Returns 400
    [Documentation]    Verify attestation with invalid certificate is rejected
    [Tags]    attestation    validation    api
    ${device_id}    Create Test Device For Attestation
    ${attest_data}    Generate Sample Attestation Data    ${device_id}
    Set To Dictionary    ${attest_data}    certificate_chain=["invalid_cert"]
    ${headers}    Create Admin Session
    ${response}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Submit Attestation For Non Existent Device Returns 404
    [Documentation]    Verify attestation for non-existent device is rejected
    [Tags]    attestation    validation    api
    ${attest_data}    Generate Sample Attestation Data    non-existent-device
    ${headers}    Create Admin Session
    ${response}    Submit Attestation    non-existent-device    ${attest_data}    ${headers}    expected_status=404

Submit Attestation With Missing Signature Returns 400
    [Documentation]    Verify attestation without signature is rejected
    [Tags]    attestation    validation    api
    ${device_id}    Create Test Device For Attestation
    ${attest_data}    Generate Sample Attestation Data    ${device_id}
    Remove From Dictionary    ${attest_data}    signature
    ${headers}    Create Admin Session
    ${response}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Get Attestation Status Returns 200
    [Documentation]    Verify fetching attestation status returns correct state
    [Tags]    attestation    smoke    api
    ${device_id}    Create Test Device For Attestation
    ${attest_data}    Generate Sample Attestation Data    ${device_id}
    ${headers}    Create Admin Session
    ${create_resp}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=201
    ${attest_id}    Get From Dictionary    ${create_resp.json()}    id
    Append To List    ${TEST_ATTESTATION_IDS}    ${attest_id}
    ${status_resp}    Get Attestation Status    ${device_id}    ${attest_id}    ${headers}    expected_status=200
    ${json}    Set Variable    ${status_resp.json()}
    Dictionary Should Contain Key    ${json}    status
    ${status}    Get From Dictionary    ${json}    status
    Should Be True    "${status}" in ["pending", "verified", "rejected", "processing"]

Get Attestation Status With Invalid Id Returns 404
    [Documentation]    Verify fetching non-existent attestation returns 404
    [Tags]    attestation    validation    api
    ${device_id}    Create Test Device For Attestation
    ${headers}    Create Admin Session
    ${response}    Get Attestation Status    ${device_id}    bad-attestation-id    ${headers}    expected_status=404

List Device Attestations Returns Results
    [Documentation]    Verify listing all attestations for a device
    [Tags]    attestation    api
    ${device_id}    Create Test Device For Attestation
    ${attest_data}    Generate Sample Attestation Data    ${device_id}
    ${headers}    Create Admin Session
    ${create_resp}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=201
    ${attest_id}    Get From Dictionary    ${create_resp.json()}    id
    Append To List    ${TEST_ATTESTATION_IDS}    ${attest_id}
    ${list_resp}    List Device Attestations    ${device_id}    ${headers}    expected_status=200
    ${json}    Set Variable    ${list_resp.json()}
    Dictionary Should Contain Key    ${json}    data
    ${data}    Get From Dictionary    ${json}    data
    Should Not Be Empty    ${data}

Submit Attestation With Expired Timestamp Returns 400
    [Documentation]    Verify expired timestamps in attestation are rejected
    [Tags]    attestation    validation    api
    ${device_id}    Create Test Device For Attestation
    ${attest_data}    Generate Sample Attestation Data    ${device_id}
    Set To Dictionary    ${attest_data}    timestamp=1000000
    ${headers}    Create Admin Session
    ${response}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Submit Multiple Attestations For Same Device
    [Documentation]    Verify multiple attestations can be submitted for same device
    [Tags]    attestation    api
    ${device_id}    Create Test Device For Attestation
    ${headers}    Create Admin Session
    FOR    ${i}    IN RANGE    3
        ${attest_data}    Generate Sample Attestation Data    ${device_id}
        Set To Dictionary    ${attest_data}    firmware_hash=hash_${i}
        ${resp}    Submit Attestation    ${device_id}    ${attest_data}    ${headers}    expected_status=201
        ${attest_id}    Get From Dictionary    ${resp.json()}    id
        Append To List    ${TEST_ATTESTATION_IDS}    ${attest_id}
    END
    ${list_resp}    List Device Attestations    ${device_id}    ${headers}
    ${json}    Set Variable    ${list_resp.json()}
    ${data}    Get From Dictionary    ${json}    data
    Length Should Be    ${data}    3
