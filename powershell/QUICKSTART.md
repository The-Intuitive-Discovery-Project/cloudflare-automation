# Quick start

This is intentionally a one-time credential setup followed by simple commands.

1. Open PowerShell in the `powershell` folder.
2. Create the Cloudflare automation token with the permissions documented in `TOKEN-PERMISSIONS.md`.
3. Run `./TinyThorDeploy.ps1 Setup` and enter the Cloudflare Account ID and deployment token once.
4. Run `./TinyThorDeploy.ps1 RefreshRegistry` whenever the shared project registry changes later; this does not ask for the token again.
5. Run `./TinyThorDeploy.ps1 DiscoverLocal`.
6. Run `./TinyThorDeploy.ps1 Audit`.
7. Run `./TinyThorDeploy.ps1 SyncGitHubSecrets` after GitHub CLI is signed in.
8. Test the backup path first with `./TinyThorDeploy.ps1 Backup -Project intuition`.
9. Deploy one verified safe target with `./TinyThorDeploy.ps1 Deploy -Project intuition`.

`Backup` creates a source snapshot and exports every D1 database registered for that Worker. Each D1 export must exist and be non-empty, and a SHA-256 verification record is written. A backup failure stops the process.

`Deploy` repeats the required backup, performs a Wrangler dry-run, and then asks for the exact confirmation phrase. `DeployAll` skips protected, disabled, and non-deploy-ready targets.

Only verified deployment repositories receive the shared Cloudflare token. Central Admin receives the credential for backup/automation use, but deployment through this manager is disabled until complete All-in-One backup coverage is verified. Marketplace, TinyThor links, the test site, and other unverified/planned repositories remain disabled until their authoritative deployment source is confirmed.
