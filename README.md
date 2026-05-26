# Sypnose

Universal plugin for Claude Code. One command installs everything.

## Install

**Linux / macOS / WSL:**
```bash
curl -sf https://raw.githubusercontent.com/radelqui/sypnose-install/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/radelqui/sypnose-install/main/install.ps1 | iex
```

**Or clone and install locally:**
```bash
git clone https://github.com/radelqui/sypnose-install.git && cd sypnose-install && ./install.sh
```

Restart Claude Code after install. Type `/sypnose` to start.

## What gets installed

| Component | Count | Description |
|-----------|-------|-------------|
| MCP Server | 1 | 14 tools via HTTP (zero dependencies) |
| `/sypnose` | 1 skill | Unified system: 6 phases, 13 laws, workers, subagents, verification |
| `/graphify` | 1 skill | Knowledge graph builder (code, docs, papers) |
| `/bios` | 1 skill | Agent identity system |
| Rules | 7 | Memory protocol, verification, iron laws, delegation |
| Agents | 4 | architect (opus), developer (sonnet), verifier (haiku), researcher (sonnet) |
| Hooks | 3 | Auto-save/restore state across sessions |

## `/sypnose` — the unified command

Everything in one invocation:

- **6-phase protocol**: read, plan, approve, dispatch, verify, save
- **13 iron laws**: Boris Cherny 2026 + Karpathy 4 Principles + Superpowers
- **Worker dispatch**: claw-dispatch JSON with waves, verification gates, model routing
- **Subagent execution**: fresh per task, two-stage review (spec + quality)
- **TDD plans**: bite-sized steps, no placeholders, actual code
- **Multi-tier verification**: evidence before claims, always
- **10 advanced patterns**: squad mode, competing hypotheses, batch fan-out, ultraplan
- **Agent catalog**: declarative YAML definitions (works with Gemini, DeepSeek, Cursor)
- **Prompt defense**: anti-injection baseline for all workers
- **Instinct system**: continuous learning, pattern capture, skill promotion

## 14 MCP tools

All tools connect to Sypnose cloud backend via HTTP. No local server needed.

| Tool | Description |
|------|-------------|
| `kb_save` / `kb_read` / `kb_search` / `kb_list` / `kb_context` | Knowledge Base (persistent, cross-session) |
| `memory_status` / `memory_search` / `memory_add` | Memory Palace (semantic memory) |
| `memory_kg_query` / `memory_kg_add` | Knowledge Graph |
| `deep_query` / `deep_ingest` | LightRAG (hybrid/local/global/naive search) |
| `channel_status` / `channel_publish` | Inter-agent messaging hub |

## Architecture

```
Claude Code (any machine, any OS)
    |
    | HTTP POST (native transport, v2.1+)
    v
Sypnose Unified MCP v3.0.0
    |
    +-- KB Service (:18791)
    +-- Memory Palace (:18796)
    +-- LightRAG (:18800)
    +-- Channel Hub (:8095)
```

## Profiles

```bash
./install.sh                    # Full (default): MCP + skills + rules + agents + hooks
./install.sh --profile minimal  # MCP + skills + rules only
```

## Requirements

- Claude Code v2.1+ (HTTP transport support)
- That's it. No Node.js. No npm. No Python.

## Uninstall

```bash
claude mcp remove sypnose
rm -rf ~/.claude/skills/{sypnose,graphify,bios}
rm -f ~/.claude/rules/{00-memory-protocol,01-verification,02-sypnose-tools,03-worker-delegation,04-subagent-delegation,05-writing-plans,06-iron-laws}.md
rm -f ~/.claude/agents/{architect,developer,verifier,researcher}.md
```
