*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    ../../../libraries/SecurityTestLibrary.py
Resource    ../../../resources/common.resource
Resource    ../../../resources/api_keywords.resource
Resource    ../../../resources/auth_keywords.resource

Suite Setup    Create Admin Session
Suite Teardown    Cleanup Ssrf Test Devices

*** Variables ***
@{SSRF_DEVICE_IDS}           ${EMPTY}

*** Keywords ***
Cleanup Ssrf Test Devices
    ${headers}    Create Admin Session
    FOR    ${dev_id}    IN    @{SSRF_DEVICE_IDS}
        Run Keyword And Ignore Error    Delete Device    ${dev_id}    ${headers}    expected_status=204
    END

*** Test Cases ***
Device Registration Url Field Rejects Localhost
    [Documentation]    Verify 127.0.0.1 is blocked in URL fields
    [Tags]    owasp    A10    ssrf    security
    ${headers}    Create Admin Session
    ${url_payloads}    Create List
    ...    http://127.0.0.1:8080/admin
    ...    http://127.0.0.1:5432
    ...    https://127.0.0.1:443
    ...    http://127.0.0.1
    FOR    ${url}    IN    @{url_payloads}
        ${serial}    Generate Unique Device Serial
        ${device_data}    Create Dictionary
        ...    serial_number=${serial}
        ...    device_type=matter_controller
        ...    manufacturer=SSRFTest
        ...    model=Test
        ...    firmware_version=1.0.0
        ...    provisioning_url=${url}
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
        ${json}    Set Variable    ${response.json()}
        Dictionary Should Contain Key    ${json}    error
        Log    localhost URL ${url} correctly rejected
    END

Device Registration Url Field Rejects Private Ips
    [Documentation]    Verify private IP ranges are blocked in URL fields
    [Tags]    owasp    A10    ssrf    security
    ${headers}    Create Admin Session
    ${private_ips}    Create List
    ...    http://10.0.0.1/admin
    ...    http://10.0.0.1:8080
    ...    http://10.0.0.1:443
    ...    http://10.0.0.1
    ...    http://172.16.0.1
    ...    http://172.31.255.255
    ...    http://192.168.0.1
    ...    http://192.168.1.1
    ...    http://10.10.10.10
    FOR    ${url}    IN    @{private_ips}
        ${internal}    Is Internal Ip    ${url}
        IF    ${internal}
            ${serial}    Generate Unique Device Serial
            ${device_data}    Create Dictionary
            ...    serial_number=${serial}
            ...    device_type=matter_controller
            ...    manufacturer=SSRFTest
            ...    model=Test
            ...    firmware_version=1.0.0
            ...    provisioning_url=${url}
            ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
            ${json}    Set Variable    ${response.json()}
            Dictionary Should Contain Key    ${json}    error
            Log    Private IP URL ${url} correctly rejected
        END
    END

Cloud Metadata Endpoint Access Blocked
    [Documentation]    Verify cloud metadata IP 169.254.169.254 is blocked
    [Tags]    owasp    A10    ssrf    cloud-metadata    security
    ${headers}    Create Admin Session
    ${metadata_urls}    Create List
    ...    http://169.254.169.254/latest/meta-data/
    ...    http://169.254.169.254/latest/user-data/
    ...    http://169.254.169.254/metadata/instance?api-version=2021-02-01
    ...    http://169.254.169.254
    FOR    ${url}    IN    @{metadata_urls}
        ${serial}    Generate Unique Device Serial
        ${device_data}    Create Dictionary
        ...    serial_number=${serial}
        ...    device_type=matter_controller
        ...    manufacturer=SSRFTest
        ...    model=Test
        ...    firmware_version=1.0.0
        ...    provisioning_url=${url}
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
        ${json}    Set Variable    ${response.json()}
        Dictionary Should Contain Key    ${json}    error
        Log    Metadata URL ${url} correctly rejected
    END

Url Validation On Provisioning Endpoints
    [Documentation]    Verify URL validation on provisioning endpoints
    [Tags]    owasp    A10    ssrf    url-validation    security
    ${headers}    Create Admin Session
    ${invalid_urls}    Create List
    ...    file:///etc/passwd
    ...    file:///etc/shadow
    ...    file:///proc/self/environ
    ...    file://localhost/etc/passwd
    ...    gopher://127.0.0.1:6379
    ...    dict://127.0.0.1:6379
    ...    ftp://evil.com
    ...    ldap://127.0.0.1:389
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=SSRFTest
    ...    model=Test
    ...    firmware_version=1.0.0
    ...    provisioning_url=${invalid_urls}[0]
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Dns Rebinding Protection
    [Documentation]    Verify DNS rebinding-like hostnames are blocked
    [Tags]    owasp    A10    ssrf    dns-rebinding    security
    ${headers}    Create Admin Session
    ${dns_rebinding}    Create List
    ...    http://127.0.0.1.nip.io/
    ...    http://1.2.3.4.xip.io/
    ...    http://localhost.xyz
    FOR    ${url}    IN    @{dns_rebinding}
        ${serial}    Generate Unique Device Serial
        ${device_data}    Create Dictionary
        ...    serial_number=${serial}
        ...    device_type=matter_controller
        ...    manufacturer=SSRFTest
        ...    model=Test
        ...    firmware_version=1.0.0
        ...    provisioning_url=${url}
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
        Log    DNS rebinding URL ${url} correctly rejected or sanitized
    END

Redirect Following Prevention
    [Documentation]    Verify SSRF via redirect is prevented
    [Tags]    owasp    A10    ssrf    redirect    security
    ${headers}    Create Admin Session
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=SSRFTest
    ...    model=Test
    ...    firmware_version=1.0.0
    ...    provisioning_url=http://evil.com/redirect?target=http://169.254.169.254
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=400
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Url Scheme Validation
    [Documentation]    Verify only allowed URL schemes are accepted
    [Tags]    owasp    A10    ssrf    url-scheme    security
    ${headers}    Create Admin Session
    ${allowed_scheme_url}    Create Dictionary
    ...    serial_number=SCHEME-TEST-${RANDOM}
    ...    device_type=matter_controller
    ...    manufacturer=SSRFTest
    ...    model=Test
    ...    firmware_version=1.0.0
    ...    provisioning_url=https://valid-registry.example.com/device
    ${response}    Create Device    ${allowed_scheme_url}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${SSRF_DEVICE_IDS}    ${device_id}
