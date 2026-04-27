# Sypnose v7 — Installer E2E tests

Smoke tests that simulate a "clean PC" and verify the v7 installer drops the right
files in the right places. They do **not** require a running Claude Desktop —
they only check filesystem artifacts.

## What gets verified

1. The installer runs without a non-zero exit.
2. `claude_desktop_config.json` exists at the OS-correct path.
3. The 4 SSE MCPs are present and well-formed:
   - `knowledge-hub`     → `https://kb.sypnose.cloud/sse`
   - `sypnose-memory`    → `https://memory.sypnose.cloud/sse`
   - `sypnose-hub`       → `https://hub.sypnose.cloud/sse`
   - `sypnose-lightrag`  → `https://lightrag.sypnose.cloud/sse`
   - Each must be `command: "npx"` with `args` including `supergateway` and the URL.
4. `~/.claude/commands/sypnose-execute.md` exists.

Each step prints `OK` or `FAIL`, and the script exits non-zero if anything fails.

## How to run

### Linux / macOS
```bash
bash tests/test-installer-v7.sh                # default: fetch installer over HTTPS, cleanup at end
bash tests/test-installer-v7.sh --keep         # keep the sandbox after the run
bash tests/test-installer-v7.sh --local ../install-local.sh   # use a local copy of the installer
INSTALL_URL=https://example/install bash tests/test-installer-v7.sh   # override URL
```

Sandbox: `/tmp/sypnose-v7-test-sandbox/`
- `HOME` and `XDG_CONFIG_HOME` are redirected into the sandbox.
- On macOS the test looks at `~/Library/Application Support/Claude/...`.
- On Linux it looks at `~/.config/Claude/...`.
- `jq` is used if available for strict JSON checks; otherwise it falls back to grep.

### Windows (PowerShell)
```powershell
.\tests\test-installer-v7.ps1                                      # default
.\tests\test-installer-v7.ps1 -KeepSandbox                         # keep sandbox
.\tests\test-installer-v7.ps1 -LocalInstaller C:\path\install-local.ps1
.\tests\test-installer-v7.ps1 -InstallUrl https://example/install.ps1
```

Sandbox: `$env:TEMP\sypnose-v7-test-sandbox\`
- `%APPDATA%` and `%USERPROFILE%` are redirected into the sandbox while the script runs and restored at the end.
- Config is checked at `$env:APPDATA\Claude\claude_desktop_config.json`.

## Limitations (read before reporting bugs)

- These tests **only verify files on disk**. They do not start Claude Desktop and do not check that the MCPs actually connect — that requires Cloudflare Access sign-in and a Claude restart, which is out of scope.
- The "Restart Claude Desktop" step from the installer is intentionally **not** exercised.
- They do not test Cloudflare Access self-service enrollment.
- `npx supergateway` may run on first MCP connect and download packages; that side effect is not measured here.
- On Windows, env-var redirection is process-local. Other tools spawned outside the script (e.g. a real Claude Desktop already running) still see the real `%APPDATA%`.
- The shell test redirects `HOME` only inside the script; if the installer spawns subprocesses that bypass `HOME`, those would touch the real home directory. Inspect the installer if in doubt.

## Reporting bugs

If a test fails, attach:

1. The full console output (step-by-step OK/FAIL list).
2. The contents of the sandbox config file (run with `--keep` / `-KeepSandbox`):
   - Linux:   `/tmp/sypnose-v7-test-sandbox/.config/Claude/claude_desktop_config.json`
   - macOS:   `/tmp/sypnose-v7-test-sandbox/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%TEMP%\sypnose-v7-test-sandbox\Roaming\Claude\claude_desktop_config.json`
3. The installer URL used and OS / shell version.
4. Diff against `agent-config-canonical.json` (in the parent dir) — that is the source of truth for the expected MCP block.

File issues at the `radelqui/sypnose-install` repo or paste a KB report with key
`resultado-test-installer-v7-<fecha>` and category `report`.
