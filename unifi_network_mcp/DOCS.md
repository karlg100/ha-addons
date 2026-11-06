# UniFi Network MCP

Runs the [UniFi Network MCP server](https://github.com/sirkirby/unifi-mcp) inside Home Assistant so an MCP client such as Claude can query and, if you allow it, manage your UniFi network.

## Before you install

1. **Create a dedicated local admin** on your UniFi console (UniFi OS → Admins & Users), e.g. `claude-mcp`. Use a local account rather than your Ubiquiti SSO login, and leave MFA off for this account, since the server can't complete a 2FA prompt. Give it only the role you're comfortable with.
2. **Generate a bearer token** of at least 32 characters, for example in the HA Terminal add-on:
   ```
   openssl rand -hex 32
   ```

## Configuration

| Option | What it does |
|---|---|
| `controller_host` | IP or hostname of the UniFi console |
| `username` / `password` | The local admin account from step 1 |
| `site` | UniFi site, usually `default` |
| `auth_token` | The token from step 2. Every request must send `Authorization: Bearer <token>` |
| `allowed_hosts` | Hostnames/IPs Claude uses to reach HA. Requests with any other `Host` header are rejected |
| `allow_create` / `allow_update` / `allow_delete` | Off by default, which makes the add-on read-only. Even when on, every change goes through a preview-then-confirm step |
| `ssl_fingerprint` | Optional. Pins the console's certificate so the connection is verified even though the UDM's cert is self-signed. Get it with `openssl s_client -connect <udm-ip>:443 </dev/null 2>/dev/null \| openssl x509 -noout -fingerprint -sha256` |
| `api_key` | Optional UniFi Integration API key for a few extra features |

## Connecting Claude Desktop

Add this to `claude_desktop_config.json`, replacing the token:

```json
{
  "mcpServers": {
    "unifi-network": {
      "command": "npx",
      "args": [
        "-y", "mcp-remote",
        "http://homeassistant.local:3000/mcp",
        "--allow-http",
        "--header", "Authorization: Bearer ${UNIFI_MCP_TOKEN}"
      ],
      "env": { "UNIFI_MCP_TOKEN": "paste-your-token-here" }
    }
  }
}
```

Restart Claude Desktop and ask it to list your UniFi devices.

## Updating and rolling back

Every version of this add-on is published as its own image (`ghcr.io/karlg100/<arch>-addon-unifi-network-mcp:<version>`), and published versions are never overwritten or deleted. That is what makes rollback work:

1. When you update, leave **Create backup** ticked in the update dialog (or take a partial backup of just this add-on first).
2. To roll back, go to **Settings → System → Backups**, open that backup, and restore only this add-on. Home Assistant pulls the image for the version recorded in the backup and restores your options with it.

Each version also has a matching GitHub release (`unifi_network_mcp-v<version>`) with its changelog and source.

## Security notes

- The endpoint is plain HTTP on your LAN, protected by the bearer token and the Host allowlist. **Do not port-forward 3000** or expose it through Nabu Casa.
- For access from claude.ai or the mobile app, put an authenticated HTTPS layer in front (for example the upstream project's Cloud Relay) instead of exposing this port.
- Wi-Fi passphrases, VPN keys and similar secrets are redacted from tool results by default.
