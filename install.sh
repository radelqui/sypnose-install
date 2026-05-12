#!/bin/bash

# Sypnose v8.1 Installer for Linux and macOS
# Adds ssh-mcp multi-host on top of v8.0.0.

set -e

# --- Configuration ---
SYPNOSE_VERSION="v8.1.0"
SYPNOSE_REPO="radelqui/sypnose-install"
RELEASE_URL="https://api.github.com/repos/${SYPNOSE_REPO}/tarball/refs/tags/${SYPNOSE_VERSION}"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_JSON="$HOME/.claude.json"
MCP_DIR="$CLAUDE_DIR/mcp-servers"
SKILLS_DIR="$CLAUDE_DIR/skills"
COMMANDS_DIR="$CLAUDE_DIR/commands"
INSTALL_DIR="$HOME/.sypnose-v8.1"

# --- Colors ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'

# --- Helper Functions ---
print_info()    { echo -e "${C_BLUE}[INFO] $1${C_RESET}"; }
print_success() { echo -e "${C_GREEN}[SUCCESS] $1${C_RESET}"; }
print_warning() { echo -e "${C_YELLOW}[WARNING] $1${C_RESET}"; }
print_error()   { echo -e "${C_RED}[ERROR] $1${C_RESET}" >&2; }

# --- Main Installation Flow ---

# 1. Detect OS and Claude Code installation
print_info "Starting Sypnose v8.1 installation..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    print_error "Unsupported OS: $OSTYPE. Use install.ps1 on Windows."
    exit 1
fi
print_info "Detected OS: $OS"

if [ ! -d "$CLAUDE_DIR" ]; then
    print_error "Claude Code directory not found at $CLAUDE_DIR. Install Claude Code first."
    exit 1
fi
print_info "Found Claude Code installation at $CLAUDE_DIR"

if ! command -v jq >/dev/null 2>&1; then
    print_error "'jq' is required for JSON merge but is not installed."
    print_error "Install it with: 'sudo apt install jq' (Debian/Ubuntu) or 'brew install jq' (macOS)."
    exit 1
fi
print_info "jq available: $(jq --version)"

# 2. Get GitHub Username and trigger Cloudflare Access
print_info "To install Sypnose v8.1, you need to be on the approved list."
read -p "Enter your GitHub username: " GITHUB_USERNAME
print_info "Cloudflare Access URL: https://sypnose.cloudflareaccess.com/approve?user=${GITHUB_USERNAME}"
read -p "Press [Enter] after you have been approved..."
print_info "Assuming user '${GITHUB_USERNAME}' has been approved."

# 3. Download and extract the release tar.gz
print_info "Downloading Sypnose v8.1 release from ${RELEASE_URL}..."
mkdir -p "${INSTALL_DIR}"
if ! curl -L --fail -o "${INSTALL_DIR}/sypnose-v8.1.tar.gz" "${RELEASE_URL}"; then
    print_error "Failed to download release. Check URL and connection."
    exit 1
fi
print_info "Extracting..."
tar -xzf "${INSTALL_DIR}/sypnose-v8.1.tar.gz" -C "${INSTALL_DIR}"

# locate the unpacked root (GitHub tarballs prefix the top dir with the repo+sha)
SRC_ROOT=$(find "${INSTALL_DIR}" -maxdepth 2 -type d -name 'mcp-kb' | head -1)
SRC_ROOT="${SRC_ROOT%/mcp-kb}"
if [ -z "$SRC_ROOT" ] || [ ! -d "$SRC_ROOT" ]; then
    print_error "Could not locate plugin root after extraction."
    exit 1
fi
print_info "Source root: $SRC_ROOT"

# 4. Install MCPs
print_info "Installing 7 MCPs (kb, memory, a2a, boris, graphify, claw, ssh-mcp)..."
mkdir -p "$MCP_DIR"
for d in mcp-kb mcp-memory mcp-a2a mcp-boris mcp-graphify mcp-claw mcp-ssh; do
    if [ -d "$SRC_ROOT/$d" ]; then
        cp -r "$SRC_ROOT/$d" "$MCP_DIR/"
    fi
done
print_success "MCPs installed."

# 5. Install Skills
print_info "Installing 5 skills..."
mkdir -p "$SKILLS_DIR"
if [ -d "$SRC_ROOT/skills" ]; then
    cp -r "$SRC_ROOT/skills/." "$SKILLS_DIR/"
fi
print_success "Skills installed."

# 6. Register Commands
print_info "Registering commands..."
mkdir -p "$COMMANDS_DIR"
if [ -d "$SRC_ROOT/commands" ]; then
    cp -r "$SRC_ROOT/commands/." "$COMMANDS_DIR/"
fi
print_success "Commands registered."

# 7. Configure ~/.claude.json — inject ssh-mcp profiles from manifest
print_info "Configuring ~/.claude.json with ssh-mcp profiles..."

if [ ! -f "$CLAUDE_JSON" ]; then
    print_error "~/.claude.json not found. Open Claude Code at least once before installing Sypnose."
    exit 1
fi

BACKUP="${CLAUDE_JSON}.bak-pre-sypnose-v81-$(date +%Y%m%d-%H%M%S)"
cp "$CLAUDE_JSON" "$BACKUP"
print_info "Backup saved to $BACKUP"

MANIFEST="$SRC_ROOT/manifest.json"
if [ ! -f "$MANIFEST" ]; then
    print_error "manifest.json not found at $MANIFEST"
    exit 1
fi

# Determine which project key to inject under (use $HOME by default).
PROJECT_KEY="$HOME"

# Iterate ssh-mcp profiles via jq and inject one MCP entry per profile.
NUM_PROFILES=$(jq '.mcpServers[] | select(.name=="ssh-mcp") | .default_profiles | length' "$MANIFEST")
if [ -z "$NUM_PROFILES" ] || [ "$NUM_PROFILES" = "null" ] || [ "$NUM_PROFILES" -eq 0 ]; then
    print_warning "No ssh-mcp profiles found in manifest. Skipping ssh-mcp injection."
else
    for i in $(seq 0 $((NUM_PROFILES - 1))); do
        NAME=$(jq -r --argjson i "$i" '.mcpServers[] | select(.name=="ssh-mcp") | .default_profiles[$i].name' "$MANIFEST")
        HOST=$(jq -r --argjson i "$i" '.mcpServers[] | select(.name=="ssh-mcp") | .default_profiles[$i].host' "$MANIFEST")
        PORT=$(jq -r --argjson i "$i" '.mcpServers[] | select(.name=="ssh-mcp") | .default_profiles[$i].port' "$MANIFEST")
        USER_=$(jq -r --argjson i "$i" '.mcpServers[] | select(.name=="ssh-mcp") | .default_profiles[$i].user' "$MANIFEST")
        KEY_ENV=$(jq -r --argjson i "$i" '.mcpServers[] | select(.name=="ssh-mcp") | .default_profiles[$i].key_env' "$MANIFEST")
        DEFAULT_KEY=$(jq -r --argjson i "$i" '.mcpServers[] | select(.name=="ssh-mcp") | .default_profiles[$i].default_key' "$MANIFEST")

        # Resolve key: env var > default. Expand ~ to $HOME.
        KEY_PATH="${!KEY_ENV:-$DEFAULT_KEY}"
        KEY_PATH="${KEY_PATH/#\~/$HOME}"

        if [ ! -f "$KEY_PATH" ]; then
            print_warning "SSH key for profile $NAME not found at $KEY_PATH — registering anyway, set $KEY_ENV before use."
        fi

        TMP="$(mktemp)"
        jq --arg pk "$PROJECT_KEY" \
           --arg name "$NAME" \
           --arg host "$HOST" \
           --argjson port "$PORT" \
           --arg user "$USER_" \
           --arg key "$KEY_PATH" '
            .projects = (.projects // {}) |
            .projects[$pk] = (.projects[$pk] // {}) |
            .projects[$pk].mcpServers = (.projects[$pk].mcpServers // {}) |
            .projects[$pk].mcpServers[$name] = {
                type: "stdio",
                command: "npx",
                args: ["-y", "ssh-mcp", "--",
                       ("--host=" + $host),
                       ("--port=" + ($port|tostring)),
                       ("--user=" + $user),
                       ("--key=" + $key)],
                env: {}
            }
           ' "$CLAUDE_JSON" > "$TMP" && mv "$TMP" "$CLAUDE_JSON"

        print_success "Registered MCP '$NAME' -> $USER_@$HOST:$PORT (key: $KEY_PATH)"
    done
fi

# 8. Verify Health Endpoints (best effort, non-blocking)
print_info "Verifying local health endpoints..."
for url in "http://localhost:18791/health" "http://localhost:18792/health" "http://localhost:18790/health"; do
    if curl -s -f --max-time 3 "$url" > /dev/null 2>&1; then
        print_success "Reachable: $url"
    else
        print_warning "Not reachable (skip if you don't run these locally): $url"
    fi
done

# 9. Cleanup + final message
rm -rf "${INSTALL_DIR}"
print_success "Sypnose v8.1 installed successfully!"
print_info "Restart Claude Code so the new MCP servers are loaded."
print_info "Then type '/bios' to start."
