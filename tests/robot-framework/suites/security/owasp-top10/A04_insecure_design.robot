*** Settings ***
Library    Collections
Library    RequestsLibrary
Library    DateTime
Resource    ../../../resources/common.resource
Resource    ../../../resources/api_keywords.resource
Resource    ../../../resources/auth_keywords.resource

Suite Setup    Create Admin Session

*** Test Cases ***
Rate Limiting On Auth Endpoints
    [Documentation]    Verify auth login endpoint has rate limiting
    [Tags]    owasp    A04    rate-limiting    auth    security
    ${body}    Create Dictionary    email=ratelimit@test.com    password=TestPass123
    ${rate_limited}    Set Variable    ${FALSE}
    FOR    ${i}    IN RANGE    50
        ${response}    POST
        ...    ${BASE_URL}${API_VERSION}/auth/login
        ...    json=${body}
        ...    expected_status=any
        ${status}    Set Variable    ${response.status_code}
        IF    ${status} == 429
            ${rate_limited}    Set Variable    ${TRUE}
            Log    Rate limited triggered after ${i} requests
            Break
        END
    END
    Should Be True    ${rate_limited}    Auth endpoint was not rate limited!

Rate Limiting On Proof Generation
    [Documentation]    Verify proof generation endpoint has rate limiting
    [Tags]    owasp    A04    rate-limiting    proof    security
    ${headers}    Create Admin Session
    ${proof_request}    Create Dictionary
    ...    circuit_type=${CIRCUIT_TYPE_DAC}
    ...    public_inputs={}
    ...    private_inputs={}
    ${rate_limited}    Set Variable    ${FALSE}
    FOR    ${i}    IN RANGE    30
        ${response}    POST
        ...    ${BASE_URL}${API_VERSION}/proofs
        ...    json=${proof_request}
        ...    headers=${headers}
        ...    expected_status=any
        ${status}    Set Variable    ${response.status_code}
        IF    ${status} == 429
            ${rate_limited}    Set Variable    ${TRUE}
            Log    Proof rate limiting triggered after ${i} requests
            Break
        END
    END
    Should Be True    ${rate_limited}    Proof endpoint was not rate limited!

Input Validation On Device Serial Number
    [Documentation]    Verify serial number input validation rejects invalid formats
    [Tags]    owasp    A04    input-validation    device    security
    ${headers}    Create Admin Session
    ${invalid_serials}    Create List
    ...    ${EMPTY}
    ...    ${SPACE}
    ...    A
    ...    AB
    ...    ${SPACE}${SPACE}${SPACE}
    ...    ${SPACE}ABC
    ...    ABC${SPACE}
    ...    a
    FOR    ${serial}    IN    @{invalid_serials}
        ${device_data}    Create Dictionary
        ...    serial_number=${serial}
        ...    device_type=matter_controller
        ...    manufacturer=ValidationTest
        ...    model=Test
        ...    firmware_version=1.0.0
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=422
        ${json}    Set Variable    ${response.json()}
        Dictionary Should Contain Key    ${json}    error
    END

Input Validation On Device Type
    [Documentation]    Verify device type validation rejects invalid values
    [Tags]    owasp    A04    input-validation    device    security
    ${headers}    Create Admin Session
    ${invalid_types}    Create List
    ...    ${EMPTY}
    ...    invalid_device_type_xyz
    ...    <script>alert(1)</script>
    FOR    ${device_type}    IN    @{invalid_types}
        ${device_data}    Create Dictionary
        ...    serial_number=TYPE-INVALID-${RANDOM}
        ...    device_type=${device_type}
        ...    manufacturer=ValidationTest
        ...    model=Test
        ...    firmware_version=1.0.0
        ${response}    Create Device    ${device_data}    ${headers}    expected_status=422
        Log    Invalid device type ${device_type} correctly rejected
    END

Excessive Data Exposure In List Endpoints
    [Documentation]    Verify device list endpoints do not expose sensitive fields
    [Tags]    owasp    A04    data-exposure    privacy    security
    ${headers}    Create Admin Session
    ${response}    List Devices    ${headers}    expected_status=200
    ${json}    Set Variable    ${response.json()}
    ${data}    Get From Dictionary    ${json}    data
    IF    ${data}
        ${first_device}    Get From List    ${data}    0
        Dictionary Should Not Contain Key    ${first_device}    secret_key
        Dictionary Should Not Contain Key    ${first_device}    private_key
        Dictionary Should Not Contain Key    ${first_device}    attestation_private_key
        Dictionary Should Not Contain Key    ${first_device}    password
    END

Excessive Data Exposure On Single Device
    [Documentation]    Verify single device endpoint does not expose sensitive fields
    [Tags]    owasp    A04    data-exposure    privacy    security
    ${headers}    Create Admin Session
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=ExposureTest
    ...    model=Test
    ...    firmware_version=1.0.0
    ${create_resp}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${create_resp.json()}    id
    ${get_resp}    Get Device    ${device_id}    ${headers}    expected_status=200
    ${get_json}    Set Variable    ${get_resp.json()}
    Dictionary Should Not Contain Key    ${get_json}    secret_key
    Dictionary Should Not Contain Key    ${get_json}    private_key
    Dictionary Should Not Contain Key    ${get_json}    password
    Run Keyword And Ignore Error    Delete Device    ${device_id}    ${headers}

Large Payload Rejected
    [Documentation]    Verify excessively large payloads are rejected
    [Tags]    owasp    A04    input-validation    dos    security
    ${headers}    Create Admin Session
    ${large_string}    Evaluate    "A" * 100000
    ${device_data}    Create Dictionary
    ...    serial_number=LARGE-PAYLOAD-TEST
    ...    device_type=matter_controller
    ...    manufacturer=${large_string}
    ...    model=Test
    ...    firmware_version=1.0.0
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=413
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error

Negative Pagination Values Handled
    [Documentation]    Verify negative pagination values are handled gracefully
    [Tags]    owasp    A04    input-validation    pagination    security
    ${headers}    Create Admin Session
    ${invalid_params}    Create List
    ...    {"page": -1, "page_size": 20}
    ...    {"page": 0, "page_size": -1}
    ...    {"page": -5, "page_size": -5}
    ...    {"page": "abc", "page_size": 20}
    FOR    ${params}    IN    @{invalid_params}
        ${response}    GET
        ...    ${BASE_URL}${API_VERSION}/devices
        ...    headers=${headers}
        ...    params=${params}
        ...    expected_status=400
        Log    Invalid pagination ${params} correctly rejected
    END

Mass Assignment Prevention
    [Documentation]    Verify mass assignment attacks are prevented
    [Tags]    owasp    A04    mass-assignment    security
    ${headers}    Create Admin Session
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=MassAssign
    ...    model=Test
    ...    firmware_version=1.0.0
    ...    role=admin
    ...    is_admin=true
    ...    tenant_id=another-tenant
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${json}    Set Variable    ${response.json()}
    ${device_id}    Get From Dictionary    ${json}    id
    Run Keyword And Ignore Error    Delete Device    ${device_id}    ${headers}
    Dictionary Should Not Contain Key    ${json}    role
