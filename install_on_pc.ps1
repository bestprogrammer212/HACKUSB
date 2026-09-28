[CmdletBinding()]
param(
    [ValidateSet('auto','wsl','native')]
    [string]$Mode = 'auto',

    [ValidateSet('winget','choco','scoop')]
    [string]$PackageManager = 'winget'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err($Message)  { Write-Host "[FAIL] $Message" -ForegroundColor Red }

function Ensure-InstallerScript {
    $repoRoot = Split-Path -Parent $PSCommandPath
    $script = Join-Path $repoRoot 'install_on_pc.zsh'
    if (-not (Test-Path -Path $script -PathType Leaf)) {
        throw "Could not find $script"
    }
    return @{ Root = $repoRoot; Script = $script }
}

function Convert-ToWslPath([string]$Path) {
    $wslPath = & wsl.exe wslpath -a "$Path" 2>$null
    if (-not $wslPath) {
        $drive = $Path.Substring(0,1).ToLowerInvariant()
        $rest = $Path.Substring(2).Replace('\\','/')
        return "/mnt/$drive$rest"
    }
    return ($wslPath | Select-Object -First 1).Trim()
}

function Ensure-GitBash {
    $candidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\usr\bin\bash.exe",
        "$env:ProgramFiles(x86)\Git\bin\bash.exe"
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }

    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) { return $bashCmd.Source }

    switch ($PackageManager) {
        'winget' { & winget install --id Git.Git --accept-source-agreements --accept-package-agreements }
        'choco'  { & choco install -y git }
        'scoop'  { & scoop install git }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }

    throw 'Git Bash is missing. Install Git for Windows and rerun.'
}

function Run-WithWsl($RepoRoot) {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw 'WSL is not available. Install WSL2 first: wsl --install (PowerShell as Administrator).'
    }

    $wslRepo = Convert-ToWslPath -Path $RepoRoot
    Write-Info "Using WSL2 path: $wslRepo"
    & wsl.exe bash -lc "cd '$wslRepo' && sudo zsh ./install_on_pc.zsh"
}

function Run-WithGitBash($RepoRoot) {
    $bashExe = Ensure-GitBash
    $unixPath = $RepoRoot.Replace('\\','/')
    if ($unixPath -match '^([A-Za-z]):/(.*)$') {
        $drive = $matches[1].ToLowerInvariant()
        $rest = $matches[2]
        $unixPath = "/$drive/$rest"
    }

    Write-Warn 'Native Windows mode has limited Linux tool compatibility. WSL2 is recommended.'
    & "$bashExe" -lc "cd '$unixPath' && zsh ./install_on_pc.zsh"
}

try {
    Write-Host 'HACK USB — PC tool installer launcher (authorized systems only)' -ForegroundColor Magenta

    $repo = Ensure-InstallerScript

    if ($Mode -eq 'auto') {
        $Mode = if (Get-Command wsl.exe -ErrorAction SilentlyContinue) { 'wsl' } else { 'native' }
        Write-Info "Auto-selected mode: $Mode"
    }

    switch ($Mode) {
        'wsl'    { Run-WithWsl -RepoRoot $repo.Root }
        'native' { Run-WithGitBash -RepoRoot $repo.Root }
        default  { throw "Unsupported mode: $Mode" }
    }
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}
