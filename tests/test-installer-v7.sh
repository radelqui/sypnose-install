#!/usr/bin/env bash
# tests/test-installer-v7.sh
# E2E test for Sypnose v7 installer (Linux/Mac) — simulates a "clean PC".
# Creates a sandbox HOME, runs the installer, and verifies artifacts.
#
# Usage:
#   bash tests/test-installer-v7.sh                 # run + cleanup
#   bash tests/test-installer-v7.sh --keep          # keep sandbox after run
#   bash tests/test-installer-v7.sh --local PATH    # use local install-local.sh instead of curl
#   INSTALL_URL=... bash tests/test-installer-v7.sh # override installer URL
#
# Exit code: 0 on full success, !=0 on any failed check.

set -u

# --- args ---------------------------------------------------------------
KEEP=0
LOCAL_INSTALLER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)  KEEP=1; shift ;;
    --local) LOCAL_INSTALLER="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

INSTALL_URL="${INSTALL_URL:-https://sypnose.cloud/install}"
FALLBACK_URL="https://raw.githubusercontent.com/radelqui/sypnose-install/main/install-local.sh"

# --- sandbox ------------------------------------------------------------
SANDBOX="/tmp/sypnose-v7-test-sandbox"
rm -rf "$SANDBOX"
mkdir -p "$SANDBOX/.config" "$SANDBOX/.claude/commands" "$SANDBOX/Library/Application Support/Claude"

export HOME="$SANDBOX"
export XDG_CONFIG_HOME="$SANDBOX/.config"

# Detect platform — config path differs.
case "$(uname -s)" in
  Darwin*) CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
  *)       CONFIG="$HOME/.config/Claude/claude_desktop_config.json" ;;
esac

PASS=0; FAIL=0
RESULTS=()

step() {
  local status="$1" msg="$2"
  if [[ "$status" == "ok" ]]; then
    RESULTS+=("OK    $msg"); PASS=$((PASS+1))
  else
    RESULTS+=("FAIL  $msg"); FAIL=$((FAIL+1))
  fi
}

echo "==> Sypnose v7 installer test (Linux/Mac)"
echo "    HOME=$HOME"
echo "    CONFIG=$CONFIG"
echo

# --- step 1: run installer ---------------------------------------------
T0=$(date +%s)
if [[ -n "$LOCAL_INSTALLER" ]]; then
  echo "==> Running local installer: $LOCAL_INSTALLER"
  bash "$LOCAL_INSTALLER" </dev/null
  RC=$?
else
  echo "==> Fetching + running: $INSTALL_URL"
  if ! curl -fsSL "$INSTALL_URL" | bash </dev/null; then
    echo "    primary failed, trying fallback: $FALLBACK_URL"
    curl -fsSL "$FALLBACK_URL" | bash </dev/null
    RC=$?
  else
    RC=0
  fi
fi
T1=$(date +%s)
DUR=$((T1 - T0))

if [[ $RC -eq 0 ]]; then step ok "installer exited 0 (${DUR}s)"
else                     step fail "installer exited $RC (${DUR}s)"; fi

# --- step 2: config file exists ----------------------------------------
if [[ -f "$CONFIG" ]]; then
  step ok "config file exists at $CONFIG"
else
  step fail "config file missing at $CONFIG"
fi

# --- step 3: parse + verify 4 MCPs SSE ---------------------------------
EXPECTED_MCPS=(knowledge-hub sypnose-memory sypnose-hub sypnose-lightrag)
EXPECTED_HOSTS=(kb.sypnose.cloud memory.sypnose.cloud hub.sypnose.cloud lightrag.sypnose.cloud)

if [[ -f "$CONFIG" ]]; then
  if command -v jq >/dev/null 2>&1; then
    for i in "${!EXPECTED_MCPS[@]}"; do
      mcp="${EXPECTED_MCPS[$i]}"
      host="${EXPECTED_HOSTS[$i]}"
      cmd=$(jq -r ".mcpServers[\"$mcp\"].command // empty" "$CONFIG")
      args=$(jq -r ".mcpServers[\"$mcp\"].args | join(\" \") // empty" "$CONFIG")
      if [[ "$cmd" == "npx" ]] && [[ "$args" == *"supergateway"* ]] && [[ "$args" == *"$host/sse"* ]]; then
        step ok "MCP '$mcp' = npx supergateway --sse https://$host/sse"
      else
        step fail "MCP '$mcp' missing or malformed (cmd='$cmd' args='$args')"
      fi
    done
  else
    # Fallback grep-based check.
    for i in "${!EXPECTED_MCPS[@]}"; do
      mcp="${EXPECTED_MCPS[$i]}"
      host="${EXPECTED_HOSTS[$i]}"
      if grep -q "\"$mcp\"" "$CONFIG" && grep -q "$host/sse" "$CONFIG"; then
        step ok "MCP '$mcp' present (grep, host=$host)"
      else
        step fail "MCP '$mcp' missing or wrong host (grep)"
      fi
    done
    step ok "(jq not installed — used grep fallback; install jq for stricter checks)"
  fi
else
  step fail "skipped MCP checks (no config file)"
fi

# --- step 4: skill/command file exists ---------------------------------
SKILL="$HOME/.claude/commands/sypnose-execute.md"
if [[ -f "$SKILL" ]]; then
  step ok "skill present: $SKILL"
else
  step fail "skill missing: $SKILL"
fi

# --- report ------------------------------------------------------------
echo
echo "==> Results"
for line in "${RESULTS[@]}"; do echo "    $line"; done
echo
echo "    PASS=$PASS  FAIL=$FAIL  TOTAL_TIME=${DUR}s"

# --- cleanup -----------------------------------------------------------
if [[ $KEEP -eq 1 ]]; then
  echo "==> Sandbox kept at $SANDBOX (--keep)"
else
  rm -rf "$SANDBOX"
  echo "==> Sandbox removed"
fi

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
