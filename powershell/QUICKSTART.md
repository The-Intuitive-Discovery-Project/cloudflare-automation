# Quick start

This is intentionally a one-time credential setup followed by simple commands.

## Easiest Windows setup

After the Cloudflare token is created, open PowerShell in the `powershell` folder and run:

```powershell
.\Bootstrap.ps1 -InstallMissing -LoginGitHub -RunSetup
```

That checks Git/Node/GitHub CLI, can install missing prerequisites through Windows Package Manager, starts the normal GitHub CLI login when needed, and then launches the one-time Cloudflare setup. It does not create the Cloudflare token for you and never writes that token into the repository.

## After setup

1. Run `./TinyThorDeploy.ps1 RefreshRegistry` whenever the shared project registry changes later; this does not ask for the token again.
2. Run `./TinyThorDeploy.ps1 DiscoverLocal`.
3. Run `./TinyThorDeploy.ps1 Audit`.
4. Run `./TinyThorDeploy.ps1 SyncGitHubSecrets`.
5. Test the backup path first with `./TinyThorDeploy.ps1 Backup -Project intuition`.
6. Deploy one verified safe target with `./TinyThorDeploy.ps1 Deploy -Project intuition`.

`Backup` creates a source snapshot and exports every D1 database registered for that Worker. Each D1 export must exist and be non-empty, and a SHA-256 verification record is written. A backup failure stops the process.

`Deploy` repeats the required backup, performs a Wrangler dry-run, and then asks for the exact confirmation phrase. `DeployAll` skips protected, disabled, and non-deploy-ready targets.

Only verified deployment repositories receive the shared Cloudflare token. Central Admin receives the credential for backup/automation use, but deployment through this manager is disabled until complete All-in-One backup coverage is verified. Marketplace, TinyThor links, the test site, and other unverified/planned repositories remain disabled until their authoritative deployment source is confirmed.

See `TOKEN-PERMISSIONS.md` before creating the Cloudflare token.
