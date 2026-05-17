*** Settings ***
Library    Collections
Library    RequestsLibrary
Resource    ../../../resources/common.resource
Resource    ../../../resources/api_keywords.resource
Resource    ../../../resources/auth_keywords.resource

Suite Setup    Create Sessions
Suite Teardown    Cleanup Access Control Artifacts

*** Variables ***
@{TENANT_A_DEVICES}          ${EMPTY}
@{TENANT_B_DEVICES}          ${EMPTY}

*** Keywords ***
Create Sessions
    Create Session    unauth    ${BASE_URL}
    ${headers_a}    Create Tenant Session    ${TENANT_A_EMAIL}    ${TENANT_A_PASSWORD}
    Set Suite Variable    ${TENANT_A_HEADERS}    ${headers_a}
    ${headers_b}    Create Tenant Session    ${TENANT_B_EMAIL}    ${TENANT_B_PASSWORD}
    Set Suite Variable    ${TENANT_B_HEADERS}    ${headers_b}
    ${admin_headers}    Create Admin Session
    Set Suite Variable    ${ADMIN_HEADERS}    ${admin_headers}

Cleanup Access Control Artifacts
    FOR    ${dev_id}    IN    @{TENANT_A_DEVICES}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${ADMIN_HEADERS}    expected_status=204
    END
    FOR    ${dev_id}    IN    @{TENANT_B_DEVICES}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${ADMIN_HEADERS}    expected_status=204
    END

Create Tenant A Device
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=TenantAInc
    ...    model=TA-100
    ...    firmware_version=1.0.0
    ...    tenant_id=tenant-a
    ${response}    Create Device    ${device_data}    ${TENANT_A_HEADERS}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${TENANT_A_DEVICES}    ${device_id}
    RETURN    ${device_id}

Create Tenant B Device
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=TenantBInc
    ...    model=TB-200
    ...    firmware_version=2.0.0
    ...    tenant_id=tenant-b
    ${response}    Create Device    ${device_data}    ${TENANT_B_HEADERS}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${TENANT_B_DEVICES}    ${device_id}
    RETURN    ${device_id}

*** Test Cases ***
Tenant A Cannot Access Tenant B Devices
    [Documentation]    Verify tenant isolation: Tenant A cannot read Tenant B's devices
    [Tags]    owasp    A01    access-control    tenant-isolation    security
    ${tenant_b_device_id}    Create Tenant B Device
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device_id}
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=403
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Regular User Cannot Access Admin Endpoints
    [Documentation]    Verify non-admin users cannot access admin-only endpoints
    [Tags]    owasp    A01    access-control    privilege-escalation    security
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/admin/users
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=403
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Unauthenticated Access To Protected Endpoints Returns 401
    [Documentation]    Verify unauthenticated requests to protected endpoints are rejected
    [Tags]    owasp    A01    access-control    unauthenticated    security
    ${response}    GET    ${BASE_URL}${API_VERSION}/devices    expected_status=401
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Unauthenticated Device Creation Returns 401
    [Documentation]    Verify device creation without auth header is rejected
    [Tags]    owasp    A01    access-control    unauthenticated    security
    ${device_data}    Create Dictionary
    ...    serial_number=UNAUTH-TEST
    ...    device_type=matter_controller
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    json=${device_data}
    ...    expected_status=401

Idor Attempt Access Device By Incrementing Ids
    [Documentation]    Verify IDOR protection: sequential IDs cannot be used to access other tenants' devices
    [Tags]    owasp    A01    idor    access-control    security
    ${tenant_a_device_id}    Create Tenant A Device
    ${numeric_part}    Evaluate    "".join([c for c in "${tenant_a_device_id}" if c.isdigit()]) or "0"
    ${guess_id}    Evaluate    str(int("${numeric_part}") + 1) if "${numeric_part}" else "9999"
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/devices/${guess_id}
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=404

Forceful Browsing To Admin Endpoints Returns 403
    [Documentation]    Verify admin-only paths are inaccessible to regular users
    [Tags]    owasp    A01    forceful-browsing    security
    ${admin_paths}    Create List
    ...    ${BASE_URL}/admin
    ...    ${BASE_URL}/admin/dashboard
    ...    ${BASE_URL}${API_VERSION}/admin
    ...    ${BASE_URL}${API_VERSION}/admin/config
    ...    ${BASE_URL}/administrator
    ...    ${BASE_URL}/manage
    FOR    ${path}    IN    @{admin_paths}
        ${response}    GET    ${path}    headers=${TENANT_A_HEADERS}    expected_status=403
        Log    Path ${path} correctly returned 403
    END

Tenant A Cannot Delete Tenant B Device
    [Documentation]    Verify Tenant A cannot delete Tenant B's device
    [Tags]    owasp    A01    access-control    tenant-isolation    security
    ${tenant_b_device_id}    Create Tenant B Device
    ${response}    DELETE
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device_id}
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=403

Tenant A Cannot Update Tenant B Device
    [Documentation]    Verify Tenant A cannot modify Tenant B's device
    [Tags]    owasp    A01    access-control    tenant-isolation    security
    ${tenant_b_device_id}    Create Tenant B Device
    ${update_data}    Create Dictionary    firmware_version=hacked
    ${response}    PUT
    ...    ${BASE_URL}${API_VERSION}/devices/${tenant_b_device_id}
    ...    json=${update_data}
    ...    headers=${TENANT_A_HEADERS}
    ...    expected_status=403

Tenant A Cannot List Tenant B Devices
    [Documentation]    Verify Tenant A's device list does not include Tenant B devices
    [Tags]    owasp    A01    access-control    tenant-isolation    security
    ${tenant_b_device_id}    Create Tenant B Device
    ${response}    List Devices    ${TENANT_A_HEADERS}    expected_status=200
    ${json}    Set Variable    ${response.json()}
    ${data}    Get From Dictionary    ${json}    data
    ${ids}    Evaluate    [d["id"] for d in $data if "id" in d]
    Should Not Contain    ${ids}    ${tenant_b_device_id}

Access Control On Proof Endpoints
    [Documentation]    Verify proof endpoints enforce access control
    [Tags]    owasp    A01    access-control    security
    ${unauth_response}    POST
    ...    ${BASE_URL}${API_VERSION}/proofs
    ...    json={}
    ...    expected_status=401
    ${json}    Set Variable    ${unauth_response.json()}
    Dictionary Should Contain Key    ${json}    error
