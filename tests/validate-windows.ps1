# validate-windows.ps1
# Valida a instalacao Windows depois de rodar windows/setp-windows.ps1.

param(
    [string]$WslDistro = "Ubuntu",
    [switch]$RequireNvidiaTools
)

$ErrorActionPreference = "Continue"
$Passed = 0
$Failed = 0
$Skipped = 0

function Pass {
    param([string]$Message)
    $script:Passed++
    Write-Host "[ok] $Message" -ForegroundColor Green
}

function Fail {
    param([string]$Message)
    $script:Failed++
    Write-Host "[fail] $Message" -ForegroundColor Red
}

function Skip {
    param([string]$Message)
    $script:Skipped++
    Write-Host "[skip] $Message" -ForegroundColor Yellow
}

function Test-CommandAvailable {
    param(
        [string]$Command,
        [string]$Label = $Command
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Pass "$Label encontrado"
    } else {
        Fail "$Label nao encontrado"
    }
}

function Test-WingetPackage {
    param(
        [string]$Name,
        [string[]]$Ids,
        [bool]$Required = $true
    )

    foreach ($id in $Ids) {
        $output = & winget list --id $id -e --accept-source-agreements 2>$null | Out-String
        if ($LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($id)) {
            Pass "$Name instalado ($id)"
            return
        }
    }

    if ($Required) {
        Fail "$Name nao encontrado via winget"
    } else {
        Skip "$Name nao encontrado via winget"
    }
}

function Test-NvidiaGpu {
    $detected = @()

    try {
        $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($gpu in $gpus) {
            if ($gpu.Name -match "NVIDIA" -or $gpu.PNPDeviceID -match "VEN_10DE") {
                $detected += $gpu.Name
            }
        }
    } catch {}

    try {
        $displayDevices = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.PNPClass -eq "Display" -or $_.Class -eq "Display") -and
                ($_.Name -match "NVIDIA" -or $_.DeviceID -match "VEN_10DE")
            }

        foreach ($device in $displayDevices) {
            $detected += $device.Name
        }
    } catch {}

    return @($detected | Where-Object { $_ } | Select-Object -Unique)
}

Write-Host ""
Write-Host "== Windows base ==" -ForegroundColor Cyan
Test-CommandAvailable winget "WinGet"
Test-CommandAvailable git "Git"
Test-CommandAvailable gh "GitHub CLI"
Test-CommandAvailable wt "Windows Terminal"
Test-CommandAvailable pwsh "PowerShell 7"

Write-Host ""
Write-Host "== Apps Winget ==" -ForegroundColor Cyan
Test-WingetPackage "7-Zip" @("7zip.7zip")
Test-WingetPackage "Windows Terminal" @("Microsoft.WindowsTerminal")
Test-WingetPackage "PowerShell 7" @("Microsoft.PowerShell")
Test-WingetPackage "Git" @("Git.Git")
Test-WingetPackage "GitHub CLI" @("GitHub.cli")
Test-WingetPackage "Brave" @("Brave.Brave", "BraveSoftware.BraveBrowser")
Test-WingetPackage "VS Code" @("Microsoft.VisualStudioCode")
Test-WingetPackage "Docker Desktop" @("Docker.DockerDesktop")
Test-WingetPackage "DBeaver Community" @("DBeaver.DBeaver.Community")
Test-WingetPackage "MongoDB Compass" @("MongoDB.Compass.Full")
Test-WingetPackage "AutoHotkey v2" @("AutoHotkey.AutoHotkey")
Test-WingetPackage "Flow Launcher" @("Flow-Launcher.Flow-Launcher")
Test-WingetPackage "GlazeWM" @("glzr-io.glazewm", "GlazeWM") $false

Write-Host ""
Write-Host "== NVIDIA ==" -ForegroundColor Cyan
$nvidiaGpus = Test-NvidiaGpu
if ($nvidiaGpus.Count -gt 0) {
    foreach ($gpu in $nvidiaGpus) {
        Pass "GPU NVIDIA detectada: $gpu"
    }

    Test-WingetPackage "NVIDIA GeForce Experience" @("Nvidia.GeForceExperience") $false
    Test-WingetPackage "NVCleanstall" @("TechPowerUp.NVCleanstall") $false
    Test-WingetPackage "Display Driver Uninstaller" @("Wagnardsoft.DisplayDriverUninstaller") $false
} elseif ($RequireNvidiaTools) {
    Fail "RequireNvidiaTools foi usado, mas nenhuma GPU NVIDIA foi detectada"
} else {
    Skip "nenhuma GPU NVIDIA detectada"
}

Write-Host ""
Write-Host "== WSL ==" -ForegroundColor Cyan
Test-CommandAvailable wsl "WSL"

$wslStatus = & wsl --status 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) {
    Pass "wsl --status responde"
} else {
    Fail "wsl --status falhou: $wslStatus"
}

$distros = & wsl -l -q 2>$null
if ($distros -match [regex]::Escape($WslDistro)) {
    Pass "distro $WslDistro instalada"
} else {
    Fail "distro $WslDistro nao encontrada"
}

$wslVersionOutput = & wsl -l -v 2>$null | Out-String
if ($wslVersionOutput -match $WslDistro -and $wslVersionOutput -match "\s2\s") {
    Pass "$WslDistro esta em WSL2"
} else {
    Fail "nao consegui confirmar $WslDistro em WSL2"
}

$wslConf = & wsl -d $WslDistro -- bash -lc "cat /etc/wsl.conf" 2>$null | Out-String
if ($LASTEXITCODE -eq 0 -and $wslConf -match "systemd=true") {
    Pass "WSL systemd configurado"
} else {
    Fail "WSL systemd nao confirmado"
}

if ($wslConf -match "appendWindowsPath=false") {
    Pass "WSL appendWindowsPath=false configurado"
} else {
    Fail "WSL appendWindowsPath=false nao confirmado"
}

$defaultUser = & wsl -d $WslDistro -- bash -lc "whoami" 2>$null | Out-String
if ($LASTEXITCODE -eq 0 -and $defaultUser.Trim() -and $defaultUser.Trim() -ne "root") {
    Pass "usuario default do WSL nao-root: $($defaultUser.Trim())"
} else {
    Fail "usuario default do WSL parece root ou nao respondeu"
}

$homePath = & wsl -d $WslDistro -- bash -lc 'printf "%s" "$HOME"' 2>$null | Out-String
$homePath = $homePath.Trim()
if ($LASTEXITCODE -eq 0 -and $homePath -match "^/home/[^/]+$") {
    Pass "HOME do WSL esta no filesystem Linux: $homePath"
} else {
    Fail "HOME do WSL fora do esperado: $homePath"
}

$pathHasWindowsMount = & wsl -d $WslDistro -- bash -lc 'case "$PATH" in *"/mnt/c/"*) exit 1 ;; *) exit 0 ;; esac' 2>$null
if ($LASTEXITCODE -eq 0) {
    Pass "PATH do WSL nao contem /mnt/c"
} else {
    Fail "PATH do WSL contem /mnt/c"
}

$devPath = & wsl -d $WslDistro -- bash -lc 'printf "%s" "$HOME/dev"' 2>$null | Out-String
$devPath = $devPath.Trim()
if ($devPath -match "^/home/[^/]+/dev$") {
    Pass "pasta de projetos esperada no WSL: $devPath"
} else {
    Fail "pasta de projetos fora do esperado: $devPath"
}

Write-Host ""
Write-Host "== Configs geradas ==" -ForegroundColor Cyan
$ahkFile = Join-Path $env:USERPROFILE "dev-setup\windows\ahk\jal-hotkeys.ahk"
$glazeFile = Join-Path $env:USERPROFILE ".glzr\glazewm\config.yaml"

if (Test-Path $ahkFile) {
    Pass "AutoHotkey config existe"
} else {
    Fail "AutoHotkey config nao encontrada em $ahkFile"
}

if (Test-Path $glazeFile) {
    Pass "GlazeWM config existe"
} else {
    Skip "GlazeWM config nao encontrada em $glazeFile"
}

Write-Host ""
Write-Host "Resultado: $Passed ok, $Failed fail, $Skipped skip"

if ($Failed -gt 0) {
    exit 1
}
