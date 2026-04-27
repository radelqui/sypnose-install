# Sypnose Tunnels — Public HTTPS Endpoints

Updated: 2026-04-27 — 23 tunnels active across 2 Cloudflare connectors.

## Auth
All tunnels protected by **Cloudflare Access policy**:
- Auth method: Google Sign-In
- Session: 24h
- Authorized emails: managed by Carlos in Cloudflare Zero Trust dashboard
- Service tokens available for automation (`CF-Access-Client-Id` + `CF-Access-Client-Secret` headers)

## Tunnel 1 — sypnose-server (VPS Sypnose 62.171.147.46)
UUID: `aa228030-2b0d-4ee2-bc9a-1e990b87d7b9`

| Hostname | Backend | Purpose |
|---|---|---|
| `sypnose.cloud` | localhost:3001 | Web pública |
| `kb.sypnose.cloud` | localhost:18791 | Knowledge Hub REST + SSE |
| `memory.sypnose.cloud` | localhost:18792 | Sypnose Memory Palace MCP |
| `proxy.sypnose.cloud` | localhost:8317 | CLIProxyAPI (46 LLMs) |
| `sse.sypnose.cloud` | localhost:8095 | Sypnose SSE general |
| `lightrag.sypnose.cloud` | localhost:18794 | LightRAG SSE primary |
| `chat.sypnose.cloud` | localhost:9100 | Chat UI |
| `claw.sypnose.cloud` | localhost:18830 | claw-dispatch primary executor |

## Tunnel 2 — contabo-server (Contabo 217.216.48.91) — added 2026-04-27
UUID: `70258c97-46b0-4aa5-9a14-d50c96170173`

| Hostname | Backend | Purpose |
|---|---|---|
| `oc.sypnose.cloud` | localhost:18790 | OpenClaw health-api |
| `kb217.sypnose.cloud` | localhost:18791 | KB local Contabo (mirror DB) |
| `mem217.sypnose.cloud` | localhost:18792 | sypnose-memory local |
| `hub.sypnose.cloud` | localhost:18793 | sypnose-hub SSE bus |
| `lightragsse.sypnose.cloud` | localhost:18794 | LightRAG SSE local |
| `mithos.sypnose.cloud` | localhost:18810 | Mithos legacy dispatcher |
| `claw217.sypnose.cloud` | localhost:18830 | claw-dispatch Contabo |
| `gestoriard.sypnose.cloud` | localhost:3080 | GestoriaRD WAF (prod) |
| `sse217.sypnose.cloud` | localhost:8095 | sypnose-sse v5.2 |
| `cliproxy217.sypnose.cloud` | localhost:8317 | CLIProxyAPI 217 |
| `perplexity.sypnose.cloud` | localhost:8318 | Perplexity proxy |
| `ir2.sypnose.cloud` | localhost:8319 | DGII IR-2 FastAPI |
| `ococliproxy.sypnose.cloud` | localhost:8320 | OpenClaw cliproxy dedicated |
| `dgii.sypnose.cloud` | localhost:8321 | DGII scraper API |
| `rag.sypnose.cloud` | localhost:8322 | DGII RAG SharePoint |

## Add tunnel to your Claude config
See `agent-config-canonical.json` at repo root.

Direct REST APIs (not MCP) — use `fetch`/`curl` with Cloudflare Access cookies or service tokens.

