#Requires -Version 5.1
<#
.SYNOPSIS
    Developer environment setup for Windows.

.DESCRIPTION
    Installs and configures: Git, MSVC Build Tools, .NET SDK, CMake, Conan,
    NuGet. Versions are driven by config.json (sibling to this script) and can
    be overridden via parameters or environment variables.

.PARAMETER Prefix
    Root installation directory.  Default: C:\DevEnv  (or config.json value).

.PARAMETER SkipGit
    Skip Git installation.

.PARAMETER SkipMsvc
    Skip Visual Studio Build Tools / MSVC installation.

.PARAMETER SkipDotnet
    Skip .NET SDK installation.

.PARAMETER SkipCMake
    Skip CMake installation.

.PARAMETER SkipConan
    Skip Conan installation.

.PARAMETER SkipNuget
    Skip NuGet CLI installation.

.PARAMETER DryRun
    Print all actions without executing them.

.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -Prefix D:\Build -SkipNuget
    .\setup.ps1 -DryRun
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]  $Prefix    = "",
    [switch]  $SkipGit,
    [switch]  $SkipMsvc,
    [switch]  $SkipDotnet,
    [switch]  $SkipCMake,
    [switch]  $SkipConan,
    [switch]  $SkipNuget,
    [switch]  $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  Helper functions
# ══════════════════════════════════════════════════════════════════════════════
function Get-Cfg([string]$Path, [string]$Default) {
    try {
        $val = $Config
        foreach ($key in $Path.Split('.')) { $val = $val.$key }
        if ($null -ne $val -and $val -ne '') { return "$val" }
    } catch {}
    return $Default
}

# ── Version defaults (env var → config.json → hard-coded) ─────────────────────
function Resolve-Version([string]$EnvVar, [string]$CfgPath, [string]$HardDefault) {
    $v = [System.Environment]::GetEnvironmentVariable($EnvVar)
    if ($v) { return $v }
    return Get-Cfg $CfgPath $HardDefault
}

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts  = (Get-Date).ToString("HH:mm:ss")
    $line = "[$ts] [$Level] $Message"
    switch ($Level) {
        "INFO"    { Write-Host "  [INFO ] $Message" -ForegroundColor Cyan }
        "OK"      { Write-Host "  [OK   ] $Message" -ForegroundColor Green }
        "WARN"    { Write-Host "  [WARN ] $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host "  [ERROR] $Message" -ForegroundColor Red }
        "DRY"     { Write-Host "  [DRY  ] Would: $Message" -ForegroundColor DarkYellow }
        "STEP"    {
            Write-Host ""
            Write-Host "  ══ $Message ══" -ForegroundColor White
        }
    }
    if ($LogFile -and (Test-Path (Split-Path $LogFile))) {
        Add-Content -Path $LogFile -Value $line
    }
}

function Log-Info($m)    { Write-Log "INFO"  $m }
function Log-OK($m)      { Write-Log "OK"    $m }
function Log-Warn($m)    { Write-Log "WARN"  $m }
function Log-Error($m)   { Write-Log "ERROR" $m; throw $m }
function Log-Step($m)    { Write-Log "STEP"  $m }
function Log-Dry($m)     { Write-Log "DRY"   $m }



# ── Run helper (respects -DryRun) ─────────────────────────────────────────────
function Invoke-Step {
    param(
        [string]    $Description,
        [scriptblock] $Action
    )
    if ($DryRun) {
        Log-Dry $Description
    } else {
        Log-Info $Description
        & $Action
    }
}

# ── Download helper ────────────────────────────────────────────────────────────
function Get-RemoteFile([string]$Url, [string]$Dest) {
    Log-Info "Downloading: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
}

# ── Elevate check ──────────────────────────────────────────────────────────────
function Assert-Admin {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log-Error "This script must be run as Administrator."
    }
}

# ── Ensure directories ─────────────────────────────────────────────────────────
function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        if ($DryRun) { Log-Dry "mkdir -p '$Path'" }
        else { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    }
}

# ── Add to system PATH (persistent) ───────────────────────────────────────────
function Add-ToSystemPath([string]$Dir) {
    if ($DryRun) { Log-Dry "Add '$Dir' to system PATH"; return }
    $current = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($current -notlike "*$Dir*") {
        [System.Environment]::SetEnvironmentVariable(
            "Path", "$current;$Dir", "Machine")
        $env:Path += ";$Dir"
        Log-Info "Added to system PATH: $Dir"
    }
}

# ── winget availability ────────────────────────────────────────────────────────
$WingetAvailable = $null
function Test-Winget {
    if ($null -eq $WingetAvailable) {
        $script:WingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    }
    return $WingetAvailable
}

# ══════════════════════════════════════════════════════════════════════════════
#  RUN Script
# ══════════════════════════════════════════════════════════════════════════════

# ── Script location ────────────────────────────────────────────────────────────
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigFile = Join-Path $ScriptDir "config.json"

# ── Load config.json ───────────────────────────────────────────────────────────
$Config = $null
if (Test-Path $ConfigFile) {
    try   { $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json }
    catch { Write-Warning "Failed to parse config.json — using built-in defaults." }
}

$GitVersion    = Resolve-Version "GIT_VERSION"    "versions.git.windows" "2.47.1.2"
$GccVersion    = Resolve-Version "GCC_VERSION"    "versions.gcc.version" "13"         # unused on Windows
$DotnetVersion = Resolve-Version "DOTNET_VERSION" "versions.dotnet_sdk"  "9.0.2"
$CmakeVersion  = Resolve-Version "CMAKE_VERSION"  "versions.cmake"       "3.25.3"
$ConanVersion  = Resolve-Version "CONAN_VERSION"  "versions.conan"       "2.10.2"
$NugetVersion  = Resolve-Version "NUGET_VERSION"  "versions.nuget"       "6.12.1"

# ── Prefix resolution ──────────────────────────────────────────────────────────
if (-not $Prefix) {
    $Prefix = [System.Environment]::GetEnvironmentVariable("DEVENV_PREFIX")
    if (-not $Prefix) { $Prefix = Get-Cfg "install.prefix_windows" "C:\DevEnv" }
}

# ── Logging ────────────────────────────────────────────────────────────────────
$LogDir  = Join-Path $Prefix "logs"
$LogFile = $null   # set after ensuring dir exists



# ══════════════════════════════════════════════════════════════════════════════
#  Install functions
# ══════════════════════════════════════════════════════════════════════════════

# ── Git ────────────────────────────────────────────────────────────────────────
function Install-Git {
    Log-Step "Git $GitVersion"

    $installed = Get-Command git -ErrorAction SilentlyContinue
    if ($installed) {
        $iv = & git --version 2>$null
        if ($iv -like "*$GitVersion*") {
            Log-OK "Git $iv already installed — skipping."
            return
        }
        Log-Warn "Git ($iv) installed but $GitVersion requested."
    }

    # Try winget first; fall back to direct installer
    if (Test-Winget) {
        Invoke-Step "winget install Git.Git --version $GitVersion" {
            winget install --id Git.Git --version $GitVersion `
                --accept-package-agreements --accept-source-agreements --silent
        }
    } else {
        $arch   = if ([System.Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
        $gitExe = Join-Path $env:TEMP "git-installer.exe"
        $url    = "https://github.com/git-for-windows/git/releases/download/v${GitVersion}.windows.1/Git-${GitVersion}-${arch}.exe"
        Invoke-Step "Download & install Git $GitVersion" {
            Get-RemoteFile $url $gitExe
            Start-Process -FilePath $gitExe -ArgumentList "/SILENT /NORESTART" -Wait
        }
    }

    Log-OK "Git installed."
}

# ── MSVC Build Tools ───────────────────────────────────────────────────────────
function Install-Msvc {
    Log-Step "Visual Studio Build Tools (MSVC C/C++)"

    # Check if MSVC is already present (vswhere.exe)
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
                    -property installationPath 2>$null
        if ($vsPath) {
            Log-OK "MSVC already installed at: $vsPath — skipping."
            return
        }
    }

    $installerUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
    $installerExe = Join-Path $env:TEMP "vs_buildtools.exe"

    Invoke-Step "Download VS Build Tools installer" {
        Get-RemoteFile $installerUrl $installerExe
    }

    # Workload: C++ Build Tools + Windows SDK + CMake (bundled) + Clang (optional)
    $components = @(
        "Microsoft.VisualStudio.Workload.VCTools"
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
        "Microsoft.VisualStudio.Component.Windows11SDK.22621"
        "Microsoft.VisualStudio.Component.VC.CMake.Project"   # VS-bundled CMake (we install our own)
        "Microsoft.VisualStudio.Component.VC.ATL"
        "Microsoft.VisualStudio.Component.VC.Redist.14.Latest"
    )
    $addArgs = ($components | ForEach-Object { "--add $_" }) -join " "

    Invoke-Step "Install VS Build Tools (this may take several minutes)" {
        $args = @(
            "--quiet", "--wait", "--norestart", "--nocache",
            "--installPath", (Join-Path $Prefix "vs-buildtools")
        ) + ($components | ForEach-Object { "--add"; $_ })

        $proc = Start-Process -FilePath $installerExe -ArgumentList $args -Wait -PassThru
        if ($proc.ExitCode -notin @(0, 3010)) {
            Log-Error "VS Build Tools installer exited with code $($proc.ExitCode)"
        }
    }

    Log-OK "MSVC Build Tools installed."
}

# ── .NET SDK ──────────────────────────────────────────────────────────────────
function Install-Dotnet {
    Log-Step ".NET SDK $DotnetVersion"

    $DotnetDir = Join-Path $Prefix "dotnet"
    $DotnetExe = Join-Path $DotnetDir "dotnet.exe"

    if (Test-Path $DotnetExe) {
        $iv = & $DotnetExe --version 2>$null
        if ($iv -like "$DotnetVersion*") {
            Log-OK ".NET SDK $iv already at $DotnetDir — skipping."
            return
        }
        Log-Warn ".NET SDK $iv found but $DotnetVersion requested — reinstalling."
    }

    $installScript = Join-Path $env:TEMP "dotnet-install.ps1"
    Invoke-Step "Download dotnet-install.ps1" {
        Get-RemoteFile "https://dot.net/v1/dotnet-install.ps1" $installScript
    }

    Invoke-Step "Install .NET SDK $DotnetVersion (SDK only, no ASP.NET)" {
        # Install SDK component only
        & $installScript `
            -Version    $DotnetVersion `
            -InstallDir $DotnetDir `
            -Runtime    "dotnet" `
            -NoPath

        # Then install the full SDK on top
        & $installScript `
            -Version    $DotnetVersion `
            -InstallDir $DotnetDir `
            -NoPath
    }

    Add-ToSystemPath $DotnetDir
    [System.Environment]::SetEnvironmentVariable("DOTNET_ROOT", $DotnetDir, "Machine")
    [System.Environment]::SetEnvironmentVariable("DOTNET_CLI_TELEMETRY_OPTOUT", "1", "Machine")
    [System.Environment]::SetEnvironmentVariable("DOTNET_NOLOGO", "1", "Machine")

    Log-OK ".NET SDK $DotnetVersion installed at $DotnetDir."
}

# ── CMake ─────────────────────────────────────────────────────────────────────
function Install-CMake {
    Log-Step "CMake $CmakeVersion"

    $CMakeDir = Join-Path $Prefix "cmake"
    $CMakeExe = Join-Path $CMakeDir "bin\cmake.exe"

    if (Test-Path $CMakeExe) {
        $iv = (& $CMakeExe --version 2>$null | Select-Object -First 1) -replace 'cmake version ',''
        if ($iv -like "$CmakeVersion*") {
            Log-OK "CMake $iv already at $CMakeDir — skipping."
            return
        }
        Log-Warn "CMake $iv found but $CmakeVersion requested — reinstalling."
    }

    $MajorMinor = ($CmakeVersion -split '\.' | Select-Object -First 2) -join '.'
    $Zip        = Join-Path $env:TEMP "cmake-${CmakeVersion}-windows-x86_64.zip"
    $Url        = "https://cmake.org/files/v${MajorMinor}/cmake-${CmakeVersion}-windows-x86_64.zip"

    Invoke-Step "Download cmake-${CmakeVersion}-windows-x86_64.zip" {
        Get-RemoteFile $Url $Zip
    }

    Invoke-Step "Extract CMake to $CMakeDir" {
        $TmpDir = Join-Path $env:TEMP "cmake-extract"
        if (Test-Path $TmpDir) { Remove-Item $TmpDir -Recurse -Force }
        Expand-Archive -Path $Zip -DestinationPath $TmpDir -Force
        $Extracted = Get-ChildItem $TmpDir | Select-Object -First 1
        if (Test-Path $CMakeDir) { Remove-Item $CMakeDir -Recurse -Force }
        Move-Item $Extracted.FullName $CMakeDir
        Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Add-ToSystemPath (Join-Path $CMakeDir "bin")

    Log-OK "CMake $CmakeVersion installed at $CMakeDir."
}

# ── Python (prerequisite for Conan) ───────────────────────────────────────────
function Ensure-Python {
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $pv = & python --version 2>&1
        Log-Info "Python found: $pv"
        return
    }

    Log-Step "Python (Conan prerequisite)"
    if (Test-Winget) {
        Invoke-Step "winget install Python.Python.3.12" {
            winget install --id Python.Python.3.12 `
                --accept-package-agreements --accept-source-agreements --silent
        }
    } else {
        $pyUrl = "https://www.python.org/ftp/python/3.12.8/python-3.12.8-amd64.exe"
        $pyExe = Join-Path $env:TEMP "python-installer.exe"
        Invoke-Step "Download & install Python 3.12.8" {
            Get-RemoteFile $pyUrl $pyExe
            Start-Process -FilePath $pyExe `
                -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" `
                -Wait
        }
    }

    # Refresh PATH in current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Log-OK "Python installed."
}

# ── Conan ─────────────────────────────────────────────────────────────────────
function Install-Conan {
    Log-Step "Conan $ConanVersion"

    $ConanVenv = Join-Path $Prefix "conan-venv"
    $ConanExe  = Join-Path $ConanVenv "Scripts\conan.exe"

    if (Test-Path $ConanExe) {
        $iv = (& $ConanExe --version 2>$null) -replace 'Conan version ',''
        if ($iv -like "$ConanVersion*") {
            Log-OK "Conan $iv already installed — skipping."
            return
        }
        Log-Warn "Conan $iv found but $ConanVersion requested — reinstalling."
    }

    Ensure-Python

    Invoke-Step "Create Python venv for Conan at $ConanVenv" {
        & python -m venv $ConanVenv
    }

    Invoke-Step "pip install conan==$ConanVersion" {
        & "$ConanVenv\Scripts\pip.exe" install --quiet --upgrade pip
        & "$ConanVenv\Scripts\pip.exe" install --quiet "conan==$ConanVersion"
    }

    Add-ToSystemPath (Join-Path $ConanVenv "Scripts")

    Log-OK "Conan $ConanVersion installed at $ConanVenv."
}

# ── NuGet ─────────────────────────────────────────────────────────────────────
function Install-Nuget {
    Log-Step "NuGet CLI $NugetVersion"

    $NugetDir = Join-Path $Prefix "nuget"
    $NugetExe = Join-Path $NugetDir "nuget.exe"

    if (Test-Path $NugetExe) {
        Log-OK "nuget.exe already present at $NugetExe — skipping."
        return
    }

    Ensure-Dir $NugetDir

    $Url = "https://dist.nuget.org/win-x86-commandline/v${NugetVersion}/nuget.exe"
    Invoke-Step "Download nuget.exe v$NugetVersion" {
        Get-RemoteFile $Url $NugetExe
    }

    Add-ToSystemPath $NugetDir

    Log-OK "nuget.exe $NugetVersion installed at $NugetDir."
}

# ── Generate environment script ────────────────────────────────────────────────
function New-EnvScript {
    Log-Step "Generating environment activation script"

    $EnvScript = Join-Path $Prefix "env.ps1"

    if ($DryRun) { Log-Dry "Write $EnvScript"; return }

    $content = @"
# =============================================================================
# DevEnv environment activation — generated by setup.ps1
# Dot-source this file in your session or CI pipeline:
#   . '$EnvScript'
# =============================================================================

`$DevEnvRoot = '$Prefix'

# .NET SDK
`$dotnetDir = Join-Path `$DevEnvRoot 'dotnet'
if (Test-Path `$dotnetDir) {
    `$env:DOTNET_ROOT = `$dotnetDir
    `$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    `$env:DOTNET_NOLOGO = '1'
    `$env:Path = "`$dotnetDir;`$env:Path"
}

# CMake
`$cmakeDir = Join-Path `$DevEnvRoot 'cmake\bin'
if (Test-Path `$cmakeDir) { `$env:Path = "`$cmakeDir;`$env:Path" }

# Conan
`$conanDir = Join-Path `$DevEnvRoot 'conan-venv\Scripts'
if (Test-Path `$conanDir) {
    `$env:CONAN_HOME = Join-Path `$DevEnvRoot 'conan-home'
    `$env:Path = "`$conanDir;`$env:Path"
}

# NuGet
`$nugetDir = Join-Path `$DevEnvRoot 'nuget'
if (Test-Path `$nugetDir) { `$env:Path = "`$nugetDir;`$env:Path" }

# MSVC (locate via vswhere)
`$vswhere = "`${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path `$vswhere) {
    `$vsPath = & `$vswhere -latest -products * ``
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ``
        -property installationPath 2>`$null
    if (`$vsPath) {
        # Import the Developer PowerShell environment
        `$vsDevShell = Join-Path `$vsPath 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
        if (Test-Path `$vsDevShell) {
            Import-Module `$vsDevShell -ErrorAction SilentlyContinue
            Enter-VsDevShell -VsInstallPath `$vsPath -SkipAutomaticLocation ``
                             -DevCmdArguments '-arch=x64 -host_arch=x64' -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "[devenv] Environment activated (root: `$DevEnvRoot)" -ForegroundColor Cyan
"@

    Set-Content -Path $EnvScript -Value $content -Encoding UTF8
    Log-OK "Activation script: $EnvScript"
    Write-Host ""
    Write-Host "  To activate in your shell:" -ForegroundColor White
    Write-Host "    . '$EnvScript'" -ForegroundColor Yellow
    Write-Host ""
}

# ── Summary ────────────────────────────────────────────────────────────────────
function Show-Summary {
    $DotnetExe = Join-Path $Prefix "dotnet\dotnet.exe"
    $CmakeExe  = Join-Path $Prefix "cmake\bin\cmake.exe"
    $ConanExe  = Join-Path $Prefix "conan-venv\Scripts\conan.exe"
    $NugetExe  = Join-Path $Prefix "nuget\nuget.exe"

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor White
    Write-Host "  ║           DevEnv Setup Summary                       ║" -ForegroundColor White
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor White

    $rows = [ordered]@{
        "OS"       = "$([System.Environment]::OSVersion.VersionString)"
        "Prefix"   = $Prefix
        "Git"      = if (Get-Command git -EA SilentlyContinue) { (& git --version) } else { "skipped" }
        "MSVC"     = if (Test-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe") { "installed (use env.ps1 to activate)" } else { "skipped" }
        ".NET SDK" = if (Test-Path $DotnetExe) { (& $DotnetExe --version) } else { "skipped" }
        "CMake"    = if (Test-Path $CmakeExe)  { ((& $CmakeExe --version | Select-Object -First 1) -replace 'cmake version ','') } else { "skipped" }
        "Conan"    = if (Test-Path $ConanExe)  { ((& $ConanExe --version) -replace 'Conan version ','') } else { "skipped" }
        "NuGet"    = if (Test-Path $NugetExe)  { "v$NugetVersion" } else { "skipped" }
    }

    foreach ($k in $rows.Keys) {
        Write-Host ("  {0,-18} {1}" -f $k, $rows[$k])
    }
    Write-Host ""
}

# ══════════════════════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════════════════════
function Main {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║          Developer Environment Setup                 ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    if (-not $DryRun) { Assert-Admin }
    if ($DryRun)      { Log-Warn "DRY-RUN MODE — no changes will be made." }

    Ensure-Dir $Prefix
    Ensure-Dir (Join-Path $Prefix "logs")

    if (-not $DryRun) {
        $ts      = (Get-Date).ToString("yyyyMMdd-HHmmss")
        $script:LogFile = Join-Path $Prefix "logs\setup-${ts}.log"
        New-Item -ItemType File -Path $LogFile -Force | Out-Null
    }

    Log-Info "Prefix:  $Prefix"
    Log-Info "Dry run: $DryRun"

    if (-not $SkipGit)    { Install-Git }
    if (-not $SkipMsvc)   { Install-Msvc }
    if (-not $SkipDotnet) { Install-Dotnet }
    if (-not $SkipCMake)  { Install-CMake }
    if (-not $SkipConan)  { Install-Conan }
    if (-not $SkipNuget)  { Install-Nuget }

    New-EnvScript

    if (-not $DryRun) {
        Show-Summary
        Log-OK "DevEnv setup complete.  Log: $LogFile"
    } else {
        Log-OK "Dry run complete — no changes made."
    }
}

Main
