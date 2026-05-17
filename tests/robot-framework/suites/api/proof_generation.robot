*** Settings ***
Library    Collections
Library    RequestsLibrary
Resource    ../../resources/common.resource
Resource    ../../resources/api_keywords.resource
Resource    ../../resources/zk_keywords.resource

Suite Setup    Create Admin Session
Suite Teardown    Cleanup Proof Test Artifacts

*** Variables ***
@{TEST_DEVICE_IDS}           ${EMPTY}

*** Keywords ***
Cleanup Proof Test Artifacts
    ${headers}    Create Admin Session
    FOR    ${dev_id}    IN    @{TEST_DEVICE_IDS}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${headers}    expected_status=204
    END
    Log    Cleaned up proof test artifacts

Create Device For Proof Tests
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=ProofTest
    ...    model=PROOF-2000
    ...    firmware_version=1.0.0
    ...    tenant_id=tenant-a
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${TEST_DEVICE_IDS}    ${device_id}
    RETURN    ${device_id}

Get Sample Public Inputs
    [Arguments]    ${device_id}
    ${timestamp}    Get Current Date    result_format=epoch
    ${public_inputs}    Create Dictionary
    ...    device_id=${device_id}
    ...    timestamp=${timestamp}
    ...    device_type=matter_controller
    ...    firmware_version=1.0.0
    RETURN    ${public_inputs}

Get Sample Private Inputs
    [Arguments]    ${device_id}
    ${private_inputs}    Create Dictionary
    ...    serial_number=SN-${device_id}
    ...    secret_key=test_secret_key_for_proof
    ...    attestation_key=attest_key_abc123
    ...    dac_private_key=dac_private_key_xyz
    RETURN    ${private_inputs}

*** Test Cases ***
Generate Proof With Valid Inputs Returns 202
    [Documentation]    Verify proof generation is accepted asynchronously
    [Tags]    proof    zk    smoke    api
    ${device_id}    Create Device For Proof Tests
    ${public_inputs}    Get Sample Public Inputs    ${device_id}
    ${private_inputs}    Get Sample Private Inputs    ${device_id}
    ${headers}    Create Admin Session
    ${response}    Generate ZK Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}    expected_status=202
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    proof_id
    Dictionary Should Contain Key    ${json}    status
    ${status}    Get From Dictionary    ${json}    status
    Should Be Equal    ${status}    processing

Generate Proof With Invalid Circuit Name Returns 400
    [Documentation]    Verify invalid circuit name is rejected
    [Tags]    proof    zk    validation    api
    ${public_inputs}    Get Sample Public Inputs    test-device
    ${private_inputs}    Get Sample Private Inputs    test-device
    ${headers}    Create Admin Session
    ${response}    Generate ZK Proof    invalid_circuit    ${public_inputs}    ${private_inputs}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Generate Proof With Missing Public Inputs Returns 400
    [Documentation]    Verify proof without public inputs is rejected
    [Tags]    proof    zk    validation    api
    ${headers}    Create Admin Session
    ${proof_request}    Create Dictionary
    ...    circuit_type=${CIRCUIT_TYPE_DAC}
    ...    private_inputs={}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${PROOF_ENDPOINT}
    ...    json=${proof_request}
    ...    headers=${headers}
    ...    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Generate Proof With Empty Private Inputs Returns 400
    [Documentation]    Verify proof without private inputs is rejected
    [Tags]    proof    zk    validation    api
    ${headers}    Create Admin Session
    ${public_inputs}    Get Sample Public Inputs    test-device
    ${proof_request}    Create Dictionary
    ...    circuit_type=${CIRCUIT_TYPE_DAC}
    ...    public_inputs=${public_inputs}
    ...    private_inputs={}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${PROOF_ENDPOINT}
    ...    json=${proof_request}
    ...    headers=${headers}
    ...    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Verify Valid Proof Returns 200
    [Documentation]    Verify proof verification succeeds for a valid proof
    [Tags]    proof    zk    smoke    api
    ${device_id}    Create Device For Proof Tests
    ${public_inputs}    Get Sample Public Inputs    ${device_id}
    ${private_inputs}    Get Sample Private Inputs    ${device_id}
    ${headers}    Create Admin Session
    ${generate_resp}    Generate And Wait For Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}
    ${proof_data}    Get From Dictionary    ${generate_resp.json()}    proof
    ${verify_resp}    Verify ZK Proof    ${proof_data}    ${public_inputs}    ${headers}    expected_status=200
    ${json}    Set Variable    ${verify_resp.json()}
    Dictionary Should Contain Key    ${json}    verified
    ${verified}    Get From Dictionary    ${json}    verified
    Should Be Equal    ${verified}    ${TRUE}

Verify Tampered Proof Returns 400
    [Documentation]    Verify a tampered proof is rejected
    [Tags]    proof    zk    security    api
    ${device_id}    Create Device For Proof Tests
    ${public_inputs}    Get Sample Public Inputs    ${device_id}
    ${private_inputs}    Get Sample Private Inputs    ${device_id}
    ${headers}    Create Admin Session
    ${generate_resp}    Generate And Wait For Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}
    ${proof_data}    Get From Dictionary    ${generate_resp.json()}    proof
    ${tampered_proof}    Evaluate    ${proof_data} + "tampered"
    ${verify_resp}    Verify ZK Proof    ${tampered_proof}    ${public_inputs}    ${headers}    expected_status=400
    ${json}    Set Variable    ${verify_resp.json()}
    Dictionary Should Contain Key    ${json}    error

Verify Proof With Wrong Public Inputs Returns 400
    [Documentation]    Verify proof with incorrect public inputs is rejected
    [Tags]    proof    zk    security    api
    ${device_id}    Create Device For Proof Tests
    ${public_inputs}    Get Sample Public Inputs    ${device_id}
    ${private_inputs}    Get Sample Private Inputs    ${device_id}
    ${headers}    Create Admin Session
    ${generate_resp}    Generate And Wait For Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}
    ${proof_data}    Get From Dictionary    ${generate_resp.json()}    proof
    ${wrong_inputs}    Get Sample Public Inputs    wrong-device-id
    ${verify_resp}    Verify ZK Proof    ${proof_data}    ${wrong_inputs}    ${headers}    expected_status=400
    ${json}    Set Variable    ${verify_resp.json()}
    Dictionary Should Contain Key    ${json}    error

Generate Pai Circuit Proof Returns 202
    [Documentation]    Verify PAI circuit proof generation is accepted
    [Tags]    proof    zk    api
    ${device_id}    Create Device For Proof Tests
    ${public_inputs}    Get Sample Public Inputs    ${device_id}
    ${private_inputs}    Get Sample Private Inputs    ${device_id}
    ${headers}    Create Admin Session
    ${response}    Generate ZK Proof    ${CIRCUIT_TYPE_PAI}    ${public_inputs}    ${private_inputs}    ${headers}    expected_status=202
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    proof_id

Check Proof Status Returns Processing Or Completed
    [Documentation]    Verify proof status endpoint returns current state
    [Tags]    proof    zk    api
    ${device_id}    Create Device For Proof Tests
    ${public_inputs}    Get Sample Public Inputs    ${device_id}
    ${private_inputs}    Get Sample Private Inputs    ${device_id}
    ${headers}    Create Admin Session
    ${submit_resp}    Generate ZK Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}    expected_status=202
    ${proof_id}    Get From Dictionary    ${submit_resp.json()}    proof_id
    ${status_resp}    Check Proof Status    ${proof_id}    ${headers}    expected_status=200
    ${json}    Set Variable    ${status_resp.json()}
    Dictionary Should Contain Key    ${json}    status
    ${status}    Get From Dictionary    ${json}    status
    Should Be True    "${status}" in ["processing", "completed", "failed"]
