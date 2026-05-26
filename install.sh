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

VERSION="2.0.0"
REPO="https://raw.githubusercontent.com/radelqui/sypnose-install/main"
MCP_URL="http://62.171.147.46:18900/mcp"
MCP_KEY="21ff9b26fd454001328aaf60774f332d45138112f689af3a9b34de3dc5845589"

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
        --help|-h) echo "Usage: install.sh [--profile full|minimal]"; exit 0 ;;
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

    # Fallback: write .mcp.json
    local mcp_file="$CLAUDE_HOME/.mcp.json"
    local sypnose_json='{
  "type": "http",
  "url": "'"$MCP_URL"'",
  "headers": { "Authorization": "Bearer '"$MCP_KEY"'" }
}'

    mkdir -p "$CLAUDE_HOME"
    if [[ -f "$mcp_file" ]] && command -v jq &>/dev/null; then
        jq --argjson s "$sypnose_json" '.mcpServers.sypnose = $s' "$mcp_file" > "${mcp_file}.tmp" \
            && mv "${mcp_file}.tmp" "$mcp_file"
    elif [[ -f "$mcp_file" ]] && command -v python3 &>/dev/null; then
        python3 -c "
import json
f='$mcp_file'
d=json.load(open(f))
d.setdefault('mcpServers',{})['sypnose']=json.loads('$sypnose_json')
json.dump(d,open(f,'w'),indent=2)
"
    else
        cat > "$mcp_file" << EOF
{ "mcpServers": { "sypnose": $sypnose_json } }
EOF
    fi
    ok "MCP registered: sypnose (via .mcp.json)"
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
            cp "$SCRIPT_DIR/rules/$rule" "$dest"; ((count++))
        elif download "$REPO/rules/$rule" "$dest"; then
            ((count++))
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
            cp "$SCRIPT_DIR/agents/$agent" "$dest"; ((count++))
        elif download "$REPO/agents/$agent" "$dest"; then
            ((count++))
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

    # hooks.json
    if [[ ! -f "$hooks_file" ]]; then
        if has_local && [[ -f "$SCRIPT_DIR/hooks/hooks.json" ]]; then
            cp "$SCRIPT_DIR/hooks/hooks.json" "$hooks_file"
        else
            download "$REPO/hooks/hooks.json" "$hooks_file" || true
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

    # MCP
    if [[ -f "$CLAUDE_HOME/.mcp.json" ]] && grep -q "sypnose" "$CLAUDE_HOME/.mcp.json"; then
        ok "MCP config: OK"; ((pass++))
    else err "MCP config: MISSING"; ((fail++)); fi

    # Skill
    if [[ -f "$SKILLS_DIR/sypnose/SKILL.md" ]]; then
        local lines=$(wc -l < "$SKILLS_DIR/sypnose/SKILL.md")
        ok "/sypnose skill: OK ($lines lines)"; ((pass++))
    else err "/sypnose skill: MISSING"; ((fail++)); fi

    # Rules
    local rc=$(find "$RULES_DIR" -name "*.md" 2>/dev/null | wc -l)
    if [[ $rc -ge 5 ]]; then ok "Rules: OK ($rc files)"; ((pass++))
    else err "Rules: MISSING ($rc files)"; ((fail++)); fi

    # Agents
    local ac=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l)
    if [[ $ac -ge 3 ]]; then ok "Agents: OK ($ac files)"; ((pass++))
    else warn "Agents: $ac files"; ((fail++)); fi

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

# ── Main ─────────────────────────────────────────────────────
banner
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
