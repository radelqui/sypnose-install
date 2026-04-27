# Sypnose v7 — One-line Installer

Setup Claude Code + Claude Desktop to talk to the Sypnose multi-agent system in 1 command.

## Quick Install

### Mac / Linux
```bash
curl -fsSL https://sypnose.cloud/install | bash
```

(or directly from raw GitHub:)
```bash
curl -fsSL https://raw.githubusercontent.com/radelqui/sypnose-install/main/install-local.sh | bash
```

### Windows (PowerShell)
```powershell
iwr https://sypnose.cloud/install.ps1 | iex
```

(or:)
```powershell
irm https://raw.githubusercontent.com/radelqui/sypnose-install/main/install-local.ps1 | iex
```

## What it installs

1. KB Hub (local mirror of shared knowledge base)
2. Sypnose skills: `bios`, `sypnose-create-plan`
3. Slash commands → `~/.claude/commands/`: `/sypnose-execute` v6, `/sypnose-parl-score`
4. MCP wiring to the 4 canonical Sypnose servers (knowledge-hub, sypnose-memory, sypnose-hub, sypnose-lightrag)

After install, restart Claude Code or Claude Desktop and you're operational.

## Tunnels available — 23 HTTPS endpoints
See **[docs/TUNNELS.md](docs/TUNNELS.md)** for the full inventory.

Two Cloudflare tunnels route the entire Sypnose runtime:
- `sypnose-server` (VPS 62.171.147.46) — 8 hostnames: web, KB, Memory, LightRAG, claw-dispatch primary, etc.
- `contabo-server` (Contabo 217.216.48.91) — 15 hostnames: GestoriaRD prod, DGII scraper, OpenClaw, ir2-api, perplexity, etc.

All protected by Cloudflare Access policy (Google Sign-In, 24h session). Authorized emails managed by Carlos.

## Canonical MCP config
[`agent-config-canonical.json`](agent-config-canonical.json) at repo root — drop into your Claude config and you have the 4 MCP servers wired.

## For Claude Code agents joining the system

Tell your Claude this once after install:

```
Read: kb_read key=sm-arquitecto-manual-arranque-v1 project=sypnose
Read: kb_read key=sypnose-agentes-directorio-v1 project=sypnose
Read: kb_read key=cloudflare-tunnels-inventory-270427 project=sypnose
```

Three reads = onboarded. Total time: ~3 minutes.

## Ley §11 — "El arquitecto sabe más que el SM"

Every prompt the SM dispatches MUST include this clause at the end:

> "Tú conoces tu sistema mejor que el SM. Si algo en este prompt no encuadra
> con la realidad de tu repo/servicio, OMÍTELO o MEJÓRALO. Si encuentras un
> falso positivo, corrígelo. Si falta un paso obvio, añádelo. Reporta qué
> cambiaste y por qué."

The SM sees the whole system; the architect knows the inside of their repo.
Without explicit license to correct the prompt, the architect runs literal
and breaks things. Anular esta ley = SM dictador → falsos positivos → tiempo
perdido. Manual SM v1.1 §11 is canonical reference.

## Dry Run

```bash
curl -fsSL https://sypnose.cloud/install -o install.sh && bash install.sh --dry-run
```

```powershell
iwr https://sypnose.cloud/install.ps1 -OutFile install.ps1 ; .\install.ps1 -DryRun
```

## Requirements

- Node.js >= 18
- Git
- Claude Code CLI or Claude Desktop

## Full server install (architects, SREs)

For the full Sypnose server setup (Mithos Dispatch + workers + LightRAG ingest), use `radelqui/sypnose` `install-sypnose-full.sh` (private repo).

## License

MIT
