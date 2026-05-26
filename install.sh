#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# SYPNOSE INSTALLER — Universal Claude Code Plugin
# Zero dependencies. Works on Linux, macOS, WSL, Git Bash.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# ── Config ───────────────────────────────────────────────────
SYPNOSE_URL="http://62.171.147.46:18900/mcp"
SYPNOSE_KEY="21ff9b26fd454001328aaf60774f332d45138112f689af3a9b34de3dc5845589"
PLUGIN_NAME="sypnose"
VERSION="1.0.0"

# ── Paths ────────────────────────────────────────────────────
if [[ "${OS:-}" == "Windows_NT" ]]; then
    CLAUDE_HOME="${APPDATA}/../.claude"
else
    CLAUDE_HOME="${HOME}/.claude"
fi
CLAUDE_HOME="$(cd "$CLAUDE_HOME" 2>/dev/null && pwd || echo "$HOME/.claude")"

RULES_DIR="$CLAUDE_HOME/rules/sypnose"
SKILLS_DIR="$CLAUDE_HOME/skills/sypnose"
HOOKS_FILE="$CLAUDE_HOME/hooks.json"
PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Defaults ─────────────────────────────────────────────────
PROFILE="full"
VERBOSE=0

# ── Args ─────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) PROFILE="$2"; shift 2 ;;
        --verbose|-v) VERBOSE=1; shift ;;
        --help|-h)
            echo "Usage: install.sh [--profile full|minimal|dev|server] [--verbose]"
            exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

# ── Functions ────────────────────────────────────────────────
log() { echo "[sypnose] $*"; }
debug() { [[ $VERBOSE -eq 1 ]] && echo "  > $*" || true; }

install_mcp() {
    log "Registering Sypnose MCP (HTTP transport)..."

    # Method 1: claude CLI
    if command -v claude &>/dev/null; then
        claude mcp add --transport http \
            -H "Authorization: Bearer $SYPNOSE_KEY" \
            "$PLUGIN_NAME" "$SYPNOSE_URL" 2>/dev/null && {
            log "  MCP registered via claude CLI"
            return 0
        }
    fi

    # Method 2: Direct .mcp.json merge
    local mcp_file="$CLAUDE_HOME/.mcp.json"
    if [[ -f "$mcp_file" ]]; then
        # Merge into existing
        local tmp=$(mktemp)
        if command -v jq &>/dev/null; then
            jq --arg url "$SYPNOSE_URL" --arg key "$SYPNOSE_KEY" \
                '.mcpServers.sypnose = {"type":"http","url":$url,"headers":{"Authorization":("Bearer "+$key)}}' \
                "$mcp_file" > "$tmp" && mv "$tmp" "$mcp_file"
        else
            # Fallback: Python one-liner
            python3 -c "
import json,sys
f='$mcp_file'
d=json.load(open(f))
d.setdefault('mcpServers',{})['sypnose']={'type':'http','url':'$SYPNOSE_URL','headers':{'Authorization':'Bearer $SYPNOSE_KEY'}}
json.dump(d,open(f,'w'),indent=2)
" 2>/dev/null || {
                # Last resort: write fresh
                cat > "$mcp_file" << MCPEOF
{
  "mcpServers": {
    "sypnose": {
      "type": "http",
      "url": "$SYPNOSE_URL",
      "headers": {
        "Authorization": "Bearer $SYPNOSE_KEY"
      }
    }
  }
}
MCPEOF
            }
        fi
    else
        mkdir -p "$(dirname "$mcp_file")"
        cat > "$mcp_file" << MCPEOF
{
  "mcpServers": {
    "sypnose": {
      "type": "http",
      "url": "$SYPNOSE_URL",
      "headers": {
        "Authorization": "Bearer $SYPNOSE_KEY"
      }
    }
  }
}
MCPEOF
    fi
    log "  MCP config written to $mcp_file"
}

install_rules() {
    log "Installing rules..."
    mkdir -p "$RULES_DIR"
    cp "$PLUGIN_DIR/rules/"*.md "$RULES_DIR/" 2>/dev/null || true
    debug "Rules -> $RULES_DIR"
}

install_skills() {
    log "Installing skills..."
    mkdir -p "$SKILLS_DIR"

    # Copy each skill directory
    for skill_dir in "$PLUGIN_DIR/skills/"*/; do
        [[ -d "$skill_dir" ]] || continue
        local name=$(basename "$skill_dir")
        mkdir -p "$SKILLS_DIR/$name"
        cp "$skill_dir"* "$SKILLS_DIR/$name/" 2>/dev/null || true
        debug "Skill: $name"
    done
}

install_hooks() {
    log "Installing hooks..."

    if [[ -f "$HOOKS_FILE" ]]; then
        # Merge hooks (append sypnose hooks to existing arrays)
        if command -v jq &>/dev/null; then
            local tmp=$(mktemp)
            jq -s '.[0] as $existing | .[1] as $new |
                reduce ($new | keys[]) as $event ($existing;
                    .[$event] = ((.[$event] // []) + $new[$event] | unique_by(.name))
                )' "$HOOKS_FILE" "$PLUGIN_DIR/hooks/hooks.json" > "$tmp" \
                && mv "$tmp" "$HOOKS_FILE"
        else
            # If no jq, only install if no hooks exist
            cp "$PLUGIN_DIR/hooks/hooks.json" "$HOOKS_FILE"
        fi
    else
        cp "$PLUGIN_DIR/hooks/hooks.json" "$HOOKS_FILE"
    fi

    # Copy hook scripts
    mkdir -p "$CLAUDE_HOME/hooks/sypnose"
    cp "$PLUGIN_DIR/hooks/scripts/"*.sh "$CLAUDE_HOME/hooks/sypnose/" 2>/dev/null || true
    chmod +x "$CLAUDE_HOME/hooks/sypnose/"*.sh 2>/dev/null || true
    debug "Hooks -> $CLAUDE_HOME/hooks/sypnose/"
}

install_agents() {
    log "Installing agents..."
    mkdir -p "$CLAUDE_HOME/agents/sypnose"
    cp "$PLUGIN_DIR/agents/"*.md "$CLAUDE_HOME/agents/sypnose/" 2>/dev/null || true
    debug "Agents -> $CLAUDE_HOME/agents/sypnose/"
}

write_state() {
    local state_file="$CLAUDE_HOME/plugins/sypnose/install-state.json"
    mkdir -p "$(dirname "$state_file")"
    cat > "$state_file" << EOF
{
  "version": "$VERSION",
  "profile": "$PROFILE",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "plugin_dir": "$PLUGIN_DIR",
  "components": {
    "mcp": true,
    "rules": $([ "$PROFILE" != "minimal" ] || echo true && echo true),
    "skills": $([ "$PROFILE" = "full" ] || [ "$PROFILE" = "dev" ] && echo true || echo false),
    "hooks": $([ "$PROFILE" = "full" ] || [ "$PROFILE" = "dev" ] && echo true || echo false),
    "agents": $([ "$PROFILE" = "full" ] && echo true || echo false)
  }
}
EOF
    debug "State -> $state_file"
}

# ── Main ─────────────────────────────────────────────────────
log "═══════════════════════════════════════════"
log " SYPNOSE v$VERSION — Installing ($PROFILE)"
log "═══════════════════════════════════════════"
log ""

# Always install MCP (core of everything)
install_mcp

# Profile-based components
case "$PROFILE" in
    minimal)
        install_rules
        ;;
    dev)
        install_rules
        install_skills
        install_hooks
        ;;
    server)
        install_rules
        install_hooks
        ;;
    full)
        install_rules
        install_skills
        install_hooks
        install_agents
        ;;
    *)
        log "Unknown profile: $PROFILE (use: full|minimal|dev|server)"
        exit 1
        ;;
esac

write_state

log ""
log "═══════════════════════════════════════════"
log " INSTALLED SUCCESSFULLY"
log "═══════════════════════════════════════════"
log ""
log " MCP: sypnose (14 tools via HTTP)"
log " Rules: $RULES_DIR"
[[ "$PROFILE" == "full" || "$PROFILE" == "dev" ]] && log " Skills: $SKILLS_DIR"
[[ "$PROFILE" == "full" || "$PROFILE" == "dev" || "$PROFILE" == "server" ]] && log " Hooks: $HOOKS_FILE"
[[ "$PROFILE" == "full" ]] && log " Agents: $CLAUDE_HOME/agents/sypnose/"
log ""
log " Next: restart Claude Code to activate."
log ""
