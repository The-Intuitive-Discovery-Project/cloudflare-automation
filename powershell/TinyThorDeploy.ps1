param(
  [Parameter(Mandatory=$true, Position=0)]
  [ValidateSet('Setup','RefreshRegistry','Audit','List','DiscoverLocal','SetLocalPath','Backup','SyncGitHubSecrets','Deploy','DeployAll')]
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

function Require-Tool($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { Fail "Required tool '$name' was not found." }
}

function Read-Reference {
  if (-not (Test-Path $ReferencePath)) { Fail "Reference config missing: $ReferencePath" }
  return Get-Content $ReferencePath -Raw | ConvertFrom-Json -Depth 30
}

function Load-Config {
  if (-not (Test-Path $ConfigPath)) { Fail "Setup has not been completed. Run: .\TinyThorDeploy.ps1 Setup" }
  return Get-Content $ConfigPath -Raw | ConvertFrom-Json -Depth 30
}

function Save-Config($config) {
  Ensure-StateDir
  $config | ConvertTo-Json -Depth 30 | Set-Content -Path $ConfigPath -Encoding UTF8
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

function New-ProjectFromReference($r, $existing = $null) {
  $localPath = ''
  $backupCommand = ''
  if ($null -ne $existing) {
    if ($existing.PSObject.Properties.Name -contains 'localPath') { $localPath = [string]$existing.localPath }
    if ($existing.PSObject.Properties.Name -contains 'backupCommand') { $backupCommand = [string]$existing.backupCommand }
  }
  return [pscustomobject]@{
    name = [string]$r.name
    repo = [string]$r.repo
    cloudflareType = [string]$r.cloudflareType
    cloudflareName = [string]$r.cloudflareName
    configPath = [string]$r.configPath
    status = [string]$r.status
    deployReady = [bool]$r.deployReady
    credentialSync = [bool]$r.credentialSync
    enabled = [bool]$r.enabled
    protected = [bool]$r.protected
    localPath = $localPath
    backupCommand = $backupCommand
  }
}

function Refresh-Registry($config) {
  $ref = Read-Reference
  $newProjects = @()
  foreach ($r in $ref.projects) {
    $existing = @($config.projects | Where-Object { $_.name -eq $r.name })
    $old = if ($existing.Count -eq 1) { $existing[0] } else { $null }
    $newProjects += New-ProjectFromReference $r $old
  }
  $config.version = [int]$ref.version
  $config.projects = $newProjects
  return $config
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
    } else {
      Write-Warn 'No .git directory found; source bundle backup was skipped.'
    }

    if ($p.backupCommand) {
      Write-Info 'Running project-specific read-only backup command...'
      Invoke-Expression $p.backupCommand
      if ($LASTEXITCODE -ne 0) { Fail "Project-specific backup failed for $($p.name)." }
    }

    @(
      "Project: $($p.name)",
      "Repository: $($p.repo)",
      "Created: $(Get-Date -Format o)",
      "Local path: $($p.localPath)",
      "Registry status: $($p.status)"
    ) | Set-Content (Join-Path $dest 'backup-manifest.txt')
  }
  finally { Pop-Location }

  Write-Ok "Backup completed: $dest"
  return $dest
}

function Deploy-Project($config, $p) {
  if (-not $p.deployReady) { Fail "Project '$($p.name)' is not marked deploy-ready. Status: $($p.status)" }
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
        $wranglerConfig = if ([string]::IsNullOrWhiteSpace($p.configPath)) { 'wrangler.jsonc' } else { $p.configPath }
        if (-not (Test-Path $wranglerConfig)) { Fail "Expected Wrangler config was not found: $wranglerConfig" }
        Write-Info "Dry-running $($p.name)..."
        & npx --yes wrangler@latest deploy --config $wranglerConfig --dry-run
        if ($LASTEXITCODE -ne 0) { Fail 'Wrangler dry-run failed. Nothing was deployed.' }
        $confirm = Read-Host "Type DEPLOY $($p.name) to continue"
        if ($confirm -ne "DEPLOY $($p.name)") { Fail 'Deployment cancelled. Backup was kept.' }
        & npx --yes wrangler@latest deploy --config $wranglerConfig
        if ($LASTEXITCODE -ne 0) { Fail 'Cloudflare deployment failed.' }
      }
      else {
        Fail "Deployment type '$($p.cloudflareType)' for '$($p.name)' is not enabled. The manager fails closed for unverified targets."
      }
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
    $ref = Read-Reference
    $config = [pscustomobject]@{
      version = [int]$ref.version
      cloudflareAccountId = $accountId
      projects = @($ref.projects | ForEach-Object { New-ProjectFromReference $_ })
    }
    Save-Config $config
    Write-Ok 'Setup completed. Token is encrypted with Windows DPAPI for this Windows user.'
  }
  'RefreshRegistry' {
    $config = Load-Config
    $config = Refresh-Registry $config
    Save-Config $config
    Write-Ok 'Project registry refreshed without changing the stored Cloudflare token or saved local paths.'
  }
  'List' {
    $config = Load-Config
    $config.projects | Select-Object name,cloudflareType,deployReady,credentialSync,enabled,protected,status,localPath | Format-Table -AutoSize
  }
  'Audit' {
    $config = Load-Config
    Write-Info 'Deployment manager audit'
    Write-Host "State directory: $StateDir"
    Write-Host "Encrypted token present: $(Test-Path $SecretPath)"
    Write-Host "Account ID present: $(-not [string]::IsNullOrWhiteSpace($config.cloudflareAccountId))"
    foreach ($p in $config.projects) {
      $pathOk = -not [string]::IsNullOrWhiteSpace($p.localPath) -and (Test-Path $p.localPath)
      $configOk = $true
      if ($pathOk -and $p.deployReady -and $p.cloudflareType -eq 'worker') {
        $wranglerConfig = if ([string]::IsNullOrWhiteSpace($p.configPath)) { 'wrangler.jsonc' } else { $p.configPath }
        $configOk = Test-Path (Join-Path $p.localPath $wranglerConfig)
      }
      Write-Host ("{0,-22} ready={1,-5} secrets={2,-5} enabled={3,-5} protected={4,-5} path={5,-5} config={6,-5} {7}" -f $p.name,$p.deployReady,$p.credentialSync,$p.enabled,$p.protected,$pathOk,$configOk,$p.status)
    }
  }
  'DiscoverLocal' {
    $config = Load-Config
    $roots = @($HOME, (Join-Path $HOME 'Documents'), (Join-Path $HOME 'Desktop')) | Where-Object { Test-Path $_ } | Select-Object -Unique
    foreach ($p in $config.projects) {
      if ([string]::IsNullOrWhiteSpace($p.repo)) { continue }
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
    $targets = @($config.projects | Where-Object { $_.credentialSync -and $_.deployReady -and -not [string]::IsNullOrWhiteSpace($_.repo) })
    if ($targets.Count -eq 0) { Fail 'No credential-sync targets are registered.' }
    foreach ($p in $targets) {
      Write-Info "Syncing Cloudflare Actions secrets to $($p.repo)..."
      $token | & gh secret set CLOUDFLARE_API_TOKEN --repo $p.repo
      if ($LASTEXITCODE -ne 0) { Fail "Failed setting CLOUDFLARE_API_TOKEN in $($p.repo)." }
      $token | & gh secret set CLOUDFLARE_DEPLOY_TOKEN --repo $p.repo
      if ($LASTEXITCODE -ne 0) { Fail "Failed setting CLOUDFLARE_DEPLOY_TOKEN in $($p.repo)." }
      $config.cloudflareAccountId | & gh secret set CLOUDFLARE_ACCOUNT_ID --repo $p.repo
      if ($LASTEXITCODE -ne 0) { Fail "Failed setting CLOUDFLARE_ACCOUNT_ID in $($p.repo)." }
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
    $targets = @($config.projects | Where-Object { $_.deployReady -and $_.enabled -and -not $_.protected })
    if ($targets.Count -eq 0) { Fail 'No enabled, unprotected, deploy-ready projects are configured.' }
    Write-Warn 'DeployAll will back up each target, dry-run it, and still require an explicit per-project confirmation.'
    foreach ($p in $targets) { Deploy-Project $config $p }
  }
}
