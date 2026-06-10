#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# SYPNOSE UNINSTALLER
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
CLAUDE_HOME="${HOME}/.claude"
echo "[sypnose] Uninstalling..."

command -v claude &>/dev/null && claude mcp remove sypnose 2>/dev/null || true

rm -rf "$CLAUDE_HOME/skills/sypnose" "$CLAUDE_HOME/skills/graphify" "$CLAUDE_HOME/skills/bios" 2>/dev/null || true
rm -rf "$CLAUDE_HOME/hooks/sypnose" 2>/dev/null || true
for r in 00-memory-protocol 01-verification 02-sypnose-tools 03-worker-delegation 04-subagent-delegation 05-writing-plans 06-iron-laws; do
    rm -f "$CLAUDE_HOME/rules/$r.md" 2>/dev/null || true
done
for a in architect developer verifier researcher; do
    rm -f "$CLAUDE_HOME/agents/$a.md" 2>/dev/null || true
done

# Quitar sypnose de ~/.claude.json (scope user real)
USER_JSON="${HOME}/.claude.json"
if [[ -f "$USER_JSON" ]] && command -v jq &>/dev/null; then
    jq 'del(.mcpServers.sypnose)' "$USER_JSON" > "${USER_JSON}.tmp" && mv "${USER_JSON}.tmp" "$USER_JSON"
fi
# Quitar hooks sypnose de hooks.json
HOOKS_FILE="$CLAUDE_HOME/hooks.json"
if [[ -f "$HOOKS_FILE" ]] && command -v jq &>/dev/null; then
    jq 'walk(if type == "array" then [.[] | select((.name // "") | startswith("sypnose") | not)] else . end)' \
        "$HOOKS_FILE" > "${HOOKS_FILE}.tmp" && mv "${HOOKS_FILE}.tmp" "$HOOKS_FILE"
fi
echo "[sypnose] Uninstalled. Restart Claude Code."
