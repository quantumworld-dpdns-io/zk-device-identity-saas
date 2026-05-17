*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    ../libraries/ZkDeviceLibrary.py
Resource    common.resource

*** Variables ***
${PROOF_ENDPOINT}            /proofs
${VERIFY_ENDPOINT}           /proofs/verify
${CIRCUIT_ENDPOINT}          /circuits
${PROOF_WAIT_MAX_RETRIES}    30
${PROOF_WAIT_INTERVAL}       2s
${CIRCUIT_TYPE_DAC}          dac
${CIRCUIT_TYPE_PAI}          pai
${CIRCUIT_TYPE_PAA}          paa
${CIRCUIT_TYPE_COMPLIANCE}   compliance

*** Keywords ***
Generate ZK Proof
    [Arguments]    ${circuit_type}    ${public_inputs}    ${private_inputs}    ${headers}=${None}    ${expected_status}=202
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${proof_request}    Create Dictionary
    ...    circuit_type=${circuit_type}
    ...    public_inputs=${public_inputs}
    ...    private_inputs=${private_inputs}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${PROOF_ENDPOINT}
    ...    json=${proof_request}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Verify ZK Proof
    [Arguments]    ${proof_data}    ${public_inputs}    ${headers}=${None}    ${expected_status}=200
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${verify_request}    Create Dictionary
    ...    proof=${proof_data}
    ...    public_inputs=${public_inputs}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${VERIFY_ENDPOINT}
    ...    json=${verify_request}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Check Proof Status
    [Arguments]    ${proof_id}    ${headers}=${None}    ${expected_status}=200
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${PROOF_ENDPOINT}/${proof_id}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Wait For Proof Completion
    [Arguments]    ${proof_id}    ${headers}=${None}    ${timeout}=${PROOF_WAIT_MAX_RETRIES}
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    FOR    ${i}    IN RANGE    ${timeout}
        ${response}    Check Proof Status    ${proof_id}    ${headers}
        ${status}    Get From Dictionary    ${response.json()}    status
        IF    "${status}" == "completed"
            RETURN    ${response}
        ELSE IF    "${status}" == "failed"
            Fail    Proof generation failed: ${response.json()}[error]
        END
        Sleep    ${PROOF_WAIT_INTERVAL}
    END
    Fail    Proof did not complete within ${timeout} retries

Generate And Wait For Proof
    [Arguments]    ${circuit_type}    ${public_inputs}    ${private_inputs}    ${headers}=${None}
    ${submit_response}    Generate ZK Proof    ${circuit_type}    ${public_inputs}    ${private_inputs}    ${headers}
    ${proof_id}    Get From Dictionary    ${submit_response.json()}    proof_id
    ${proof_response}    Wait For Proof Completion    ${proof_id}    ${headers}
    RETURN    ${proof_response}

Create Test Circuit
    [Arguments]    ${circuit_name}    ${source_code}    ${headers}=${None}    ${expected_status}=201
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${circuit_data}    Create Dictionary
    ...    name=${circuit_name}
    ...    source=${source_code}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${CIRCUIT_ENDPOINT}
    ...    json=${circuit_data}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Get Standard Device Public Inputs
    [Arguments]    ${device_id}
    ${public_inputs}    Create Dictionary
    ...    device_id=${device_id}
    ...    timestamp=${EMPTY}
    ...    device_type=matter_controller
    RETURN    ${public_inputs}

Get Standard Device Private Inputs
    [Arguments]    ${serial_number}    ${secret_key}=default_secret_key_123
    ${private_inputs}    Create Dictionary
    ...    serial_number=${serial_number}
    ...    secret_key=${secret_key}
    ...    attestation_private_key=test_attestation_private_key
    RETURN    ${private_inputs}
