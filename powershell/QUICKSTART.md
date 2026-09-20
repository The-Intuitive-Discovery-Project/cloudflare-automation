# Quick start

This is intentionally a one-time credential setup followed by simple commands.

1. Open PowerShell in the `powershell` folder.
2. Run `./TinyThorDeploy.ps1 Setup` and enter the Cloudflare Account ID and deployment token once.
3. Run `./TinyThorDeploy.ps1 RefreshRegistry` whenever the shared project registry changes later; this does not ask for the token again.
4. Run `./TinyThorDeploy.ps1 DiscoverLocal`.
5. Run `./TinyThorDeploy.ps1 Audit`.
6. Run `./TinyThorDeploy.ps1 SyncGitHubSecrets` after GitHub CLI is signed in.
7. Deploy one verified safe target with `./TinyThorDeploy.ps1 Deploy -Project intuition`.

`Deploy` creates a local pre-deploy backup and performs a Wrangler dry-run before asking for the exact confirmation phrase. `DeployAll` skips protected, disabled, and non-deploy-ready targets.

Only verified deployment repositories receive the shared Cloudflare token. Central Admin remains protected by default. Marketplace, TinyThor links, the test site, and other unverified/planned repositories remain disabled until their authoritative deployment source is confirmed.
