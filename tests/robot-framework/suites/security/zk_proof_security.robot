*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    ../../../libraries/ZkDeviceLibrary.py
Resource    ../../resources/common.resource
Resource    ../../resources/api_keywords.resource
Resource    ../../resources/zk_keywords.resource

Suite Setup    Create Admin Session
Suite Teardown    Cleanup ZkTest Devices

*** Variables ***
@{ZK_DEVICE_IDS}             ${EMPTY}

*** Keywords ***
Cleanup ZkTest Devices
    ${headers}    Create Admin Session
    FOR    ${dev_id}    IN    @{ZK_DEVICE_IDS}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${headers}    expected_status=204
    END

Setup Device For ZkTest
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=ZKSecurity
    ...    model=ZK-PROOF
    ...    firmware_version=1.0.0
    ...    tenant_id=tenant-a
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${ZK_DEVICE_IDS}    ${device_id}
    RETURN    ${device_id}

Get ZkPublicInputs
    [Arguments]    ${device_id}
    ${timestamp}    Get Current Date    result_format=epoch
    ${public_inputs}    Create Dictionary
    ...    device_id=${device_id}
    ...    timestamp=${timestamp}
    ...    device_type=matter_controller
    ...    firmware_version=1.0.0
    RETURN    ${public_inputs}

Get ZkPrivateInputs
    [Arguments]    ${device_id}
    ${private_inputs}    Create Dictionary
    ...    serial_number=SN-${device_id}
    ...    secret_key=zk_test_secret_${RANDOM}
    ...    attestation_key=attest_key_789
    RETURN    ${private_inputs}

*** Test Cases ***
Replay Attack Same Proof Rejected Twice
    [Documentation]    Verify the same ZK proof cannot be verified twice (replay protection)
    [Tags]    zk    security    replay    proof    security
    ${device_id}    Setup Device For ZkTest
    ${public_inputs}    Get ZkPublicInputs    ${device_id}
    ${private_inputs}    Get ZkPrivateInputs    ${device_id}
    ${headers}    Create Admin Session
    ${proof_resp}    Generate And Wait For Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}
    ${proof_data}    Get From Dictionary    ${proof_resp.json()}    proof
    ${first_verify}    Verify ZK Proof    ${proof_data}    ${public_inputs}    ${headers}    expected_status=200
    ${second_verify}    Verify ZK Proof    ${proof_data}    ${public_inputs}    ${headers}    expected_status=400
    ${json}    Set Variable    ${second_verify.json()}
    Dictionary Should Contain Key    ${json}    error
    ${error}    Get From Dictionary    ${json}    error
    Should Contain    ${error}    replay    Replay attack not detected!

Proof With Wrong Public Inputs Rejected
    [Documentation]    Verify proof with mismatched public inputs is rejected
    [Tags]    zk    security    proof    public-inputs    security
    ${device_id}    Setup Device For ZkTest
    ${public_inputs}    Get ZkPublicInputs    ${device_id}
    ${private_inputs}    Get ZkPrivateInputs    ${device_id}
    ${headers}    Create Admin Session
    ${proof_resp}    Generate And Wait For Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}
    ${proof_data}    Get From Dictionary    ${proof_resp.json()}    proof
    ${wrong_public_inputs}    Create Dictionary
    ...    device_id=wrong-device
    ...    timestamp=0
    ...    device_type=attacker
    ...    firmware_version=0.0.0
    ${verify_resp}    Verify ZK Proof    ${proof_data}    ${wrong_public_inputs}    ${headers}    expected_status=400
    ${json}    Set Variable    ${verify_resp.json()}
    Dictionary Should Contain Key    ${json}    error

Proof With Tampered Proof Data Rejected
    [Documentation]    Verify proof with corrupted proof data is rejected
    [Tags]    zk    security    proof    tampering    security
    ${device_id}    Setup Device For ZkTest
    ${public_inputs}    Get ZkPublicInputs    ${device_id}
    ${private_inputs}    Get ZkPrivateInputs    ${device_id}
    ${headers}    Create Admin Session
    ${proof_resp}    Generate And Wait For Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}
    ${proof_data}    Get From Dictionary    ${proof_resp.json()}    proof
    ${tampered}    Evaluate    ${proof_data}[0:10] + "TAMPER" + ${proof_data}[10:]
    ${verify_resp}    Verify ZK Proof    ${tampered}    ${public_inputs}    ${headers}    expected_status=400
    ${json}    Set Variable    ${verify_resp.json()}
    Dictionary Should Contain Key    ${json}    error

Under Constrained Circuit Detection
    [Documentation]    Verify under-constrained circuits (missing constraints) are rejected
    [Tags]    zk    security    circuit    constraints    security
    ${headers}    Create Admin Session
    ${under_constrained_code}    Set Variable    fn main(x: Field, y: Field) -> pub Field { x + y }
    ${response}    Create Test Circuit    under_constrained_test    ${under_constrained_code}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Private Input Leakage Check
    [Documentation]    Verify public proof outputs do not reveal private inputs
    [Tags]    zk    security    privacy    input-leakage    security
    ${device_id}    Setup Device For ZkTest
    ${private_secret}    Set Variable    super_secret_private_value_${RANDOM}
    ${public_inputs}    Get ZkPublicInputs    ${device_id}
    ${private_inputs}    Create Dictionary
    ...    serial_number=SN-${device_id}
    ...    secret_key=${private_secret}
    ...    attestation_key=secret_attest_key
    ${headers}    Create Admin Session
    ${proof_resp}    Generate And Wait For Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}
    ${proof_json}    Set Variable    ${proof_resp.json()}
    ${proof_str}    Evaluate    str(${proof_json})
    Should Not Contain    ${proof_str}    ${private_secret}
    Should Not Contain    ${proof_str}    super_secret
    Should Not Contain    ${proof_str}    secret_attest_key

Proof With Invalid Circuit Type Rejected
    [Documentation]    Verify unsupported circuit types are rejected
    [Tags]    zk    security    circuit    validation    security
    ${headers}    Create Admin Session
    ${response}    Generate ZK Proof    nonexistent_circuit    {}    {}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Proof With Empty Public Inputs For Required Circuit Rejected
    [Documentation]    Verify circuits requiring public inputs reject empty input
    [Tags]    zk    security    circuit    input-validation    security
    ${device_id}    Setup Device For ZkTest
    ${headers}    Create Admin Session
    ${response}    Generate ZK Proof    ${CIRCUIT_TYPE_DAC}    {}    {"test": "data"}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Cross Circuit Proof Verification Rejected
    [Documentation]    Verify proof from one circuit cannot verify against another circuit
    [Tags]    zk    security    circuit    cross-circuit    security
    ${device_id}    Setup Device For ZkTest
    ${public_inputs}    Get ZkPublicInputs    ${device_id}
    ${private_inputs}    Get ZkPrivateInputs    ${device_id}
    ${headers}    Create Admin Session
    ${dac_proof}    Generate And Wait For Proof    ${CIRCUIT_TYPE_DAC}    ${public_inputs}    ${private_inputs}    ${headers}
    ${proof_data}    Get From Dictionary    ${dac_proof.json()}    proof
    ${pai_public}    Create Dictionary    device_id=${device_id}    compliance_check=true
    ${verify_resp}    POST
    ...    ${BASE_URL}${API_VERSION}/proofs/verify
    ...    json={"proof": ${proof_data}, "public_inputs": ${pai_public}, "circuit_type": "${CIRCUIT_TYPE_PAI}"}
    ...    headers=${headers}
    ...    expected_status=400
    ${json}    Set Variable    ${verify_resp.json()}
    Dictionary Should Contain Key    ${json}    error
