# Sypnose

Universal plugin for Claude Code & Claude Desktop. One command installs everything.

/ `sypnose` → `/registry` → `/graphify` — orchestration, live API/composition registry, and a knowledge-graph engine (HTML + **Mermaid**) so humans and agents can see how any function or server connects.

## Install

You need a Sypnose API key (never hardcoded — you pass it at install time).

**Linux / macOS / WSL:**
```bash
SYPNOSE_KEY=your-key bash -c "$(curl -sfL https://raw.githubusercontent.com/radelqui/sypnose-install/main/install.sh)"
# or, after git clone:
SYPNOSE_KEY=your-key ./install.sh        # also: ./install.sh --key your-key
```

**Windows (PowerShell):**
```powershell
$env:SYPNOSE_KEY="your-key"; irm https://raw.githubusercontent.com/radelqui/sypnose-install/main/install.ps1 | iex
```
If you don't pass the key, the installer prompts for it securely.

Restart Claude Code after install. Type `/sypnose` to start.

### Claude Desktop (no CLI)

Claude Desktop uses the same MCP over HTTPS — add it as a remote connector:

1. Settings → Connectors → Add custom connector.
2. URL: `https://mcp.sypnose.com/mcp`
3. Header: `Authorization: Bearer your-key`
4. Save and restart Desktop. The 14 Sypnose tools appear in the tool list.

The skills/rules/agents/hooks part is Claude Code only; on Desktop you get the MCP tools (KB, Memory Palace, Knowledge Graph, LightRAG, Channel).

## What gets installed

| Component | Count | Description |
|-----------|-------|-------------|
| MCP Server | 1 | 14 tools via HTTPS (zero local deps) |
| `/sypnose` | 1 skill | Unified system: 6 phases, 13 laws, workers, subagents, verification, **registry+graphify** |
| `/registry` | in `/sypnose` | Live API/composition inventory; engine = `/graphify` |
| `/graphify` | 1 skill | Knowledge-graph engine of `/registry` — HTML, **Mermaid (`--mermaid`)**, SVG, Neo4j |
| `/bios` | 1 skill | Agent identity system |
| Rules | 7 | Memory protocol, verification, iron laws, delegation |
| Agents | 4 | architect, developer, verifier, researcher — **all `model: sonnet` (Sonnet 4.6)** |
| Hooks | 3 | Auto-save/restore state (bash + PowerShell variants) |

## Models

All agents, sub-agents and workers run on **`claude-sonnet-4-6`** whenever available.
Gemini (`openai/gemini-2.5-pro` / `-flash`) is a declared fallback only, never the default.

## `/registry` → `/graphify` → Mermaid

```
/graphify <path> --mermaid    # graphify-out/graph.mmd — paste into mermaid.live, or let an agent parse it
registry graph                # shortcut: graphify --mermaid on the current project
registry impact "table X"     # what breaks if I change X (uses the graph)
```

## Architecture

```
Claude Code / Desktop (any machine, any OS)
    |
    | HTTPS POST
    v
https://mcp.sypnose.com/mcp   (nginx + TLS → 127.0.0.1:18900, server 67)
    |
    +-- KB Service (:18791)
    +-- Memory Palace (:18796)
    +-- LightRAG (:18800)
    +-- Channel Hub / A2A (:8095)
```

## Profiles

```bash
./install.sh                    # Full: MCP + skills + rules + agents + hooks
./install.sh --profile minimal  # MCP + skills + rules only
```

## Requirements

- Claude Code v2.1+ (HTTP transport) or Claude Desktop (remote connector)
- A Sypnose API key
- No Node.js, npm, or Python on the client

## Uninstall

```bash
./uninstall.sh      # Linux/macOS/WSL
.\uninstall.ps1     # Windows
```
