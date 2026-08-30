[CmdletBinding()]
param(
    [switch]$Prepare,
    [ValidateSet('none', 'session', 'auth')]
    [string]$Targeted = 'none',
    [switch]$Full
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = Split-Path -Parent $scriptRoot
Set-Location -LiteralPath $repositoryRoot

function Write-Blocked([string]$Message) {
    [Console]::Error.WriteLine("BLOCKED — $Message")
}

function Invoke-Checked([string]$Label, [scriptblock]$Action) {
    Write-Host "==> $Label"
    & $Action
    if ($LASTEXITCODE -ne 0) {
        Write-Blocked "$Label failed with exit $LASTEXITCODE."
        exit $LASTEXITCODE
    }
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    Write-Blocked 'tool/setup_mosigame.ps1 supports Windows only.'
    exit 3
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Blocked 'Git is not available on PATH. Install it manually.'
    exit 3
}

$beforeStatus = (& git status --porcelain=v2 --branch --untracked-files=all) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) {
    Write-Blocked 'Git working-tree state could not be read.'
    exit 3
}

$requiredFiles = @(
    'AGENTS.md',
    'docs/engineering/ENGINEERING_CONTRACT.md',
    'docs/engineering/PROJECT_CLI.md',
    'pubspec.yaml',
    '.nvmrc',
    'functions/package.json',
    'functions/package-lock.json',
    'android/app/google-services.json',
    'ios/Runner/GoogleService-Info.plist',
    'lib/firebase/firebase_options.dart'
)
$missingFiles = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($missingFiles.Count -gt 0) {
    Write-Blocked "Required repository files are missing: $($missingFiles -join ', ')"
    exit 3
}

foreach ($command in @('flutter', 'dart', 'node', 'npm', 'java')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        Write-Blocked "$command is not available on PATH. Install or select it manually."
        exit 3
    }
}

$javaStart = [Diagnostics.ProcessStartInfo]::new()
$javaStart.FileName = (Get-Command java).Source
$javaStart.UseShellExecute = $false
$javaStart.RedirectStandardOutput = $true
$javaStart.RedirectStandardError = $true
$javaStart.Arguments = '-version'
$javaProcess = [Diagnostics.Process]::Start($javaStart)
$javaOutput = $javaProcess.StandardError.ReadToEnd()
$javaProcess.WaitForExit()
$javaVersion = ($javaOutput -split '\r?\n' | Select-Object -First 1) -join ''
if ($javaProcess.ExitCode -ne 0 -or $javaVersion -notmatch '"([0-9]+)') {
    Write-Blocked 'Java version could not be determined.'
    exit 3
}
if ([int]$Matches[1] -lt 17) {
    Write-Blocked "Java 17 or newer is required; found major $($Matches[1])."
    exit 3
}

$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adbCommand) {
    $adbCandidates = @()
    if ($env:ANDROID_SDK_ROOT) {
        $adbCandidates += Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe'
    }
    if ($env:ANDROID_HOME) {
        $adbCandidates += Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
    }
    if ($env:LOCALAPPDATA) {
        $adbCandidates += Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    }
    $adbFound = $false
    foreach ($adbCandidate in $adbCandidates) {
        if (Test-Path -LiteralPath $adbCandidate -PathType Leaf) {
            $adbFound = $true
            break
        }
    }
    if (-not $adbFound) {
        Write-Blocked 'Android SDK platform-tools/ADB was not found.'
        exit 3
    }
}

$expectedNodeMajor = (Get-Content -LiteralPath '.nvmrc' -Raw).Trim()
$actualNode = (& node --version).Trim()
if ($LASTEXITCODE -ne 0 -or $actualNode -notmatch '^v?([0-9]+)') {
    Write-Blocked 'Node.js version could not be determined.'
    exit 3
}
if ($Matches[1] -ne $expectedNodeMajor) {
    Write-Blocked "Node.js major $($Matches[1]) does not match .nvmrc $expectedNodeMajor."
    exit 3
}

Write-Host 'OS: windows'
Write-Host "Setup mode: $(if ($Prepare) { 'prepare' } else { 'audit' })"
Write-Host "Node: $actualNode"
Write-Host "Java: $javaVersion"

if ($Prepare) {
    Invoke-Checked 'Flutter repository dependencies' { & flutter pub get }
    Push-Location -LiteralPath 'functions'
    try {
        Invoke-Checked 'Functions repository dependencies' { & npm ci }
    } finally {
        Pop-Location
    }
} elseif (-not (Test-Path -LiteralPath '.dart_tool/package_config.json') -or
          -not (Test-Path -LiteralPath 'functions/node_modules' -PathType Container)) {
    Write-Blocked 'Repository dependencies are incomplete. Re-run with -Prepare after approval.'
    exit 3
}

Invoke-Checked 'Mosigame Project CLI doctor' {
    & "$repositoryRoot\tool\invoke_mosigame.ps1" doctor
}

if ($Targeted -ne 'none') {
    Invoke-Checked "Mosigame targeted suite: $Targeted" {
        & "$repositoryRoot\tool\invoke_mosigame.ps1" test $Targeted
    }
}

if ($Full) {
    Invoke-Checked 'Mosigame FULL validation' {
        & "$repositoryRoot\tool\invoke_mosigame.ps1" validate --full
    }
}

$afterStatus = (& git status --porcelain=v2 --branch --untracked-files=all) -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) {
    Write-Blocked 'Final Git working-tree state could not be read.'
    exit 3
}
if ($afterStatus -cne $beforeStatus) {
    Write-Blocked 'Git working-tree state changed. Inspect the diff; nothing was restored.'
    exit 1
}

Write-Host 'READY — MOSIGAME DEVELOPMENT ENVIRONMENT'
Write-Host "Targeted: $(if ($Targeted -eq 'none') { 'NOT RUN' } else { 'PASS' })"
Write-Host "FULL: $(if ($Full) { 'PASS' } else { 'NOT RUN' })"
Write-Host 'Working tree: preserved'
exit 0
