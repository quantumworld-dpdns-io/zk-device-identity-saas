*** Settings ***
Library    Collections
Library    RequestsLibrary
Resource    ../../resources/common.resource
Resource    ../../resources/api_keywords.resource
Resource    ../../resources/auth_keywords.resource

Suite Setup    Create Admin Session
Suite Teardown    Delete All Test Devices

*** Variables ***
${TEST_DEVICE_SERIAL_PREFIX}  TEST-ROBOT-
@{TEST_DEVICE_IDS}            ${EMPTY}

*** Keywords ***
Delete All Test Devices
    ${headers}    Create Admin Session
    FOR    ${device_id}    IN    @{TEST_DEVICE_IDS}
        Run Keyword And Ignore Error    Delete Device    ${device_id}    ${headers}    expected_status=204
    END
    Log    Cleaned up ${TEST_DEVICE_IDS} test devices

Create Test Device Data
    ${serial}    Generate Unique Device Serial
    ${device_data}    Create Dictionary
    ...    serial_number=${serial}
    ...    device_type=matter_controller
    ...    manufacturer=TestManufacturer
    ...    model=Model-X
    ...    firmware_version=1.0.0
    ...    tenant_id=tenant-a
    RETURN    ${device_data}

Create Test Device And Track
    ${device_data}    Create Test Device Data
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${TEST_DEVICE_IDS}    ${device_id}
    RETURN    ${response}

*** Test Cases ***
Create Device With Valid Data Returns 201
    [Documentation]    Verify device creation with complete valid data
    [Tags]    device    crud    smoke    api
    ${device_data}    Create Test Device Data
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    id
    Dictionary Should Contain Key    ${json}    serial_number
    Should Be Equal    ${json}[serial_number]    ${device_data}[serial_number]
    Dictionary Should Contain Key    ${json}    created_at
    ${device_id}    Get From Dictionary    ${json}    id
    Append To List    ${TEST_DEVICE_IDS}    ${device_id}

Create Device With Missing Fields Returns 422
    [Documentation]    Verify device creation fails with incomplete data
    [Tags]    device    crud    validation    api
    ${headers}    Create Admin Session
    ${incomplete_data}    Create Dictionary    serial_number=MISSING-TYPE
    ${response}    Create Device    ${incomplete_data}    ${headers}    expected_status=422
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    error
    ${error}    Get From Dictionary    ${json}    error
    Should Not Be Empty    ${error}

Create Device With Duplicate Serial Returns 409
    [Documentation]    Verify duplicate serial number is rejected
    [Tags]    device    crud    validation    api
    ${device_data}    Create Test Device Data
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${TEST_DEVICE_IDS}    ${device_id}
    ${response2}    Create Device    ${device_data}    ${headers}    expected_status=409
    ${json}    Set Variable    ${response2.json()}
    Dictionary Should Contain Key    ${json}    error

Get Device By Id Returns 200
    [Documentation]    Verify fetching a device by valid ID
    [Tags]    device    crud    smoke    api
    ${response}    Create Test Device And Track
    ${created_json}    Set Variable    ${response.json()}
    ${device_id}    Get From Dictionary    ${created_json}    id
    ${get_response}    Get Device    ${device_id}
    Assert Response Status    ${get_response}    200
    ${get_json}    Set Variable    ${get_response.json()}
    Should Be Equal    ${get_json}[id]    ${device_id}

Get Device With Invalid Id Returns 404
    [Documentation]    Verify fetching a device with non-existent ID returns 404
    [Tags]    device    crud    validation    api
    ${headers}    Create Admin Session
    ${response}    Get Device    non-existent-id-12345    ${headers}    expected_status=404

List Devices Returns Paginated Results
    [Documentation]    Verify device listing returns paginated data
    [Tags]    device    crud    smoke    api
    ${headers}    Create Admin Session
    ${response}    List Devices    ${headers}    expected_status=200
    ${json}    Set Variable    ${response.json()}
    Dictionary Should Contain Key    ${json}    data
    Dictionary Should Contain Key    ${json}    total
    Dictionary Should Contain Key    ${json}    page
    Dictionary Should Contain Key    ${json}    page_size

List Devices With Pagination Params
    [Documentation]    Verify pagination parameters are respected
    [Tags]    device    crud    pagination    api
    ${headers}    Create Admin Session
    ${params}    Create Dictionary    page=1    page_size=5
    ${response}    List Devices    ${headers}    params=${params}
    ${json}    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${json}[page]    1
    Should Be Equal As Integers    ${json}[page_size]    5

List Devices Filters By Tenant
    [Documentation]    Verify tenant-scoped device listing
    [Tags]    device    crud    tenant    api
    ${tenant_headers}    Create Tenant Session    ${TENANT_A_EMAIL}    ${TENANT_A_PASSWORD}
    ${device_data}    Create Test Device Data
    ${create_resp}    Create Device    ${device_data}    ${tenant_headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${create_resp.json()}    id
    Append To List    ${TEST_DEVICE_IDS}    ${device_id}
    ${list_resp}    List Devices    ${tenant_headers}
    ${json}    Set Variable    ${list_resp.json()}
    ${data}    Get From Dictionary    ${json}    data
    ${ids}    Evaluate    [d["id"] for d in $data if "id" in d]
    Should Contain    ${ids}    ${device_id}

Update Device Returns 200
    [Documentation]    Verify updating device fields succeeds
    [Tags]    device    crud    smoke    api
    ${response}    Create Test Device And Track
    ${device_id}    Get From Dictionary    ${response.json()}    id
    ${update_data}    Create Dictionary    firmware_version=2.0.0    model=Model-X-Updated
    ${headers}    Create Admin Session
    ${update_resp}    Update Device    ${device_id}    ${update_data}    ${headers}    expected_status=200
    ${json}    Set Variable    ${update_resp.json()}
    Should Be Equal    ${json}[firmware_version]    2.0.0
    Should Be Equal    ${json}[model]    Model-X-Updated

Update Device With Invalid Data Returns 422
    [Documentation]    Verify updating with invalid fields is rejected
    [Tags]    device    crud    validation    api
    ${response}    Create Test Device And Track
    ${device_id}    Get From Dictionary    ${response.json()}    id
    ${invalid_update}    Create Dictionary    serial_number=${EMPTY}
    ${headers}    Create Admin Session
    ${response2}    Update Device    ${device_id}    ${invalid_update}    ${headers}    expected_status=422

Delete Device Returns 204
    [Documentation]    Verify device deletion returns no content
    [Tags]    device    crud    smoke    api
    ${device_data}    Create Test Device Data
    ${headers}    Create Admin Session
    ${create_resp}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${create_resp.json()}    id
    ${delete_resp}    Delete Device    ${device_id}    ${headers}    expected_status=204
    Run Keyword And Expect Error    *    Get Device    ${device_id}    ${headers}    expected_status=404

Delete Already Deleted Device Returns 404
    [Documentation]    Verify deleting an already-removed device returns 404
    [Tags]    device    crud    validation    api
    ${device_data}    Create Test Device Data
    ${headers}    Create Admin Session
    ${create_resp}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${create_resp.json()}    id
    Delete Device    ${device_id}    ${headers}    expected_status=204
    Delete Device    ${device_id}    ${headers}    expected_status=404

Create Device With Special Characters In Name
    [Documentation]    Verify special characters are handled in device name
    [Tags]    device    crud    validation    api
    ${device_data}    Create Test Device Data
    Set To Dictionary    ${device_data}    device_name=Device_<script>alert(1)</script>
    ${headers}    Create Admin Session
    ${response}    Create Device    ${device_data}    ${headers}    expected_status=201
    ${device_id}    Get From Dictionary    ${response.json()}    id
    Append To List    ${TEST_DEVICE_IDS}    ${device_id}
    ${get_resp}    Get Device    ${device_id}    ${headers}
    ${json}    Set Variable    ${get_resp.json()}
    Should Contain    ${json}[device_name]    Device_
