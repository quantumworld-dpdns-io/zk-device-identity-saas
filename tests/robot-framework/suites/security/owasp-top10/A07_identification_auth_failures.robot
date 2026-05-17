*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    DateTime
Resource    ../../../resources/common.resource
Resource    ../../../resources/auth_keywords.resource

Suite Setup    Create Admin Session

*** Variables ***
${LOCKOUT_TEST_EMAIL}        lockout-test-${RANDOM}@test.com

*** Test Cases ***
Weak Password Rejected Less Than 8 Characters
    [Documentation]    Verify passwords shorter than 8 characters are rejected at registration
    [Tags]    owasp    A07    auth    weak-password    security
    ${weak_passwords}    Create List
    ...    Ab1
    ...    aB3$
    ...    1234567
    ...    pass
    ...    abcd123
    FOR    ${weak_pw}    IN    @{weak_passwords}
        ${email}    Evaluate    "weak-${RANDOM}@test.com"
        ${response}    Register    ${email}    ${weak_pw}    expected_status=400
        ${json}    Set Variable    ${response.json()}
        Dictionary Should Contain Key    ${json}    error
        Log    Weak password "${weak_pw}" correctly rejected
    END

Jwt With None Algorithm Rejected
    [Documentation]    Verify JWT with alg: none is rejected by the server
    [Tags]    owasp    A07    auth    jwt    algorithm    security
    ${forged_token}    Generate Malicious Jwt    {"sub": "admin", "role": "admin"}    none
    ${headers}    Create Dictionary    Authorization=${BEARER} ${forged_token}    Content-Type=${CONTENT_TYPE_JSON}
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    headers=${headers}
    ...    expected_status=401
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Expired Jwt Returns 401
    [Documentation]    Verify expired JWT tokens are rejected
    [Tags]    owasp    A07    auth    jwt    expiry    security
    ${expired_token}    Create Expired Token
    ${headers}    Create Dictionary    Authorization=${BEARER} ${expired_token}    Content-Type=${CONTENT_TYPE_JSON}
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    headers=${headers}
    ...    expected_status=401
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Multiple Failed Logins Triggers Lockout
    [Documentation]    Verify account lockout after multiple failed login attempts
    [Tags]    owasp    A07    auth    lockout    brute-force    security
    ${test_email}    Set Variable    lockout-${RANDOM}@test.com
    Register    ${test_email}    TestPass123!    expected_status=201
    FOR    ${i}    IN RANGE    10
        ${response}    Login    ${test_email}    WrongPass!    expected_status=401
    END
    ${response}    Login    ${test_email}    TestPass123!    expected_status=401
    ${json}    Set Variable    ${response.json()}
    ${error}    Get From Dictionary    ${json}    error
    Should Contain    ${error}    locked    Account not locked after failed attempts

Session Fixation Not Possible
    [Documentation]    Verify session fixation: login with predefined session is not possible
    [Tags]    owasp    A07    auth    session-fixation    security
    ${predefined_token}    Set Variable    fixated-session-token-12345
    ${headers}    Create Dictionary    Authorization=${BEARER} ${predefined_token}    Content-Type=${CONTENT_TYPE_JSON}
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/auth/profile
    ...    headers=${headers}
    ...    expected_status=401

Mfa Enforcement For Admin Roles
    [Documentation]    Verify MFA is required or available for admin accounts
    [Tags]    owasp    A07    auth    mfa    security
    ${headers}    Create Admin Session
    ${response}    Activate Mfa    ${headers}    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    secret
    Dictionary Should Contain Key    ${json}    qr_code

Token Refresh With Invalid Token Returns 401
    [Documentation]    Verify refresh token endpoint rejects invalid tokens
    [Tags]    owasp    A07    auth    token    security
    ${response}    Refresh Token    invalid-refresh-token    expected_status=401
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Reused Refresh Token Returns 401
    [Documentation]    Verify refresh token cannot be reused after rotation
    [Tags]    owasp    A07    auth    token    rotation    security
    ${login_resp}    Login    ${ADMIN_EMAIL}    ${ADMIN_PASSWORD}    expected_status=200
    ${refresh_token}    Set Variable    ${login_resp.json()}[refresh_token]
    ${first_resp}    Refresh Token    ${refresh_token}    expected_status=200
    ${second_resp}    Refresh Token    ${refresh_token}    expected_status=401
    ${json}    Set Variable    ${second_resp.json()}
    Dictionary Should Contain Key    ${json}    error

Login With Email Case Insensitivity
    [Documentation]    Verify login is case-insensitive for emails
    [Tags]    owasp    A07    auth    email    security
    ${mixed_case_email}    Evaluate    "${ADMIN_EMAIL}".swapcase()
    ${response}    Login    ${mixed_case_email}    ${ADMIN_PASSWORD}    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    access_token

Brute Force Protection On Auth Endpoint
    [Documentation]    Verify brute force protection returns 429 after many attempts
    [Tags]    owasp    A07    auth    brute-force    rate-limit    security
    ${test_email}    Set Variable    bruteforce-${RANDOM}@test.com
    Register    ${test_email}    TestPass123!    expected_status=201
    ${rate_limited}    Set Variable    ${FALSE}
    FOR    ${i}    IN RANGE    30
        ${response}    POST
        ...    ${BASE_URL}${API_VERSION}/auth/login
        ...    json={"email": "${test_email}", "password": "wrong${i}"}
        ...    expected_status=any
        IF    ${response.status_code} == 429
            ${rate_limited}    Set Variable    ${TRUE}
            Break
        END
    END
    Should Be True    ${rate_limited}    Brute force protection not triggered
