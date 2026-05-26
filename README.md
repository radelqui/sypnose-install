# Sypnose — Universal Claude Code Plugin

One command. Zero dependencies. 14 AI tools + 8 skills + 7 rules + 4 agents + 3 hooks.

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

## What You Get

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

### 8 Skills

| Skill | Trigger | Description |
|-------|---------|-------------|
| `/sypnose` | crear plan, dispatch, wave | Full Sypnose SM protocol v3 (Boris + Karpathy + Iron Laws) |
| `/sypnose-execute` | ejecutar | Architect execution protocol — workers, never direct code |
| `/sypnose-create-plan` | crear dispatch | Create and validate claw-dispatch JSON for workers |
| `/graphify` | `/graphify` | Any input to knowledge graph (code, docs, papers, images, video) |
| `/bios` | `/bios` | Agent identity system via KB |
| `verification-before-completion` | before claiming done | Evidence before assertions, always |
| `subagent-driven-development` | executing with subagents | Fresh subagent per task + two-stage review |
| `writing-plans` | writing implementation plans | Bite-sized TDD plans with zero placeholders |
| `executing-plans` | executing existing plans | Load plan, review, execute, verify |

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
