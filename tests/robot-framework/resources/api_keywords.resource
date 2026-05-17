*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    ../libraries/ZkDeviceLibrary.py
Resource    common.resource

*** Variables ***
${DEVICE_ENDPOINT}           /devices
${ATTESTATION_ENDPOINT}      /attestations
${PROOF_ENDPOINT}            /proofs
${COMPLIANCE_ENDPOINT}       /compliance
${CERTIFICATE_ENDPOINT}      /certificates

*** Keywords ***
Create Device
    [Arguments]    ${device_data}    ${headers}=${None}    ${expected_status}=201
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${DEVICE_ENDPOINT}
    ...    json=${device_data}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Get Device
    [Arguments]    ${device_id}    ${headers}=${None}    ${expected_status}=200
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${DEVICE_ENDPOINT}/${device_id}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

List Devices
    [Arguments]    ${headers}=${None}    ${expected_status}=200    ${params}=${None}
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${DEVICE_ENDPOINT}
    ...    headers=${headers}
    ...    params=${params}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Update Device
    [Arguments]    ${device_id}    ${update_data}    ${headers}=${None}    ${expected_status}=200
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    PUT
    ...    ${BASE_URL}${API_VERSION}${DEVICE_ENDPOINT}/${device_id}
    ...    json=${update_data}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Delete Device
    [Arguments]    ${device_id}    ${headers}=${None}    ${expected_status}=204
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    DELETE
    ...    ${BASE_URL}${API_VERSION}${DEVICE_ENDPOINT}/${device_id}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Submit Attestation
    [Arguments]    ${device_id}    ${attestation_data}    ${headers}=${None}    ${expected_status}=201
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${DEVICE_ENDPOINT}/${device_id}${ATTESTATION_ENDPOINT}
    ...    json=${attestation_data}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Get Attestation Status
    [Arguments]    ${device_id}    ${attestation_id}    ${headers}=${None}    ${expected_status}=200
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${DEVICE_ENDPOINT}/${device_id}${ATTESTATION_ENDPOINT}/${attestation_id}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

List Device Attestations
    [Arguments]    ${device_id}    ${headers}=${None}    ${expected_status}=200
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${DEVICE_ENDPOINT}/${device_id}${ATTESTATION_ENDPOINT}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Generate Proof
    [Arguments]    ${proof_request}    ${headers}=${None}    ${expected_status}=202
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${PROOF_ENDPOINT}
    ...    json=${proof_request}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Verify Proof
    [Arguments]    ${proof_data}    ${headers}=${None}    ${expected_status}=200
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${PROOF_ENDPOINT}/verify
    ...    json=${proof_data}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Check Compliance
    [Arguments]    ${device_id}    ${headers}=${None}    ${expected_status}=200
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${COMPLIANCE_ENDPOINT}/devices/${device_id}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Submit Certificate
    [Arguments]    ${device_id}    ${cert_data}    ${headers}=${None}    ${expected_status}=201
    IF    ${headers} == ${None}
        ${headers}    Create Admin Session
    END
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${DEVICE_ENDPOINT}/${device_id}${CERTIFICATE_ENDPOINT}
    ...    json=${cert_data}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Load Test Device Data
    [Arguments]    ${index}=0
    ${data_file}    Get File    ${CURDIR}/../data/test_devices.json
    ${devices}    Evaluate    json.loads($data_file)    json
    ${device}    Set Variable    ${devices}[${index}]
    RETURN    ${device}
