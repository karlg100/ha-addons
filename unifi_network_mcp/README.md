# UniFi Network MCP

![Supports aarch64][aarch64-shield] ![Supports amd64][amd64-shield] ![Read-only by default][readonly-shield]

Ask Claude about your UniFi network in plain language, and let it make changes only when you say so.

This add-on runs the [UniFi Network MCP server][upstream] by sirkirby inside Home Assistant. It connects to your UniFi console (UDM, UCG, Cloud Key or self-hosted Network app) and gives Claude, or any other MCP client, a set of tools for your network.

## What you can ask

- "Which clients are on the IoT network, and which have weak signal?"
- "Has anything dropped off the network in the last hour?"
- "Show me my APs' channel use and any rogue APs nearby."
- "Are any of my firewall rules redundant or conflicting?"
- "Give me a quick health check of the whole network."

## Safe by default

- **Read-only until you opt in.** Creating, changing and deleting are separate switches, all off. Even when on, every change shows a preview and needs confirmation.
- **Token-protected.** Every request needs a bearer token you generate, and requests to unknown hostnames are refused.
- **Secrets stay hidden.** Wi-Fi passphrases, VPN keys and similar values are redacted from everything Claude sees.
- **LAN only.** It listens on your network, not the internet.

## Before you install

You need two things, and the **Documentation** tab walks through both:

1. A **local admin account** on your UniFi console, for example `claude-mcp`, without MFA. A Ubiquiti SSO login won't work.
2. A **bearer token** of at least 32 characters, for example from `openssl rand -hex 32`.

## Rolling back

Every version is published as its own image and never overwritten. Leave **Create backup** ticked when updating, and restoring that backup brings back the previous version exactly.

---

Not affiliated with or endorsed by Ubiquiti. UniFi is a trademark of Ubiquiti Inc.

[upstream]: https://github.com/sirkirby/unifi-mcp
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[readonly-shield]: https://img.shields.io/badge/writes-off_by_default-blue.svg
