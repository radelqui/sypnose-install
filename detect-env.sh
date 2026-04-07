#!/usr/bin/env bash
# ============================================================================
# Sypnose v5.2 - Environment Detector (macOS / Linux)
# ============================================================================
# READ-ONLY: This script only detects your environment. It does NOT modify
# any files or install anything.
#
# Usage:
#   bash detect-env.sh
# ============================================================================

set -uo pipefail

OS="$(uname -s)"

# ============================================================================
# COLORS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}[OK]${RESET}"; }
fail() { echo -e "${RED}[!!]${RESET}"; }

cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# DETECT OS
# ============================================================================

case "$OS" in
    Darwin)
        OS_DISPLAY="macOS $(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
        CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
        ;;
    Linux)
        if [ -f /etc/os-release ]; then
            # shellcheck disable=SC1091
            OS_DISPLAY="Linux $(. /etc/os-release && echo "$PRETTY_NAME")"
        else
            OS_DISPLAY="Linux $(uname -r)"
        fi
        CLAUDE_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
        ;;
    MINGW*|CYGWIN*|MSYS*)
        OS_DISPLAY="Windows (Git Bash / WSL detected)"
        CLAUDE_CONFIG=""
        echo "Note: For native Windows, use detect-env.ps1 instead."
        ;;
    *)
        OS_DISPLAY="Unknown ($OS)"
        CLAUDE_CONFIG=""
        ;;
esac

# ============================================================================
# DETECT TOOLS
# ============================================================================

NODE_STATUS="NOT FOUND"
NODE_VER=""
NODE_OK=false

if cmd_exists node; then
    NODE_VER="$(node --version 2>/dev/null | head -1)"
    NODE_MAJOR="$(echo "$NODE_VER" | sed 's/v\([0-9]*\)\..*/\1/' 2>/dev/null || echo '0')"
    if [ "${NODE_MAJOR:-0}" -ge 18 ] 2>/dev/null; then
        NODE_STATUS="$NODE_VER"
        NODE_OK=true
    else
        NODE_STATUS="$NODE_VER (< 18 - upgrade needed)"
        NODE_OK=false
    fi
fi

GIT_STATUS="NOT FOUND"
GIT_OK=false
if cmd_exists git; then
    GIT_STATUS="$(git --version 2>/dev/null | sed 's/git version //' | head -1)"
    GIT_OK=true
fi

PYTHON_STATUS="NOT FOUND"
PYTHON_OK=false
if cmd_exists python3; then
    PYTHON_STATUS="$(python3 --version 2>/dev/null | head -1)"
    PYTHON_OK=true
elif cmd_exists python; then
    PYTHON_STATUS="$(python --version 2>/dev/null | head -1) (via 'python')"
    PYTHON_OK=true
fi

SSH_STATUS="NOT FOUND"
SSH_OK=false
if cmd_exists ssh; then
    SSH_VER="$(ssh -V 2>&1 | head -1 || echo 'available')"
    SSH_STATUS="$SSH_VER"
    SSH_OK=true
fi

CLAUDE_CODE_STATUS="NOT FOUND"
CLAUDE_CODE_OK=false
if cmd_exists claude; then
    CLAUDE_CODE_VER="$(claude --version 2>/dev/null | head -1 || echo 'installed')"
    CLAUDE_CODE_STATUS="$CLAUDE_CODE_VER"
    CLAUDE_CODE_OK=true
fi

CLAUDE_DESKTOP_STATUS="NOT FOUND"
CLAUDE_DESKTOP_OK=false
MCP_CONFIG_OK=false
if [ -n "$CLAUDE_CONFIG" ] && [ -f "$CLAUDE_CONFIG" ]; then
    CLAUDE_DESKTOP_STATUS="config found at $CLAUDE_CONFIG"
    CLAUDE_DESKTOP_OK=true
    # Check if knowledge-hub MCP is configured
    if grep -q "knowledge-hub" "$CLAUDE_CONFIG" 2>/dev/null; then
        MCP_CONFIG_OK=true
    fi
fi

# ============================================================================
# DETERMINE LEVEL
# ============================================================================

# Level 1: missing node OR git OR ssh
# Level 2: has node+git+ssh but no Claude config or no MCP entry
# Level 3: has everything including MCP config

if ! $NODE_OK || ! $GIT_OK || ! $SSH_OK; then
    LEVEL=1
elif ! $CLAUDE_DESKTOP_OK || ! $MCP_CONFIG_OK; then
    LEVEL=2
else
    LEVEL=3
fi

# ============================================================================
# OUTPUT
# ============================================================================

echo ""
echo -e "${CYAN}=== SYPNOSE ENV DETECTOR ===${RESET}"
echo ""
echo -e "  OS:                  ${WHITE}${OS_DISPLAY}${RESET}"
echo ""

# Node
if $NODE_OK; then
    echo -e "  Node.js:             ${GREEN}${NODE_STATUS}${RESET}  $(ok)"
else
    echo -e "  Node.js:             ${RED}${NODE_STATUS}${RESET}  $(fail)"
fi

# Git
if $GIT_OK; then
    echo -e "  Git:                 ${GREEN}${GIT_STATUS}${RESET}  $(ok)"
else
    echo -e "  Git:                 ${RED}${GIT_STATUS}${RESET}  $(fail)"
fi

# Python
if $PYTHON_OK; then
    echo -e "  Python:              ${GREEN}${PYTHON_STATUS}${RESET}  $(ok)"
else
    echo -e "  Python:              ${RED}${PYTHON_STATUS}${RESET}  $(fail)"
fi

# SSH
if $SSH_OK; then
    echo -e "  SSH:                 ${GREEN}available${RESET}  $(ok)"
else
    echo -e "  SSH:                 ${RED}NOT FOUND${RESET}  $(fail)"
fi

# Claude Code CLI
if $CLAUDE_CODE_OK; then
    echo -e "  Claude Code CLI:     ${GREEN}${CLAUDE_CODE_STATUS}${RESET}  $(ok)"
else
    echo -e "  Claude Code CLI:     ${YELLOW}NOT FOUND${RESET}  (optional)"
fi

# Claude Desktop
if $CLAUDE_DESKTOP_OK; then
    echo -e "  Claude Desktop:      ${GREEN}config found${RESET}  $(ok)"
    if $MCP_CONFIG_OK; then
        echo -e "  MCP knowledge-hub:   ${GREEN}configured${RESET}  $(ok)"
    else
        echo -e "  MCP knowledge-hub:   ${YELLOW}NOT configured${RESET}  (run install-local.sh)"
    fi
else
    echo -e "  Claude Desktop:      ${YELLOW}NOT FOUND${RESET}  (optional)"
    echo -e "  MCP knowledge-hub:   ${RED}NOT configured${RESET}  $(fail)"
fi

echo ""
echo -e "${CYAN}--- DETECTED LEVEL: ${LEVEL} ---${RESET}"
echo ""

case $LEVEL in
    1)
        echo -e "  ${RED}Nivel 1: Faltan herramientas base${RESET}"
        echo ""
        echo "  Action required:"
        ! $NODE_OK && echo -e "    ${RED}[!!]${RESET} Install Node.js >= 18:  https://nodejs.org"
        ! $GIT_OK  && echo -e "    ${RED}[!!]${RESET} Install Git:            https://git-scm.com"
        ! $SSH_OK  && echo -e "    ${RED}[!!]${RESET} Install SSH client:     (openssh-client)"
        echo ""
        echo -e "  Next step: ${WHITE}Install missing tools, then re-run detect-env.sh${RESET}"
        echo -e "  Installer: ${WHITE}bash install-local.sh${RESET}"
        ;;
    2)
        echo -e "  ${YELLOW}Nivel 2: Herramientas OK, falta configuracion MCP${RESET}"
        echo ""
        echo "  Tools detected: Node.js, Git, SSH  [OK]"
        ! $CLAUDE_DESKTOP_OK && echo -e "  ${YELLOW}Claude Desktop config not found${RESET}"
        ! $MCP_CONFIG_OK     && echo -e "  ${YELLOW}knowledge-hub MCP not configured${RESET}"
        echo ""
        echo -e "  Next step: ${WHITE}bash install-local.sh${RESET}"
        ;;
    3)
        echo -e "  ${GREEN}Nivel 3: Todo OK, solo ajustes menores si es necesario${RESET}"
        echo ""
        echo -e "  ${GREEN}[OK] Node.js, Git, SSH, Claude Desktop, MCP all configured${RESET}"
        echo ""
        echo -e "  To update configuration: ${WHITE}bash install-local.sh --update${RESET}"
        ;;
esac

echo ""
