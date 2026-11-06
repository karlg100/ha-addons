#!/bin/sh
set -eu

OPTS="${OPTIONS_FILE:-/data/options.json}"
# Note: not `.[$k] // empty`, which would turn a boolean false into "".
opt() { jq -r --arg k "$1" 'if .[$k] == null then empty else .[$k] end' "$OPTS"; }
bool() { if [ "$(opt "$1")" = "true" ]; then echo true; else echo false; fi; }
fail() { echo "[unifi-network-mcp add-on] ERROR: $*" >&2; exit 1; }

# --- Controller connection (local admin account: not Ubiquiti SSO, no MFA) ---
UNIFI_HOST="$(opt controller_host)"
UNIFI_USERNAME="$(opt username)"
UNIFI_SITE="$(opt site)"
UNIFI_VERIFY_SSL="$(bool verify_ssl)"
export UNIFI_HOST UNIFI_USERNAME UNIFI_SITE UNIFI_VERIFY_SSL

PORT_OPT="$(opt controller_port)"
if [ -n "$PORT_OPT" ]; then
  UNIFI_PORT="$PORT_OPT"
  export UNIFI_PORT
fi

# Pins the console's self-signed cert; overrides verify_ssl when set.
FINGERPRINT="$(opt ssl_fingerprint)"
if [ -n "$FINGERPRINT" ]; then
  UNIFI_NETWORK_SSL_FINGERPRINT="$FINGERPRINT"
  export UNIFI_NETWORK_SSL_FINGERPRINT
fi

[ -n "$UNIFI_HOST" ] || fail "controller_host is not set"
[ -n "$UNIFI_USERNAME" ] || fail "username is not set"
[ -n "$(opt password)" ] || fail "password is not set"

# --- Secrets: passed as files, never as environment variables ---
umask 077
SECRETS=/tmp/secrets
mkdir -p "$SECRETS"

opt password | tr -d '\n' > "$SECRETS/password"
export UNIFI_PASSWORD_FILE="$SECRETS/password"

if [ -n "$(opt api_key)" ]; then
  opt api_key | tr -d '\n' > "$SECRETS/api_key"
  export UNIFI_API_KEY_FILE="$SECRETS/api_key"
fi

TOKEN="$(opt auth_token)"
[ "${#TOKEN}" -ge 32 ] || fail "auth_token must be at least 32 characters (generate one with: openssl rand -hex 32)"
printf '%s' "$TOKEN" > "$SECRETS/auth_token"
unset TOKEN
export UNIFI_MCP_HTTP_AUTH_TOKEN_FILE="$SECRETS/auth_token"

# --- HTTP transport ---
export UNIFI_MCP_HTTP_ENABLED=true
export UNIFI_MCP_HOST=0.0.0.0
export UNIFI_MCP_PORT=3000
EXTRA_HOSTS="$(jq -r '(.allowed_hosts // []) | join(",")' "$OPTS")"
export UNIFI_MCP_ALLOWED_HOSTS="localhost,127.0.0.1${EXTRA_HOSTS:+,$EXTRA_HOSTS}"

# --- Write permissions (all off by default = read-only) ---
export UNIFI_TOOL_PERMISSION_MODE=confirm
export UNIFI_REQUIRE_PREVIEW_TOKEN=true
UNIFI_POLICY_CREATE="$(bool allow_create)"
UNIFI_POLICY_UPDATE="$(bool allow_update)"
UNIFI_POLICY_DELETE="$(bool allow_delete)"
export UNIFI_POLICY_CREATE UNIFI_POLICY_UPDATE UNIFI_POLICY_DELETE
# With every write off, also turn on the server's master read-only switch,
# which denies all non-read actions regardless of the gates above.
if [ "$UNIFI_POLICY_CREATE$UNIFI_POLICY_UPDATE$UNIFI_POLICY_DELETE" = "falsefalsefalse" ]; then
  export UNIFI_NETWORK_READ_ONLY=true
fi

UNIFI_MCP_LOG_LEVEL="$(opt log_level | tr '[:lower:]' '[:upper:]')"
export UNIFI_MCP_LOG_LEVEL

echo "[unifi-network-mcp add-on] controller ${UNIFI_HOST} (site ${UNIFI_SITE}); allowed hosts: ${UNIFI_MCP_ALLOWED_HOSTS}"
echo "[unifi-network-mcp add-on] writes: create=${UNIFI_POLICY_CREATE} update=${UNIFI_POLICY_UPDATE} delete=${UNIFI_POLICY_DELETE}"

# Plain-language check of the controller login (one attempt, never blocks startup)
python3 "$(dirname "$0")/preflight.py" || true

# exec so the server is PID 1 and runs HTTP-only (see init: false in config.yaml)
exec unifi-network-mcp
