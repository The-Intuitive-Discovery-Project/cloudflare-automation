param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$StateDir = Join-Path $env:APPDATA 'TinyThorDeploy'
$ConfigPath = Join-Path $StateDir 'config.json'
$SecretPath = Join-Path $StateDir 'cloudflare-token.txt'
$ReferencePath = Join-Path $PSScriptRoot 'projects.reference.json'

function Write-Info($m) { Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m) { throw $m }

if ($env:OS -ne 'Windows_NT') { Fail 'Local TinyThor credential setup is Windows-only.' }
if (-not (Test-Path $ReferencePath)) { Fail "Project registry missing: $ReferencePath" }
if (-not (Get-Command npx.cmd -ErrorAction SilentlyContinue)) { Fail 'Node.js / npx.cmd is required.' }

if ((Test-Path $ConfigPath) -and (Test-Path $SecretPath) -and -not $Force) {
  Fail 'Local TinyThor Cloudflare setup already exists. Run CHECK-STATUS.bat instead. Use -Force only when intentionally replacing the local stored credential.'
}

function ConvertFrom-JsonCompat([string]$Json) {
  $cmd = Get-Command ConvertFrom-Json -ErrorAction Stop
  if ($cmd.Parameters.ContainsKey('Depth')) { return $Json | ConvertFrom-Json -Depth 30 }
  return $Json | ConvertFrom-Json
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
    d1Databases = @($r.d1Databases)
    status = [string]$r.status
    deployReady = [bool]$r.deployReady
    credentialSync = [bool]$r.credentialSync
    enabled = [bool]$r.enabled
    protected = [bool]$r.protected
    localPath = $localPath
    backupCommand = $backupCommand
  }
}

function Select-Account($accounts) {
  $items = @($accounts)
  if ($items.Count -eq 0) { return '' }
  if ($items.Count -eq 1) {
    Write-Ok "Cloudflare account found automatically: $($items[0].name)"
    return [string]$items[0].id
  }

  Write-Host ''
  Write-Info 'More than one Cloudflare account is available to this token.'
  for ($i = 0; $i -lt $items.Count; $i++) {
    Write-Host "  $($i + 1)) $($items[$i].name)"
  }
  $choice = Read-Host 'Enter the number of the account used for Hunter sites'
  $number = 0
  if (-not [int]::TryParse($choice, [ref]$number) -or $number -lt 1 -or $number -gt $items.Count) {
    Fail 'Invalid Cloudflare account selection.'
  }
  return [string]$items[$number - 1].id
}

function Resolve-AccountId([string]$token) {
  Write-Info 'Finding the Cloudflare Account ID automatically...'
  try {
    $headers = @{ Authorization = "Bearer $token" }
    $response = Invoke-RestMethod -Method Get -Uri 'https://api.cloudflare.com/client/v4/accounts?per_page=50' -Headers $headers -TimeoutSec 30
    if ($response.success) {
      $id = Select-Account @($response.result)
      if (-not [string]::IsNullOrWhiteSpace($id)) { return $id }
    }
  }
  catch {
    Write-Warn 'Cloudflare Accounts API did not return the account list; trying Wrangler discovery instead.'
  }

  $oldToken = $env:CLOUDFLARE_API_TOKEN
  $oldAccount = $env:CLOUDFLARE_ACCOUNT_ID
  try {
    $env:CLOUDFLARE_API_TOKEN = $token
    Remove-Item Env:CLOUDFLARE_ACCOUNT_ID -ErrorAction SilentlyContinue
    $output = (& npx.cmd --yes wrangler@latest whoami 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
      $ids = @([regex]::Matches($output, '(?i)\b[a-f0-9]{32}\b') | ForEach-Object { $_.Value.ToLowerInvariant() } | Select-Object -Unique)
      if ($ids.Count -eq 1) {
        Write-Ok 'Cloudflare Account ID discovered automatically with Wrangler.'
        return [string]$ids[0]
      }
      if ($ids.Count -gt 1) {
        Write-Host $output
        Write-Warn 'Wrangler found more than one account ID. The account list above is from Cloudflare.'
        $choice = Read-Host 'Paste the Account ID for the account used by Hunter sites'
        if ($choice -in $ids) { return [string]$choice }
        Fail 'The selected Account ID was not one of the IDs returned by Wrangler.'
      }
    }
  }
  finally {
    $env:CLOUDFLARE_API_TOKEN = $oldToken
    $env:CLOUDFLARE_ACCOUNT_ID = $oldAccount
  }

  Fail 'The Account ID could not be discovered automatically from the existing token. No local credential was stored.'
}

Write-Host ''
Write-Host '=== Connect Existing Cloudflare Token ===' -ForegroundColor Cyan
Write-Host 'Use the Cloudflare token that was already created. Do not create another token.' -ForegroundColor Yellow
Write-Host 'The token entry is hidden and is not written to this repository.' -ForegroundColor Gray
Write-Host ''

$secureToken = Read-Host 'Existing Cloudflare API token' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
$plainToken = ''
try { $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
if ([string]::IsNullOrWhiteSpace($plainToken)) { Fail 'Token cannot be blank.' }

$accountId = Resolve-AccountId $plainToken
if ([string]::IsNullOrWhiteSpace($accountId)) { Fail 'Cloudflare Account ID discovery returned blank.' }

Write-Info 'Verifying the existing token with Wrangler...'
$oldToken = $env:CLOUDFLARE_API_TOKEN
$oldAccount = $env:CLOUDFLARE_ACCOUNT_ID
try {
  $env:CLOUDFLARE_API_TOKEN = $plainToken
  $env:CLOUDFLARE_ACCOUNT_ID = $accountId
  & npx.cmd --yes wrangler@latest whoami
  if ($LASTEXITCODE -ne 0) { Fail 'Cloudflare credential verification failed. Nothing was stored.' }
}
finally {
  $env:CLOUDFLARE_API_TOKEN = $oldToken
  $env:CLOUDFLARE_ACCOUNT_ID = $oldAccount
}

$existingConfig = $null
if (Test-Path $ConfigPath) {
  try { $existingConfig = ConvertFrom-JsonCompat (Get-Content $ConfigPath -Raw) } catch { $existingConfig = $null }
}

$reference = ConvertFrom-JsonCompat (Get-Content $ReferencePath -Raw)
$projects = @()
foreach ($r in @($reference.projects)) {
  $old = $null
  if ($existingConfig) {
    $matches = @($existingConfig.projects | Where-Object { $_.name -eq $r.name })
    if ($matches.Count -eq 1) { $old = $matches[0] }
  }
  $projects += New-ProjectFromReference $r $old
}

if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }
$secureToken | ConvertFrom-SecureString | Set-Content -Path $SecretPath -Encoding UTF8
$config = [pscustomobject]@{
  version = [int]$reference.version
  cloudflareAccountId = $accountId
  projects = $projects
}
$config | ConvertTo-Json -Depth 30 | Set-Content -Path $ConfigPath -Encoding UTF8
$plainToken = $null

Write-Ok 'Local setup completed.'
Write-Ok 'Existing Cloudflare token is encrypted with Windows DPAPI for this Windows user.'
Write-Ok 'Cloudflare Account ID was discovered and stored locally.'
Write-Host 'No website was deployed and no GitHub secret was changed.' -ForegroundColor Cyan
