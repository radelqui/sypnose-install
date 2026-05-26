# Sypnose Install — Plugin Repository

## What This Is
This is the installer for the Sypnose Claude Code plugin.
It gives any Claude Code access to 14 AI tools (KB, Memory Palace, LightRAG, Channel).

## For Users (Installing)
Run: `./install.sh` (Linux/Mac) or `.\install.ps1` (Windows)

## For Developers (Contributing)

### Structure
```
sypnose-install/
  install.sh          # Unix installer
  install.ps1         # Windows installer
  uninstall.sh        # Cleanup
  rules/              # Rules injected to ~/.claude/rules/sypnose/
    00-memory-protocol.md
    01-verification.md
    02-sypnose-tools.md
    03-worker-delegation.md
  skills/             # Skills copied to ~/.claude/skills/sypnose/
    sypnose/SKILL.md
    bios/SKILL.md
    graphify/SKILL.md
  hooks/              # Hooks merged into ~/.claude/hooks.json
    hooks.json
    scripts/          # Hook scripts copied to ~/.claude/hooks/sypnose/
  agents/             # Agent definitions -> ~/.claude/agents/sypnose/
    architect.md
    developer.md
    verifier.md
    researcher.md
  mcp-configs/        # Reference MCP config (used by installer)
    sypnose.json
```

### Adding a New Skill
1. Create `skills/<name>/SKILL.md`
2. Use YAML frontmatter: name, description, trigger
3. Document: When to Activate, Workflow, Quality Rules
4. Test: `./install.sh --profile dev` then verify in Claude Code

### Adding a New Rule
1. Create `rules/NN-<name>.md` (NN = priority number)
2. Keep it concise (Claude Code injects ALL rules every turn)
3. Test: `./install.sh --profile minimal` then verify

### Adding a New Agent
1. Create `agents/<name>.md`
2. YAML frontmatter: name, description, tools, model
3. Define: Role, Workflow, Output Format, Rules
4. Test: verify Claude Code can invoke via sub-agent

## Server Side
The MCP server runs on Contabo VPS 67:
- Service: `sypnose-unified.service`
- Port: 18900
- Source: `/home/shared/sypnose-mcp-unified/index.js`
- Transports: Streamable HTTP (/mcp) + SSE (/sse)
