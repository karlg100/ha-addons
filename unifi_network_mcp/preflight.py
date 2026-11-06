"""Startup login check for the UniFi Network MCP add-on.

Tries one login against the controller and logs, in plain words, whether the
add-on's credentials work and what to fix if they don't. It never stops the
add-on from starting: the server still runs and keeps retrying on its own.

Reads the same environment run.sh exports for the server, and never logs the
password. Only one attempt is made, so it can't trip the controller's lockout.
"""

import hashlib
import json
import os
import socket
import ssl
import sys
import urllib.error
import urllib.request

PREFIX = "[unifi-network-mcp add-on]"
TIMEOUT = 8


class FingerprintMismatch(Exception):
    pass


def log(level, msg):
    print(f"{PREFIX} {level}: {msg}", flush=True)


def read_secret(var):
    path = os.environ.get(var)
    if not path:
        return ""
    with open(path, encoding="utf-8") as f:
        return f.read().rstrip("\n")


def tls_context(host, port):
    """Match the server's TLS settings: pinned fingerprint, verified, or off."""
    fingerprint = os.environ.get("UNIFI_NETWORK_SSL_FINGERPRINT", "")
    if fingerprint:
        want = fingerprint.replace(":", "").lower()
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        with socket.create_connection((host, port), TIMEOUT) as raw:
            with ctx.wrap_socket(raw, server_hostname=host) as tls:
                got = hashlib.sha256(tls.getpeercert(binary_form=True)).hexdigest()
        if got != want:
            raise FingerprintMismatch(got)
        return ctx
    if os.environ.get("UNIFI_VERIFY_SSL") == "true":
        return ssl.create_default_context()
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def try_login(base, path, body, ctx):
    req = urllib.request.Request(
        base + path,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def main():
    host = os.environ.get("UNIFI_HOST", "")
    port = int(os.environ.get("UNIFI_PORT", "443"))
    user = os.environ.get("UNIFI_USERNAME", "")
    password = read_secret("UNIFI_PASSWORD_FILE")
    where = f"{host}:{port}" if port != 443 else host

    log("INFO", f"checking login to the controller at {where} as '{user}'...")

    try:
        ctx = tls_context(host, port)
    except FingerprintMismatch as e:
        log("ERROR", f"the controller's certificate doesn't match ssl_fingerprint "
                     f"(it presents {e}). Nothing was sent. Update ssl_fingerprint if the "
                     "console's certificate changed, or check controller_host.")
        return
    except ssl.SSLError as e:
        log("ERROR", f"could not verify the controller's certificate: {e}. "
                     "Check ssl_fingerprint (or verify_ssl) in the add-on configuration.")
        return
    except OSError as e:
        log("ERROR", f"could not reach the controller at {where} ({e}). "
                     "Check controller_host and controller_port, and that Home Assistant can reach it.")
        return

    body = json.dumps({"username": user, "password": password, "rememberMe": False}).encode()
    base = f"https://{host}:{port}"
    try:
        # UniFi OS consoles (UDM, UCG, Cloud Key Gen2+), then self-hosted Network app
        status, data = try_login(base, "/api/auth/login", body, ctx)
        if status == 404:
            status, data = try_login(base, "/api/login", body, ctx)
    except ssl.SSLError as e:
        log("ERROR", f"TLS error talking to the controller at {where}: {e}. "
                     "Turn verify_ssl off, or set ssl_fingerprint to pin its certificate.")
        return
    except (OSError, urllib.error.URLError) as e:
        log("ERROR", f"could not reach the controller at {where} ({e}). "
                     "Check controller_host and controller_port, and that Home Assistant can reach it.")
        return

    text = data.decode("utf-8", "replace").lower()
    if 200 <= status < 300:
        log("INFO", "login OK: the username and password are accepted by the controller.")
    elif status == 499 or "mfa" in text or "2fa" in text or "totp" in text:
        log("ERROR", f"login refused (HTTP {status}): the account '{user}' has two-factor "
                     "authentication turned on. Use a local admin account without MFA.")
    elif status in (401, 403):
        log("ERROR", f"login refused (HTTP {status}): the password is incorrect for '{user}', "
                     "or that account doesn't exist, isn't a local account (a Ubiquiti/ui.com "
                     "SSO login won't work), or has no access to the Network app. "
                     "Retype the password in the add-on configuration and restart.")
    elif status == 429:
        log("ERROR", "login refused (HTTP 429): the controller is temporarily blocking logins "
                     "after too many failed attempts. Wait 5-10 minutes, then restart the add-on.")
    else:
        log("WARNING", f"unexpected answer to the login (HTTP {status}). "
                       "The server will still try to connect; check its log below.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # never block startup on a diagnostics bug
        log("WARNING", f"login check skipped ({type(e).__name__}: {e})")
    sys.exit(0)
