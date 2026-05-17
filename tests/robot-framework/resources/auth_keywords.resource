*** Settings ***
Library    Collections
Library    String
Library    DateTime
Library    RequestsLibrary
Resource    common.resource

*** Variables ***
${AUTH_ENDPOINT}             /auth
${REGISTER_ENDPOINT}         /auth/register
${LOGIN_ENDPOINT}            /auth/login
${TOKEN_ENDPOINT}            /auth/token
${REFRESH_ENDPOINT}          /auth/refresh
${LOGOUT_ENDPOINT}           /auth/logout
${MFACTIVATE_ENDPOINT}       /auth/mfa/activate
${MFAVERIFY_ENDPOINT}        /auth/mfa/verify

*** Keywords ***
Login
    [Arguments]    ${email}    ${password}    ${expected_status}=200
    ${body}    Create Dictionary    email=${email}    password=${password}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${LOGIN_ENDPOINT}
    ...    json=${body}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Register
    [Arguments]    ${email}    ${password}    ${name}=Default User    ${expected_status}=201
    ${body}    Create Dictionary    email=${email}    password=${password}    name=${name}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${REGISTER_ENDPOINT}
    ...    json=${body}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Get Token
    [Arguments]    ${email}    ${password}    ${expected_status}=200
    ${response}    Login    ${email}    ${password}    ${expected_status}
    RETURN    ${response}

Refresh Token
    [Arguments]    ${refresh_token}    ${expected_status}=200
    ${body}    Create Dictionary    refresh_token=${refresh_token}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${REFRESH_ENDPOINT}
    ...    json=${body}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Logout
    [Arguments]    ${headers}    ${expected_status}=200
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${LOGOUT_ENDPOINT}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Check Auth Header
    [Arguments]    ${response}
    ${headers}    Get Variable    ${response.headers}
    Dictionary Should Contain Key    ${headers}    Authorization
    ${auth_value}    Get From Dictionary    ${headers}    Authorization
    Should Start With    ${auth_value}    ${BEARER}

Verify JWT
    [Arguments]    ${token}
    ${parts}    Evaluate    "${token}".split(".")
    Length Should Be    ${parts}    3
    ${header}    Evaluate    __import__("base64").urlsafe_b64decode(${parts}[0] + "==").decode("utf-8")
    ${payload}    Evaluate    __import__("base64").urlsafe_b64decode(${parts}[1] + "==").decode("utf-8")
    ${header_dict}    Evaluate    json.loads("""${header}""")    json
    ${payload_dict}    Evaluate    json.loads("""${payload}""")    json
    Dictionary Should Contain Key    ${header_dict}    alg
    Should Not Be Equal    ${header_dict}[alg]    none
    Dictionary Should Contain Key    ${payload_dict}    exp
    Dictionary Should Contain Key    ${payload_dict}    sub
    RETURN    ${header_dict}    ${payload_dict}

Get Token Expiry
    [Arguments]    ${token}
    ${parts}    Evaluate    "${token}".split(".")
    ${payload}    Evaluate    __import__("base64").urlsafe_b64decode(${parts}[1] + "==").decode("utf-8")
    ${payload_dict}    Evaluate    json.loads("""${payload}""")    json
    ${exp}    Get From Dictionary    ${payload_dict}    exp
    RETURN    ${exp}

Get Token Claims
    [Arguments]    ${token}
    ${parts}    Evaluate    "${token}".split(".")
    ${payload}    Evaluate    __import__("base64").urlsafe_b64decode(${parts}[1] + "==").decode("utf-8")
    ${payload_dict}    Evaluate    json.loads("""${payload}""")    json
    RETURN    ${payload_dict}

Activate Mfa
    [Arguments]    ${headers}    ${expected_status}=200
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${MFACTIVATE_ENDPOINT}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Verify Mfa
    [Arguments]    ${mfa_code}    ${headers}    ${expected_status}=200
    ${body}    Create Dictionary    mfa_code=${mfa_code}
    ${response}    POST
    ...    ${BASE_URL}${API_VERSION}${MFAVERIFY_ENDPOINT}
    ...    json=${body}
    ...    headers=${headers}
    ...    expected_status=${expected_status}
    RETURN    ${response}

Create Expired Token
    ${header}    Create Dictionary    alg=HS256    typ=JWT
    ${payload}    Create Dictionary    sub=test    exp=1000000000    iat=999999999
    ${header_b64}    Evaluate    __import__("base64").urlsafe_b64encode(json.dumps(${header}).encode()).rstrip(b"=").decode()
    ${payload_b64}    Evaluate    __import__("base64").urlsafe_b64encode(json.dumps(${payload}).encode()).rstrip(b"=").decode()
    ${token}    Catenate    SEPARATOR=.    ${header_b64}    ${payload_b64}    invalid_signature
    RETURN    ${token}
