# Quick start

This is intentionally a one-time credential setup followed by simple commands.

## Easiest Windows setup

After the Cloudflare token is created, use either of these:

- Double-click `START-HERE.bat`
- Or open PowerShell in this folder and run:

```powershell
.\Bootstrap.ps1 -FullSetup
```

The full setup checks for PowerShell 7, Git, Node.js, and GitHub CLI; installs missing tools through Windows Package Manager when possible; starts the normal GitHub CLI login if needed; launches the one-time Cloudflare credential setup; refreshes the verified project registry; discovers local project folders; audits the configuration; and syncs the approved Cloudflare credential to verified GitHub repositories.

It does **not** deploy a production website.

The Cloudflare token is never written into this repository. The local copy is encrypted for the current Windows user, and GitHub receives it only as repository secrets for projects explicitly marked deploy-ready and credential-sync approved.

## First safe test after setup

Run:

```powershell
.\TinyThorDeploy.ps1 Backup -Project intuition
```

That creates a source snapshot and exports every D1 database registered for the Intuition Worker. Each export must exist and be non-empty, and a SHA-256 verification record is written. Any backup failure stops the process.

When a deployment is requested later, `Deploy` repeats the required backup, performs a Wrangler dry-run, and then asks for the exact confirmation phrase before touching production. `DeployAll` skips protected, disabled, and non-deploy-ready targets.

Central Admin can receive the approved credential for backup/automation use, but deployment through this manager stays disabled until complete All-in-One backup coverage is verified. Marketplace, TinyThor links, the test site, and other unverified/planned repositories remain disabled until their authoritative deployment source is confirmed.

See `TOKEN-PERMISSIONS.md` before creating the Cloudflare token.
