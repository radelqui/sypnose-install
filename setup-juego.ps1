$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  SETUP JUEGO PC — Terminal + SSH + Profile" -ForegroundColor Cyan
Write-Host ""

# ── 1. Windows Terminal ─────────────────────────────────
Write-Host "  [1/5] Windows Terminal..." -ForegroundColor DarkGray -NoNewline
$wt = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
if ($wt) {
    Write-Host " YA INSTALADO" -ForegroundColor Green
} else {
    try {
        winget install --id Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements -e 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Host " INSTALADO" -ForegroundColor Green }
        else { throw "winget fallo" }
    } catch {
        Write-Host " FALLO — instala Windows Terminal desde Microsoft Store" -ForegroundColor Red
        Write-Host "    ms-windows-store://pdp/?productid=9N0DX20HK701" -ForegroundColor DarkGray
    }
}

# ── 2. SSH key + config ─────────────────────────────────
Write-Host "  [2/5] SSH config..." -ForegroundColor DarkGray -NoNewline
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (!(Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir -Force | Out-Null }

# Buscar key existente
$key = $null
foreach ($p in @("*radelqui*","id_ed25519","id_rsa")) {
    $f = Get-ChildItem $sshDir -Filter $p -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne ".pub" -and $_.Name -ne "config" -and $_.Name -ne "known_hosts" }
    if ($f) { $key = ($f | Select-Object -First 1).Name; break }
}
if (!$key) {
    Write-Host " NO HAY KEY — generando..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -f "$sshDir\id_ed25519" -N '""' -q
    $key = "id_ed25519"
    Write-Host ""
    Write-Host "  !! KEY NUEVA GENERADA — necesitas añadir la pubkey al servidor !!" -ForegroundColor Red
    Write-Host "  Pubkey:" -ForegroundColor Yellow
    Get-Content "$sshDir\$key.pub"
    Write-Host ""
}

$sshConfig = Join-Path $sshDir "config"
$hasBlock = (Test-Path $sshConfig) -and ((Get-Content $sshConfig -Raw -ErrorAction SilentlyContinue) -match "sypnose-67")
if ($hasBlock) {
    Write-Host " YA EXISTE (key: $key)" -ForegroundColor Green
} else {
    @"

Host sypnose-67
    HostName 62.171.147.46
    Port 2024
    User sypnose
    IdentityFile ~/.ssh/$key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 30
"@ | Add-Content $sshConfig -Encoding UTF8
    Write-Host " CREADO (key: $key)" -ForegroundColor Green
}

# ── 3. JetBrainsMono Nerd Font ──────────────────────────
Write-Host "  [3/5] Font JetBrainsMono..." -ForegroundColor DarkGray -NoNewline
$fontCheck = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -like "*JetBrainsMono*Nerd*" }
if ($fontCheck) {
    Write-Host " YA INSTALADA" -ForegroundColor Green
} else {
    try {
        $zip = Join-Path $env:TEMP "JBM.zip"
        $dir = Join-Path $env:TEMP "JBM"
        Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -OutFile $zip -UseBasicParsing
        Expand-Archive $zip $dir -Force
        $sh = New-Object -ComObject Shell.Application
        $ff = $sh.Namespace(0x14)
        Get-ChildItem $dir -Filter "*.ttf" | ForEach-Object { $ff.CopyHere($_.FullName, 0x14) }
        Remove-Item $zip,$dir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host " INSTALADA" -ForegroundColor Green
    } catch { Write-Host " FALLO — instala desde nerdfonts.com" -ForegroundColor Yellow }
}

# ── 4. Windows Terminal profile ─────────────────────────
Write-Host "  [4/5] Perfil WT..." -ForegroundColor DarkGray -NoNewline
$wtSettings = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (!(Test-Path $wtSettings)) {
    $wtPkg = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
    if ($wtPkg) {
        Start-Process "wt.exe" -ErrorAction SilentlyContinue
        Start-Sleep 4
        Stop-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue -Force
        Start-Sleep 1
    }
}

if (!(Test-Path $wtSettings)) {
    Write-Host " WT no disponible aun" -ForegroundColor Yellow
} else {
    $json = Get-Content $wtSettings -Raw | ConvertFrom-Json
    $exists = $json.profiles.list | Where-Object { $_.name -like "*Juego*" -or $_.name -like "*Sypnose*" }
    if ($exists) {
        Write-Host " YA EXISTE" -ForegroundColor Green
    } else {
        if (!$json.schemes) { $json | Add-Member -NotePropertyName schemes -NotePropertyValue @() -Force }
        if (!($json.schemes | Where-Object { $_.name -eq "Dracula" })) {
            $json.schemes += @{
                name="Dracula"; background="#282A36"; foreground="#F8F8F2"; cursorColor="#F8F8F2"
                selectionBackground="#44475A"; black="#21222C"; red="#FF5555"; green="#50FA7B"
                yellow="#F1FA8C"; blue="#BD93F9"; purple="#FF79C6"; cyan="#8BE9FD"; white="#F8F8F2"
                brightBlack="#6272A4"; brightRed="#FF6E6E"; brightGreen="#69FF94"; brightYellow="#FFFFA5"
                brightBlue="#D6ACFF"; brightPurple="#FF92DF"; brightCyan="#A4FFFF"; brightWhite="#FFFFFF"
            }
        }

        # Perfil: click derecho en C:\juego -> abre tmux del servidor
        $json.profiles.list += @{
            guid="{5ypn05e-0067-jueg-0001-000000000001}"
            name="Juego (Sypnose 67 tmux)"
            commandline="ssh sypnose-67 -t `"tmux attach -t juego 2>/dev/null || tmux new -s juego -c /home/sypnose/juego`""
            startingDirectory="C:\juego"
            tabColor="#DA7756"
            tabTitle="Juego tmux"
            suppressApplicationTitle=$true
            hidden=$false
            colorScheme="Dracula"
            font=@{face="JetBrainsMono Nerd Font";size=11;weight="normal"}
            cursorShape="bar"
            padding="16"
        }
        $json.profiles.list += @{
            guid="{5ypn05e-0067-jueg-0001-000000000002}"
            name="Sypnose 67 (shell)"
            commandline="ssh sypnose-67"
            startingDirectory="%USERPROFILE%"
            tabColor="#6B7280"
            tabTitle="Sypnose Shell"
            suppressApplicationTitle=$true
            hidden=$false
            colorScheme="Dracula"
            font=@{face="JetBrainsMono Nerd Font";size=11;weight="normal"}
            cursorShape="bar"
            padding="16"
        }

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

# ── 5. PowerShell $PROFILE — boton derecho auto-connect ─
Write-Host "  [5/5] PowerShell profile..." -ForegroundColor DarkGray -NoNewline
$profilePath = [System.IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'), "WindowsPowerShell", "Microsoft.PowerShell_profile.ps1")
$profileDir = Split-Path $profilePath
if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }

$profileBlock = @'

# ── SYPNOSE JUEGO — auto-connect al servidor ──────────
$_JUEGO_DIR = "C:\juego"
if ((Get-Location).Path -eq $_JUEGO_DIR -or (Get-Location).Path.StartsWith("$_JUEGO_DIR\")) {
    $host.UI.RawUI.WindowTitle = "Juego (Sypnose 67)"
    Write-Host ""
    Write-Host "  JUEGO — conectando al servidor..." -ForegroundColor Cyan
    Write-Host ""
    ssh sypnose-67 -t "tmux attach -t juego 2>/dev/null || tmux new -s juego -c /home/sypnose/juego"
    Write-Host ""
    Write-Host "  Desconectado. Escribe 'juego' para reconectar." -ForegroundColor Yellow
}

function juego {
    ssh sypnose-67 -t "tmux attach -t juego 2>/dev/null || tmux new -s juego -c /home/sypnose/juego"
}
# ── FIN SYPNOSE JUEGO ─────────────────────────────────
'@

$profileExists = (Test-Path $profilePath) -and ((Get-Content $profilePath -Raw -ErrorAction SilentlyContinue) -match "SYPNOSE JUEGO")
if ($profileExists) {
    Write-Host " YA EXISTE" -ForegroundColor Green
} else {
    Add-Content $profilePath $profileBlock -Encoding UTF8
    Write-Host " INSTALADO" -ForegroundColor Green
}

# ── 6. Registrar como default para C:\juego ─────────────
# Configurar Windows Terminal como terminal por defecto para boton derecho
Write-Host ""
Write-Host "  [+] Para que boton derecho en C:\juego abra el tmux:" -ForegroundColor White
Write-Host "      1. Abre Windows Terminal" -ForegroundColor Gray
Write-Host "      2. Settings > Startup > Default terminal: Windows Terminal" -ForegroundColor Gray
Write-Host "      3. Ahora boton derecho en C:\juego > 'Abrir en terminal'" -ForegroundColor Gray
Write-Host "      4. Se conecta AUTOMATICO al tmux del servidor" -ForegroundColor Gray

# ── Test SSH ────────────────────────────────────────────
Write-Host ""
Write-Host "  Test SSH..." -ForegroundColor DarkGray -NoNewline
$test = & ssh -o ConnectTimeout=10 -o BatchMode=yes sypnose-67 "echo OK" 2>&1
if ("$test" -match "OK") {
    Write-Host " CONECTADO" -ForegroundColor Green
} else {
    Write-Host " FALLO" -ForegroundColor Red
    Write-Host "    $test" -ForegroundColor DarkGray
    Write-Host "    Si es key nueva, pasa la pubkey a Carlos para añadirla al servidor" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  SETUP COMPLETO" -ForegroundColor Green
Write-Host ""
