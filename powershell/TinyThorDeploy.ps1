param(
  [Parameter(Mandatory=$true, Position=0)]
  [ValidateSet('Setup','Audit','List','DiscoverLocal','SetLocalPath','Backup','SyncGitHubSecrets','Deploy','DeployAll')]
  [string]$Action,
  [string]$Project,
  [string]$Path,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$AppName = 'TinyThorDeploy'
$StateDir = Join-Path $env:APPDATA $AppName
$ConfigPath = Join-Path $StateDir 'config.json'
$SecretPath = Join-Path $StateDir 'cloudflare-token.txt'
$ReferencePath = Join-Path $PSScriptRoot 'projects.reference.json'
$BackupRoot = Join-Path $HOME 'TinyThor-Backups'

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m) { throw $m }

function Ensure-StateDir {
  if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }
}

function Load-Config {
  if (-not (Test-Path $ConfigPath)) { Fail "Setup has not been completed. Run: .\TinyThorDeploy.ps1 Setup" }
  return Get-Content $ConfigPath -Raw | ConvertFrom-Json -Depth 20
}

function Save-Config($config) {
  Ensure-StateDir
  $config | ConvertTo-Json -Depth 20 | Set-Content -Path $ConfigPath -Encoding UTF8
}

function Get-Token {
  if (-not $IsWindows) { Fail 'Local token storage is intentionally Windows-only because this script uses Windows DPAPI.' }
  if (-not (Test-Path $SecretPath)) { Fail 'Cloudflare token is not stored yet. Run Setup.' }
  $enc = Get-Content $SecretPath -Raw
  $secure = ConvertTo-SecureString $enc
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Store-Token([Security.SecureString]$secureToken) {
  if (-not $IsWindows) { Fail 'Token storage requires Windows DPAPI.' }
  Ensure-StateDir
  $secureToken | ConvertFrom-SecureString | Set-Content -Path $SecretPath -Encoding UTF8
}

function Invoke-WranglerWhoAmI($accountId, $token) {
  $oldToken = $env:CLOUDFLARE_API_TOKEN
  $oldAccount = $env:CLOUDFLARE_ACCOUNT_ID
  try {
    $env:CLOUDFLARE_API_TOKEN = $token
    $env:CLOUDFLARE_ACCOUNT_ID = $accountId
    & npx --yes wrangler@latest whoami
    if ($LASTEXITCODE -ne 0) { Fail 'Cloudflare credential verification failed.' }
  }
  finally {
    $env:CLOUDFLARE_API_TOKEN = $oldToken
    $env:CLOUDFLARE_ACCOUNT_ID = $oldAccount
  }
}

function Get-Project($config, $name) {
  $p = @($config.projects | Where-Object { $_.name -eq $name })
  if ($p.Count -ne 1) { Fail "Project '$name' was not found or is ambiguous." }
  return $p[0]
}

function Require-Tool($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { Fail "Required tool '$name' was not found." }
}

function Backup-Project($p) {
  if ([string]::IsNullOrWhiteSpace($p.localPath) -or -not (Test-Path $p.localPath)) { Fail "Local path for '$($p.name)' is not configured or does not exist." }
  $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
  $dest = Join-Path $BackupRoot "$($p.name)-$stamp"
  New-Item -ItemType Directory -Path $dest -Force | Out-Null

  Write-Info "Backing up $($p.name) before any deployment..."
  Push-Location $p.localPath
  try {
    if (Test-Path '.git') {
      Require-Tool git
      & git bundle create (Join-Path $dest 'source.bundle') --all
      if ($LASTEXITCODE -ne 0) { Fail 'Git bundle backup failed.' }
      & git rev-parse HEAD | Set-Content (Join-Path $dest 'source-commit.txt')
      & git status --short | Set-Content (Join-Path $dest 'working-tree-status.txt')
    }

    if ($p.backupCommand) {
      Write-Info "Running project-specific read-only backup command..."
      Invoke-Expression $p.backupCommand
      if ($LASTEXITCODE -ne 0) { Fail "Project-specific backup failed for $($p.name)." }
    }

    @(
      "Project: $($p.name)",
      "Repository: $($p.repo)",
      "Created: $(Get-Date -Format o)",
      "Local path: $($p.localPath)"
    ) | Set-Content (Join-Path $dest 'backup-manifest.txt')
  }
  finally { Pop-Location }

  Write-Ok "Backup completed: $dest"
  return $dest
}

function Deploy-Project($config, $p) {
  if (-not $p.enabled) { Fail "Project '$($p.name)' is disabled in the deployment manager." }
  if ($p.protected -and -not $Force) { Fail "Project '$($p.name)' is protected. It will not deploy without -Force." }
  if ([string]::IsNullOrWhiteSpace($p.localPath) -or -not (Test-Path $p.localPath)) { Fail "Local path for '$($p.name)' is not configured." }

  $null = Backup-Project $p
  $token = Get-Token
  $oldToken = $env:CLOUDFLARE_API_TOKEN
  $oldAccount = $env:CLOUDFLARE_ACCOUNT_ID
  try {
    $env:CLOUDFLARE_API_TOKEN = $token
    $env:CLOUDFLARE_ACCOUNT_ID = $config.cloudflareAccountId
    Push-Location $p.localPath
    try {
      Require-Tool npx
      if ($p.cloudflareType -eq 'worker') {
        Write-Info "Dry-running $($p.name)..."
        & npx --yes wrangler@latest deploy --config wrangler.jsonc --dry-run
        if ($LASTEXITCODE -ne 0) { Fail 'Wrangler dry-run failed. Nothing was deployed.' }
        $confirm = Read-Host "Type DEPLOY $($p.name) to continue"
        if ($confirm -ne "DEPLOY $($p.name)") { Fail 'Deployment cancelled. Backup was kept.' }
        & npx --yes wrangler@latest deploy --config wrangler.jsonc
        if ($LASTEXITCODE -ne 0) { Fail 'Cloudflare deployment failed.' }
      }
      elseif ($p.cloudflareType -eq 'pages') {
        Fail "Pages deployment for '$($p.name)' remains intentionally disabled until its exact build/output directory is verified."
      }
      else { Fail "Unknown deployment type for '$($p.name)'." }
    }
    finally { Pop-Location }
  }
  finally {
    $env:CLOUDFLARE_API_TOKEN = $oldToken
    $env:CLOUDFLARE_ACCOUNT_ID = $oldAccount
  }
  Write-Ok "Deployment finished for $($p.name)."
}

switch ($Action) {
  'Setup' {
    if (-not (Test-Path $ReferencePath)) { Fail "Reference config missing: $ReferencePath" }
    Require-Tool npx
    Ensure-StateDir
    $accountId = Read-Host 'Cloudflare Account ID'
    if ([string]::IsNullOrWhiteSpace($accountId)) { Fail 'Account ID cannot be blank.' }
    $secureToken = Read-Host 'Cloudflare deployment API token' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    try { $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    if ([string]::IsNullOrWhiteSpace($plainToken)) { Fail 'Token cannot be blank.' }
    Invoke-WranglerWhoAmI $accountId $plainToken
    Store-Token $secureToken
    $ref = Get-Content $ReferencePath -Raw | ConvertFrom-Json -Depth 20
    $config = [pscustomobject]@{
      version = 1
      cloudflareAccountId = $accountId
      projects = @($ref.projects | ForEach-Object {
        [pscustomobject]@{
          name=$_.name; repo=$_.repo; cloudflareType=$_.cloudflareType; cloudflareName=$_.cloudflareName
          enabled=$_.enabled; protected=$_.protected; localPath=''; backupCommand=''
        }
      })
    }
    Save-Config $config
    Write-Ok 'Setup completed. Token is encrypted with Windows DPAPI for this Windows user.'
  }
  'List' {
    $config = Load-Config
    $config.projects | Select-Object name,repo,cloudflareType,cloudflareName,enabled,protected,localPath | Format-Table -AutoSize
  }
  'Audit' {
    $config = Load-Config
    Write-Info 'Deployment manager audit'
    Write-Host "State directory: $StateDir"
    Write-Host "Encrypted token present: $(Test-Path $SecretPath)"
    Write-Host "Account ID present: $(-not [string]::IsNullOrWhiteSpace($config.cloudflareAccountId))"
    foreach ($p in $config.projects) {
      $pathOk = -not [string]::IsNullOrWhiteSpace($p.localPath) -and (Test-Path $p.localPath)
      Write-Host ("{0,-20} enabled={1,-5} protected={2,-5} path={3}" -f $p.name,$p.enabled,$p.protected,$pathOk)
    }
  }
  'DiscoverLocal' {
    $config = Load-Config
    $roots = @($HOME, (Join-Path $HOME 'Documents'), (Join-Path $HOME 'Desktop')) | Where-Object { Test-Path $_ } | Select-Object -Unique
    foreach ($p in $config.projects) {
      $repoLeaf = ($p.repo -split '/')[-1]
      $matches = foreach ($root in $roots) {
        Get-ChildItem -Path $root -Directory -Depth 4 -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $repoLeaf }
      }
      $matches = @($matches | Select-Object -Unique FullName)
      if ($matches.Count -eq 1) {
        $p.localPath = $matches[0].FullName
        Write-Ok "$($p.name) -> $($p.localPath)"
      } elseif ($matches.Count -gt 1) {
        Write-Warn "Multiple local matches for $($p.name); use SetLocalPath."
      }
    }
    Save-Config $config
  }
  'SetLocalPath' {
    if ([string]::IsNullOrWhiteSpace($Project) -or [string]::IsNullOrWhiteSpace($Path)) { Fail 'Use -Project NAME -Path FULLPATH.' }
    $config = Load-Config
    if (-not (Test-Path $Path)) { Fail "Path does not exist: $Path" }
    $p = Get-Project $config $Project
    $p.localPath = [IO.Path]::GetFullPath($Path)
    Save-Config $config
    Write-Ok "$Project local path saved."
  }
  'Backup' {
    if ([string]::IsNullOrWhiteSpace($Project)) { Fail 'Use -Project NAME.' }
    $config = Load-Config
    $p = Get-Project $config $Project
    $null = Backup-Project $p
  }
  'SyncGitHubSecrets' {
    $config = Load-Config
    Require-Tool gh
    $token = Get-Token
    & gh auth status
    if ($LASTEXITCODE -ne 0) { Fail 'GitHub CLI is not authenticated.' }
    foreach ($p in $config.projects | Where-Object { $_.enabled -or $_.protected }) {
      if ([string]::IsNullOrWhiteSpace($p.repo)) { continue }
      Write-Info "Syncing Cloudflare Actions secrets to $($p.repo)..."
      $token | & gh secret set CLOUDFLARE_API_TOKEN --repo $p.repo
      if ($LASTEXITCODE -ne 0) { Fail "Failed setting token in $($p.repo)." }
      $config.cloudflareAccountId | & gh secret set CLOUDFLARE_ACCOUNT_ID --repo $p.repo
      if ($LASTEXITCODE -ne 0) { Fail "Failed setting account ID in $($p.repo)." }
      Write-Ok "Secrets synced: $($p.repo)"
    }
  }
  'Deploy' {
    if ([string]::IsNullOrWhiteSpace($Project)) { Fail 'Use -Project NAME.' }
    $config = Load-Config
    $p = Get-Project $config $Project
    Deploy-Project $config $p
  }
  'DeployAll' {
    $config = Load-Config
    $targets = @($config.projects | Where-Object { $_.enabled -and -not $_.protected })
    if ($targets.Count -eq 0) { Fail 'No enabled, unprotected projects are configured.' }
    Write-Warn 'DeployAll will back up each target, dry-run it, and still require an explicit per-project confirmation.'
    foreach ($p in $targets) { Deploy-Project $config $p }
  }
}
