"""
SecurityTestLibrary - Robot Framework library for security testing.
Provides keywords for TLS testing, JWT forgery, injection payloads, and security header validation.
"""

import json
import base64
import socket
import ssl
import re
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlparse


class SecurityTestLibrary:
    """Robot Framework library for OWASP security testing."""

    WEAK_TLS_CIPHERS: List[str] = [
        "RC4-MD5",
        "RC4-SHA",
        "RC4-SHA256",
        "ECDHE-RSA-RC4-SHA",
        "AECDH-RC4-SHA",
        "DHE-RSA-RC4-SHA",
        "RC4-MD5",
        "EXP-RC4-MD5",
        "EXP-RC4-SHA",
        "EXP-EDH-RSA-DES-CBC-SHA",
        "EXP-DES-CBC-SHA",
        "EXP-RC2-CBC-MD5",
        "DES-CBC-SHA",
        "DES-CBC3-SHA",
        "EDH-RSA-DES-CBC-SHA",
        "EDH-RSA-DES-CBC3-SHA",
        "PSK-3DES-EDE-CBC-SHA",
        "TLS_RSA_WITH_3DES_EDE_CBC_SHA",
        "TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA",
        "TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA",
        "TLS_DH_anon_WITH_AES_128_CBC_SHA",
        "TLS_DH_anon_WITH_AES_256_CBC_SHA",
        "SSLv3",
        "TLSv1.0",
    ]

    SQL_INJECTION_PAYLOADS: List[str] = [
        "' OR '1'='1",
        "' OR 1=1--",
        "' OR '1'='1' --",
        '" OR "1"="1',
        "admin'--",
        "admin' #",
        "' UNION SELECT * FROM users--",
        "' UNION SELECT 1,2,3--",
        "1; DROP TABLE users",
        "1'; DROP TABLE devices;--",
        "' WAITFOR DELAY '0:0:5'--",
        "1 OR 1=1",
        "' OR 1=1 LIMIT 1--",
        "' UNION SELECT @@version--",
        "'; EXEC xp_cmdshell('whoami')--",
        "' OR 'x'='x",
        "' AND 1=1--",
        "admin'/*",
        "1' ORDER BY 1--",
        "') OR 1=1--",
    ]

    XSS_PAYLOADS: List[str] = [
        "<script>alert(1)</script>",
        "<img src=x onerror=alert(1)>",
        "<svg onload=alert(1)>",
        "javascript:alert(1)",
        "\"><script>alert(1)</script>",
        "'><script>alert(1)</script>",
        "<scr<script>ipt>alert(1)</scr</script>ipt>",
        "<<SCRIPT>alert(1)</SCRIPT>",
        "<BODY ONLOAD=alert(1)>",
        "<IMG SRC=\"jav\x00ascript:alert(1)\">",
        "<IMG SRC=&#106&#97&#118&#97&#115&#99&#114&#105&#112&#116&#58&#97&#108&#101&#114&#116&#40&#49&#41>",
        "\\\"><script>alert(1)</script>",
        "<input onfocus=alert(1) autofocus>",
    ]

    def get_weak_tls_ciphers(self) -> List[str]:
        """Return a list of known weak TLS cipher strings for testing."""
        return self.WEAK_TLS_CIPHERS.copy()

    def check_tls_cipher(
        self,
        host: str,
        port: int,
        cipher: str,
    ) -> bool:
        """Check if a specific TLS cipher is accepted by the server.

        Args:
            host: Server hostname
            port: Server port
            cipher: Cipher name to test

        Returns:
            True if cipher is accepted, False otherwise
        """
        try:
            context = ssl.create_default_context()
            context.set_ciphers(cipher)
            sock = socket.create_connection((host, port), timeout=5)
            with context.wrap_socket(sock, server_hostname=host) as ssock:
                negotiated_cipher = ssock.cipher()
                if negotiated_cipher:
                    return cipher.lower() in str(negotiated_cipher).lower()
            return False
        except (ssl.SSLError, ConnectionRefusedError, socket.timeout, OSError):
            return False
        except Exception:
            return False

    def generate_malicious_jwt(
        self,
        payload: Dict[str, Any],
        algorithm: str = "none",
    ) -> str:
        """Generate a forged JWT token for security testing.

        Args:
            payload: JWT payload claims
            algorithm: Signing algorithm (none, HS256, etc.)

        Returns:
            Encoded JWT token string
        """
        header = {"alg": algorithm, "typ": "JWT"}

        header_b64 = self._base64url_encode(json.dumps(header))
        payload_b64 = self._base64url_encode(json.dumps(payload))

        if algorithm.lower() == "none":
            token = f"{header_b64}.{payload_b64}."
        else:
            token = f"{header_b64}.{payload_b64}.invalidsignature"

        return token

    def generate_sql_injection_payloads(self) -> List[str]:
        """Return common SQL injection payload strings."""
        return self.SQL_INJECTION_PAYLOADS.copy()

    def generate_xss_payloads(self) -> List[str]:
        """Return common XSS attack vectors."""
        return self.XSS_PAYLOADS.copy()

    def check_security_headers(self, response: Any) -> Dict[str, bool]:
        """Validate security headers in an HTTP response.

        Args:
            response: HTTP response object (must have .headers dict-like)

        Returns:
            Dictionary mapping header names to boolean presence/validity
        """
        headers = {}
        if hasattr(response, "headers"):
            rh = response.headers
        elif isinstance(response, dict):
            rh = response
        else:
            rh = {}

        checks = {
            "X-Content-Type-Options": lambda v: v and "nosniff" in v.lower(),
            "X-Frame-Options": lambda v: v
            and v.upper() in ("DENY", "SAMEORIGIN"),
            "X-XSS-Protection": lambda v: v and "1" in v,
            "Strict-Transport-Security": lambda v: v and "max-age" in v.lower(),
            "Content-Security-Policy": lambda v: bool(v),
            "Cache-Control": lambda v: v
            and ("no-store" in v.lower() or "no-cache" in v.lower()),
            "Pragma": lambda v: v and "no-cache" in v.lower(),
            "Referrer-Policy": lambda v: bool(v),
            "Permissions-Policy": lambda v: bool(v),
        }

        for header_name, validator in checks.items():
            raw_value = None
            for hk, hv in rh.items():
                if hk.lower() == header_name.lower():
                    raw_value = hv
                    break
            if raw_value is not None:
                headers[header_name] = validator(raw_value) if validator else True
            else:
                headers[header_name] = False

        return headers

    def is_internal_ip(self, ip_address: str) -> bool:
        """Check if an IP address or URL host is private/reserved.

        Args:
            ip_address: IP address string or URL

        Returns:
            True if the IP is private or reserved
        """
        host = ip_address
        if "://" in ip_address:
            try:
                parsed = urlparse(ip_address)
                host = parsed.hostname or ip_address
            except Exception:
                host = ip_address

        ip_patterns = [
            r"^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$",
            r"^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$",
            r"^172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3}$",
            r"^192\.168\.\d{1,3}\.\d{1,3}$",
            r"^169\.254\.\d{1,3}\.\d{1,3}$",
            r"^0\.0\.0\.0$",
            r"^::1$",
            r"^fc00:",
            r"^fe80:",
            r"^localhost$",
            r"^127\.0\.0\.1$",
        ]

        for pattern in ip_patterns:
            if re.match(pattern, host):
                return True

        try:
            addr_info = socket.getaddrinfo(host, None)
            for info in addr_info:
                addr = info[4][0]
                for pattern in ip_patterns:
                    if re.match(pattern, addr):
                        return True
        except Exception:
            pass

        return False

    def _base64url_encode(self, data: str) -> str:
        """Base64url encode a string without padding."""
        return (
            base64.urlsafe_b64encode(data.encode()).rstrip(b"=").decode()
        )
