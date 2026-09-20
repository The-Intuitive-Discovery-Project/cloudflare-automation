param(
  [switch]$InstallMissing,
  [switch]$RunSetup,
  [switch]$LoginGitHub
)

$ErrorActionPreference = 'Stop'

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

if (-not $IsWindows) { throw 'TinyThor deployment bootstrap is Windows-only.' }

$requirements = @(
  [pscustomobject]@{ Name='git'; Command='git'; WingetId='Git.Git' },
  [pscustomobject]@{ Name='Node.js / npx'; Command='npx'; WingetId='OpenJS.NodeJS.LTS' },
  [pscustomobject]@{ Name='GitHub CLI'; Command='gh'; WingetId='GitHub.cli' }
)

Write-Info 'Checking TinyThor deployment prerequisites...'
$missing = @()
foreach ($r in $requirements) {
  if (Get-Command $r.Command -ErrorAction SilentlyContinue) {
    Write-Ok "$($r.Name) is installed."
  } else {
    Write-Warn "$($r.Name) is missing."
    $missing += $r
  }
}

if ($missing.Count -gt 0) {
  if (-not $InstallMissing) {
    Write-Host ''
    Write-Warn 'Nothing was installed automatically.'
    Write-Host 'Re-run with -InstallMissing to install the missing prerequisites with Windows Package Manager (winget).'
    exit 2
  }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is not available, so missing prerequisites cannot be installed automatically.'
  }

  foreach ($r in $missing) {
    Write-Info "Installing $($r.Name) with winget..."
    & winget install --id $r.WingetId --exact --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget failed while installing $($r.Name)." }
  }

  Write-Host ''
  Write-Ok 'Prerequisite installation finished.'
  Write-Warn 'If a newly installed command is not visible in this PowerShell window yet, close PowerShell, reopen it, and run Bootstrap.ps1 again.'
}

foreach ($r in $requirements) {
  if (-not (Get-Command $r.Command -ErrorAction SilentlyContinue)) {
    throw "$($r.Name) is still unavailable in this PowerShell session. Reopen PowerShell and run this script again."
  }
}

Write-Host ''
Write-Ok 'All required local tools are available.'

if ($LoginGitHub) {
  Write-Info 'Checking GitHub CLI authentication...'
  & gh auth status
  if ($LASTEXITCODE -ne 0) {
    Write-Info 'Starting the normal GitHub CLI login flow...'
    & gh auth login --web --git-protocol https
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI login did not complete successfully.' }
  }
  Write-Ok 'GitHub CLI authentication is ready.'
}

if ($RunSetup) {
  $manager = Join-Path $PSScriptRoot 'TinyThorDeploy.ps1'
  if (-not (Test-Path $manager)) { throw "Deployment manager was not found: $manager" }
  Write-Info 'Starting one-time TinyThor Cloudflare setup...'
  & $manager Setup
  if ($LASTEXITCODE -ne 0) { throw 'TinyThor Cloudflare setup did not complete successfully.' }
}

Write-Host ''
Write-Ok 'Bootstrap checks complete.'
Write-Host 'Recommended one-time command after the Cloudflare token is created:' -ForegroundColor Gray
Write-Host '  .\Bootstrap.ps1 -InstallMissing -LoginGitHub -RunSetup' -ForegroundColor Yellow
