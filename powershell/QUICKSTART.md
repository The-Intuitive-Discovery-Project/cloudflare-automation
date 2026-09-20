# Quick start

## Current state

Hunter has already created the Cloudflare deployment token. **Do not create another token** unless the existing token is being intentionally rotated or its permissions prove insufficient.

The remaining setup is only about verifying/reusing that existing token locally and syncing it to approved GitHub repositories when needed.

## Check what is already done first

Double-click:

`CHECK-STATUS.bat`

That performs a read-only status check. It reports whether the encrypted local token/config exist, whether the existing Cloudflare credential verifies, whether local project paths are known, and whether the expected GitHub Actions secret **names** are present in approved repositories. It never prints secret values, never changes secrets, and never deploys a website.

## Repair/finish setup only if the status check finds a gap

Use either of these:

- Double-click `START-HERE.bat`
- Or open PowerShell in this folder and run:

```powershell
.\Bootstrap.ps1 -FullSetup
```

If the encrypted local TinyThor deployment credential is already present, FullSetup reuses it instead of asking for the token again. If the local credential has never been stored on this Windows account, Setup may ask for the **existing** Cloudflare token once so it can encrypt it locally with Windows DPAPI. That is not a request to create a new Cloudflare token.

The full setup checks for PowerShell 7, Git, Node.js, and GitHub CLI; installs missing tools through Windows Package Manager when possible; checks GitHub CLI login; refreshes the verified project registry; discovers local project folders; audits the configuration; and syncs the approved Cloudflare credential to verified GitHub repositories.

It does **not** deploy a production website.

The Cloudflare token is never written into this repository. The local copy is encrypted for the current Windows user, and GitHub receives it only as repository secrets for projects explicitly marked deploy-ready and credential-sync approved.

## First safe backup test after setup

Run:

```powershell
.\TinyThorDeploy.ps1 Backup -Project intuition
```

That creates a source snapshot and exports every D1 database registered for the Intuition Worker. Each export must exist and be non-empty, and a SHA-256 verification record is written. Any backup failure stops the process.

When a deployment is requested later, `Deploy` repeats the required backup, performs a Wrangler dry-run, and then asks for the exact confirmation phrase before touching production. `DeployAll` skips protected, disabled, and non-deploy-ready targets.

Central Admin can receive the approved credential for backup/automation use, but deployment through this manager stays disabled until complete All-in-One backup coverage is verified. Marketplace, TinyThor links, the test site, and other unverified/planned repositories remain disabled until their authoritative deployment source is confirmed.

`TOKEN-PERMISSIONS.md` is a reference for auditing the existing token or for a future intentional rotation; it is not an instruction to create another token now.
