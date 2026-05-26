# Sypnose Tools Reference — Quick Guide

You have 14 MCP tools from Sypnose. Use them proactively.

## Knowledge Base (persistent storage)
- `kb_save` — Save entry: `{key, content, category?, project?}`
- `kb_read` — Read by key: `{key, project?}`
- `kb_search` — Search: `{query, category?, project?, limit?}`
- `kb_list` — List entries: `{category?, project?, limit?}`
- `kb_context` — Get HOT entries: `{limit?}`

## Memory Palace (semantic memory)
- `memory_status` — Stats and health check
- `memory_search` — Semantic search: `{query, limit?}`
- `memory_add` — Add memory: `{content, category?, tags?}`
- `memory_kg_query` — Query knowledge graph: `{query}`
- `memory_kg_add` — Add KG fact: `{subject, predicate, object}`

## LightRAG (deep semantic search)
- `deep_query` — Search with modes: `{query, mode?}` (modes: hybrid/local/global/naive)
- `deep_ingest` — Ingest text: `{content, source?}`

## Channel (inter-agent communication)
- `channel_status` — Hub health check
- `channel_publish` — Send message: `{channel, message, from?}`

## When to Use What
- **Quick lookup** → `kb_read` (exact key)
- **Find something** → `kb_search` (text) or `memory_search` (semantic)
- **Save progress** → `memory_add` (session state) or `kb_save` (permanent knowledge)
- **Deep research** → `deep_query` with mode="hybrid"
- **Connect facts** → `memory_kg_add` then `memory_kg_query`
- **Talk to other agents** → `channel_publish`
