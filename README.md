# Sypnose v5.2 — Installer

One-line installer for Claude Code + Claude Desktop.

## Quick Install

### Mac / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/radelqui/sypnose-install/main/install-local.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/radelqui/sypnose-install/main/install-local.ps1 | iex
```

## What it does

1. Detects your environment (Node.js, Git, Claude Code, Claude Desktop)
2. Installs KB Hub (local knowledge base)
3. Installs Sypnose skills (bios, sypnose-create-plan)
4. Configures MCP connection

## Dry Run (preview without changes)

### Mac / Linux
```bash
curl -fsSL https://raw.githubusercontent.com/radelqui/sypnose-install/main/install-local.sh -o install.sh && bash install.sh --dry-run
```

### Windows
```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/radelqui/sypnose-install/main/install-local.ps1 -OutFile install.ps1; .\install.ps1 -DryRun
```

## Requirements

- Node.js >= 18
- Git
- Claude Code CLI or Claude Desktop

## License

MIT
