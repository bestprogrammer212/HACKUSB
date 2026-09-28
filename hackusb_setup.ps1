[CmdletBinding()]
param(
    [ValidateSet('auto','wsl','native')]
    [string]$Mode = 'auto',

    [ValidateSet('winget','choco','scoop')]
    [string]$PackageManager = 'winget',

    [string]$UsbPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Ok($Message)   { Write-Host "[ OK ] $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err($Message)  { Write-Host "[FAIL] $Message" -ForegroundColor Red }

function Get-ExecutionPolicyHint {
    $policy = Get-ExecutionPolicy -Scope Process
    if ($policy -eq 'Undefined') {
        $policy = Get-ExecutionPolicy
    }
    if ($policy -in @('Restricted','AllSigned')) {
        Write-Warn "Execution policy '$policy' may block this script."
        Write-Host "Run in the same terminal session:  Set-ExecutionPolicy -Scope Process Bypass" -ForegroundColor Yellow
    }
}

function Ensure-RepoScript {
    $repoRoot = Split-Path -Parent $PSCommandPath
    $zshScript = Join-Path $repoRoot 'hackusb_setup.zsh'
    if (-not (Test-Path -Path $zshScript -PathType Leaf)) {
        throw "Could not find $zshScript"
    }
    return @{ Root = $repoRoot; Script = $zshScript }
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
    $gitBashCandidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\usr\bin\bash.exe",
        "$env:ProgramFiles(x86)\Git\bin\bash.exe"
    )

    foreach ($candidate in $gitBashCandidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) { return $bashCmd.Source }

    Write-Warn 'Git Bash was not found. Trying package-manager install of Git first.'
    switch ($PackageManager) {
        'winget' {
            & winget install --id Git.Git --accept-source-agreements --accept-package-agreements
        }
        'choco' {
            & choco install -y git
        }
        'scoop' {
            & scoop install git
        }
    }

    foreach ($candidate in $gitBashCandidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    throw 'Git Bash is still missing. Install Git for Windows, then re-run this script.'
}

function Run-WithWsl($RepoRoot) {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw 'WSL is not available. Install WSL2 first: wsl --install (PowerShell as Administrator).'
    }

    $wslRepo = Convert-ToWslPath -Path $RepoRoot
    Write-Info "Using WSL2 path: $wslRepo"
    Write-Info 'Running: sudo zsh ./hackusb_setup.zsh (inside WSL2)'

    & wsl.exe bash -lc "cd '$wslRepo' && sudo zsh ./hackusb_setup.zsh"
}

function Run-WithGitBash($RepoRoot) {
    $bashExe = Ensure-GitBash
    Write-Info "Using Bash executable: $bashExe"
    Write-Warn 'Native Windows mode has limited tool coverage. WSL2 is recommended for full compatibility.'

    $unixPath = $RepoRoot.Replace('\\','/')
    if ($unixPath -match '^([A-Za-z]):/(.*)$') {
        $drive = $matches[1].ToLowerInvariant()
        $rest = $matches[2]
        $unixPath = "/$drive/$rest"
    }

    & "$bashExe" -lc "cd '$unixPath' && zsh ./hackusb_setup.zsh"
}

try {
    Write-Host 'HACK USB — Windows launcher (authorized systems only)' -ForegroundColor Magenta
    Write-Host 'Unauthorized access is illegal. Use only with explicit permission.' -ForegroundColor Yellow

    Get-ExecutionPolicyHint

    if ($UsbPath) {
        Write-Info "Provided USB path: $UsbPath"
        if ($UsbPath -match '^[A-Za-z]:\\') {
            Write-Info "WSL2 equivalent path: $(Convert-ToWslPath -Path $UsbPath)"
        }
    }

    $repo = Ensure-RepoScript

    if ($Mode -eq 'auto') {
        $Mode = if (Get-Command wsl.exe -ErrorAction SilentlyContinue) { 'wsl' } else { 'native' }
        Write-Info "Auto-selected mode: $Mode"
    }

    switch ($Mode) {
        'wsl'    { Run-WithWsl -RepoRoot $repo.Root }
        'native' { Run-WithGitBash -RepoRoot $repo.Root }
        default  { throw "Unsupported mode: $Mode" }
    }

    Write-Ok 'Completed launcher flow.'
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}
