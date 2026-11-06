#!/bin/sh
# Build the add-on image and check it starts the way Home Assistant runs it:
# run.sh as the container's main process, options from /data/options.json,
# no stdin. Passes when the MCP endpoint rejects a request without the token
# (401), answers an initialize request with it (200), and rejects an
# unknown Host header (421).
#
# No real controller is needed: the server listens before it connects.
set -eu

ADDON_DIR="${ADDON_DIR:-unifi_network_mcp}"
IMAGE=addon-smoke-test
NAME=addon-smoke-test
PORT=3000

work="$(mktemp -d)"
cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

docker build -t "$IMAGE" "$ADDON_DIR"

token="$(openssl rand -hex 32)"
jq -n --arg token "$token" '{
  controller_host: "192.0.2.1", username: "smoke-test", password: "not-a-real-password",
  site: "default", verify_ssl: false, api_key: "", auth_token: $token,
  allowed_hosts: ["homeassistant.local"],
  allow_create: false, allow_update: false, allow_delete: false, log_level: "info"
}' > "$work/options.json"
chmod 644 "$work/options.json"

docker run -d --name "$NAME" -p "127.0.0.1:$PORT:3000" -v "$work:/data:ro" "$IMAGE" >/dev/null

url="http://127.0.0.1:$PORT/mcp"
init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1"}}}'

status() {
  curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' "$@" -d "$init" "$url" || true
}

fail() {
  echo "SMOKE TEST FAILED: $*" >&2
  echo "--- container logs ---" >&2
  docker logs "$NAME" >&2 2>&1 || true
  exit 1
}

i=0
until [ "$(status)" = "401" ]; do
  i=$((i + 1))
  if [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" != "true" ]; then
    fail "container exited during startup"
  fi
  [ "$i" -lt 60 ] || fail "endpoint never came up"
  sleep 2
done
echo "ok: no token -> 401"

code="$(status -H "Authorization: Bearer $token" -H "Host: homeassistant.local:$PORT")"
[ "$code" = "200" ] || fail "initialize with token returned $code, expected 200"
echo "ok: token + allowed host -> 200"

code="$(status -H "Authorization: Bearer $token" -H "Host: evil.example")"
[ "$code" = "421" ] || fail "unknown Host header returned $code, expected 421"
echo "ok: unknown host -> 421"

docker logs "$NAME" 2>&1 | grep -q "running Streamable HTTP transport only" \
  || fail "server did not run in HTTP-only (PID 1) mode"
echo "ok: HTTP-only mode as PID 1"

echo "Smoke test passed."
