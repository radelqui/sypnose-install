#!/usr/bin/env bash
# ============================================================================
# Sypnose v5.2 - Local Installer for macOS and Linux
# ============================================================================
# This script detects your environment and configures Claude Code/Desktop
# to connect to a Sypnose server or run KB Hub in standalone mode.
#
# Usage:
#   bash install-local.sh              # Interactive mode
#   bash install-local.sh --dry-run    # Show what would be done, no changes
#   bash install-local.sh --standalone # Install KB Hub locally (no server)
#   bash install-local.sh --yes        # Auto-confirm all prompts
#   bash install-local.sh --server-ip=IP --server-user=USER --standalone
#   bash install-local.sh --help       # Show all options
# ============================================================================

set -euo pipefail

# ============================================================================
# FLAGS & GLOBALS
# ============================================================================

SERVER_IP=""
SERVER_PORT="22"
SERVER_USER=""
SSH_KEY=""
DRY_RUN=false
STANDALONE=false
AUTO_YES=false
UPDATE_ONLY=false
KB_EXISTS=false

for arg in "$@"; do
    case "$arg" in
        --server-ip=*)   SERVER_IP="${arg#*=}" ;;
        --server-port=*) SERVER_PORT="${arg#*=}" ;;
        --server-user=*) SERVER_USER="${arg#*=}" ;;
        --ssh-key=*)     SSH_KEY="${arg#*=}" ;;
        --standalone)    STANDALONE=true ;;
        --dry-run)       DRY_RUN=true ;;
        --yes)           AUTO_YES=true ;;
        --update)        UPDATE_ONLY=true ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "  --server-ip=IP      Server IP address"
            echo "  --server-port=PORT  SSH port (default: 22)"
            echo "  --server-user=USER  SSH username"
            echo "  --ssh-key=PATH      SSH key path"
            echo "  --standalone        Install KB Hub locally (no server required)"
            echo "  --dry-run           Show what would be done, no changes made"
            echo "  --yes               Auto-confirm all prompts"
            echo "  --update            Update existing installation only"
            echo "  -h, --help          Show this help"
            exit 0
            ;;
    esac
done

OS="$(uname -s)"
INSTALLED=()
MISSING=()
HAS_ERRORS=false
KB_MODE="local :18791"

# ============================================================================
# COLORS & HELPERS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

log_ok()   { echo -e "  ${GREEN}[OK]${RESET} $1"; }
log_fail() { echo -e "  ${RED}[!] ${RESET} $1"; }
log_info() { echo -e "  ${YELLOW}[-] ${RESET} $1"; }
log_step() { echo -e "  ${WHITE}>>  ${RESET} $1"; }
log_head() { echo -e "\n${CYAN}=== $1 ===${RESET}\n"; }

dry_run_msg() {
    if $DRY_RUN; then
        log_info "[DRY-RUN] haria: $1"
        return 0
    fi
    return 1
}

cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

confirm_action() {
    local prompt="$1"
    if $AUTO_YES; then
        echo -e "  ${YELLOW}[-] ${RESET} $prompt [auto-yes]"
        return 0
    fi
    read -r -p "  $prompt (y/N): " REPLY
    [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]
}

# ============================================================================
# DETECT OS DETAILS
# ============================================================================

detect_os() {
    case "$OS" in
        Darwin)
            OS_NAME="macOS"
            OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
            CLAUDE_CONFIG_PATH="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
            PKG_HINT="brew install"
            ;;
        Linux)
            OS_NAME="Linux"
            if [ -f /etc/os-release ]; then
                # shellcheck disable=SC1091
                OS_VERSION="$(. /etc/os-release && echo "$PRETTY_NAME")"
            else
                OS_VERSION="$(uname -r)"
            fi
            CLAUDE_CONFIG_PATH="$HOME/.config/Claude/claude_desktop_config.json"
            if cmd_exists apt; then
                PKG_HINT="sudo apt install"
            elif cmd_exists dnf; then
                PKG_HINT="sudo dnf install"
            elif cmd_exists pacman; then
                PKG_HINT="sudo pacman -S"
            else
                PKG_HINT="<your-package-manager> install"
            fi
            ;;
        *)
            echo "Unsupported OS: $OS"
            echo "This script supports macOS and Linux only."
            echo "For Windows, use install-local.ps1"
            exit 1
            ;;
    esac
}

# ============================================================================
# WAVE 1 - DETECT INSTALLED TOOLS
# ============================================================================

detect_tools() {
    log_head "DETECTING ENVIRONMENT"

    echo -e "  OS: ${CYAN}${OS_NAME} ${OS_VERSION}${RESET}"
    echo ""

    # --- Node.js ---
    if cmd_exists node; then
        NODE_VER="$(node --version 2>/dev/null | head -1)"
        NODE_MAJOR="$(echo "$NODE_VER" | sed 's/v\([0-9]*\)\..*/\1/')"
        if [ "$NODE_MAJOR" -ge 18 ] 2>/dev/null; then
            log_ok "Node.js $NODE_VER (>= 18 required)"
            INSTALLED+=("Node.js")
        else
            log_fail "Node.js $NODE_VER found but version < 18 required"
            MISSING+=("Node.js (upgrade needed)")
        fi
    else
        log_fail "Node.js NOT FOUND"
        MISSING+=("node")
    fi

    # --- Git ---
    if cmd_exists git; then
        GIT_VER="$(git --version 2>/dev/null | head -1)"
        log_ok "Git: $GIT_VER"
        INSTALLED+=("Git")
    else
        log_fail "Git NOT FOUND"
        MISSING+=("git")
    fi

    # --- Python3 ---
    if cmd_exists python3; then
        PY_VER="$(python3 --version 2>/dev/null | head -1)"
        log_ok "Python: $PY_VER"
        INSTALLED+=("Python")
    elif cmd_exists python; then
        PY_VER="$(python --version 2>/dev/null | head -1)"
        log_ok "Python (via 'python'): $PY_VER"
        INSTALLED+=("Python")
    else
        log_fail "Python NOT FOUND"
        MISSING+=("python3")
    fi

    # --- SSH ---
    if cmd_exists ssh; then
        log_ok "SSH client available"
        INSTALLED+=("SSH")
    else
        log_fail "SSH NOT FOUND"
        MISSING+=("openssh-client")
    fi

    # --- Claude Code CLI ---
    if cmd_exists claude; then
        CLAUDE_VER="$(claude --version 2>/dev/null | head -1 || echo 'unknown')"
        log_ok "Claude Code CLI: $CLAUDE_VER"
        INSTALLED+=("Claude Code CLI")
    else
        log_info "Claude Code CLI not found (Claude Desktop may still work)"
    fi

    # --- Claude Desktop config ---
    if [ -f "$CLAUDE_CONFIG_PATH" ]; then
        log_ok "Claude Desktop config found: $CLAUDE_CONFIG_PATH"
        INSTALLED+=("Claude Desktop")
    else
        log_info "Claude Desktop config not found at $CLAUDE_CONFIG_PATH"
    fi
}

# ============================================================================
# DETECT KB HUB (check before standalone install)
# ============================================================================

detect_kb_hub() {
    if curl -s --connect-timeout 3 http://localhost:18791/health 2>/dev/null | grep -q '"ok"'; then
        log_ok "KB Hub ya disponible en localhost:18791 - modo standalone no necesario"
        KB_EXISTS=true
        KB_MODE="existing :18791"
        return 0
    fi
    # Also try /api/health endpoint (used by this version of server.js)
    if curl -s --connect-timeout 3 http://localhost:18791/api/health 2>/dev/null | grep -q '"ok"'; then
        log_ok "KB Hub ya disponible en localhost:18791 - modo standalone no necesario"
        KB_EXISTS=true
        KB_MODE="existing :18791"
        return 0
    fi
    return 1
}

# ============================================================================
# SHOW INSTALL INSTRUCTIONS FOR MISSING TOOLS
# ============================================================================

show_install_instructions() {
    if [ "${#MISSING[@]}" -eq 0 ]; then
        return 0
    fi

    log_head "INSTALLATION INSTRUCTIONS FOR MISSING TOOLS"
    echo -e "  ${YELLOW}The following tools are required. Please install them manually:${RESET}"
    echo ""

    for tool in "${MISSING[@]}"; do
        case "$tool" in
            node|"Node.js"*)
                echo -e "  ${WHITE}NODE.JS (>= 18):${RESET}"
                if [ "$OS_NAME" = "macOS" ]; then
                    log_step "brew install node"
                    log_step "Or download from: https://nodejs.org/en/download/"
                    log_step "Or use nvm: https://github.com/nvm-sh/nvm"
                else
                    log_step "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
                    log_step "sudo apt-get install -y nodejs"
                    log_step "Or via nvm: https://github.com/nvm-sh/nvm"
                fi
                echo ""
                ;;
            git)
                echo -e "  ${WHITE}GIT:${RESET}"
                log_step "$PKG_HINT git"
                if [ "$OS_NAME" = "macOS" ]; then
                    log_step "Or install Xcode Command Line Tools: xcode-select --install"
                fi
                echo ""
                ;;
            python3)
                echo -e "  ${WHITE}PYTHON3:${RESET}"
                log_step "$PKG_HINT python3"
                if [ "$OS_NAME" = "macOS" ]; then
                    log_step "Or download from: https://www.python.org/downloads/"
                fi
                echo ""
                ;;
            openssh-client)
                echo -e "  ${WHITE}SSH:${RESET}"
                log_step "$PKG_HINT openssh-client"
                echo ""
                ;;
        esac
    done

    echo -e "  ${YELLOW}After installing missing tools, re-run this script.${RESET}"

    if ! $STANDALONE; then
        echo ""
        if confirm_action "Continue anyway in standalone mode?"; then
            STANDALONE=true
        else
            echo "  Exiting. Install missing tools and re-run."
            exit 0
        fi
    fi
}

# ============================================================================
# WAVE 2 - GET SERVER DETAILS (if not standalone)
# ============================================================================

test_server_connection() {
    log_head "SERVER CONNECTION"
    echo -e "  ${WHITE}Enter your Sypnose server details.${RESET}"
    echo -e "  (Leave blank to skip and use standalone mode)"
    echo ""

    if [ -z "$SERVER_IP" ]; then
        read -r -p "  Server IP or hostname [YOUR_SERVER_IP]: " SERVER_IP
    fi
    if [ -z "$SERVER_PORT" ] || [ "$SERVER_PORT" = "22" ]; then
        read -r -p "  SSH port [22]: " _PORT
        SERVER_PORT="${_PORT:-22}"
    fi
    if [ -z "$SERVER_USER" ]; then
        read -r -p "  SSH username [YOUR_USER]: " SERVER_USER
    fi

    SERVER_PORT="${SERVER_PORT:-22}"

    if [ -z "$SERVER_IP" ] || [ -z "$SERVER_USER" ]; then
        log_info "No server details provided. Switching to standalone mode."
        STANDALONE=true
        return
    fi

    echo ""
    log_step "Testing SSH connection to ${SERVER_USER}@${SERVER_IP}:${SERVER_PORT} ..."

    if $DRY_RUN; then
        log_info "[DRY-RUN] haria: ssh -p $SERVER_PORT ${SERVER_USER}@${SERVER_IP} echo SYPNOSE_OK"
        SSH_OK=true
        return
    fi

    SSH_OPTS="-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
    if [ -n "$SSH_KEY" ]; then
        SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
    fi

    if SSH_RESULT=$(ssh $SSH_OPTS \
                       -p "$SERVER_PORT" \
                       "${SERVER_USER}@${SERVER_IP}" \
                       "echo SYPNOSE_OK" 2>&1); then
        if echo "$SSH_RESULT" | grep -q "SYPNOSE_OK"; then
            log_ok "SSH connection successful"
            SSH_OK=true
        else
            log_fail "SSH test failed. Falling back to standalone mode."
            STANDALONE=true
            SSH_OK=false
        fi
    else
        log_fail "SSH connection failed: $SSH_RESULT"
        STANDALONE=true
        SSH_OK=false
    fi
}

# ============================================================================
# WAVE 3 - STANDALONE: INSTALL KB HUB LOCALLY
# ============================================================================

install_kb_hub_local() {
    log_head "STANDALONE MODE - KB HUB LOCAL"

    if $KB_EXISTS; then
        log_ok "KB Hub ya en ejecucion en localhost:18791 - omitiendo instalacion"
        return 0
    fi

    DEFAULT_KB_PATH="$HOME/sypnose-kb-hub"
    echo -e "  ${WHITE}KB Hub will be installed locally (no server required).${RESET}"

    if $DRY_RUN; then
        KB_HUB_PATH="$DEFAULT_KB_PATH"
        log_info "[DRY-RUN] haria: mkdir -p $KB_HUB_PATH/src $KB_HUB_PATH/data"
        log_info "[DRY-RUN] haria: npm init -y en $KB_HUB_PATH"
        log_info "[DRY-RUN] haria: npm install --loglevel=error express better-sqlite3"
        log_info "[DRY-RUN] haria: crear $KB_HUB_PATH/src/server.js"
        INSTALLED+=("KB Hub (local, dry-run)")
        return
    fi

    if $AUTO_YES; then
        KB_HUB_PATH="$DEFAULT_KB_PATH"
        log_info "Install path (auto): $KB_HUB_PATH"
    else
        read -r -p "  Install path [$DEFAULT_KB_PATH]: " KB_HUB_PATH
        KB_HUB_PATH="${KB_HUB_PATH:-$DEFAULT_KB_PATH}"
    fi

    mkdir -p "$KB_HUB_PATH/src" "$KB_HUB_PATH/data"

    if [ ! -f "$KB_HUB_PATH/package.json" ]; then
        log_step "Initializing npm package..."
        (cd "$KB_HUB_PATH" && npm init -y >/dev/null 2>&1)
        log_step "Installing KB Hub dependencies (express, better-sqlite3)..."
        (cd "$KB_HUB_PATH" && npm install --loglevel=error express better-sqlite3)
    fi

    if [ ! -f "$KB_HUB_PATH/src/server.js" ]; then
        cat > "$KB_HUB_PATH/src/server.js" << 'SERVEREOF'
const express = require('express');
const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

const PORT = process.env.PORT || 18791;
const DB_PATH = process.env.DB_PATH || path.join(__dirname, '..', 'data', 'kb.db');

const dataDir = path.dirname(DB_PATH);
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

const db = new Database(DB_PATH);
db.exec(`CREATE TABLE IF NOT EXISTS kb (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  key TEXT UNIQUE NOT NULL,
  value TEXT,
  category TEXT,
  project TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
)`);

const app = express();
app.use(express.json());

app.get('/health', (req, res) => res.json({ ok: true, version: '5.2' }));
app.get('/api/health', (req, res) => res.json({ status: 'ok', version: '5.2' }));

app.post('/api/kb/save', (req, res) => {
  const { key, value, category, project } = req.body;
  db.prepare(`INSERT INTO kb (key, value, category, project) VALUES (?, ?, ?, ?)
    ON CONFLICT(key) DO UPDATE SET value=excluded.value, category=excluded.category,
    project=excluded.project, updated_at=datetime('now')`).run(key, value, category, project);
  res.json({ saved: true, key });
});

app.get('/api/search', (req, res) => {
  const q = req.query.q || '';
  const rows = db.prepare(`SELECT * FROM kb WHERE key LIKE ? OR value LIKE ? OR category LIKE ?`)
    .all(`%${q}%`, `%${q}%`, `%${q}%`);
  res.json(rows);
});

app.listen(PORT, () => console.log(`KB Hub listening on port ${PORT}`));
SERVEREOF
    fi

    log_ok "KB Hub installed at: $KB_HUB_PATH"
    INSTALLED+=("KB Hub (local)")
    KB_MODE="standalone :18791"
}

# ============================================================================
# WAVE 2 (new) - INSTALL SKILLS AND HOOKS
# ============================================================================

install_skills_and_hooks() {
    log_head "INSTALLING SKILLS"

    local claude_dir="$HOME/.claude"

    if $DRY_RUN; then
        log_info "[DRY-RUN] haria: mkdir -p $claude_dir/skills/bios $claude_dir/skills/sypnose-create-plan"
        log_info "[DRY-RUN] haria: crear $claude_dir/skills/bios/SKILL.md"
        log_info "[DRY-RUN] haria: crear $claude_dir/skills/sypnose-create-plan/SKILL.md"
        log_info "[DRY-RUN] haria: curl commands/sypnose-execute.md → $claude_dir/commands/sypnose-execute.md"
        log_info "[DRY-RUN] haria: curl commands/sypnose-parl-score.md → $claude_dir/commands/sypnose-parl-score.md"
        return 0
    fi

    mkdir -p "$claude_dir/skills/bios" "$claude_dir/skills/sypnose-create-plan"

    if [ ! -f "$claude_dir/skills/bios/SKILL.md" ]; then
        cat > "$claude_dir/skills/bios/SKILL.md" << 'SKILL_EOF'
# bios - Session Boot
Use at session start to check state, memory, notifications.
SKILL_EOF
        log_ok "Skill bios instalado"
    else
        log_info "Skill bios ya existe, no sobreescrito"
    fi

    if [ ! -f "$claude_dir/skills/sypnose-create-plan/SKILL.md" ]; then
        cat > "$claude_dir/skills/sypnose-create-plan/SKILL.md" << 'SKILL_EOF'
# sypnose-create-plan - Plan Creator
Creates and sends plans to architects via Sypnose.
SKILL_EOF
        log_ok "Skill sypnose-create-plan instalado"
    else
        log_info "Skill sypnose-create-plan ya existe, no sobreescrito"
    fi

    # Install sypnose-execute v6 commands to ~/.claude/commands/ (global slash commands for Claude Code)
    local COMMANDS_BASE="https://raw.githubusercontent.com/radelqui/sypnose-install/main/commands"
    mkdir -p "$claude_dir/commands"
    for cmd in sypnose-execute sypnose-parl-score; do
        if $DRY_RUN; then
            log_info "[DRY-RUN] haria: curl $COMMANDS_BASE/$cmd.md → $claude_dir/commands/$cmd.md"
        elif curl -fsSL "$COMMANDS_BASE/$cmd.md" -o "$claude_dir/commands/$cmd.md" 2>/dev/null; then
            log_ok "Command /$cmd instalado en $claude_dir/commands/"
        else
            log_warn "No se pudo descargar $cmd.md — instalar manualmente desde radelqui/sypnose-install/commands/"
        fi
    done

    INSTALLED+=("Commands: sypnose-execute v6, sypnose-parl-score")
}

# ============================================================================
# WAVE 4 - CONFIGURE MCP JSON
# ============================================================================

configure_mcp() {
    log_head "CONFIGURING MCP"

    local config_dir
    config_dir="$(dirname "$CLAUDE_CONFIG_PATH")"

    if [ -z "${KB_HUB_PATH:-}" ]; then
        KB_HUB_PATH="$HOME/sypnose-kb-hub"
    fi

    local server_js_path="$KB_HUB_PATH/src/server.js"
    local db_path="$KB_HUB_PATH/data/kb.db"

    # Also configure .mcp.json for Claude Code CLI projects
    local project_mcp_file="./.mcp.json"
    if $DRY_RUN; then
        log_info "[DRY-RUN] haria: escribir MCP config en $CLAUDE_CONFIG_PATH (knowledge-hub -> node $server_js_path)"
        log_info "[DRY-RUN] haria: crear/verificar $project_mcp_file con knowledge-hub"
        return
    fi

    mkdir -p "$config_dir"

    # Read existing config or start fresh
    if [ -f "$CLAUDE_CONFIG_PATH" ]; then
        existing_json="$(cat "$CLAUDE_CONFIG_PATH")"
    else
        existing_json='{}'
    fi

    # Use python3 to safely merge JSON
    python3 - <<PYEOF
import json, sys

try:
    existing = json.loads('''${existing_json}''')
except Exception:
    existing = {}

if 'mcpServers' not in existing:
    existing['mcpServers'] = {}

existing['mcpServers']['knowledge-hub'] = {
    'command': 'node',
    'args': ['${server_js_path}'],
    'env': {
        'PORT': '18791',
        'DB_PATH': '${db_path}'
    }
}

with open('${CLAUDE_CONFIG_PATH}', 'w') as f:
    json.dump(existing, f, indent=2)

print('  MCP config written successfully.')
PYEOF

    log_ok "MCP config written to: $CLAUDE_CONFIG_PATH"

    # Create .mcp.json for project-level Claude Code CLI configuration
    if [ ! -f "$project_mcp_file" ]; then
        cat > "$project_mcp_file" << MCP_EOF
{
  "mcpServers": {
    "knowledge-hub": {
      "command": "node",
      "args": ["${server_js_path}"],
      "env": {"PORT": "18791", "DB_PATH": "${db_path}"}
    }
  }
}
MCP_EOF
        log_ok ".mcp.json creado con knowledge-hub"
    else
        log_info ".mcp.json ya existe - verificar manualmente que tiene knowledge-hub"
    fi

    INSTALLED+=("MCP: knowledge-hub")
}

# ============================================================================
# FINAL SUMMARY (enhanced)
# ============================================================================

print_summary() {
    log_head "SUMMARY"

    if [ "${#INSTALLED[@]}" -gt 0 ]; then
        echo -e "  ${GREEN}Installed / Detected:${RESET}"
        for item in "${INSTALLED[@]}"; do
            log_ok "$item"
        done
    fi

    if [ "${#MISSING[@]}" -gt 0 ]; then
        echo ""
        echo -e "  ${RED}Missing (action required):${RESET}"
        for item in "${MISSING[@]}"; do
            log_fail "$item"
        done
    fi

    echo ""
    echo "=================================================="
    echo "  SYPNOSE v5.2 INSTALADO"
    echo "=================================================="
    echo "  KB Hub:  ${KB_MODE}"
    echo "  Skills:  bios, sypnose-create-plan"
    echo "  Commands: sypnose-execute v6, sypnose-parl-score (en ~/.claude/commands/)"
    echo "  MCP:     knowledge-hub"
    echo "  Reinicia Claude Code para activar."
    echo "=================================================="
    echo ""

    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY-RUN] No se ejecuto nada. Ningun archivo fue modificado.${RESET}"
        exit 0
    else
        echo -e "  ${WHITE}Next steps:${RESET}"
        echo -e "    1. Restart Claude Desktop or Claude Code for MCP changes to take effect."
        if $STANDALONE || $KB_EXISTS; then
            echo -e "    2. Start KB Hub:   node ${KB_HUB_PATH:-\$HOME/sypnose-kb-hub}/src/server.js"
            echo -e "    3. Verify health:  curl http://localhost:18791/api/health"
        else
            echo -e "    2. Verify server:  ssh -p ${SERVER_PORT:-22} ${SERVER_USER:-YOUR_USER}@${SERVER_IP:-YOUR_SERVER_IP} echo OK"
        fi
        echo -e "    4. Run detect-env.sh to confirm full configuration."
    fi

    echo ""
    echo -e "  ${CYAN}Sypnose v5.2 local setup complete.${RESET}"
    echo ""
}

# ============================================================================
# MAIN ENTRYPOINT
# ============================================================================

echo ""
echo -e "${CYAN}============================================================${RESET}"
echo -e "${CYAN}  Sypnose v5.2 - Local Installer for macOS / Linux${RESET}"
echo -e "${CYAN}============================================================${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN MODE - no changes will be made]${RESET}"
fi

detect_os
detect_tools
show_install_instructions

SSH_OK=false
KB_HUB_PATH=""

# Detect if KB Hub is already running before deciding on standalone
log_head "CHECKING KB HUB"
detect_kb_hub || true

if ! $STANDALONE && ! $KB_EXISTS; then
    if [ -n "$SERVER_IP" ] && [ -n "$SERVER_USER" ]; then
        # CLI params provided - test connection directly
        test_server_connection
    else
        test_server_connection
    fi
fi

if $STANDALONE; then
    install_kb_hub_local
fi

install_skills_and_hooks
configure_mcp
print_summary
