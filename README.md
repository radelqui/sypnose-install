# Sypnose — Universal Claude Code Plugin

One command. Zero dependencies. 14 AI tools instantly available.

## Install (ANY Claude Code, ANY OS)

```bash
claude install-plugin github:radelqui/sypnose-install
```

Or manual:
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
| `deep_query` | LightRAG semantic search |
| `deep_ingest` | Ingest text to RAG |
| `channel_status` | Hub health |
| `channel_publish` | Send message to agents |

### Skills

| Skill | Trigger | Description |
|-------|---------|-------------|
| `/sypnose` | Auto | Full Sypnose protocol |
| `/bios` | `/bios` | Agent identity system |
| `/graphify` | `/graphify` | Knowledge graph builder |

### Hooks

| Event | Hook | Description |
|-------|------|-------------|
| SessionStart | memory-restore | Load previous session state |
| PreCompact | memory-save | Persist state before compaction |
| Stop | memory-persist | Auto-save progress on exit |

### Rules

| Rule | Description |
|------|-------------|
| memory-protocol | Always save/restore state |
| verification | Never declare "done" without evidence |
| worker-delegation | Delegate to workers, never code directly |

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
https://mcp.sypnose.cloud/mcp  (Sypnose Unified MCP v3.0.0)
    |
    | Internal routing (zero latency)
    v
KB(:18791) + Memory(:18796) + LightRAG(:18800) + Hub(:8095)
```

## Requirements

- Claude Code v2.1+ (HTTP transport support)
- That's it. No Node.js. No npm. No Python. Nothing.

## Uninstall

```bash
./uninstall.sh
# or
claude mcp remove sypnose
```
