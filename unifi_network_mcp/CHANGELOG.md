# Changelog

## 0.45.0.1

- Startup now checks the UniFi login once and explains the result in the log in plain words: wrong password or non-local account, two-factor turned on, controller lockout, unreachable address, or a certificate that doesn't match `ssl_fingerprint`.
- Add a container health check on the MCP port, so Supervisor can spot a hung server.
- Still packages `unifi-network-mcp` 0.45.0.

## 0.45.0

- Initial add-on release, packaging `unifi-network-mcp` 0.45.0.
- Streamable HTTP on port 3000 (`/mcp`), bearer-token required, Host-header allowlist.
- Read-only by default; create/update/delete each opt-in, always preview-then-confirm.
