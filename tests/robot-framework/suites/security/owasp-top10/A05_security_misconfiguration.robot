*** Settings ***
Library    Collections
Library    RequestsLibrary
Resource    ../../../resources/common.resource
Resource    ../../../resources/auth_keywords.resource

Suite Setup    Create Admin Session

*** Test Cases ***
Default Credentials Rejected
    [Documentation]    Verify well-known default credentials are rejected
    [Tags]    owasp    A05    misconfiguration    default-creds    security
    ${default_creds}    Create List
    ...    {"email": "admin@admin.com", "password": "admin"}
    ...    {"email": "admin@admin.com", "password": "password"}
    ...    {"email": "admin@admin.com", "password": "admin123"}
    ...    {"email": "root@root.com", "password": "root"}
    ...    {"email": "test@test.com", "password": "test"}
    ...    {"email": "user@user.com", "password": "12345678"}
    ...    {"email": "admin@example.com", "password": "password1"}
    FOR    ${creds}    IN    @{default_creds}
        ${response}    POST
        ...    ${BASE_URL}${API_VERSION}/auth/login
        ...    json=${creds}
        ...    expected_status=401
        Log    Default creds ${creds}[email] correctly rejected
    END

Debug Endpoints Return 404 In Production Mode
    [Documentation]    Verify debug/info endpoints are disabled in production
    [Tags]    owasp    A05    misconfiguration    debug    security
    ${headers}    Create Admin Session
    ${debug_paths}    Create List
    ...    /debug
    ...    /debug/pprof
    ...    /debug/vars
    ...    /api/v1/debug
    ...    /swagger/index.html
    ...    /actuator
    ...    /actuator/info
    ...    /api/v1/_debug
    ...    /console
    ...    /api/v1/graphql
    FOR    ${path}    IN    @{debug_paths}
        ${response}    GET    ${BASE_URL}${path}    headers=${headers}    expected_status=404
        Log    Debug path ${path} correctly disabled
    END

Cors Headers Are Properly Restricted
    [Documentation]    Verify CORS headers do not allow all origins
    [Tags]    owasp    A05    misconfiguration    cors    security
    ${headers}    Create Dictionary    Origin=https://evil.com
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    headers=${headers}    expected_status=200
    ${resp_headers}    Set Variable    ${response.headers}
    ${access_control}    Get From Dictionary    ${resp_headers}    Access-Control-Allow-Origin    default=
    Should Not Be Equal    ${access_control}    *
    Should Not Be Equal    ${access_control}    https://evil.com

Security Headers Present
    [Documentation]    Verify required security headers are present in responses
    [Tags]    owasp    A05    misconfiguration    headers    security
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${resp_headers}    Set Variable    ${response.headers}
    ${required_headers}    Create List
    ...    X-Content-Type-Options
    ...    X-Frame-Options
    ...    X-XSS-Protection
    ...    Strict-Transport-Security
    ...    Content-Security-Policy
    ...    Cache-Control
    ...    Pragma
    FOR    ${header}    IN    @{required_headers}
        Dictionary Should Contain Key    ${resp_headers}    ${header}
        ${value}    Get From Dictionary    ${resp_headers}    ${header}
        Should Not Be Empty    ${value}
    END

X-Content-Type-Options Is Nosniff
    [Documentation]    Verify X-Content-Type-Options header is set to nosniff
    [Tags]    owasp    A05    misconfiguration    headers    security
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${resp_headers}    Set Variable    ${response.headers}
    ${xcto}    Get From Dictionary    ${resp_headers}    X-Content-Type-Options
    Should Be Equal    ${xcto}    nosniff

X-Frame-Options Is Deny Or Sameorigin
    [Documentation]    Verify X-Frame-Options prevents clickjacking
    [Tags]    owasp    A05    misconfiguration    headers    security
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${resp_headers}    Set Variable    ${response.headers}
    ${xfo}    Get From Dictionary    ${resp_headers}    X-Frame-Options
    Should Be True    "${xfo}" == "DENY" or "${xfo}" == "SAMEORIGIN"

Http Methods Properly Restricted
    [Documentation]    Verify HTTP method restrictions on endpoints
    [Tags]    owasp    A05    misconfiguration    http-methods    security
    ${headers}    Create Admin Session
    ${disallowed_methods}    Create List    PUT    PATCH    DELETE    TRACE    OPTIONS
    FOR    ${method}    IN    @{disallowed_methods}
        ${response}    ${method}
        ...    ${BASE_URL}${API_VERSION}/health
        ...    headers=${headers}
        ...    expected_status=405
        Log    Method ${method} correctly rejected on health endpoint
    END

Delete Not Allowed On Read Only Endpoints
    [Documentation]    Verify DELETE method is restricted to appropriate endpoints
    [Tags]    owasp    A05    misconfiguration    http-methods    security
    ${headers}    Create Admin Session
    ${response}    DELETE
    ...    ${BASE_URL}${API_VERSION}/health
    ...    headers=${headers}
    ...    expected_status=405

Trace Method Disabled
    [Documentation]    Verify TRACE method is disabled
    [Tags]    owasp    A05    misconfiguration    http-methods    security
    ${response}    TRACE    ${BASE_URL}/    expected_status=405
    ${response2}    TRACE    ${BASE_URL}${API_VERSION}/health    expected_status=405

Server Version Not Exposed
    [Documentation]    Verify Server header does not expose detailed version info
    [Tags]    owasp    A05    misconfiguration    information-disclosure    security
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${resp_headers}    Set Variable    ${response.headers}
    ${server}    Get From Dictionary    ${resp_headers}    Server    default=unknown
    Should Not Contain    ${server}    nginx/1.
    Should Not Contain    ${server}    Apache/2.
    Should Not Contain    ${server}    Go/
    Should Not Contain    ${server}    Rust/

Verbose Error Messages Disabled
    [Documentation]    Verify error messages are not verbose
    [Tags]    owasp    A05    misconfiguration    error-handling    security
    ${headers}    Create Admin Session
    ${response}    GET    ${BASE_URL}${API_VERSION}/devices/nonexistent    headers=${headers}    expected_status=404
    ${body_str}    Evaluate    str(${response.json()})
    ${length}    Get Length    ${body_str}
    Should Be True    ${length} < 500    Error message too verbose: ${length} chars
