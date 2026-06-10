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

# Quitar sypnose de ~/.claude.json y hooks de hooks.json (python3, con fallback jq)
USER_JSON="${HOME}/.claude.json"
HOOKS_FILE="$CLAUDE_HOME/hooks.json"
if command -v python3 &>/dev/null; then
    UJ="$USER_JSON" HF="$HOOKS_FILE" python3 << 'PYCLEAN'
import json, os
uj = os.environ["UJ"]
if os.path.exists(uj):
    try:
        d = json.load(open(uj)); d.get("mcpServers", {}).pop("sypnose", None)
        json.dump(d, open(uj, "w"), indent=2)
    except Exception: pass
hf = os.environ["HF"]
if os.path.exists(hf):
    try:
        h = json.load(open(hf))
        for ev in list(h.get("hooks", {})):
            h["hooks"][ev] = [e for e in h["hooks"][ev]
                              if not str(e.get("name", "")).startswith("sypnose")]
        json.dump(h, open(hf, "w"), indent=2)
    except Exception: pass
PYCLEAN
elif command -v jq &>/dev/null; then
    [[ -f "$USER_JSON" ]] && jq 'del(.mcpServers.sypnose)' "$USER_JSON" > "${USER_JSON}.tmp" && mv "${USER_JSON}.tmp" "$USER_JSON"
    [[ -f "$HOOKS_FILE" ]] && jq 'walk(if type == "array" then [.[] | select((.name // "") | startswith("sypnose") | not)] else . end)' \
        "$HOOKS_FILE" > "${HOOKS_FILE}.tmp" && mv "${HOOKS_FILE}.tmp" "$HOOKS_FILE"
fi
echo "[sypnose] Uninstalled. Restart Claude Code."
