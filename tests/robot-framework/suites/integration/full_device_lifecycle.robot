*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    DateTime
Resource    ../../resources/common.resource
Resource    ../../resources/api_keywords.resource
Resource    ../../resources/auth_keywords.resource
Resource    ../../resources/zk_keywords.resource

Suite Setup    Create Admin Session

*** Variables ***
${LIFECYCLE_DEVICE_ID}       ${EMPTY}
${LIFECYCLE_ATTESTATION_ID}  ${EMPTY}
${LIFECYCLE_PROOF_ID}        ${EMPTY}

*** Test Cases ***
Step 1 Register Device
    [Documentation]    E2E: Register a new device with complete metadata
    [Tags]    integration    lifecycle    e2e    smoke
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=LifecycleTest
    ...    model=LC-3000
    ...    firmware_version=1.0.0
    ...    tenant_id=tenant-a
    ...    device_name=Lifecycle_Device_1
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    id
    ${LIFECYCLE_DEVICE_ID}    Get From Dictionary    ${json}    id
    Set Suite Variable    ${LIFECYCLE_DEVICE_ID}
    Dictionary Should Contain Key    ${json}    serial_number
    Should Be Equal    ${json}[serial_number]    ${serial}
    Should Be Equal    ${json}[status]    active
    Log    Device registered: ${LIFECYCLE_DEVICE_ID}

Step 2 Submit Dcc
    [Documentation]    E2E: Submit Device Compliance Certificate for the registered device
    [Tags]    integration    lifecycle    e2e
    ${headers}    Create Admin Session
    ${dcc_data}    Create Dictionary
    ...    device_id=${LIFECYCLE_DEVICE_ID}
    ...    certification_type=matter
    ...    certification_id=MATTER-CERT-${RANDOM}
    ...    issue_date=2025-01-01
    ...    expiry_date=2030-12-31
    ...    approved=true
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}/devices/${LIFECYCLE_DEVICE_ID}/certificates
    ...    json=${dcc_data}
    ...    headers=${headers}
    ...    expected_status=201
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    id
    Log    DCC submitted for device ${LIFECYCLE_DEVICE_ID}

Step 3 Submit Attestation
    [Documentation]    E2E: Submit device attestation with certificate chain
    [Tags]    integration    lifecycle    e2e    smoke
    ${headers}    Create Admin Session
    ${timestamp}    Get Current Date    result_format=epoch
    ${attestation_data}    Create Dictionary
    ...    device_id=${LIFECYCLE_DEVICE_ID}
    ...    attestation_type=dac
    ...    certificate_chain=["-----BEGIN CERTIFICATE-----\nMIIC...\n-----END CERTIFICATE-----"]
    ...    firmware_hash=lifecycle_firmware_hash_abc
    ...    timestamp=${timestamp}
    ...    signature=lifecycle_test_signature_123
    ${response}    Submit Attestation    ${LIFECYCLE_DEVICE_ID}    ${attestation_data}    ${headers}    expected_status=201
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    id
    ${LIFECYCLE_ATTESTATION_ID}    Get From Dictionary    ${json}    id
    Set Suite Variable    ${LIFECYCLE_ATTESTATION_ID}
    Dictionary Should Contain Key    ${json}    status
    Log    Attestation submitted: ${LIFECYCLE_ATTESTATION_ID}

Step 4 Generate Proof
    [Documentation]    E2E: Generate ZK proof for the attested device
    [Tags]    integration    lifecycle    e2e    zk
    ${headers}    Create Admin Session
    ${public_inputs}    Create Dictionary
    ...    device_id=${LIFECYCLE_DEVICE_ID}
    ...    timestamp=${RANDOM}
    ...    device_type=matter_controller
    ...    firmware_version=1.0.0
    ${private_inputs}    Create Dictionary
    ...    serial_number=LC-SERIAL-001
    ...    secret_key=lifecycle_secret_key
    ...    attestation_key=lifecycle_attest_key
    ${response}    Generate ZK Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}    expected_status=202
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    proof_id
    ${LIFECYCLE_PROOF_ID}    Get From Dictionary    ${json}    proof_id
    Set Suite Variable    ${LIFECYCLE_PROOF_ID}
    Log    Proof generation started: ${LIFECYCLE_PROOF_ID}

Step 5 Wait For Proof Completion
    [Documentation]    E2E: Wait for async proof generation to complete
    [Tags]    integration    lifecycle    e2e    zk
    ${headers}    Create Admin Session
    ${proof_response}    Wait For Proof Completion    ${LIFECYCLE_PROOF_ID}    ${headers}
    ${json}    Set Variable    ${proof_response.json()}
    Dictionary Should Contain Key    ${json}    proof
    Dictionary Should Contain Key    ${json}    status
    Should Be Equal    ${json}[status]    completed
    ${proof_data}    Get From Dictionary    ${json}    proof
    Set Suite Variable    ${LIFECYCLE_PROOF_DATA}    ${proof_data}
    Log    Proof completed

Step 6 Verify Proof
    [Documentation]    E2E: Verify the generated ZK proof
    [Tags]    integration    lifecycle    e2e    zk    smoke
    ${headers}    Create Admin Session
    ${public_inputs}    Create Dictionary
    ...    device_id=${LIFECYCLE_DEVICE_ID}
    ...    timestamp=${RANDOM}
    ...    device_type=matter_controller
    ...    firmware_version=1.0.0
    ${response}    Verify ZK Proof    ${LIFECYCLE_PROOF_DATA}    ${public_inputs}    ${headers}    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    verified
    Should Be Equal    ${json}[verified]    ${TRUE}
    Log    Proof verified successfully

Step 7 Check Compliance
    [Documentation]    E2E: Verify device compliance status
    [Tags]    integration    lifecycle    e2e    compliance
    ${headers}    Create Admin Session
    ${response}    Check Compliance    ${LIFECYCLE_DEVICE_ID}    ${headers}    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    compliant
    Dictionary Should Contain Key    ${json}    attestations
    Dictionary Should Contain Key    ${json}    proofs
    Log    Device compliance: ${json}[compliant]

Step 8 Get Device Audit Trail
    [Documentation]    E2E: Verify the complete device lifecycle is recorded
    [Tags]    integration    lifecycle    e2e    audit
    ${headers}    Create Admin Session
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${AUDIT_LOG_ENDPOINT}
    ...    headers=${headers}
    ...    params={"device_id": "${LIFECYCLE_DEVICE_ID}"}
    ...    expected_status=200
    ${json}    Set Variable    ${response.json()}
    ${logs}    Get From Dictionary    ${json}    logs
    Length Should Be Greater Than    ${logs}    0
    ${actions}    Evaluate    [log["action"] for log in $logs if "action" in log]
    Should Contain    ${actions}    device_created
    Log    Device lifecycle audit trail verified

Step 9 Delete Device
    [Documentation]    E2E: Clean up by deleting the device
    [Tags]    integration    lifecycle    e2e
    ${headers}    Create Admin Session
    ${response}    Delete Device    ${LIFECYCLE_DEVICE_ID}    ${headers}    expected_status=204
    Log    Device ${LIFECYCLE_DEVICE_ID} deleted

Step 10 Verify Deletion
    [Documentation]    E2E: Verify device is no longer accessible after deletion
    [Tags]    integration    lifecycle    e2e
    ${headers}    Create Admin Session
    ${response}    Get Device    ${LIFECYCLE_DEVICE_ID}    ${headers}    expected_status=404
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error
    Log    Device deletion confirmed
