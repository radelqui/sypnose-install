#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Sypnose — Universal Claude Code Plugin Installer
# One command. Zero dependencies. Linux / macOS / WSL / Git Bash.
#
# Remote install:
#   curl -sf https://raw.githubusercontent.com/radelqui/sypnose-install/main/install.sh | bash
#
# Local install (after git clone):
#   ./install.sh [--profile full|minimal]
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

VERSION="7.1.0"
REPO="https://raw.githubusercontent.com/radelqui/sypnose-install/main"
MCP_URL="${SYPNOSE_URL:-https://mcp.sypnose.com/mcp}"
MCP_KEY="${SYPNOSE_KEY:-}"   # NUNCA hardcodear la key. Se pasa por env o --key.

# ── Paths ────────────────────────────────────────────────────
CLAUDE_HOME="${HOME}/.claude"
SKILLS_DIR="$CLAUDE_HOME/skills"
RULES_DIR="$CLAUDE_HOME/rules"
AGENTS_DIR="$CLAUDE_HOME/agents"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" && pwd 2>/dev/null || echo "/tmp")"

# ── Profile ──────────────────────────────────────────────────
PROFILE="full"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile|-p) PROFILE="$2"; shift 2 ;;
        --key|-k) MCP_KEY="$2"; shift 2 ;;
        --url|-u) MCP_URL="$2"; shift 2 ;;
        --help|-h) echo "Usage: install.sh [--profile full|minimal] [--key SYPNOSE_KEY] [--url MCP_URL]"; exit 0 ;;
        *) shift ;;
    esac
done

# ── Helpers ──────────────────────────────────────────────────
banner() {
    echo ""
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║     SYPNOSE v$VERSION                       ║"
    echo "  ║     Universal Claude Code Plugin          ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo ""
}

ok()   { echo "  [+] $*"; }
warn() { echo "  [!] $*"; }
err()  { echo "  [x] $*"; }

download() {
    local url="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if command -v curl &>/dev/null; then
        curl -sfL "$url" -o "$dest" 2>/dev/null && return 0
    elif command -v wget &>/dev/null; then
        wget -qO "$dest" "$url" 2>/dev/null && return 0
    fi
    warn "Failed: $url"
    return 1
}

has_local() { [[ -d "$SCRIPT_DIR/skills" ]]; }

# ── Step 1: MCP ──────────────────────────────────────────────
install_mcp() {
    echo "  ── MCP Server ──────────────────────────────"

    if command -v claude &>/dev/null; then
        if claude mcp add -s user --transport http \
            -H "Authorization: Bearer $MCP_KEY" \
            sypnose "$MCP_URL" 2>/dev/null; then
            ok "MCP registered: sypnose (via claude CLI)"
            return
        fi
    fi

    # Fallback: scope user real de Claude Code es ~/.claude.json (mcpServers)
    local mcp_file="${HOME}/.claude.json"
    if command -v python3 &>/dev/null; then
        SYP_URL="$MCP_URL" SYP_KEY="$MCP_KEY" MCP_FILE="$mcp_file" python3 << 'PYMERGE'
import json, os
path = os.environ["MCP_FILE"]
try:
    d = json.load(open(path))
except (FileNotFoundError, json.JSONDecodeError):
    d = {}
d.setdefault("mcpServers", {})["sypnose"] = {
    "type": "http",
    "url": os.environ["SYP_URL"],
    "headers": {"Authorization": "Bearer " + os.environ["SYP_KEY"]},
}
json.dump(d, open(path, "w"), indent=2)
PYMERGE
        ok "MCP registered: sypnose (via .claude.json)"
    else
        # Sin python3: solo crear si no existe (no arriesgar pisar config del usuario)
        if [[ ! -f "$mcp_file" ]]; then
            printf '{\n  "mcpServers": {\n    "sypnose": {\n      "type": "http",\n      "url": "%s",\n      "headers": { "Authorization": "Bearer %s" }\n    }\n  }\n}\n' "$MCP_URL" "$MCP_KEY" > "$mcp_file"
            ok "MCP registered: sypnose (via .claude.json)"
        else
            warn "~/.claude.json existe y no hay python3 — anade sypnose manualmente o usa: claude mcp add"
        fi
    fi
}

# ── Step 2: Skills ───────────────────────────────────────────
install_skills() {
    echo "  ── Skills ──────────────────────────────────"

    for skill in sypnose graphify bios; do
        local dest="$SKILLS_DIR/$skill/SKILL.md"
        mkdir -p "$(dirname "$dest")"

        if has_local && [[ -f "$SCRIPT_DIR/skills/$skill/SKILL.md" ]]; then
            cp "$SCRIPT_DIR/skills/$skill/SKILL.md" "$dest"
            ok "/$skill installed (local)"
        elif download "$REPO/skills/$skill/SKILL.md" "$dest"; then
            ok "/$skill installed (remote)"
        else
            err "/$skill FAILED"
        fi
    done

    # graphify-mermaid (motor Mermaid de /registry)
    local tool_dest="$SKILLS_DIR/graphify/tools/graphify-mermaid.py"
    if has_local && [[ -f "$SCRIPT_DIR/tools/graphify-mermaid.py" ]]; then
        mkdir -p "$(dirname "$tool_dest")"; cp "$SCRIPT_DIR/tools/graphify-mermaid.py" "$tool_dest"
        ok "graphify-mermaid installed (local)"
    elif download "$REPO/tools/graphify-mermaid.py" "$tool_dest"; then
        ok "graphify-mermaid installed (remote)"
    fi
}

# ── Step 3: Rules ────────────────────────────────────────────
install_rules() {
    echo "  ── Rules ───────────────────────────────────"
    mkdir -p "$RULES_DIR"
    local count=0

    for rule in 00-memory-protocol.md 01-verification.md 02-sypnose-tools.md \
                03-worker-delegation.md 04-subagent-delegation.md \
                05-writing-plans.md 06-iron-laws.md; do
        local dest="$RULES_DIR/$rule"
        if has_local && [[ -f "$SCRIPT_DIR/rules/$rule" ]]; then
            cp "$SCRIPT_DIR/rules/$rule" "$dest"; count=$((count+1))
        elif download "$REPO/rules/$rule" "$dest"; then
            count=$((count+1))
        fi
    done
    ok "$count rules installed"
}

# ── Step 4: Agents ───────────────────────────────────────────
install_agents() {
    echo "  ── Agents ──────────────────────────────────"
    mkdir -p "$AGENTS_DIR"
    local count=0

    for agent in architect.md developer.md verifier.md researcher.md; do
        local dest="$AGENTS_DIR/$agent"
        if has_local && [[ -f "$SCRIPT_DIR/agents/$agent" ]]; then
            cp "$SCRIPT_DIR/agents/$agent" "$dest"; count=$((count+1))
        elif download "$REPO/agents/$agent" "$dest"; then
            count=$((count+1))
        fi
    done
    ok "$count agents installed"
}

# ── Step 5: Hooks ────────────────────────────────────────────
install_hooks() {
    echo "  ── Hooks ───────────────────────────────────"
    local hooks_file="$CLAUDE_HOME/hooks.json"
    local scripts_dir="$CLAUDE_HOME/hooks/sypnose"
    mkdir -p "$scripts_dir"

    # hooks.json — MERGE si existe, copiar si no
    local src_hooks="/tmp/sypnose-hooks.json"
    if has_local && [[ -f "$SCRIPT_DIR/hooks/hooks.json" ]]; then
        cp "$SCRIPT_DIR/hooks/hooks.json" "$src_hooks"
    else
        download "$REPO/hooks/hooks.json" "$src_hooks" || true
    fi
    if [[ -f "$src_hooks" ]]; then
        if [[ ! -f "$hooks_file" ]]; then
            cp "$src_hooks" "$hooks_file"
        elif command -v python3 &>/dev/null; then
            python3 - "$hooks_file" "$src_hooks" << 'PYEOF'
import json, sys
dst_f, src_f = sys.argv[1], sys.argv[2]
dst = json.load(open(dst_f)); src = json.load(open(src_f))
hooks = dst.setdefault("hooks", {})
for event, entries in src.get("hooks", {}).items():
    cur = hooks.setdefault(event, [])
    names = {e.get("name") for e in cur if isinstance(e, dict)}
    for e in entries:
        if e.get("name") not in names:
            cur.append(e)
json.dump(dst, open(dst_f, "w"), indent=2)
PYEOF
        else
            warn "hooks.json existe y no hay python3 para merge — revisa manualmente"
        fi
    fi

    # hook scripts
    for script in session-start.sh pre-compact.sh stop.sh; do
        if has_local && [[ -f "$SCRIPT_DIR/hooks/scripts/$script" ]]; then
            cp "$SCRIPT_DIR/hooks/scripts/$script" "$scripts_dir/$script"
        else
            download "$REPO/hooks/scripts/$script" "$scripts_dir/$script" || true
        fi
    done
    chmod +x "$scripts_dir"/*.sh 2>/dev/null || true
    ok "3 hooks installed"
}

# ── Verify ───────────────────────────────────────────────────
verify() {
    echo ""
    echo "  ── Verification ────────────────────────────"
    local pass=0 fail=0

    # MCP (CLI primero, luego ~/.claude.json)
    if command -v claude &>/dev/null && claude mcp list 2>/dev/null | grep -q "sypnose"; then
        ok "MCP config: OK (claude CLI)"; pass=$((pass+1))
    elif [[ -f "${HOME}/.claude.json" ]] && grep -q '"sypnose"' "${HOME}/.claude.json"; then
        ok "MCP config: OK (~/.claude.json)"; pass=$((pass+1))
    else err "MCP config: MISSING"; fail=$((fail+1)); fi

    # Skill
    if [[ -f "$SKILLS_DIR/sypnose/SKILL.md" ]]; then
        local lines=$(wc -l < "$SKILLS_DIR/sypnose/SKILL.md")
        ok "/sypnose skill: OK ($lines lines)"; pass=$((pass+1))
    else err "/sypnose skill: MISSING"; fail=$((fail+1)); fi

    # Rules
    local rc=$(find "$RULES_DIR" -name "*.md" 2>/dev/null | wc -l)
    if [[ $rc -ge 5 ]]; then ok "Rules: OK ($rc files)"; pass=$((pass+1))
    else err "Rules: MISSING ($rc files)"; fail=$((fail+1)); fi

    # Agents
    local ac=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l)
    if [[ $ac -ge 3 ]]; then ok "Agents: OK ($ac files)"; pass=$((pass+1))
    else warn "Agents: $ac files"; fail=$((fail+1)); fi

    echo ""
    if [[ $fail -eq 0 ]]; then
        echo "  ╔═══════════════════════════════════════════╗"
        echo "  ║  ALL $pass CHECKS PASSED                      ║"
        echo "  ║                                           ║"
        echo "  ║  Restart Claude Code to activate.         ║"
        echo "  ║  Then type /sypnose to get started.       ║"
        echo "  ╚═══════════════════════════════════════════╝"
    else
        echo "  ╔═══════════════════════════════════════════╗"
        echo "  ║  $fail CHECKS FAILED — see errors above       ║"
        echo "  ╚═══════════════════════════════════════════╝"
    fi
    echo ""
}

# ── Key check ────────────────────────────────────────────────
require_key() {
    if [[ -z "$MCP_KEY" ]]; then
        if [[ -t 0 ]]; then
            read -r -s -p "  Sypnose API key: " MCP_KEY; echo ""
        fi
    fi
    if [[ -z "$MCP_KEY" ]]; then
        err "Falta la API key. Usa: SYPNOSE_KEY=xxx bash install.sh  (o --key xxx)"
        err "Pide tu key en: https://github.com/radelqui/sypnose-install#getting-a-key"
        exit 1
    fi
}

# ── Main ─────────────────────────────────────────────────────
banner
require_key
install_mcp

case "$PROFILE" in
    full)
        install_skills
        install_rules
        install_agents
        install_hooks
        ;;
    minimal)
        install_skills
        install_rules
        ;;
esac

verify
