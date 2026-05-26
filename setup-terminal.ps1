$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  SETUP TERMINAL — Sypnose" -ForegroundColor Cyan
Write-Host ""

# ── 1. Instalar Windows Terminal ────────────────────────
Write-Host "  [1] Windows Terminal..." -ForegroundColor DarkGray -NoNewline
$wt = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
if ($wt) {
    Write-Host " YA INSTALADO" -ForegroundColor Green
} else {
    try {
        winget install --id Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements -e 2>$null
        Write-Host " INSTALADO" -ForegroundColor Green
    } catch {
        Write-Host " FALLO winget, probando Store..." -ForegroundColor Yellow
        Start-Process "ms-windows-store://pdp/?productid=9N0DX20HK701"
        Write-Host " Abre Microsoft Store e instala Windows Terminal manualmente" -ForegroundColor Yellow
    }
}

# ── 2. SSH config ───────────────────────────────────────
Write-Host "  [2] SSH config..." -ForegroundColor DarkGray -NoNewline
$sshDir = Join-Path $env:USERPROFILE ".ssh"
$sshConfig = Join-Path $sshDir "config"
if (!(Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }

# Buscar key
$key = $null
foreach ($pattern in @("*radelqui*","id_ed25519","id_rsa")) {
    $found = Get-ChildItem $sshDir -Filter $pattern -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne ".pub" -and $_.Name -ne "config" -and $_.Name -ne "known_hosts" }
    if ($found) { $key = ($found | Select-Object -First 1).Name; break }
}

if (!$key) {
    Write-Host " NO HAY SSH KEY" -ForegroundColor Red
    Write-Host "    Genera una: ssh-keygen -t ed25519 -f $sshDir\id_ed25519" -ForegroundColor Yellow
    exit 1
}

$configExists = (Test-Path $sshConfig) -and ((Get-Content $sshConfig -Raw -ErrorAction SilentlyContinue) -match "sypnose-67")
if ($configExists) {
    Write-Host " YA EXISTE (key: $key)" -ForegroundColor Green
} else {
    $block = @"

# Servidor Sypnose 67
Host sypnose-67
    HostName 62.171.147.46
    Port 2024
    User sypnose
    IdentityFile ~/.ssh/$key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 30
"@
    Add-Content $sshConfig $block -Encoding UTF8
    Write-Host " CREADO (key: $key)" -ForegroundColor Green
}

# ── 3. JetBrainsMono Nerd Font ──────────────────────────
Write-Host "  [3] Font JetBrainsMono..." -ForegroundColor DarkGray -NoNewline
$fontInstalled = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -like "*JetBrainsMono*Nerd*" }
if ($fontInstalled) {
    Write-Host " YA INSTALADA" -ForegroundColor Green
} else {
    try {
        $fontZip = Join-Path $env:TEMP "JetBrainsMono.zip"
        $fontDir = Join-Path $env:TEMP "JetBrainsMono"
        Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -OutFile $fontZip -UseBasicParsing
        Expand-Archive -Path $fontZip -DestinationPath $fontDir -Force
        $shell = New-Object -ComObject Shell.Application
        $fontsFolder = $shell.Namespace(0x14)
        Get-ChildItem $fontDir -Filter "*.ttf" | ForEach-Object { $fontsFolder.CopyHere($_.FullName, 0x14) }
        Remove-Item $fontZip, $fontDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host " INSTALADA" -ForegroundColor Green
    } catch {
        Write-Host " FALLO — instala desde nerdfonts.com" -ForegroundColor Yellow
    }
}

# ── 4. Perfil Windows Terminal ──────────────────────────
Write-Host "  [4] Perfil Terminal..." -ForegroundColor DarkGray -NoNewline
$wtSettings = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (!(Test-Path $wtSettings)) {
    # Abrir y cerrar WT para que cree su config
    $wtPkg = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
    if ($wtPkg) {
        Start-Process "wt.exe" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 4
        Stop-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue -Force
        Start-Sleep -Seconds 1
    }
}

if (!(Test-Path $wtSettings)) {
    Write-Host " WT no genera config — instala WT primero y ejecuta de nuevo" -ForegroundColor Yellow
} else {
    $json = Get-Content $wtSettings -Raw | ConvertFrom-Json

    $exists = $json.profiles.list | Where-Object { $_.name -like "*Sypnose*" }
    if ($exists) {
        Write-Host " YA EXISTE" -ForegroundColor Green
    } else {
        # Dracula scheme
        if (!$json.schemes) { $json | Add-Member -NotePropertyName schemes -NotePropertyValue @() -Force }
        $hasDracula = $json.schemes | Where-Object { $_.name -eq "Dracula" }
        if (!$hasDracula) {
            $json.schemes += @{
                name="Dracula"; background="#282A36"; foreground="#F8F8F2"; cursorColor="#F8F8F2"
                selectionBackground="#44475A"; black="#21222C"; red="#FF5555"; green="#50FA7B"
                yellow="#F1FA8C"; blue="#BD93F9"; purple="#FF79C6"; cyan="#8BE9FD"; white="#F8F8F2"
                brightBlack="#6272A4"; brightRed="#FF6E6E"; brightGreen="#69FF94"; brightYellow="#FFFFA5"
                brightBlue="#D6ACFF"; brightPurple="#FF92DF"; brightCyan="#A4FFFF"; brightWhite="#FFFFFF"
            }
        }

        # Perfiles SSH
        $json.profiles.list += @{
            guid="{5ypn05e-0067-jueg-0000-000000000001}"; name="Sypnose 67 (tmux)"
            commandline="ssh sypnose-67 -t `"tmux attach -t juego 2>/dev/null || tmux new -s juego -c /home/sypnose/juego`""
            startingDirectory="%USERPROFILE%"; tabColor="#DA7756"; tabTitle="Sypnose 67"
            suppressApplicationTitle=$true; hidden=$false; colorScheme="Dracula"
            font=@{face="JetBrainsMono Nerd Font";size=11;weight="normal"}; cursorShape="bar"; padding="16"
        }
        $json.profiles.list += @{
            guid="{5ypn05e-0067-jueg-0000-000000000002}"; name="Sypnose 67 (shell)"
            commandline="ssh sypnose-67"; startingDirectory="%USERPROFILE%"
            tabColor="#6B7280"; tabTitle="Sypnose Shell"
            suppressApplicationTitle=$true; hidden=$false; colorScheme="Dracula"
            font=@{face="JetBrainsMono Nerd Font";size=11;weight="normal"}; cursorShape="bar"; padding="16"
        }

        # Defaults
        if (!$json.profiles.defaults) { $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue @{} -Force }
        $json.profiles.defaults = @{
            colorScheme="Dracula"; cursorShape="bar"
            font=@{face="JetBrainsMono Nerd Font";size=11;weight="normal"}
            opacity=100; padding="16"; useAcrylic=$false
        }

        $json | ConvertTo-Json -Depth 10 | Set-Content $wtSettings -Encoding UTF8
        Write-Host " 2 PERFILES CREADOS" -ForegroundColor Green
    }
}

# ── 5. Test SSH ─────────────────────────────────────────
Write-Host "  [5] Test SSH..." -ForegroundColor DarkGray -NoNewline
$testResult = & ssh -o ConnectTimeout=10 sypnose-67 "echo CONECTADO" 2>&1
if ("$testResult" -match "CONECTADO") {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " FALLO" -ForegroundColor Red
    Write-Host "    $testResult" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  LISTO. Abre Windows Terminal -> perfil 'Sypnose 67 (tmux)'" -ForegroundColor Cyan
Write-Host ""
