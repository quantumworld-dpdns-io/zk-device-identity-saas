*** Settings ***
Library    Collections
Library    RequestsLibrary
Resource    ../../resources/common.resource

Suite Setup    Create Session    health_session    ${BASE_URL}

*** Test Cases ***
GET /health Returns 200
    [Documentation]    Verify the root health endpoint returns HTTP 200
    [Tags]    health    smoke    api
    ${response}    GET    ${BASE_URL}/health    expected_status=200
    Assert Response Status    ${response}    200

GET /api/v1/health Returns JSON With Status
    [Documentation]    Verify the API health endpoint returns valid JSON with status field
    [Tags]    health    smoke    api
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${content_type}    Get From Dictionary    ${response.headers}    Content-Type
    Should Contain    ${content_type}    ${CONTENT_TYPE_JSON}
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    status
    ${status}    Get From Dictionary    ${json}    status
    Should Be Equal    ${status}    ok

Health Check Includes Uptime
    [Documentation]    Verify health response includes uptime information
    [Tags]    health    smoke    api
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    uptime
    ${uptime}    Get From Dictionary    ${json}    uptime
    Should Not Be Empty    ${uptime}

Health Check Includes Database Status
    [Documentation]    Verify health response includes database connectivity status
    [Tags]    health    api
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    database
    ${db_status}    Get From Dictionary    ${json}    database
    Should Be Equal    ${db_status}    connected

Health Check Includes Services Status
    [Documentation]    Verify health response includes dependent service statuses
    [Tags]    health    api
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    services
    ${services}    Get From Dictionary    ${json}    services
    Dictionary Should Contain Key    ${services}    redis
    Dictionary Should Contain Key    ${services}    database

Health Check Includes Version Information
    [Documentation]    Verify health response includes API version info
    [Tags]    health    api
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    version
    ${version}    Get From Dictionary    ${json}    version
    Should Not Be Empty    ${version}

Health Check Is Fast
    [Documentation]    Verify health endpoint responds within acceptable time
    [Tags]    health    performance
    ${start_time}    Get Current Date    result_format=epoch
    ${response}    GET    ${BASE_URL}${API_VERSION}/health    expected_status=200
    ${end_time}    Get Current Date    result_format=epoch
    ${elapsed}    Evaluate    ${end_time} - ${start_time}
    Should Be True    ${elapsed} < 5.0    Health check took too long: ${elapsed}s
