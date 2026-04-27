#!/usr/bin/env bash
# ============================================================================
# Sypnose v7 - Public Installer for macOS and Linux
# ============================================================================
# Configures Claude Code / Claude Desktop with 4 SSE MCPs that point to the
# Sypnose cloud (kb / memory / hub / lightrag .sypnose.cloud).
#
# Auth model: Cloudflare Access "Temporary Authentication" (browser-based).
# This installer does NOT distribute or embed Service Tokens.
# After install, the user opens https://kb.sypnose.cloud once in a browser,
# requests access (Cloudflare emails Carlos), and gets a 24h session.
#
# Usage:
#   bash install-local.sh                # Interactive
#   bash install-local.sh --dry-run      # Show what would change
#   bash install-local.sh --yes          # Auto-confirm prompts
#   bash install-local.sh --no-smoke     # Skip post-install smoke check
#   bash install-local.sh --help
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# FLAGS & GLOBALS
# ----------------------------------------------------------------------------

DRY_RUN=false
AUTO_YES=false
SKIP_SMOKE=false

# Bash 3.2 compatible: use plain arrays + helper instead of associative arrays
INSTALLED=()
MISSING=()

VERSION="7.0.0"
CANONICAL_URL="https://raw.githubusercontent.com/radelqui/sypnose-install/main/agent-config-canonical.json"
COMMANDS_BASE="https://raw.githubusercontent.com/radelqui/sypnose-install/main/commands"

TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/sypnose-install-${TS}.log"
CANONICAL_TMP="/tmp/sypnose-canonical-${TS}.json"

# Inline fallback canonical (used if remote download fails). Keep this in
# sync with agent-config-canonical.json in the repo. The 4 SSE MCPs are:
#   - knowledge-hub    -> https://kb.sypnose.cloud/sse        (npx -y supergateway --sse ...)
#   - sypnose-memory   -> https://memory.sypnose.cloud/sse    (npx -y supergateway --sse ...)
#   - sypnose-hub      -> https://hub.sypnose.cloud/sse       (npx -y supergateway --sse ...)
#   - sypnose-lightrag -> https://lightrag.sypnose.cloud/sse  (npx -y supergateway --sse ...)
read -r -d '' CANONICAL_INLINE <<'CANONJSON' || true
{
  "_version": "7.0.0-inline-fallback",
  "mcpServers": {
    "knowledge-hub": {
      "command": "npx",
      "args": ["-y", "supergateway", "--sse", "https://kb.sypnose.cloud/sse"]
    },
    "sypnose-memory": {
      "command": "npx",
      "args": ["-y", "supergateway", "--sse", "https://memory.sypnose.cloud/sse"]
    },
    "sypnose-hub": {
      "command": "npx",
      "args": ["-y", "supergateway", "--sse", "https://hub.sypnose.cloud/sse"]
    },
    "sypnose-lightrag": {
      "command": "npx",
      "args": ["-y", "supergateway", "--sse", "https://lightrag.sypnose.cloud/sse"]
    }
  }
}
CANONJSON

for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=true ;;
        --yes|-y)    AUTO_YES=true ;;
        --no-smoke)  SKIP_SMOKE=true ;;
        -h|--help)
            cat <<EOF
Sypnose v${VERSION} installer for macOS / Linux.

Usage:
  bash install-local.sh [options]

Options:
  --dry-run      Show what would change without modifying anything
  --yes, -y      Auto-confirm interactive prompts
  --no-smoke     Skip post-install smoke check
  -h, --help     This help

The installer writes Claude config with 4 SSE MCPs pointing to
*.sypnose.cloud. Authentication is handled by Cloudflare Access
in the browser the first time you hit kb.sypnose.cloud.
EOF
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg (use --help)" >&2
            exit 2
            ;;
    esac
done

# ----------------------------------------------------------------------------
# LOG / OUTPUT
# ----------------------------------------------------------------------------

# Tee everything to log file (best-effort; do not fail install if log fails)
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
: > "$LOG_FILE" 2>/dev/null || true

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
WHITE=$'\033[1;37m'
RESET=$'\033[0m'

_log() {
    # Print to stdout AND append to logfile (no color in logfile)
    local plain
    plain="$(printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g' 2>/dev/null || printf '%s' "$1")"
    printf '%s\n' "$1"
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$plain" >> "$LOG_FILE" 2>/dev/null || true
}

log_ok()   { _log "  ${GREEN}[OK]${RESET}   $1"; }
log_fail() { _log "  ${RED}[ERR]${RESET}  $1"; }
log_info() { _log "  ${YELLOW}[..]${RESET}  $1"; }
log_warn() { _log "  ${YELLOW}[WARN]${RESET} $1"; }
log_step() { _log "  ${WHITE}>>${RESET}    $1"; }
log_head() { _log ""; _log "${CYAN}=== $1 ===${RESET}"; _log ""; }

dry_say() {
    if $DRY_RUN; then
        log_info "[DRY-RUN] $1"
        return 0
    fi
    return 1
}

cmd_exists() { command -v "$1" >/dev/null 2>&1; }

confirm() {
    local prompt="$1"
    if $AUTO_YES; then
        log_info "$prompt [auto-yes]"
        return 0
    fi
    local reply=""
    printf '  %s (y/N): ' "$prompt"
    read -r reply || reply=""
    case "$reply" in
        y|Y|yes|YES) return 0 ;;
        *)           return 1 ;;
    esac
}

# ----------------------------------------------------------------------------
# DETECT OS + CONFIG PATHS
# ----------------------------------------------------------------------------

detect_os() {
    OS_RAW="$(uname -s)"
    case "$OS_RAW" in
        Darwin)
            OS_NAME="macOS"
            OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
            CLAUDE_DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
            CLAUDE_CLI_CONFIG="$HOME/.claude.json"
            PKG_HINT="brew install"
            ;;
        Linux)
            OS_NAME="Linux"
            if [ -f /etc/os-release ]; then
                # shellcheck disable=SC1091
                OS_VERSION="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-Linux}")"
            else
                OS_VERSION="$(uname -r)"
            fi
            CLAUDE_DESKTOP_CONFIG="$HOME/.config/Claude/claude_desktop_config.json"
            CLAUDE_CLI_CONFIG="$HOME/.claude.json"
            if cmd_exists apt;   then PKG_HINT="sudo apt install"
            elif cmd_exists dnf; then PKG_HINT="sudo dnf install"
            elif cmd_exists pacman; then PKG_HINT="sudo pacman -S"
            else PKG_HINT="<your-package-manager> install"
            fi
            ;;
        *)
            log_fail "Unsupported OS: $OS_RAW"
            log_fail "Sypnose v${VERSION} supports macOS and Linux."
            log_fail "On Windows use install-local.ps1"
            exit 1
            ;;
    esac
}

# ----------------------------------------------------------------------------
# DETECT PREREQUISITES
# ----------------------------------------------------------------------------

detect_tools() {
    log_head "DETECTING ENVIRONMENT"
    log_info "OS: ${OS_NAME} ${OS_VERSION}"
    log_info "Log: ${LOG_FILE}"

    # Node 18+
    if cmd_exists node; then
        local nver
        nver="$(node --version 2>/dev/null | head -n1)"
        local nmaj
        nmaj="$(printf '%s' "$nver" | sed 's/^v\([0-9][0-9]*\).*/\1/')"
        if [ "${nmaj:-0}" -ge 18 ] 2>/dev/null; then
            log_ok "Node.js ${nver} (>= 18)"
            INSTALLED+=("Node.js ${nver}")
        else
            log_fail "Node.js ${nver} found but >= 18 required"
            MISSING+=("node>=18")
        fi
    else
        log_fail "Node.js not found"
        MISSING+=("node")
    fi

    # npx (ships with npm)
    if cmd_exists npx; then
        log_ok "npx available"
    else
        log_fail "npx not found (install Node.js with npm)"
        MISSING+=("npx")
    fi

    # git
    if cmd_exists git; then
        log_ok "Git: $(git --version 2>/dev/null | head -n1)"
        INSTALLED+=("git")
    else
        log_fail "Git not found"
        MISSING+=("git")
    fi

    # curl
    if cmd_exists curl; then
        log_ok "curl available"
    else
        log_fail "curl not found"
        MISSING+=("curl")
    fi

    # JSON tooling: prefer node, fallback to python3
    if cmd_exists node; then
        log_ok "JSON merge engine: node"
        JSON_ENGINE="node"
    elif cmd_exists python3; then
        log_ok "JSON merge engine: python3"
        JSON_ENGINE="python3"
    else
        log_fail "Need either node or python3 for JSON merge"
        MISSING+=("node-or-python3")
        JSON_ENGINE=""
    fi

    # Claude CLI / Desktop (informational, not blocking)
    if cmd_exists claude; then
        local cv
        cv="$(claude --version 2>/dev/null | head -n1 || echo 'unknown')"
        log_ok "Claude Code CLI: ${cv}"
        INSTALLED+=("Claude Code CLI")
    else
        log_info "Claude Code CLI not found (Claude Desktop alone is fine)"
    fi

    if [ -f "$CLAUDE_DESKTOP_CONFIG" ]; then
        log_ok "Claude Desktop config exists at ${CLAUDE_DESKTOP_CONFIG}"
        INSTALLED+=("Claude Desktop config")
    else
        log_info "Claude Desktop config not found (will be created)"
    fi
}

show_missing_help() {
    if [ "${#MISSING[@]}" -eq 0 ]; then
        return 0
    fi

    log_head "MISSING PREREQUISITES"
    log_warn "Install the following before re-running this script:"

    for tool in "${MISSING[@]}"; do
        case "$tool" in
            node|node*|npx)
                if [ "$OS_NAME" = "macOS" ]; then
                    log_step "Node.js (>=18): brew install node   OR  https://nodejs.org/"
                else
                    log_step "Node.js (>=18):"
                    log_step "   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
                    log_step "   sudo apt-get install -y nodejs"
                fi
                ;;
            git)
                log_step "Git: ${PKG_HINT} git"
                ;;
            curl)
                log_step "curl: ${PKG_HINT} curl"
                ;;
            node-or-python3)
                log_step "Either Node.js (preferred) or Python 3:"
                log_step "   ${PKG_HINT} python3"
                ;;
            *)
                log_step "${tool}"
                ;;
        esac
    done

    log_fail "Cannot continue. Install missing tools and re-run."
    exit 1
}

# ----------------------------------------------------------------------------
# DOWNLOAD CANONICAL CONFIG + VALIDATE
# ----------------------------------------------------------------------------

download_canonical() {
    log_head "RESOLVING CANONICAL CONFIG"
    log_step "URL: ${CANONICAL_URL}"

    if dry_say "curl ${CANONICAL_URL} -> ${CANONICAL_TMP} (with inline fallback)"; then
        return 0
    fi

    if curl -fsSL --max-time 15 "$CANONICAL_URL" -o "$CANONICAL_TMP" 2>>"$LOG_FILE"; then
        log_ok "Canonical config downloaded from repo"
    else
        log_warn "Download failed — falling back to inline canonical (4 SSE MCPs hardcoded in this installer)"
        printf '%s\n' "$CANONICAL_INLINE" > "$CANONICAL_TMP"
    fi

    # Validate JSON
    if [ "$JSON_ENGINE" = "node" ]; then
        if ! node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$CANONICAL_TMP" 2>>"$LOG_FILE"; then
            log_fail "Canonical config is not valid JSON"
            exit 1
        fi
    else
        if ! python3 -m json.tool "$CANONICAL_TMP" >/dev/null 2>>"$LOG_FILE"; then
            log_fail "Canonical config is not valid JSON"
            exit 1
        fi
    fi

    log_ok "Canonical config validated"
    log_info "Local copy: ${CANONICAL_TMP}"
}

# ----------------------------------------------------------------------------
# BACKUP + WRITE CLAUDE CONFIG
# ----------------------------------------------------------------------------

backup_existing_config() {
    local target="$1"
    [ -f "$target" ] || return 0

    local backup="${target}.bak-pre-sypnose-v7-${TS}"
    if dry_say "cp '${target}' '${backup}'"; then
        return 0
    fi
    cp "$target" "$backup"
    log_ok "Backup: ${backup}"
}

write_claude_config() {
    local target="$1"
    local label="$2"

    local config_dir
    config_dir="$(dirname "$target")"

    log_step "Writing ${label}: ${target}"

    if dry_say "merge canonical mcpServers into ${target}"; then
        return 0
    fi

    mkdir -p "$config_dir"

    backup_existing_config "$target"

    local existing_json="{}"
    if [ -f "$target" ] && [ -s "$target" ]; then
        existing_json="$(cat "$target")"
    fi

    # Hand off to JSON_ENGINE via files + env vars (no shell interpolation
    # of arbitrary strings into the script body)
    local existing_tmp="/tmp/sypnose-existing-${TS}.json"
    local out_tmp="/tmp/sypnose-out-${TS}.json"
    printf '%s' "$existing_json" > "$existing_tmp"

    if [ "$JSON_ENGINE" = "node" ]; then
        SYP_EXISTING="$existing_tmp" \
        SYP_CANONICAL="$CANONICAL_TMP" \
        SYP_OUT="$out_tmp" \
        node -e '
            const fs = require("fs");
            let existing = {};
            try {
                const raw = fs.readFileSync(process.env.SYP_EXISTING, "utf8");
                existing = raw.trim() ? JSON.parse(raw) : {};
            } catch (e) { existing = {}; }
            const canonical = JSON.parse(fs.readFileSync(process.env.SYP_CANONICAL, "utf8"));
            const sypKeys = ["knowledge-hub", "sypnose-memory", "sypnose-hub", "sypnose-lightrag"];
            if (!existing.mcpServers || typeof existing.mcpServers !== "object") {
                existing.mcpServers = {};
            }
            // Strip clean copy of any previous Sypnose MCPs so we start fresh
            for (const k of sypKeys) {
                if (k in existing.mcpServers) delete existing.mcpServers[k];
            }
            // Inject canonical Sypnose MCPs (without _comment / _purpose meta keys)
            const sypServers = canonical.mcpServers || {};
            for (const k of sypKeys) {
                if (!sypServers[k]) continue;
                const src = sypServers[k];
                existing.mcpServers[k] = {
                    command: src.command,
                    args: Array.isArray(src.args) ? src.args.slice() : []
                };
            }
            fs.writeFileSync(process.env.SYP_OUT, JSON.stringify(existing, null, 2) + "\n");
        ' 2>>"$LOG_FILE" || {
            log_fail "JSON merge (node) failed. See log: ${LOG_FILE}"
            rm -f "$existing_tmp"
            exit 1
        }
    else
        SYP_EXISTING="$existing_tmp" \
        SYP_CANONICAL="$CANONICAL_TMP" \
        SYP_OUT="$out_tmp" \
        python3 - <<'PYEOF' 2>>"$LOG_FILE" || { log_fail "JSON merge (python) failed"; rm -f "$existing_tmp"; exit 1; }
import json, os
existing_path  = os.environ["SYP_EXISTING"]
canonical_path = os.environ["SYP_CANONICAL"]
out_path       = os.environ["SYP_OUT"]
try:
    with open(existing_path) as f:
        raw = f.read().strip()
        existing = json.loads(raw) if raw else {}
except Exception:
    existing = {}
with open(canonical_path) as f:
    canonical = json.load(f)
syp_keys = ["knowledge-hub", "sypnose-memory", "sypnose-hub", "sypnose-lightrag"]
if not isinstance(existing.get("mcpServers"), dict):
    existing["mcpServers"] = {}
for k in syp_keys:
    existing["mcpServers"].pop(k, None)
sypsrv = canonical.get("mcpServers", {}) or {}
for k in syp_keys:
    src = sypsrv.get(k)
    if not src:
        continue
    existing["mcpServers"][k] = {
        "command": src.get("command"),
        "args":    list(src.get("args") or [])
    }
with open(out_path, "w") as f:
    json.dump(existing, f, indent=2)
    f.write("\n")
PYEOF
    fi

    mv "$out_tmp" "$target"
    rm -f "$existing_tmp"
    log_ok "Wrote ${label}: ${target}"
}

configure_claude() {
    log_head "CONFIGURING CLAUDE"

    # Always write Desktop config (Mac + Linux paths)
    write_claude_config "$CLAUDE_DESKTOP_CONFIG" "claude_desktop_config.json"
    INSTALLED+=("MCP config (Desktop)")

    # Also write the Claude Code CLI config (~/.claude.json) so CLI sees the MCPs.
    # If file does not exist, create empty {} so merge works cleanly.
    if [ ! -f "$CLAUDE_CLI_CONFIG" ] && ! $DRY_RUN; then
        printf '{}\n' > "$CLAUDE_CLI_CONFIG"
    fi
    write_claude_config "$CLAUDE_CLI_CONFIG" "~/.claude.json (Claude Code CLI)"
    INSTALLED+=("MCP config (CLI)")
}

# ----------------------------------------------------------------------------
# INSTALL SLASH COMMANDS
# ----------------------------------------------------------------------------

install_commands() {
    log_head "INSTALLING SLASH COMMANDS"

    local cmd_dir="$HOME/.claude/commands"

    if dry_say "mkdir -p ${cmd_dir} && download sypnose-execute.md, sypnose-parl-score.md"; then
        return 0
    fi

    mkdir -p "$cmd_dir"

    local cmd ok_count=0
    for cmd in sypnose-execute sypnose-parl-score; do
        if curl -fsSL "${COMMANDS_BASE}/${cmd}.md" -o "${cmd_dir}/${cmd}.md" 2>>"$LOG_FILE"; then
            log_ok "/${cmd} -> ${cmd_dir}/${cmd}.md"
            ok_count=$((ok_count + 1))
        else
            log_warn "Could not download ${cmd}.md (non-fatal). Get it from radelqui/sypnose-install/commands/"
        fi
    done

    if [ "$ok_count" -gt 0 ]; then
        INSTALLED+=("Slash commands (${ok_count}/2)")
    fi
}

# ----------------------------------------------------------------------------
# SMOKE CHECK (non-fatal)
# ----------------------------------------------------------------------------

smoke_check() {
    if $SKIP_SMOKE; then
        log_info "Smoke check skipped (--no-smoke)"
        return 0
    fi

    log_head "SMOKE CHECK"

    if dry_say "curl -I https://kb.sypnose.cloud/health"; then
        return 0
    fi

    log_step "Pinging https://kb.sypnose.cloud/health (10s timeout)"
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
            "https://kb.sypnose.cloud/health" 2>>"$LOG_FILE" || echo '000')"

    case "$code" in
        200)
            log_ok "kb.sypnose.cloud reachable (200) — Cloudflare Access already authorized for this network"
            ;;
        302|401|403)
            log_info "kb.sypnose.cloud responded ${code} — expected before browser login (next step)"
            ;;
        000)
            log_warn "Could not reach kb.sypnose.cloud (network/DNS). Check connectivity. Non-fatal."
            ;;
        *)
            log_warn "kb.sypnose.cloud responded ${code} (unexpected, non-fatal)"
            ;;
    esac
}

# ----------------------------------------------------------------------------
# SUMMARY
# ----------------------------------------------------------------------------

print_summary() {
    log_head "SUMMARY"

    if [ "${#INSTALLED[@]}" -gt 0 ]; then
        for item in "${INSTALLED[@]}"; do
            log_ok "$item"
        done
    fi

    _log ""
    _log "============================================================"
    _log "  SYPNOSE v${VERSION} INSTALLED"
    _log "============================================================"
    _log "  MCPs configured (4 SSE):"
    _log "    - knowledge-hub    -> https://kb.sypnose.cloud/sse"
    _log "    - sypnose-memory   -> https://memory.sypnose.cloud/sse"
    _log "    - sypnose-hub      -> https://hub.sypnose.cloud/sse"
    _log "    - sypnose-lightrag -> https://lightrag.sypnose.cloud/sse"
    _log ""
    _log "  Config files written:"
    _log "    - ${CLAUDE_DESKTOP_CONFIG}"
    _log "    - ${CLAUDE_CLI_CONFIG}"
    _log "  Log: ${LOG_FILE}"
    _log "============================================================"
    _log ""
    _log "${WHITE}NEXT MANUAL STEP (one-time):${RESET}"
    _log "  1. Fully restart Claude Code (or quit & reopen Claude Desktop)."
    _log "  2. Open https://kb.sypnose.cloud in your browser."
    _log "  3. Cloudflare will ask for your email and a reason — this is"
    _log "     Temporary Authentication. Carlos receives the request via email."
    _log "  4. When Carlos approves, you get a 24h browser session."
    _log "  5. Once approved, the 4 Sypnose MCPs connect automatically."
    _log ""
    _log "  For 24/7 automation (no re-login each 24h), ask Carlos to issue"
    _log "  you a Service Token (advanced setup, see docs/TUNNELS.md)."
    _log ""

    if $DRY_RUN; then
        _log "  ${YELLOW}[DRY-RUN] Nothing was actually written.${RESET}"
    fi
}

# ----------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------

_log ""
_log "${CYAN}============================================================${RESET}"
_log "${CYAN}  Sypnose v${VERSION} - Public Installer (macOS / Linux)${RESET}"
_log "${CYAN}============================================================${RESET}"

if $DRY_RUN; then
    _log "  ${YELLOW}[DRY-RUN MODE - no changes will be made]${RESET}"
fi

detect_os
detect_tools
show_missing_help

if ! $DRY_RUN && ! $AUTO_YES; then
    if ! confirm "Proceed with install?"; then
        log_info "Aborted by user."
        exit 0
    fi
fi

download_canonical
configure_claude
install_commands
smoke_check
print_summary

exit 0
