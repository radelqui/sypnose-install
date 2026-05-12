# @sypnose/mcp-ssh

Multi-host SSH wrapper around the upstream package `tufantunc/ssh-mcp@1.5.0`.

## Why this package exists

`tufantunc/ssh-mcp` is single-host per MCP instance (host/port/user/key are fixed at process start). To target multiple servers (e.g. a production box plus a worker VPS) you need N instances, each with a different name and configuration.

This Sypnose package does NOT ship its own server code. Instead it:

1. Declares the multi-host pattern in `manifest.json` (see `default_profiles`).
2. Lets `install.sh` / `install.ps1` inject one MCP entry per profile into the user's `~/.claude.json` via a `jq` (Linux/Mac) or PowerShell (Windows) merge.

Each profile becomes a tool in Claude Code:

| Profile  | Tool name                |
|----------|--------------------------|
| ssh-217  | `mcp__ssh-217__exec`     |
| ssh-67   | `mcp__ssh-67__exec`      |

## Default profiles (v8.1.0)

| Name    | Host             | Port | User    | Default key                       |
|---------|------------------|------|---------|-----------------------------------|
| ssh-217 | 217.216.48.91    | 2024 | gestoria| `~/.ssh/id_rsa`                   |
| ssh-67  | 62.171.147.46    | 2024 | sypnose | `~/.ssh/id_ed25519_radelqui`      |

The user can override the key path per host via env vars: `SYPNOSE_SSH_217_KEY`, `SYPNOSE_SSH_67_KEY`.

## Adding a new host

1. Edit `manifest.json` → `mcpServers[name=ssh-mcp].default_profiles[]` and append a new profile.
2. Reinstall the plugin (`install.sh` or `install.ps1`). The installer is idempotent.

## Troubleshooting

- `All configured authentication methods failed` → wrong key for that host. Check the key listed in `~/.ssh/authorized_keys` on the target server matches your local `id_rsa.pub` / `id_ed25519.pub`.
- Tool not visible after install → restart Claude Code (MCP servers load at startup).
- `npx -y ssh-mcp` slow first run → pulls package once, cached afterwards.
