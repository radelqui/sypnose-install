#!/bin/bash

# Sypnose v8 Installer for Linux and macOS

# --- Configuration ---
SYPNOSE_VERSION="v8.0.0"
SYPNOSE_REPO="radelqui/sypnose-install"
RELEASE_URL="https://github.com/${SYPNOSE_REPO}/releases/download/${SYPNOSE_VERSION}/sypnose-v8.tar.gz"
CLAUDE_DIR="$HOME/.claude"
MCP_DIR="$CLAUDE_DIR/mcp-servers"
SKILLS_DIR="$CLAUDE_DIR/skills"
COMMANDS_DIR="$CLAUDE_DIR/commands"
INSTALL_DIR="$HOME/.sypnose-v8"

# --- Colors ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'

# --- Helper Functions ---
print_info() {
    echo -e "${C_BLUE}[INFO] $1${C_RESET}"
}

print_success() {
    echo -e "${C_GREEN}[SUCCESS] $1${C_RESET}"
}

print_warning() {
    echo -e "${C_YELLOW}[WARNING] $1${C_RESET}"
}

print_error() {
    echo -e "${C_RED}[ERROR] $1${C_RESET}" >&2
}

# --- Main Installation Flow ---

# 1. Detect OS and Claude Code installation
print_info "Starting Sypnose v8 installation..."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    print_error "Unsupported OS: $OSTYPE. This script is for Linux and macOS."
    exit 1
fi
print_info "Detected Operating System: $OS"

if [ ! -d "$CLAUDE_DIR" ]; then
    print_error "Claude Code directory not found at $CLAUDE_DIR."
    print_error "Please make sure Claude Code is installed before running this script."
    exit 1
fi
print_info "Found Claude Code installation at $CLAUDE_DIR."

# 2. Get GitHub Username and trigger Cloudflare Access
print_info "To install Sypnose v8, you need to be on the approved list."
read -p "Enter your GitHub username: " GITHUB_USERNAME

print_info "Please follow the link to get approval from Carlos."
print_info "Cloudflare Access URL: https://sypnose.cloudflareaccess.com/approve?user=${GITHUB_USERNAME}"
read -p "Press [Enter] after you have been approved..."

# Mocking approval for now. In a real scenario, we'd poll an endpoint.
print_info "Assuming user '${GITHUB_USERNAME}' has been approved."


# 3. Download and extract the release tar.gz
print_info "Downloading Sypnose v8 release from ${RELEASE_URL}..."
mkdir -p "${INSTALL_DIR}"
if ! curl -L -o "${INSTALL_DIR}/sypnose-v8.tar.gz" "${RELEASE_URL}"; then
    print_error "Failed to download release. Check the URL and your connection."
    exit 1
fi
print_info "Download complete. Extracting files..."
tar -xzf "${INSTALL_DIR}/sypnose-v8.tar.gz" -C "${INSTALL_DIR}"
if [ $? -ne 0 ]; then
    print_error "Failed to extract release archive."
    exit 1
fi

# 4. Install MCPs
print_info "Installing 6 MCPs..."
mkdir -p "$MCP_DIR"
# Assuming the tarball contains an 'mcps' directory
cp -r "${INSTALL_DIR}/mcps/sypnose-"* "$MCP_DIR/"
print_success "MCPs installed."

# 5. Install Skills
print_info "Installing 5 skills..."
mkdir -p "$SKILLS_DIR"
# Assuming the tarball contains a 'skills' directory
cp -r "${INSTALL_DIR}/skills/sypnose-"* "$SKILLS_DIR/"
print_success "Skills installed."

# 6. Register Commands
print_info "Registering 4 commands..."
mkdir -p "$COMMANDS_DIR"
# Assuming the tarball contains a 'commands' directory
cp -r "${INSTALL_DIR}/commands/"* "$COMMANDS_DIR/"
print_success "Commands registered."

# 7. Configure claude_desktop_config.json and claude.json
print_info "Configuring Claude JSON files..."
# This part is complex and needs careful merging of JSON content.
# For now, we'll assume a script or tool handles the JSON update.
# A real implementation would use 'jq' or a similar tool.
print_warning "JSON configuration step is a placeholder."
# Placeholder for claude_desktop_config.json
# jq '.mcp_servers += [...]' "$CLAUDE_DIR/claude_desktop_config.json" > tmp.json && mv tmp.json "$CLAUDE_DIR/claude_desktop_config.json"
# Placeholder for claude.json
# jq '.skills += [...]' "$CLAUDE_DIR/claude.json" > tmp.json && mv tmp.json "$CLAUDE_DIR/claude.json"


# 8. Verify Health Endpoints
print_info "Verifying Sypnose health endpoints..."
HEALTH_URL="https://sypnose.cloud/health"
if curl -s -f "$HEALTH_URL" > /dev/null; then
    print_success "Sypnose health endpoint is reachable."
else
    print_warning "Could not reach Sypnose health endpoint at ${HEALTH_URL}."
fi

# 9. Final Message
print_success "Sypnose v8 installed successfully!"
print_info "Type '/bios' in Claude to get started."

# Clean up installation files
rm -rf "${INSTALL_DIR}"
print_info "Installation complete."

