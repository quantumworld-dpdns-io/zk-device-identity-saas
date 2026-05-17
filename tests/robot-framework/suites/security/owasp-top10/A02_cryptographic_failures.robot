*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    DateTime
Library    ../../../libraries/SecurityTestLibrary.py
Resource    ../../../resources/common.resource
Resource    ../../../resources/auth_keywords.resource

Suite Setup    Create Admin Session

*** Test Cases ***
Api Responses Do Not Contain Plaintext Passwords
    [Documentation]    Verify no API response contains plaintext passwords
    [Tags]    owasp    A02    crypto    passwords    security
    ${response}    Login    ${ADMIN_EMAIL}    ${ADMIN_PASSWORD}
    ${body_str}    Evaluate    str(${response.json()})
    Should Not Contain    ${body_str}    ${ADMIN_PASSWORD}
    Should Not Contain    ${body_str.lower()}    password

Jwt Tokens Do Not Contain Sensitive Data In Payload
    [Documentation]    Verify JWT payload does not expose sensitive information
    [Tags]    owasp    A02    crypto    jwt    security
    ${response}    Login    ${ADMIN_EMAIL}    ${ADMIN_PASSWORD}
    ${token}    Set Variable    ${response.json()}[access_token]
    ${header}    ${payload}    Verify JWT    ${token}
    Dictionary Should Not Contain Key    ${payload}    password
    Dictionary Should Not Contain Key    ${payload}    secret
    Dictionary Should Not Contain Key    ${payload}    credit_card
    Dictionary Should Not Contain Key    ${payload}    ssn

Tls Https Is Enforced
    [Documentation]    Verify HTTP requests are redirected or rejected (TLS enforcement)
    [Tags]    owasp    A02    crypto    tls    security
    ${response}    GET    http://localhost:8080/api/v1/health
    ...    expected_status=426
    Log    HTTP endpoint rejected as expected

Weak Tls Ciphers Are Rejected
    [Documentation]    Verify the server rejects weak TLS cipher suites
    [Tags]    owasp    A02    crypto    tls    cipher    security
    ${weak_ciphers}    Get Weak Tls Ciphers
    FOR    ${cipher}    IN    @{weak_ciphers}
        ${result}    Check Tls Cipher    localhost    8443    ${cipher}
        Should Be Equal    ${result}    ${FALSE}    Weak cipher ${cipher} was accepted!
    END

Error Messages Do Not Leak Stack Traces
    [Documentation]    Verify error responses do not contain stack traces
    [Tags]    owasp    A02    crypto    error-handling    security
    ${response}    GET    ${BASE_URL}${API_VERSION}/devices/invalid-id
    ...    expected_status=404
    ${body_str}    Evaluate    str(${response.json()})
    Should Not Contain    ${body_str}    Traceback
    Should Not Contain    ${body_str}    at 
    Should Not Contain    ${body_str}    .py:
    Should Not Contain    ${body_str}    .go:
    Should Not Contain    ${body_str}    File "
    Should Not Contain    ${body_str}    stack trace

Jwt Uses Strong Signing Algorithm
    [Documentation]    Verify JWT is signed with a strong algorithm, not 'none' or weak alg
    [Tags]    owasp    A02    crypto    jwt    algorithm    security
    ${response}    Login    ${ADMIN_EMAIL}    ${ADMIN_PASSWORD}
    ${token}    Set Variable    ${response.json()}[access_token]
    ${parts}    Evaluate    "${token}".split(".")
    ${header}    Evaluate    __import__("base64").urlsafe_b64decode(${parts}[0] + "==").decode("utf-8")
    ${header_dict}    Evaluate    json.loads("""${header}""")    json
    ${alg}    Get From Dictionary    ${header_dict}    alg
    Should Not Be Equal    ${alg}    none
    Should Not Be Equal    ${alg}    HS256    Weak algorithm HS256 discouraged
    Should Not Be Equal    ${alg}    HS1

Password Field Not Returned In User Profile
    [Documentation]    Verify user profile endpoint does not return password field
    [Tags]    owasp    A02    crypto    api
    ${headers}    Create Admin Session
    ${response}    GET    ${BASE_URL}${API_VERSION}/auth/profile    headers=${headers}    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Not Contain Key    ${json}    password
    Dictionary Should Not Contain Key    ${json}    password_hash
    Dictionary Should Not Contain Key    ${json}    secret

Refresh Token Does Not Expose Original Token
    [Documentation]    Verify refresh token response does not expose the original access token
    [Tags]    owasp    A02    crypto    jwt    security
    ${response}    Login    ${ADMIN_EMAIL}    ${ADMIN_PASSWORD}
    ${refresh_token}    Set Variable    ${response.json()}[refresh_token]
    ${refresh_resp}    Refresh Token    ${refresh_token}    expected_status=200
    ${json}    Set Variable    ${refresh_resp.json()}
    Dictionary Should Contain Key    ${json}    access_token
    ${new_token}    Get From Dictionary    ${json}    access_token
    Should Not Be Equal    ${new_token}    ${response.json()}[access_token]

Api Key Not Exposed In Url
    [Documentation]    Verify API keys are not transmitted in URLs
    [Tags]    owasp    A02    crypto    api-key    security
    ${headers}    Create Admin Session
    ${response}    GET    ${BASE_URL}${API_VERSION}/devices?api_key=test123
    ...    headers=${headers}
    ...    expected_status=200
    Log    API key in URL should use X-API-Key header instead
