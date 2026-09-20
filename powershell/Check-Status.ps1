param(
  [switch]$SkipCloudflareCheck,
  [switch]$SkipGitHubCheck
)

$ErrorActionPreference = 'Stop'
$StateDir = Join-Path $env:APPDATA 'TinyThorDeploy'
$ConfigPath = Join-Path $StateDir 'config.json'
$SecretPath = Join-Path $StateDir 'cloudflare-token.txt'
$ReferencePath = Join-Path $PSScriptRoot 'projects.reference.json'

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Bad($m) { Write-Host "[MISS] $m" -ForegroundColor Red }

if ($env:OS -ne 'Windows_NT') { throw 'TinyThor status check is Windows-only.' }

Write-Host ''
Write-Host '=== TinyThor Cloudflare Automation Status ===' -ForegroundColor Cyan
Write-Host 'Read-only check. No secrets are changed and no site is deployed.' -ForegroundColor Gray
Write-Host ''

$configExists = Test-Path $ConfigPath
$tokenExists = Test-Path $SecretPath

if ($configExists) { Write-Ok "Local config found: $ConfigPath" } else { Write-Bad 'Local TinyThor config is not stored on this Windows account yet.' }
if ($tokenExists) { Write-Ok 'Encrypted local Cloudflare token is present.' } else { Write-Bad 'Encrypted local Cloudflare token is not present.' }

$config = $null
if ($configExists) {
  try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -Depth 30
    if ([string]::IsNullOrWhiteSpace([string]$config.cloudflareAccountId)) {
      Write-Bad 'Local config does not contain the Cloudflare Account ID.'
    } else {
      Write-Ok 'Cloudflare Account ID is stored locally.'
    }
  } catch {
    Write-Bad "Local config could not be parsed: $($_.Exception.Message)"
  }
}

if (Test-Path $ReferencePath) {
  $reference = Get-Content $ReferencePath -Raw | ConvertFrom-Json -Depth 30
  Write-Ok "Project registry found: $(@($reference.projects).Count) project(s)."
} else {
  $reference = $null
  Write-Bad 'Project reference registry is missing.'
}

if ($config -and $reference) {
  Write-Host ''
  Write-Info 'Local project paths'
  foreach ($r in @($reference.projects)) {
    $local = @($config.projects | Where-Object name -eq $r.name)
    $path = if ($local.Count -eq 1) { [string]$local[0].localPath } else { '' }
    if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path $path)) {
      $configOk = $true
      if ($r.deployReady -and $r.cloudflareType -eq 'worker' -and -not [string]::IsNullOrWhiteSpace([string]$r.configPath)) {
        $configOk = Test-Path (Join-Path $path ([string]$r.configPath))
      }
      if ($configOk) { Write-Ok "$($r.name): $path" } else { Write-Warn "$($r.name): path exists but expected Wrangler config is missing." }
    } else {
      Write-Warn "$($r.name): local path not configured/found."
    }
  }
}

if (-not $SkipCloudflareCheck) {
  Write-Host ''
  Write-Info 'Cloudflare credential check'
  if (-not $config -or -not $tokenExists) {
    Write-Warn 'Skipped Cloudflare verification because the local encrypted setup is incomplete.'
  } elseif (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Warn 'Skipped Cloudflare verification because npx/Node.js is not installed.'
  } else {
    $enc = Get-Content $SecretPath -Raw
    $secure = ConvertTo-SecureString $enc
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $token = ''
    try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

    $oldToken = $env:CLOUDFLARE_API_TOKEN
    $oldAccount = $env:CLOUDFLARE_ACCOUNT_ID
    try {
      $env:CLOUDFLARE_API_TOKEN = $token
      $env:CLOUDFLARE_ACCOUNT_ID = [string]$config.cloudflareAccountId
      & npx --yes wrangler@latest whoami | Out-Host
      if ($LASTEXITCODE -eq 0) { Write-Ok 'Existing Cloudflare token verified successfully.' }
      else { Write-Bad 'Existing Cloudflare token could not be verified with Wrangler.' }
    }
    finally {
      $env:CLOUDFLARE_API_TOKEN = $oldToken
      $env:CLOUDFLARE_ACCOUNT_ID = $oldAccount
      $token = $null
    }
  }
}

if (-not $SkipGitHubCheck) {
  Write-Host ''
  Write-Info 'GitHub credential wiring check'
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Warn 'GitHub CLI is not installed; repository secret names could not be checked.'
  } else {
    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
      Write-Warn 'GitHub CLI is installed but not authenticated; repository secret names could not be checked.'
    } elseif (-not $reference) {
      Write-Warn 'Project registry is unavailable; GitHub repositories could not be checked.'
    } else {
      $targets = @($reference.projects | Where-Object { $_.credentialSync -and $_.deployReady -and -not [string]::IsNullOrWhiteSpace([string]$_.repo) })
      foreach ($p in $targets) {
        $raw = (& gh secret list --repo $p.repo 2>$null | Out-String)
        if ($LASTEXITCODE -ne 0) {
          Write-Warn "$($p.repo): could not list Actions secret names."
          continue
        }
        $names = @($raw -split "`r?`n" | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ })
        $missing = @('CLOUDFLARE_API_TOKEN','CLOUDFLARE_DEPLOY_TOKEN','CLOUDFLARE_ACCOUNT_ID') | Where-Object { $_ -notin $names }
        if ($missing.Count -eq 0) {
          Write-Ok "$($p.repo): expected Cloudflare secret names are present."
        } else {
          Write-Warn "$($p.repo): missing secret name(s): $($missing -join ', ')"
        }
      }
    }
  }
}

Write-Host ''
Write-Host 'Status check finished. No production deployment was performed.' -ForegroundColor Cyan
Write-Host 'If anything above is missing, START-HERE.bat is the repair/setup path; it reuses Hunter''s existing Cloudflare token.' -ForegroundColor Gray
