#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# SYPNOSE UNINSTALLER
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

CLAUDE_HOME="${HOME}/.claude"

echo "[sypnose] Uninstalling..."

# Remove MCP via CLI
if command -v claude &>/dev/null; then
    claude mcp remove sypnose 2>/dev/null || true
fi

# Remove files
rm -rf "$CLAUDE_HOME/rules/sypnose" 2>/dev/null || true
rm -rf "$CLAUDE_HOME/skills/sypnose" 2>/dev/null || true
rm -rf "$CLAUDE_HOME/hooks/sypnose" 2>/dev/null || true
rm -rf "$CLAUDE_HOME/agents/sypnose" 2>/dev/null || true
rm -rf "$CLAUDE_HOME/plugins/sypnose" 2>/dev/null || true

# Remove from .mcp.json (if jq available)
MCP_FILE="$CLAUDE_HOME/.mcp.json"
if [[ -f "$MCP_FILE" ]] && command -v jq &>/dev/null; then
    jq 'del(.mcpServers.sypnose)' "$MCP_FILE" > "${MCP_FILE}.tmp" && mv "${MCP_FILE}.tmp" "$MCP_FILE"
fi

# Remove hooks from hooks.json (best effort)
HOOKS_FILE="$CLAUDE_HOME/hooks.json"
if [[ -f "$HOOKS_FILE" ]] && command -v jq &>/dev/null; then
    jq 'walk(if type == "array" then [.[] | select(.name | startswith("sypnose") | not)] else . end)' \
        "$HOOKS_FILE" > "${HOOKS_FILE}.tmp" && mv "${HOOKS_FILE}.tmp" "$HOOKS_FILE"
fi

echo "[sypnose] Uninstalled. Restart Claude Code."
