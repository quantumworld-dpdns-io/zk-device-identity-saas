*** Settings ***
Library    Collections
Library    String
Library    DateTime
Library    RequestsLibrary
Library    ../libraries/ZkDeviceLibrary.py
Library    ../libraries/SecurityTestLibrary.py

*** Variables ***
${BASE_URL}                  http://localhost:8080
${API_VERSION}               /api/v1
${ADMIN_EMAIL}               admin@zkdevice.io
${ADMIN_PASSWORD}            Sup3rS3cur3P@ss!
${TENANT_A_EMAIL}            tenant-a@example.com
${TENANT_A_PASSWORD}         Tenant@Pass123
${TENANT_B_EMAIL}            tenant-b@example.com
${TENANT_B_PASSWORD}         Tenant@Pass456
${DEFAULT_TIMEOUT}           30s
${PAGINATION_PAGE_SIZE}      20
${BEARER}                    Bearer
${CONTENT_TYPE_JSON}         application/json
${AUDIT_LOG_ENDPOINT}        /audit/logs

*** Keywords ***
Health Check
    [Arguments]    ${expected_status}=200
    ${response}    GET    ${BASE_URL}/health    expected_status=${expected_status}
    RETURN    ${response}

Get Auth Token
    [Arguments]    ${email}=${ADMIN_EMAIL}    ${password}=${ADMIN_PASSWORD}
    ${body}    Create Dictionary    email=${email}    password=${password}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}/auth/login
    ...    json=${body}
    ...    expected_status=200
    ${token}    Set Variable    ${response.json()}[access_token]
    RETURN    ${token}

Create Admin Session
    ${token}    Get Auth Token    ${ADMIN_EMAIL}    ${ADMIN_PASSWORD}
    ${headers}    Create Dictionary    Authorization=${BEARER} ${token}    Content-Type=${CONTENT_TYPE_JSON}
    RETURN    ${headers}

Create Tenant Session
    [Arguments]    ${tenant_email}    ${tenant_password}
    ${token}    Get Auth Token    ${tenant_email}    ${tenant_password}
    ${headers}    Create Dictionary    Authorization=${BEARER} ${token}    Content-Type=${CONTENT_TYPE_JSON}
    RETURN    ${headers}

Generate Random String
    [Arguments]    ${length}=8    ${chars}=[LOWER]
    ${result}    Generate Random String    ${length}    ${chars}
    RETURN    ${result}

Generate Unique Device Serial
    ${timestamp}    Get Current Date    result_format=epoch
    ${serial}    Catenate    SEPARATOR=    DEV-    ${timestamp}    -    ${RANDOM}
    RETURN    ${serial}

Assert Response Status
    [Arguments]    ${response}    ${expected_status}
    Should Be Equal As Integers    ${response.status_code}    ${expected_status}

Assert Json Value
    [Arguments]    ${response}    ${json_path}    ${expected_value}=${None}
    ${json_body}    Set Variable    ${response.json()}
    ${actual}    Get From Dictionary    ${json_body}    ${json_path}
    IF    ${expected_value} != ${None}
        Should Be Equal    ${actual}    ${expected_value}
    END
    RETURN    ${actual}

Assert Response Contains
    [Arguments]    ${response}    ${key}
    ${json_body}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json_body}    ${key}

Validate Json Schema
    [Arguments]    ${response}    ${required_keys}
    ${json_body}    Set Variable    ${response.json()}
    FOR    ${key}    IN    @{required_keys}
        Dictionary Should Contain Key    ${json_body}    ${key}
    END

Get Api Key Headers
    [Arguments]    ${api_key}    ${scopes}=read
    ${headers}    Create Dictionary    X-API-Key=${api_key}    X-API-Scopes=${scopes}    Content-Type=${CONTENT_TYPE_JSON}
    RETURN    ${headers}
