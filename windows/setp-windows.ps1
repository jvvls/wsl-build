# setup-windows.ps1
# Windows 11 fresh install setup para workstation Windows + WSL-first.
# Roda em PowerShell como Administrador.

param(
    [string]$WslDistro = "Ubuntu",
    [string]$WslSetupUrl = "https://raw.githubusercontent.com/jvvls/wsl-build/main/install.sh",
    [string]$DotfilesRepo = "",
    [bool]$UseWin11Debloat = $true,
    [object]$InstallNvidiaTools = $null,
    [bool]$InstallGamingApps = $true,
    [bool]$InstallDevGuiApps = $true,
    [bool]$InstallWindowManager = $true,
    [bool]$InstallSpark = $false,
    [bool]$ConfigureWsl = $true,
    [bool]$RemoveOneDrive = $false,
    [bool]$AutoReboot = $false,
    [switch]$ContinueAfterReboot
)

$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$SetupRoot = Join-Path $env:USERPROFILE "dev-setup"
$LogDir = Join-Path $env:USERPROFILE "dev-setup-logs"
$WindowsConfigDir = Join-Path $SetupRoot "windows"
$AhkDir = Join-Path $WindowsConfigDir "ahk"
$GlazeDir = Join-Path $env:USERPROFILE ".glzr\glazewm"

New-Item -ItemType Directory -Force -Path $SetupRoot, $LogDir, $WindowsConfigDir, $AhkDir, $GlazeDir | Out-Null

$LogFile = Join-Path $LogDir ("setup-windows-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
Start-Transcript -Path $LogFile -Append | Out-Null

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkCyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Test-NvidiaGpu {
    $detectedGpus = @()

    try {
        $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($gpu in $gpus) {
            if ($gpu.Name -match "NVIDIA" -or $gpu.PNPDeviceID -match "VEN_10DE") {
                $detectedGpus += $gpu.Name
            }
        }
    } catch {
        Write-Warn "Não consegui consultar Win32_VideoController: $($_.Exception.Message)"
    }

    try {
        $displayDevices = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.PNPClass -eq "Display" -or $_.Class -eq "Display") -and
                ($_.Name -match "NVIDIA" -or $_.DeviceID -match "VEN_10DE")
            }

        foreach ($device in $displayDevices) {
            $detectedGpus += $device.Name
        }
    } catch {
        Write-Warn "Não consegui consultar dispositivos PnP de vídeo: $($_.Exception.Message)"
    }

    $detectedGpus = @($detectedGpus | Where-Object { $_ } | Select-Object -Unique)

    if ($detectedGpus.Count -gt 0) {
        foreach ($gpuName in $detectedGpus) {
            Write-Ok "GPU NVIDIA detectada: $gpuName"
        }

        return $true
    }

    Write-Warn "Nenhuma GPU NVIDIA detectada."
    return $false
}

function Resolve-OptionalInstallChoices {
    if ($null -eq $InstallNvidiaTools) {
        Write-Section "Ferramentas NVIDIA"
        $script:InstallNvidiaTools = Test-NvidiaGpu
    } elseif ($InstallNvidiaTools -is [bool]) {
        $script:InstallNvidiaTools = [bool]$InstallNvidiaTools
    } else {
        switch -Regex ($InstallNvidiaTools.ToString().Trim().ToLowerInvariant()) {
            "^(true|1|s|sim|y|yes)$" {
                $script:InstallNvidiaTools = $true
                break
            }
            "^(false|0|n|nao|não|no)$" {
                $script:InstallNvidiaTools = $false
                break
            }
            "^(auto|detect|detectar)$" {
                Write-Section "Ferramentas NVIDIA"
                $script:InstallNvidiaTools = Test-NvidiaGpu
                break
            }
            default {
                Write-Fail "Valor inválido para -InstallNvidiaTools: $InstallNvidiaTools. Use `$true, `$false ou auto."
                Stop-Transcript | Out-Null
                exit 1
            }
        }
    }

    if ($InstallNvidiaTools) {
        Write-Ok "Ferramentas NVIDIA serão instaladas."
    } else {
        Write-Warn "Ferramentas NVIDIA serão puladas."
    }
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Fail "Abra o Windows Terminal/PowerShell como Administrador e rode novamente."
    Stop-Transcript | Out-Null
    exit 1
}

function Test-RebootPending {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    )

    if (Test-Path $paths[0]) { return $true }
    if (Test-Path $paths[1]) { return $true }

    try {
        $pending = Get-ItemProperty -Path $paths[2] -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
        if ($pending) { return $true }
    } catch {}

    return $false
}

function Register-ResumeAfterReboot {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        Write-Warn "Não consegui registrar continuação automática porque o script não está salvo em arquivo."
        return
    }

    $args = @(
        "-ExecutionPolicy Bypass",
        "-File `"$scriptPath`"",
        "-ContinueAfterReboot"
    )

    if ($WslSetupUrl) { $args += "-WslSetupUrl `"$WslSetupUrl`"" }
    if ($DotfilesRepo) { $args += "-DotfilesRepo `"$DotfilesRepo`"" }
    $args += "-InstallNvidiaTools `$$InstallNvidiaTools"
    if ($InstallSpark) { $args += "-InstallSpark `$true" }
    if ($AutoReboot) { $args += "-AutoReboot `$true" }

    $cmd = "powershell.exe " + ($args -join " ")
    New-ItemProperty `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" `
        -Name "JalDevSetupResume" `
        -Value $cmd `
        -PropertyType String `
        -Force | Out-Null

    Write-Ok "Continuação pós-reboot registrada em RunOnce."
}

function Set-Dword {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
    } catch {
        Write-Warn "Falhou registry: $Path -> $Name"
    }
}

function Set-StringValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Value
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force | Out-Null
    } catch {
        Write-Warn "Falhou registry: $Path -> $Name"
    }
}

function Invoke-Safely {
    param(
        [string]$Name,
        [scriptblock]$Block
    )

    try {
        Write-Host "-> $Name" -ForegroundColor Gray
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Stop"
        $previousExitCode = $global:LASTEXITCODE
        $global:LASTEXITCODE = 0
        & $Block
        if ($null -ne $global:LASTEXITCODE -and $global:LASTEXITCODE -ne 0) {
            throw "Comando nativo terminou com exit code $global:LASTEXITCODE"
        }
        Write-Ok $Name
    } catch {
        Write-Warn "$Name falhou: $($_.Exception.Message)"
    } finally {
        $global:LASTEXITCODE = $previousExitCode
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Assert-NativeSuccess {
    param([string]$Step)

    if ($null -ne $global:LASTEXITCODE -and $global:LASTEXITCODE -ne 0) {
        throw "$Step terminou com exit code $global:LASTEXITCODE"
    }
}

function Ensure-Winget {
    Write-Section "Verificando WinGet"

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Ok "WinGet encontrado."
        return $true
    }

    Write-Warn "WinGet não encontrado. Tentando registrar App Installer."
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    } catch {
        Write-Warn "Não consegui registrar App Installer automaticamente."
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Ok "WinGet registrado."
        return $true
    }

    Write-Fail "WinGet ainda não está disponível. Abra a Microsoft Store, atualize 'App Installer' e rode de novo."
    return $false
}

function Install-WingetPackage {
    param(
        [string]$Name,
        [string[]]$Ids,
        [string]$Source = "",
        [bool]$Silent = $true
    )

    foreach ($id in $Ids) {
        try {
            $listArgs = @("list", "--id", $id, "-e", "--accept-source-agreements")
            if ($Source) {
                $listArgs += @("--source", $Source)
            }

            $installedOutput = & winget @listArgs 2>$null | Out-String
            if ($installedOutput -match [regex]::Escape($id)) {
                Write-Ok "$Name já instalado ($id)."
                return $true
            }
        } catch {}

        Write-Host "Instalando $Name ($id)..." -ForegroundColor Gray

        $args = @(
            "install",
            "--id", $id,
            "-e",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )

        if ($Source) {
            $args += @("--source", $Source)
        }

        if ($Silent) {
            $args += "--silent"
        }

        & winget @args

        if ($LASTEXITCODE -eq 0) {
            Write-Ok "$Name instalado."
            return $true
        }

        if ($Silent) {
            Write-Warn "$Name falhou em modo silencioso. Tentando modo normal."
            $args = $args | Where-Object { $_ -ne "--silent" }
            & winget @args

            if ($LASTEXITCODE -eq 0) {
                Write-Ok "$Name instalado em modo normal."
                return $true
            }
        }

        Write-Warn "$Name falhou com ID $id."
    }

    Write-Warn "$Name não foi instalado."
    return $false
}

function Create-RestorePointSafe {
    Write-Section "Criando ponto de restauração"

    Invoke-Safely "Habilitar System Restore no disco do sistema" {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" | Out-Null
    }

    Invoke-Safely "Criar restore point PreDevSetup" {
        Checkpoint-Computer -Description "PreDevSetup" -RestorePointType "MODIFY_SETTINGS"
    }
}

function Install-Packages {
    Write-Section "Instalando apps via WinGet"

    winget source update

    $packages = @()

    $packages += @(
        @{ Name = "7-Zip"; Ids = @("7zip.7zip"); Silent = $true },
        @{ Name = "Windows Terminal"; Ids = @("Microsoft.WindowsTerminal"); Silent = $true },
        @{ Name = "PowerShell 7"; Ids = @("Microsoft.PowerShell"); Silent = $true },
        @{ Name = "Git"; Ids = @("Git.Git"); Silent = $true },
        @{ Name = "GitHub CLI"; Ids = @("GitHub.cli"); Silent = $true },
        @{ Name = "Brave"; Ids = @("Brave.Brave", "BraveSoftware.BraveBrowser"); Silent = $true },
        @{ Name = "PowerToys"; Ids = @("Microsoft.PowerToys"); Silent = $true },
        @{ Name = "AutoHotkey v2"; Ids = @("AutoHotkey.AutoHotkey"); Silent = $true },
        @{ Name = "Flow Launcher"; Ids = @("Flow-Launcher.Flow-Launcher"); Silent = $true },
        @{ Name = "TrafficMonitor"; Ids = @("zhongyang219.TrafficMonitor.Full"); Silent = $false },
        @{ Name = "HWiNFO"; Ids = @("REALiX.HWiNFO"); Silent = $true }
    )

    if ($InstallDevGuiApps) {
        $packages += @(
            @{ Name = "VS Code"; Ids = @("Microsoft.VisualStudioCode"); Silent = $true },
            @{ Name = "Docker Desktop"; Ids = @("Docker.DockerDesktop"); Silent = $true },
            @{ Name = "DBeaver Community"; Ids = @("DBeaver.DBeaver.Community"); Silent = $true },
            @{ Name = "MongoDB Compass"; Ids = @("MongoDB.Compass.Full"); Silent = $true },
            @{ Name = "Node.js LTS"; Ids = @("OpenJS.NodeJS.LTS"); Silent = $true },
            @{ Name = "Go"; Ids = @("GoLang.Go"); Silent = $true },
            @{ Name = "Python 3.12"; Ids = @("Python.Python.3.12"); Silent = $true },
            @{ Name = "Temurin JDK 17"; Ids = @("EclipseAdoptium.Temurin.17.JDK"); Silent = $true },
            @{ Name = "Temurin JDK 21"; Ids = @("EclipseAdoptium.Temurin.21.JDK"); Silent = $true }
        )
    }

    if ($InstallGamingApps) {
        $packages += @(
            @{ Name = "Steam"; Ids = @("Valve.Steam"); Silent = $true },
            @{ Name = "Discord"; Ids = @("Discord.Discord"); Silent = $true },
            @{ Name = "Stremio"; Ids = @("Stremio.Stremio"); Silent = $true },
            @{ Name = "VLC"; Ids = @("VideoLAN.VLC"); Silent = $true },
            @{ Name = "VC++ Redistributable x64"; Ids = @("Microsoft.VCRedist.2015+.x64"); Silent = $true },
            @{ Name = "VC++ Redistributable x86"; Ids = @("Microsoft.VCRedist.2015+.x86"); Silent = $true }
        )
    }

    if ($InstallWindowManager) {
        $packages += @(
            @{ Name = "GlazeWM"; Ids = @("glzr-io.glazewm", "GlazeWM"); Silent = $true }
        )
    }

    if ($InstallNvidiaTools) {
        $packages += @(
            @{ Name = "NVIDIA GeForce Experience"; Ids = @("Nvidia.GeForceExperience"); Silent = $false },
            @{ Name = "NVCleanstall"; Ids = @("TechPowerUp.NVCleanstall"); Silent = $true },
            @{ Name = "Display Driver Uninstaller"; Ids = @("Wagnardsoft.DisplayDriverUninstaller"); Silent = $true }
        )
    }

    foreach ($pkg in $packages) {
        Install-WingetPackage -Name $pkg.Name -Ids $pkg.Ids -Silent $pkg.Silent | Out-Null
    }

    if ($InstallNvidiaTools) {
        Install-WingetPackage `
            -Name "NVIDIA Control Panel" `
            -Ids @("9NF8H0H7WMLT") `
            -Source "msstore" `
            -Silent $false | Out-Null
    }
}

function Remove-BloatAppx {
    param([string[]]$Patterns)

    foreach ($pattern in $Patterns) {
        Write-Host "Removendo Appx: $pattern" -ForegroundColor Gray

        try {
            Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue |
                Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        } catch {}

        try {
            Get-AppxProvisionedPackage -Online |
                Where-Object { $_.DisplayName -like $pattern } |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
}

function Apply-ManualSafeDebloat {
    Write-Section "Aplicando debloat conservador manual"

    $bloatApps = @(
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.People",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.Todos",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "Microsoft.Clipchamp",
        "MicrosoftTeams",
        "MSTeams",
        "Microsoft.OutlookForWindows",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.Copilot"
    )

    Remove-BloatAppx -Patterns $bloatApps

    if ($RemoveOneDrive) {
        Invoke-Safely "Remover OneDrive" {
            taskkill /f /im OneDrive.exe 2>$null
            $oneDriveSetup1 = "$env:SystemRoot\System32\OneDriveSetup.exe"
            $oneDriveSetup2 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"

            if (Test-Path $oneDriveSetup1) { & $oneDriveSetup1 /uninstall }
            if (Test-Path $oneDriveSetup2) { & $oneDriveSetup2 /uninstall }
        }
    } else {
        Write-Warn "OneDrive não foi removido por padrão para evitar perda/confusão com pastas sincronizadas."
    }

    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "ContentDeliveryAllowed" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "OemPreInstalledAppsEnabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEnabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353694Enabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353696Enabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0

    Set-Dword "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1

    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0

    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0

    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1

    Set-StringValue "HKCU:\Control Panel\Mouse" "MouseSpeed" "0"
    Set-StringValue "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0"
    Set-StringValue "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0"

    Set-Dword "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0

    Invoke-Safely "Desabilitar apps de startup comuns" {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /f | Out-Null
    }

    Write-Ok "Debloat manual aplicado."
}

function Apply-Win11DebloatSafeFlags {
    if (-not $UseWin11Debloat) {
        Write-Warn "Win11Debloat desativado por parâmetro."
        return
    }

    Write-Section "Aplicando Win11Debloat com flags conservadoras"

    $flags = @(
        "-CreateRestorePoint",
        "-Silent",
        "-DisableTelemetry",
        "-DisableSuggestions",
        "-DisableBing",
        "-DisableCopilot",
        "-DisableRecall",
        "-DisableClickToDo",
        "-DisableAISvcAutoStart",
        "-DisableEdgeAI",
        "-DisablePaintAI",
        "-DisableNotepadAI",
        "-DisableEdgeAds",
        "-DisableDesktopSpotlight",
        "-DisableLockscreenTips",
        "-DisableSettings365Ads",
        "-DisableSearchHighlights",
        "-DisableStoreSearchSuggestions",
        "-DisableStartRecommended",
        "-DisableStartPhoneLink",
        "-DisableWidgets",
        "-EnableEndTask",
        "-ShowHiddenFolders",
        "-ShowKnownFileExt",
        "-ExplorerToThisPC",
        "-HideSearchTb",
        "-HideTaskview",
        "-HideChat",
        "-TaskbarAlignLeft",
        "-PreventUpdateAutoReboot",
        "-DisableDeliveryOptimization",
        "-DisableMouseAcceleration",
        "-DisableStickyKeys",
        "-DisableFastStartup",
        "-DisableSnapAssist",
        "-DisableSnapLayouts",
        "-DisableBraveBloat"
    )

    Invoke-Safely "Executar Win11Debloat via debloat.raphi.re" {
        $script = [scriptblock]::Create((Invoke-RestMethod "https://debloat.raphi.re/"))
        & $script @flags
    }
}

function Configure-Git {
    Write-Section "Configurando Git básico"

    Invoke-Safely "Configurar Git defaults" {
        git config --global init.defaultBranch main
        git config --global core.autocrlf true
        git config --global pull.rebase false
        git config --global credential.helper manager
    }

    Write-Warn "Nome/email do Git não foram fixados aqui. Configure depois com:"
    Write-Host 'git config --global user.name "Seu Nome"'
    Write-Host 'git config --global user.email "seu@email.com"'
}

function Configure-AutoHotkey {
    Write-Section "Configurando AutoHotkey"

    $ahkFile = Join-Path $AhkDir "jal-hotkeys.ahk"

    $ahkContent = @'
#Requires AutoHotkey v2.0
#SingleInstance Force

SetCapsLockState "AlwaysOff"

; CapsLock vira uma tecla "leader".
; CapsLock + tecla = ação.

CapsLock & t::Run "wt.exe"
CapsLock & b::Run "brave.exe"
CapsLock & d::Run "Discord.exe"
CapsLock & s::Run "steam://open/main"
CapsLock & e::Run "explorer.exe"
CapsLock & c::Run "code.exe"
CapsLock & f::Run "Flow.Launcher.exe"
CapsLock & p::Run "powershell.exe"
CapsLock & q::WinClose "A"

; Fecha processo da janela ativa. Use com cuidado.
CapsLock & x::{
    try {
        pid := WinGetPID("A")
        ProcessClose pid
    }
}

; Recarrega este arquivo.
CapsLock & r::Reload

; Abre pasta de configs.
CapsLock & o::Run A_UserProfile "\dev-setup\windows"
'@

    Set-Content -Path $ahkFile -Value $ahkContent -Encoding UTF8

    $ahkExe = Get-ChildItem "$env:ProgramFiles\AutoHotkey" -Filter "AutoHotkey*.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "64|AutoHotkey.exe" } |
        Select-Object -First 1

    if (-not $ahkExe) {
        $ahkExe = Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue
    }

    if ($ahkExe) {
        $startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\jal-hotkeys.lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($startup)
        $shortcut.TargetPath = $ahkExe.Source
        if (-not $shortcut.TargetPath) { $shortcut.TargetPath = $ahkExe.FullName }
        $shortcut.Arguments = "`"$ahkFile`""
        $shortcut.WorkingDirectory = $AhkDir
        $shortcut.Save()

        Start-Process $shortcut.TargetPath -ArgumentList "`"$ahkFile`""
        Write-Ok "AutoHotkey configurado e iniciado."
    } else {
        Write-Warn "AutoHotkey exe não encontrado. O arquivo foi criado em $ahkFile."
    }
}

function Configure-GlazeWM {
    if (-not $InstallWindowManager) {
        return
    }

    Write-Section "Configurando GlazeWM"

    $configPath = Join-Path $GlazeDir "config.yaml"

    $glazeConfig = @'
general:
  startup_commands: []
  shutdown_commands: []
  config_reload_commands: []

gaps:
  inner_gap: "8px"
  outer_gap:
    top: "8px"
    right: "8px"
    bottom: "8px"
    left: "8px"

window_behavior:
  initial_state: "tiling"
  state_defaults:
    floating:
      centered: true
      shown_on_top: false
    fullscreen:
      maximized: false

workspaces:
  - name: "1"
    display_name: "DEV"
  - name: "2"
    display_name: "WEB"
  - name: "3"
    display_name: "TERM"
  - name: "4"
    display_name: "DB"
  - name: "5"
    display_name: "CHAT"
  - name: "6"
    display_name: "MEDIA"
  - name: "7"
    display_name: "GAME"
  - name: "8"
    display_name: "MISC"
  - name: "9"
    display_name: "FLOAT"

window_rules:
  - commands: ["move --workspace 1"]
    match:
      - window_process: { regex: "Code|Cursor" }

  - commands: ["move --workspace 2"]
    match:
      - window_process: { regex: "brave|chrome|msedge|firefox" }

  - commands: ["move --workspace 3"]
    match:
      - window_process: { regex: "WindowsTerminal|wt|powershell|cmd" }

  - commands: ["move --workspace 4"]
    match:
      - window_process: { regex: "dbeaver|MongoDBCompass" }

  - commands: ["move --workspace 5"]
    match:
      - window_process: { regex: "Discord|Teams" }

  - commands: ["move --workspace 6"]
    match:
      - window_process: { regex: "stremio|vlc" }

  - commands: ["move --workspace 7"]
    match:
      - window_process: { regex: "steam|Steam|steamwebhelper" }

  - commands: ["set-floating --centered"]
    match:
      - window_process: { regex: "Flow.Launcher|PowerToys|TrafficMonitor|HWiNFO64|NVCleanstall|Display Driver Uninstaller|DDU" }

binding_modes:
  - name: "resize"
    keybindings:
      - commands: ["resize --width -2%"]
        bindings: ["h", "left"]
      - commands: ["resize --width +2%"]
        bindings: ["l", "right"]
      - commands: ["resize --height +2%"]
        bindings: ["k", "up"]
      - commands: ["resize --height -2%"]
        bindings: ["j", "down"]
      - commands: ["wm-disable-binding-mode --name resize"]
        bindings: ["escape", "enter", "alt+r"]

keybindings:
  - commands: ["focus --direction left"]
    bindings: ["alt+h", "alt+left"]
  - commands: ["focus --direction right"]
    bindings: ["alt+l", "alt+right"]
  - commands: ["focus --direction up"]
    bindings: ["alt+k", "alt+up"]
  - commands: ["focus --direction down"]
    bindings: ["alt+j", "alt+down"]

  - commands: ["move --direction left"]
    bindings: ["alt+shift+h", "alt+shift+left"]
  - commands: ["move --direction right"]
    bindings: ["alt+shift+l", "alt+shift+right"]
  - commands: ["move --direction up"]
    bindings: ["alt+shift+k", "alt+shift+up"]
  - commands: ["move --direction down"]
    bindings: ["alt+shift+j", "alt+shift+down"]

  - commands: ["resize --width -2%"]
    bindings: ["alt+u"]
  - commands: ["resize --width +2%"]
    bindings: ["alt+p"]
  - commands: ["resize --height +2%"]
    bindings: ["alt+o"]
  - commands: ["resize --height -2%"]
    bindings: ["alt+i"]

  - commands: ["wm-enable-binding-mode --name resize"]
    bindings: ["alt+r"]

  - commands: ["toggle-floating --centered"]
    bindings: ["alt+shift+space"]
  - commands: ["toggle-tiling"]
    bindings: ["alt+t"]
  - commands: ["toggle-fullscreen"]
    bindings: ["alt+f"]
  - commands: ["toggle-minimized"]
    bindings: ["alt+m"]
  - commands: ["close"]
    bindings: ["alt+shift+q"]

  - commands: ["wm-reload-config"]
    bindings: ["alt+shift+r"]
  - commands: ["wm-redraw"]
    bindings: ["alt+shift+w"]
  - commands: ["wm-toggle-pause"]
    bindings: ["alt+shift+p"]

  - commands: ["shell-exec wt"]
    bindings: ["alt+enter"]
  - commands: ["shell-exec brave"]
    bindings: ["alt+b"]
  - commands: ["shell-exec code"]
    bindings: ["alt+c"]
  - commands: ["shell-exec explorer"]
    bindings: ["alt+e"]

  - commands: ["focus --workspace 1"]
    bindings: ["alt+1"]
  - commands: ["focus --workspace 2"]
    bindings: ["alt+2"]
  - commands: ["focus --workspace 3"]
    bindings: ["alt+3"]
  - commands: ["focus --workspace 4"]
    bindings: ["alt+4"]
  - commands: ["focus --workspace 5"]
    bindings: ["alt+5"]
  - commands: ["focus --workspace 6"]
    bindings: ["alt+6"]
  - commands: ["focus --workspace 7"]
    bindings: ["alt+7"]
  - commands: ["focus --workspace 8"]
    bindings: ["alt+8"]
  - commands: ["focus --workspace 9"]
    bindings: ["alt+9"]

  - commands: ["move --workspace 1", "focus --workspace 1"]
    bindings: ["alt+shift+1"]
  - commands: ["move --workspace 2", "focus --workspace 2"]
    bindings: ["alt+shift+2"]
  - commands: ["move --workspace 3", "focus --workspace 3"]
    bindings: ["alt+shift+3"]
  - commands: ["move --workspace 4", "focus --workspace 4"]
    bindings: ["alt+shift+4"]
  - commands: ["move --workspace 5", "focus --workspace 5"]
    bindings: ["alt+shift+5"]
  - commands: ["move --workspace 6", "focus --workspace 6"]
    bindings: ["alt+shift+6"]
  - commands: ["move --workspace 7", "focus --workspace 7"]
    bindings: ["alt+shift+7"]
  - commands: ["move --workspace 8", "focus --workspace 8"]
    bindings: ["alt+shift+8"]
  - commands: ["move --workspace 9", "focus --workspace 9"]
    bindings: ["alt+shift+9"]

  - commands: ["focus --next-active-workspace"]
    bindings: ["alt+s"]
  - commands: ["focus --prev-active-workspace"]
    bindings: ["alt+a"]
  - commands: ["focus --recent-workspace"]
    bindings: ["alt+d"]

  - commands: ["move-workspace --direction left"]
    bindings: ["alt+shift+a"]
  - commands: ["move-workspace --direction right"]
    bindings: ["alt+shift+d"]

  - commands: ["wm-exit"]
    bindings: ["alt+shift+e"]
'@

    Set-Content -Path $configPath -Value $glazeConfig -Encoding UTF8

    Invoke-Safely "Criar startup task do GlazeWM" {
        $taskAction = "powershell.exe -NoProfile -WindowStyle Hidden -Command `"Start-Process glazewm -ArgumentList 'start'`""
        schtasks /Create /TN "Jal GlazeWM" /TR $taskAction /SC ONLOGON /F | Out-Null
    }

    Invoke-Safely "Iniciar GlazeWM agora" {
        Start-Process glazewm -ArgumentList "start"
    }

    Write-Ok "GlazeWM configurado em $configPath"
}

function Clone-Dotfiles {
    if (-not $DotfilesRepo) {
        Write-Warn "DotfilesRepo vazio. Pulando clone de dotfiles."
        return
    }

    Write-Section "Clonando dotfiles/base"

    $target = Join-Path $env:USERPROFILE "dotfiles"

    Invoke-Safely "Clonar ou atualizar dotfiles no Windows" {
        if (Test-Path $target) {
            git -C $target pull
        } else {
            git clone $DotfilesRepo $target
        }
    }
}

function Enable-WslFeatures {
    if (-not $ConfigureWsl) {
        return
    }

    Write-Section "Habilitando WSL2"

    Invoke-Safely "Habilitar WSL" {
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    }

    Invoke-Safely "Habilitar VirtualMachinePlatform" {
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    }

    Invoke-Safely "Definir WSL2 como padrão" {
        wsl --set-default-version 2
    }

    Invoke-Safely "Instalar distro $WslDistro" {
        $installed = wsl -l -q | Out-String
        if ($installed -match $WslDistro) {
            Write-Ok "$WslDistro já instalada."
        } else {
            wsl --install -d $WslDistro --no-launch
        }
    }
}

function Configure-WslDistro {
    if (-not $ConfigureWsl) {
        return
    }

    Write-Section "Configurando distro WSL"

    $safeUser = ($env:USERNAME -replace "[^a-zA-Z0-9_-]", "").ToLower()
    if (-not $safeUser) {
        $safeUser = "dev"
    }

    $installed = wsl -l -q | Out-String
    if ($installed -notmatch $WslDistro) {
        Write-Warn "$WslDistro não parece instalada ainda. Pode ser necessário reiniciar."
        return
    }

    Invoke-Safely "Preparar usuário Linux $safeUser" {
        wsl -d $WslDistro -u root -- bash -lc "apt-get update && apt-get install -y sudo curl ca-certificates git"
        Assert-NativeSuccess "Instalar pacotes base na distro WSL"
        wsl -d $WslDistro -u root -- bash -lc "id -u $safeUser >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo $safeUser"
        Assert-NativeSuccess "Criar usuário Linux $safeUser"
        wsl -d $WslDistro -u root -- bash -lc "echo '$safeUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$safeUser-bootstrap && chmod 440 /etc/sudoers.d/$safeUser-bootstrap"
        Assert-NativeSuccess "Criar sudo temporário para bootstrap de $safeUser"
        wsl -d $WslDistro -u root -- bash -lc "printf '[user]\ndefault=$safeUser\n' > /etc/wsl.conf"
        Assert-NativeSuccess "Configurar usuário padrão do WSL"
        wsl --terminate $WslDistro
        Assert-NativeSuccess "Reiniciar distro WSL"
    }

    if ($DotfilesRepo) {
        Invoke-Safely "Clonar dotfiles/base dentro do WSL" {
            wsl -d $WslDistro -u $safeUser -- bash -lc "test -d ~/dotfiles && git -C ~/dotfiles pull || git clone '$DotfilesRepo' ~/dotfiles"
        }
    }

    if ($WslSetupUrl) {
        Invoke-Safely "Rodar setup WSL remoto" {
            $sparkEnv = ""
            if ($InstallSpark) {
                $sparkEnv = "INSTALL_SPARK=true "
            }

            try {
                wsl -d $WslDistro -u $safeUser -- bash -lc "curl -fsSL '$WslSetupUrl' | ${sparkEnv}bash"
                Assert-NativeSuccess "Rodar setup Linux no WSL"
            } finally {
                wsl -d $WslDistro -u root -- bash -lc "rm -f /etc/sudoers.d/$safeUser-bootstrap"
                Assert-NativeSuccess "Remover sudo temporário de $safeUser"
            }
        }
    } else {
        Invoke-Safely "Remover sudo temporário de $safeUser" {
            wsl -d $WslDistro -u root -- bash -lc "rm -f /etc/sudoers.d/$safeUser-bootstrap"
            Assert-NativeSuccess "Remover sudo temporário de $safeUser"
        }
        Write-Warn "WslSetupUrl vazio. Pulando seu setup WSL."
        Write-Host "Depois rode algo tipo:"
        Write-Host "wsl -d $WslDistro -- bash -lc `"curl -fsSL https://raw.githubusercontent.com/SEU_USER/SEU_REPO/main/wsl/setup-wsl.sh | bash`""
    }
}

function Final-Cleanup {
    Write-Section "Finalizando"

    Invoke-Safely "Atualizar todos os pacotes Winget instalados" {
        winget upgrade --all --accept-package-agreements --accept-source-agreements
    }

    Invoke-Safely "Reiniciar Explorer para aplicar ajustes" {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer.exe
    }

    Write-Host ""
    Write-Ok "Setup finalizado."
    Write-Host "Log salvo em: $LogFile"
    Write-Host ""
    Write-Warn "Coisas que talvez precisem de ação manual:"
    Write-Host "1. Login no GitHub: gh auth login"
    Write-Host "2. Steam/Discord/Stremio: login manual"
    if ($InstallNvidiaTools) {
        Write-Host "3. NVIDIA: use GeForce Experience/NVCleanstall para baixar o driver mais novo da sua GPU."
    } else {
        Write-Host "3. NVIDIA: ferramentas puladas; rode novamente com -InstallNvidiaTools `$true se quiser instalar."
    }
    Write-Host "4. Docker Desktop pode pedir logout/reboot para habilitar integração WSL."
    Write-Host "5. Se o WSL pediu reboot, rode o script de novo ou deixe o RunOnce continuar."
}

Create-RestorePointSafe

if (-not (Ensure-Winget)) {
    Stop-Transcript | Out-Null
    exit 1
}

Resolve-OptionalInstallChoices
Install-Packages
Apply-ManualSafeDebloat
Apply-Win11DebloatSafeFlags
Configure-Git
Clone-Dotfiles
Configure-AutoHotkey
Configure-GlazeWM
Enable-WslFeatures

if (Test-RebootPending -and -not $ContinueAfterReboot) {
    Write-Section "Reboot necessário"

    Register-ResumeAfterReboot

    if ($AutoReboot) {
        Write-Warn "Reiniciando automaticamente em 15 segundos..."
        Stop-Transcript | Out-Null
        Start-Sleep -Seconds 15
        Restart-Computer -Force
        exit
    } else {
        Write-Warn "O Windows pediu reboot. A continuação foi registrada em RunOnce."
        Write-Host "Reinicie o PC e o script tentará continuar automaticamente."
        Stop-Transcript | Out-Null
        exit
    }
}

Configure-WslDistro
Final-Cleanup

Stop-Transcript | Out-Null
