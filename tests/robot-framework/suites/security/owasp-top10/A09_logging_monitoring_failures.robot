*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    DateTime
Resource    ../../../resources/common.resource
Resource    ../../../resources/api_keywords.resource
Resource    ../../../resources/auth_keywords.resource

Suite Setup    Create Admin Session
Suite Teardown    Cleanup Logging Test Devices

*** Variables ***
@{LOGGING_DEVICE_IDS}        ${EMPTY}

*** Keywords ***
Cleanup Logging Test Devices
    ${headers}    Create Admin Session
    FOR    ${dev_id}    IN    @{LOGGING_DEVICE_IDS}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${headers}    expected_status=204
    END

Create Device For Logging Test
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=LoggingTest
    ...    model=LOG-500
    ...    firmware_version=1.0.0
    ...    tenant_id=tenant-a
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${LOGGING_DEVICE_IDS}    ${device_id}
    RETURN    ${device_id}

*** Test Cases ***
Security Events Are Logged
    [Documentation]    Verify security events are captured in audit logs
    [Tags]    owasp    A09    logging    audit    security
    ${headers}    Create Admin Session
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${AUDIT_LOG_ENDPOINT}
    ...    headers=${headers}
    ...    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    logs
    ${logs}    Get From Dictionary    ${json}    logs
    Should Not Be Empty    ${logs}

Repeated Auth Failures Generate Alerts
    [Documentation]    Verify repeated failed auth attempts appear in audit logs
    [Tags]    owasp    A09    logging    auth    monitoring    security
    ${test_email}    Set Variable    alert-test-${RANDOM}@test.com
    Register    ${test_email}    TestPass123!    expected_status=201
    FOR    ${i}    IN RANGE    5
        Login    ${test_email}    WrongPass!    expected_status=401
    END
    ${headers}    Create Admin Session
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${AUDIT_LOG_ENDPOINT}
    ...    headers=${headers}
    ...    params={"filter": "auth_failure", "email": "${test_email}"}
    ...    expected_status=200
    ${json}    Set Variable    ${response.json()}
    ${logs}    Get From Dictionary    ${json}    logs
    ${failure_logs}    Evaluate    [log for log in $logs if "auth" in str(log).lower() or "fail" in str(log).lower()]
    Length Should Be Greater Than    ${failure_logs}    0

Sensitive Data Not In Logs
    [Documentation]    Verify sensitive data like passwords are not logged
    [Tags]    owasp    A09    logging    sensitive-data    security
    ${headers}    Create Admin Session
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${AUDIT_LOG_ENDPOINT}
    ...    headers=${headers}
    ...    params={"filter": "recent"}
    ...    expected_status=200
    ${json}    Set Variable    ${response.json()}
    ${body_str}    Evaluate    str(${json})
    Should Not Contain    ${body_str}    ${ADMIN_PASSWORD}
    Should Not Contain    ${body_str.lower()}    password=

No Pii Leakage In Error Responses
    [Documentation]    Verify error responses do not leak PII
    [Tags]    owasp    A09    logging    pii    privacy    security
    ${headers}    Create Admin Session
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/devices/nonexistent-id-12345
    ...    headers=${headers}
    ...    expected_status=404
    ${body_str}    Evaluate    str(${response.json()})
    Should Not Contain    ${body_str}    email
    Should Not Contain    ${body_str}    ssn
    Should Not Contain    ${body_str}    credit
    Should Not Contain    ${body_str}    phone

Audit Trail For Device Creation
    [Documentation]    Verify device creation is recorded in audit logs
    [Tags]    owasp    A09    logging    audit    device    security
    ${headers}    Create Admin Session
    ${device_id}    Create Device For Logging Test
    ${audit_resp}    GET
    ...    ${BASE_URL}${API_VERSION}${AUDIT_LOG_ENDPOINT}
    ...    headers=${headers}
    ...    params={"filter": "device_created", "device_id": "${device_id}"}
    ...    expected_status=200
    ${json}    Set Variable    ${audit_resp.json()}
    ${logs}    Get From Dictionary    ${json}    logs
    ${create_logs}    Evaluate    [log for log in $logs if "create" in str(log).lower() or "device" in str(log).lower()]
    Length Should Be Greater Than    ${create_logs}    0

Audit Trail For Device Deletion
    [Documentation]    Verify device deletion is recorded in audit logs
    [Tags]    owasp    A09    logging    audit    device    security
    ${headers}    Create Admin Session
    ${device_id}    Create Device For Logging Test
    Delete Device    ${device_id}    ${headers}    expected_status=204
    ${audit_resp}    GET
    ...    ${BASE_URL}${API_VERSION}${AUDIT_LOG_ENDPOINT}
    ...    headers=${headers}
    ...    params={"filter": "device_deleted", "device_id": "${device_id}"}
    ...    expected_status=200
    ${json}    Set Variable    ${audit_resp.json()}
    ${logs}    Get From Dictionary    ${json}    logs
    ${delete_logs}    Evaluate    [log for log in $logs if "delet" in str(log).lower()]
    Length Should Be Greater Than    ${delete_logs}    0

Audit Log Includes Timestamp
    [Documentation]    Verify audit log entries include timestamps
    [Tags]    owasp    A09    logging    audit    security
    ${headers}    Create Admin Session
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${AUDIT_LOG_ENDPOINT}
    ...    headers=${headers}
    ...    params={"limit": 1}
    ...    expected_status=200
    ${json}    Set Variable    ${response.json()}
    ${logs}    Get From Dictionary    ${json}    logs
    ${first_log}    Get From List    ${logs}    0
    Dictionary Should Contain Key    ${first_log}    timestamp
    Dictionary Should Contain Key    ${first_log}    action
    Dictionary Should Contain Key    ${first_log}    user_id

Audit Log Does Not Expose Tokens
    [Documentation]    Verify audit logs do not contain JWT or API tokens
    [Tags]    owasp    A09    logging    sensitive-data    security
    ${headers}    Create Admin Session
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}${AUDIT_LOG_ENDPOINT}
    ...    headers=${headers}
    ...    expected_status=200
    ${json}    Set Variable    ${response.json()}
    ${body_str}    Evaluate    str(${json})
    ${token_pattern}    Evaluate    "access_token" in "${body_str}" or "refresh_token" in "${body_str}"
    Should Not Be True    ${token_pattern}    Audit logs contain token data!
