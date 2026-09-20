param(
  [switch]$InstallMissing,
  [switch]$RunSetup,
  [switch]$LoginGitHub,
  [switch]$FullSetup,
  [switch]$Relaunched
)

$ErrorActionPreference = 'Stop'

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }

if ($FullSetup) {
  $InstallMissing = $true
  $LoginGitHub = $true
  $RunSetup = $true
}

if ($env:OS -ne 'Windows_NT') { throw 'TinyThor deployment bootstrap is Windows-only.' }

function Get-PwshPath {
  $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $known = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
  if (Test-Path $known) { return $known }
  return ''
}

function Relaunch-InPowerShell7 {
  param([string]$PwshPath)
  if ([string]::IsNullOrWhiteSpace($PwshPath)) { throw 'PowerShell 7 is not available yet.' }
  $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Relaunched')
  if ($FullSetup) {
    $args += '-FullSetup'
  } else {
    if ($InstallMissing) { $args += '-InstallMissing' }
    if ($RunSetup) { $args += '-RunSetup' }
    if ($LoginGitHub) { $args += '-LoginGitHub' }
  }
  Write-Info 'Relaunching setup under PowerShell 7...'
  & $PwshPath @args
  exit $LASTEXITCODE
}

# The deployment manager intentionally targets PowerShell 7. Bootstrap itself can be
# launched from legacy Windows PowerShell and will install/relaunch PowerShell 7.
if ($PSVersionTable.PSEdition -ne 'Core') {
  $pwsh = Get-PwshPath
  if (-not [string]::IsNullOrWhiteSpace($pwsh)) {
    Relaunch-InPowerShell7 -PwshPath $pwsh
  }
  if (-not $InstallMissing) {
    Write-Warn 'PowerShell 7 is required by the deployment manager.'
    Write-Host 'Re-run this command with -InstallMissing and Bootstrap will install PowerShell 7 for you.'
    exit 2
  }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is not available, so PowerShell 7 cannot be installed automatically.'
  }
  Write-Info 'Installing PowerShell 7 with winget...'
  & winget install --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0) { throw 'winget failed while installing PowerShell 7.' }
  $pwsh = Get-PwshPath
  if ([string]::IsNullOrWhiteSpace($pwsh)) {
    throw 'PowerShell 7 was installed but pwsh.exe could not be found. Reopen PowerShell and run Bootstrap.ps1 again.'
  }
  Relaunch-InPowerShell7 -PwshPath $pwsh
}

if (-not $IsWindows) { throw 'TinyThor deployment bootstrap is Windows-only.' }

$requirements = @(
  [pscustomobject]@{ Name='Git'; Command='git'; WingetId='Git.Git' },
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

  # Refresh PATH for commands installed by winget without requiring the user to guess.
  $machinePath = [Environment]::GetEnvironmentVariable('Path','Machine')
  $userPath = [Environment]::GetEnvironmentVariable('Path','User')
  $env:Path = "$machinePath;$userPath"
}

foreach ($r in $requirements) {
  if (-not (Get-Command $r.Command -ErrorAction SilentlyContinue)) {
    throw "$($r.Name) is still unavailable after setup. Close PowerShell, reopen it, and run Bootstrap.ps1 again."
  }
}

Write-Host ''
Write-Ok 'All required local tools are available under PowerShell 7.'

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

$manager = Join-Path $PSScriptRoot 'TinyThorDeploy.ps1'
if (-not (Test-Path $manager)) { throw "Deployment manager was not found: $manager" }

if ($RunSetup) {
  Write-Info 'Starting one-time TinyThor Cloudflare setup...'
  & $manager Setup
  if ($LASTEXITCODE -ne 0) { throw 'TinyThor Cloudflare setup did not complete successfully.' }
}

if ($FullSetup) {
  Write-Info 'Refreshing the verified project registry...'
  & $manager RefreshRegistry
  if ($LASTEXITCODE -ne 0) { throw 'Project registry refresh failed.' }

  Write-Info 'Looking for local project folders...'
  & $manager DiscoverLocal
  if ($LASTEXITCODE -ne 0) { throw 'Local project discovery failed.' }

  Write-Info 'Auditing the deployment configuration...'
  & $manager Audit
  if ($LASTEXITCODE -ne 0) { throw 'Deployment manager audit failed.' }

  Write-Info 'Syncing the approved Cloudflare credential to verified GitHub repositories...'
  & $manager SyncGitHubSecrets
  if ($LASTEXITCODE -ne 0) { throw 'GitHub secret sync failed.' }

  Write-Host ''
  Write-Ok 'Full one-time setup is complete.'
  Write-Host 'No production site was deployed by Bootstrap.' -ForegroundColor Gray
  Write-Host 'Next safe test: .\TinyThorDeploy.ps1 Backup -Project intuition' -ForegroundColor Yellow
  exit 0
}

Write-Host ''
Write-Ok 'Bootstrap checks complete.'
Write-Host 'Recommended one-time command after the Cloudflare token is created:' -ForegroundColor Gray
Write-Host '  .\Bootstrap.ps1 -FullSetup' -ForegroundColor Yellow
