*** Settings ***
Library    Collections
Library    RequestsLibrary
Resource    ../../resources/common.resource
Resource    ../../resources/api_keywords.resource
Resource    ../../resources/auth_keywords.resource

Suite Setup    Create Tenant Sessions
Suite Teardown    Cleanup CrossTenant Artifacts

*** Variables ***
@{TENANT_A_DEVICES}          ${EMPTY}
@{TENANT_B_DEVICES}          ${EMPTY}

*** Keywords ***
Create Tenant Sessions
    ${headers_a}    Create Tenant Session    ${TENANT_A_EMAIL}    ${TENANT_A_PASSWORD}
    Set Suite Variable    ${TENANT_A_HEADERS}    ${headers_a}
    ${headers_b}    Create Tenant Session    ${TENANT_B_EMAIL}    ${TENANT_B_PASSWORD}
    Set Suite Variable    ${TENANT_B_HEADERS}    ${headers_b}
    ${admin_headers}    Create Admin Session
    Set Suite Variable    ${ADMIN_HEADERS}    ${admin_headers}

Cleanup CrossTenant Artifacts
    FOR    ${dev_id}    IN    @{TENANT_A_DEVICES}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${ADMIN_HEADERS}    expected_status=204
    END
    FOR    ${dev_id}    IN    @{TENANT_B_DEVICES}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${ADMIN_HEADERS}    expected_status=204
    END

Create Device For Tenant A
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=TenantAMfg
    ...    model=TA-MODEL
    ...    firmware_version=1.0.0
    ...    tenant_id=tenant-a
    ${response}    Create Device    ${device_data}    ${TENANT_A_HEADERS}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${TENANT_A_DEVICES}    ${device_id}
    RETURN    ${device_id}

Create Device For Tenant B
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=TenantBMfg
    ...    model=TB-MODEL
    ...    firmware_version=2.0.0
    ...    tenant_id=tenant-b
    ${response}    Create Device    ${device_data}    ${TENANT_B_HEADERS}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${TENANT_B_DEVICES}    ${device_id}
    RETURN    ${device_id}

*** Test Cases ***
Tenant A Cannot See Tenant B Data
    [Documentation]    Verify Tenant A cannot see any of Tenant B's devices
    [Tags]    tenant-isolation    integration    security
    ${tenant_b_device}    Create Device For Tenant B
    ${list_resp}    List Devices    ${TENANT_A_HEADERS}    expected_status=200
    ${json}    Set Variable    ${list_resp.json()}
    ${data}    Get From Dictionary    ${json}    data
    ${ids}    Evaluate    [d["id"] for d in $data if "id" in d]
    Should Not Contain    ${ids}    ${tenant_b_device}
    ${get_resp}    GET
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device}
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=403
    Log    Tenant A correctly cannot access Tenant B device

Tenant B Cannot See Tenant A Data
    [Documentation]    Verify Tenant B cannot see any of Tenant A's devices
    [Tags]    tenant-isolation    integration    security
    ${tenant_a_device}    Create Device For Tenant A
    ${list_resp}    List Devices    ${TENANT_B_HEADERS}    expected_status=200
    ${json}    Set Variable    ${list_resp.json()}
    ${data}    Get From Dictionary    ${json}    data
    ${ids}    Evaluate    [d["id"] for d in $data if "id" in d]
    Should Not Contain    ${ids}    ${tenant_a_device}
    ${get_resp}    GET
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_a_device}
    ...    headers=${TENANT_B_HEADERS}
    ...    expected_status=403
    Log    Tenant B correctly cannot access Tenant A device

Tenant A Cannot Modify Tenant B Data
    [Documentation]    Verify Tenant A cannot modify Tenant B's device
    [Tags]    tenant-isolation    integration    security
    ${tenant_b_device}    Create Device For Tenant B
    ${update_data}    Create Dictionary    device_name=hacked_by_tenant_a
    ${response}    PUT
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device}
    ...    json=${update_data}
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=403
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error
    Log    Tenant A correctly cannot modify Tenant B device

Tenant B Cannot Modify Tenant A Data
    [Documentation]    Verify Tenant B cannot modify Tenant A's device
    [Tags]    tenant-isolation    integration    security
    ${tenant_a_device}    Create Device For Tenant A
    ${update_data}    Create Dictionary    firmware_version=0.0.0
    ${response}    PUT
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_a_device}
    ...    json=${update_data}
    ...    headers=${TENANT_B_HEADERS}
    ...    expected_status=403
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error
    Log    Tenant B correctly cannot modify Tenant A device

Tenant A Cannot Delete Tenant B Data
    [Documentation]    Verify Tenant A cannot delete Tenant B's device
    [Tags]    tenant-isolation    integration    security
    ${tenant_b_device}    Create Device For Tenant B
    ${response}    DELETE
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device}
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=403
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error
    Log    Tenant A correctly cannot delete Tenant B device

Cross Tenant Api Key Rejected
    [Documentation]    Verify an API key created by Tenant A cannot access Tenant B resources
    [Tags]    tenant-isolation    integration    security
    ${key_resp}    POST
    ...    ${BASE_URL}${API_VERSION}/auth/api-keys
    ...    json={"name": "tenant-a-key-${RANDOM}"}
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=201
    ${api_key}    Get From Dictionary    ${key_resp.json()}    api_key
    ${key_headers}    Get Api Key Headers    ${api_key}
    ${tenant_b_device}    Create Device For Tenant B
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device}
    ...    headers=${key_headers}
    ...    expected_status=403
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error
    Log    Cross-tenant API key correctly rejected

Tenant A Cannot Submit Attestation For Tenant B Device
    [Documentation]    Verify Tenant A cannot submit attestation for Tenant B's device
    [Tags]    tenant-isolation    integration    security
    ${tenant_b_device}    Create Device For Tenant B
    ${timestamp}    Get Current Date    result_format=epoch
    ${attest_data}    Create Dictionary
    ...    device_id=${tenant_b_device}
    ...    attestation_type=dac
    ...    certificate_chain=["test-cert"]
    ...    firmware_hash=abc
    ...    timestamp=${timestamp}
    ...    signature=test
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device}/attestations
    ...    json=${attest_data}
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=403
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error
    Log    Cross-tenant attestation correctly rejected

Admin Can See All Tenant Data
    [Documentation]    Verify admin can access all tenant devices
    [Tags]    tenant-isolation    integration    admin
    ${tenant_a_device}    Create Device For Tenant A
    ${tenant_b_device}    Create Device For Tenant B
    ${admin_resp}    GET
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_a_device}
    ...    headers=${ADMIN_HEADERS}
    ...    expected_status=200
    ${admin_resp2}    GET
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device}
    ...    headers=${ADMIN_HEADERS}
    ...    expected_status=200
    Log    Admin correctly accesses both tenant devices

Tenant A Cannot Access Tenant B Attestations
    [Documentation]    Verify Tenant A cannot access Tenant B's attestations
    [Tags]    tenant-isolation    integration    security
    ${tenant_b_device}    Create Device For Tenant B
    ${timestamp}    Get Current Date    result_format=epoch
    ${attest_data}    Create Dictionary
    ...    device_id=${tenant_b_device}
    ...    attestation_type=dac
    ...    certificate_chain=["test-cert"]
    ...    firmware_hash=abc
    ...    timestamp=${timestamp}
    ...    signature=test
    ${attest_resp}    POST
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device}/attestations
    ...    json=${attest_data}
    ...    headers=${TENANT_B_HEADERS}
    ...    expected_status=201
    ${attest_id}    Get From Dictionary    ${attest_resp.json()}    id
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device}/attestations
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=403
    Log    Cross-tenant attestation access correctly blocked
