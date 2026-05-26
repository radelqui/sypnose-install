# Sypnose — Universal Claude Code Plugin

One command. Zero dependencies. `/sypnose` = everything.

14 MCP tools + 3 skills + 7 rules + 4 agents + 3 hooks.

## Install (ANY Claude Code, ANY OS)

```bash
git clone https://github.com/radelqui/sypnose-install.git ~/.claude/plugins/sypnose
cd ~/.claude/plugins/sypnose && ./install.sh
```

Windows:
```powershell
git clone https://github.com/radelqui/sypnose-install.git $env:USERPROFILE\.claude\plugins\sypnose
cd $env:USERPROFILE\.claude\plugins\sypnose; .\install.ps1
```

## After Install

Type `/sypnose` in Claude Code. That's it. Everything is there:
- 6-phase protocol (read, plan, approve, dispatch, verify, save)
- 13 iron laws (Boris + Karpathy + Superpowers)
- Worker dispatch (claw-dispatch JSON with waves + verification)
- Subagent execution (fresh per task + two-stage review)
- TDD plans (bite-sized, no placeholders)
- Multi-tier verification (evidence before claims)
- 10 advanced patterns (squad mode, competing hypotheses, batch fan-out...)
- 14 MCP tools reference

## What You Get

### `/sypnose` — The Unified Command (v4)

ONE command that includes EVERYTHING: plan creation, execution protocols,
worker dispatch, subagent management, verification, and all 13 iron laws.

Previously split across 8 separate skills, now unified in a single invocation.

### 14 MCP Tools (HTTP native — NO Node.js)

| Tool | Description |
|------|-------------|
| `kb_save` | Save knowledge entry |
| `kb_read` | Read by key |
| `kb_search` | Full-text search |
| `kb_list` | List with filters |
| `kb_context` | Top HOT entries |
| `memory_status` | Memory Palace stats |
| `memory_search` | Semantic search |
| `memory_add` | Add memory drawer |
| `memory_kg_query` | Query knowledge graph |
| `memory_kg_add` | Add KG fact |
| `deep_query` | LightRAG semantic search (hybrid/local/global/naive) |
| `deep_ingest` | Ingest text to RAG |
| `channel_status` | Hub health |
| `channel_publish` | Send message to agents |

### 3 Skills

| Skill | Trigger | Description |
|-------|---------|-------------|
| `/sypnose` | plan, execute, dispatch, verify | **UNIFIED** — 6 phases, 13 laws, workers, subagents, verification, TDD plans |
| `/graphify` | `/graphify` | Any input to knowledge graph (code, docs, papers, images, video) |
| `/bios` | `/bios` | Agent identity system via KB |

### 7 Rules

| Rule | Source | Description |
|------|--------|-------------|
| memory-protocol | Sypnose | Always save/restore state across sessions |
| verification | Sypnose + Boris | Never declare "done" without concrete evidence |
| sypnose-tools | Sypnose | Quick reference for all 14 MCP tools |
| worker-delegation | Sypnose | Coordinators delegate, workers execute |
| subagent-delegation | Superpowers | Fresh subagent per task + review gates |
| writing-plans | Superpowers | TDD plans with actual code, no placeholders |
| iron-laws | Boris + Karpathy | 13 non-negotiable rules for quality work |

### 4 Agents

| Agent | Model | Description |
|-------|-------|-------------|
| architect | opus | System design, trade-offs, plans |
| developer | sonnet | Implementation, bug fixes, tests |
| verifier | haiku | QA verification with evidence |
| researcher | sonnet | Web search, docs, competitive analysis |

### 3 Hooks

| Event | Hook | Description |
|-------|------|-------------|
| SessionStart | memory-restore | Load .brain/ state on start |
| PreCompact | memory-save | Save state before compaction |
| Stop | memory-persist | Auto-commit .brain/ on exit |

## Profiles

```bash
./install.sh --profile full      # Everything (default)
./install.sh --profile minimal   # MCP + rules only
./install.sh --profile dev       # MCP + rules + skills + hooks
./install.sh --profile server    # MCP + SSH + tmux session management
```

## Architecture

```
Your Claude Code (any machine, any OS)
    |
    | HTTP POST (native — Claude Code v2.1+ built-in)
    | Zero bridge, zero npm, zero dependencies
    v
http://62.171.147.46:18900/mcp  (Sypnose Unified MCP v3.0.0)
    |
    | Internal routing (zero latency)
    v
KB(:18791) + Memory(:18796) + LightRAG(:18800) + Hub(:8095)
```

## vs Everything-Claude-Code (ECC)

| Feature | ECC | Sypnose |
|---------|-----|---------|
| Install deps | Node.js required | Zero (HTTP native) |
| MCP Tools | 6 external MCPs | 14 own tools on own backend |
| Knowledge Graph | No | memory_kg_add/query + /graphify |
| Semantic Search | Basic | LightRAG 4 modes + Memory Palace |
| Inter-agent Comms | No | Channel Hub |
| Cross-session Memory | Local files only | KB cloud + Memory Palace |
| Worker Dispatch | No | claw-dispatch with Gemini workers |
| Skills | 250+ (generic) | 8 battle-tested (from production) |
| Rules | 30+ (by language) | 7 universal (from 24 failure memories) |

## Requirements

- Claude Code v2.1+ (HTTP transport support)
- That's it. No Node.js. No npm. No Python. Nothing.

## Uninstall

```bash
./uninstall.sh
# or
claude mcp remove sypnose
```
