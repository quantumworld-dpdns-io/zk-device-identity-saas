*** Settings ***
Library    Collections
Library    RequestsLibrary
Resource    ../../resources/common.resource
Resource    ../../resources/api_keywords.resource
Resource    ../../resources/auth_keywords.resource

Suite Setup    Create Admin Session

*** Test Cases ***
Api Key Rotation Works
    [Documentation]    Verify API key rotation generates a new valid key and invalidates the old one
    [Tags]    api-key    security    rotation    security
    ${headers}    Create Admin Session
    ${new_key_response}    POST
    ...    ${BASE_URL}${API_VERSION}/auth/api-keys
    ...    json={"name": "test-key-${RANDOM}"}
    ...    headers=${headers}
    ...    expected_status=201
    ${new_api_key}    Get From Dictionary    ${new_key_response.json()}    api_key
    ${key_headers}    Get Api Key Headers    ${new_api_key}
    ${test_resp}    GET
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    headers=${key_headers}
    ...    expected_status=200
    Assert Response Status    ${test_resp}    200
    ${rotate_response}    POST
    ...    ${BASE_URL}${API_VERSION}/auth/api-keys/rotate
    ...    json={"current_key": "${new_api_key}"}
    ...    headers=${headers}
    ...    expected_status=200
    ${rotated_key}    Get From Dictionary    ${rotate_response.json()}    api_key
    ${rotated_headers}    Get Api Key Headers    ${rotated_key}
    ${rotated_test}    GET
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    headers=${rotated_headers}
    ...    expected_status=200
    ${old_headers}    Get Api Key Headers    ${new_api_key}
    ${old_test}    GET
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    headers=${old_headers}
    ...    expected_status=401

Revoked Api Key Rejected
    [Documentation]    Verify revoked API keys are rejected
    [Tags]    api-key    security    revocation    security
    ${headers}    Create Admin Session
    ${create_resp}    POST
    ...    ${BASE_URL}${API_VERSION}/auth/api-keys
    ...    json={"name": "revoke-test-${RANDOM}"}
    ...    headers=${headers}
    ...    expected_status=201
    ${api_key}    Get From Dictionary    ${create_resp.json()}    api_key
    ${revoke_resp}    DELETE
    ...    ${BASE_URL}${API_VERSION}/auth/api-keys/current
    ...    headers=${headers}
    ...    json={"api_key": "${api_key}"}
    ...    expected_status=204
    ${key_headers}    Get Api Key Headers    ${api_key}
    ${test_resp}    GET
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    headers=${key_headers}
    ...    expected_status=401
    ${json}    Set Variable    ${test_resp.json()}
    Dictionary Should Contain Key    ${json}    error

Api Key With Wrong Scopes Rejected
    [Documentation]    Verify API key with insufficient scopes is rejected for privileged operations
    [Tags]    api-key    security    scopes    authorization    security
    ${headers}    Create Admin Session
    ${create_resp}    POST
    ...    ${BASE_URL}${API_VERSION}/auth/api-keys
    ...    json={"name": "scope-test-${RANDOM}", "scopes": ["read"]}
    ...    headers=${headers}
    ...    expected_status=201
    ${read_key}    Get From Dictionary    ${create_resp.json()}    api_key
    ${read_headers}    Get Api Key Headers    ${read_key}    read
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=ScopeTest
    ...    model=Test
    ...    firmware_version=1.0.0
    ${write_resp}    POST
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    json=${device_data}
    ...    headers=${read_headers}
    ...    expected_status=403
    ${json}    Set Variable    ${write_resp.json()}
    Dictionary Should Contain Key    ${json}    error
    ${read_resp}    GET
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    headers=${read_headers}
    ...    expected_status=200

Api Key Leakage In Logs Checked
    [Documentation]    Verify API keys are not exposed in log responses
    [Tags]    api-key    security    leakage    logging    security
    ${headers}    Create Admin Session
    ${audit_resp}    GET
    ...    ${BASE_URL}${API_VERSION}${AUDIT_LOG_ENDPOINT}
    ...    headers=${headers}
    ...    expected_status=200
    ${json}    Set Variable    ${audit_resp.json()}
    ${body_str}    Evaluate    str(${json})
    Should Not Contain    ${body_str}    sk-    API key pattern found in logs!

Api Key Leakage In Url Checked
    [Documentation]    Verify API keys are not transmitted via URL query parameters
    [Tags]    api-key    security    leakage    url    security
    ${headers}    Create Admin Session
    ${create_resp}    POST
    ...    ${BASE_URL}${API_VERSION}/auth/api-keys
    ...    json={"name": "url-leak-test-${RANDOM}"}
    ...    headers=${headers}
    ...    expected_status=201
    ${api_key}    Get From Dictionary    ${create_resp.json()}    api_key
    ${url_key_resp}    GET
    ...    ${BASE_URL}${API_VERSION}/devices?api_key=${api_key}
    ...    headers=${headers}
    ...    expected_status=400
    ${json}    Set Variable    ${url_key_resp.json()}
    Dictionary Should Contain Key    ${json}    error

Expired Api Key Rejected
    [Documentation]    Verify expired API keys are rejected
    [Tags]    api-key    security    expiry    security
    ${headers}    Create Admin Session
    ${create_resp}    POST
    ...    ${BASE_URL}${API_VERSION}/auth/api-keys
    ...    json={"name": "expiry-test-${RANDOM}", "expires_in": "1s"}
    ...    headers=${headers}
    ...    expected_status=201
    ${api_key}    Get From Dictionary    ${create_resp.json()}    api_key
    Sleep    2s
    ${key_headers}    Get Api Key Headers    ${api_key}
    ${test_resp}    GET
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    headers=${key_headers}
    ...    expected_status=401
    ${json}    Set Variable    ${test_resp.json()}
    Dictionary Should Contain Key    ${json}    error

Api Key Without Header Rejected
    [Documentation]    Verify requests without X-API-Key header are rejected for key-protected endpoints
    [Tags]    api-key    security    authentication    security
    ${headers}    Create Dictionary    Content-Type=${CONTENT_TYPE_JSON}
    ${response}    GET
    ...    ${BASE_URL}${API_VERSION}/devices
    ...    headers=${headers}
    ...    expected_status=401
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Api Key With Invalid Format Rejected
    [Documentation]    Verify malformed API keys are rejected
    [Tags]    api-key    security    validation    security
    ${invalid_keys}    Create List
    ...    ${EMPTY}
    ...    invalid-key-format
    ...    abc
    ...    ${SPACE}
    ...    null
    FOR    ${key}    IN    @{invalid_keys}
        ${key_headers}    Get Api Key Headers    ${key}
        ${response}    GET
        ...    ${BASE_URL}${API_VERSION}/devices
        ...    headers=${key_headers}
        ...    expected_status=401
        Log    Invalid key "${key}" correctly rejected
    END
