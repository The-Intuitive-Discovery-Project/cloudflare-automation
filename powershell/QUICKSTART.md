# Quick start

This is intentionally a one-time setup followed by simple commands.

1. Open PowerShell in the `powershell` folder.
2. Run `./TinyThorDeploy.ps1 Setup` and enter the Cloudflare Account ID and deployment token once.
3. Run `./TinyThorDeploy.ps1 DiscoverLocal`.
4. Run `./TinyThorDeploy.ps1 Audit`.
5. Run `./TinyThorDeploy.ps1 SyncGitHubSecrets` after GitHub CLI is signed in.
6. Deploy one safe target with `./TinyThorDeploy.ps1 Deploy -Project intuition`.

`Deploy` creates a local pre-deploy backup and performs a Wrangler dry-run before asking for the exact confirmation phrase. `DeployAll` skips protected targets. Central Admin remains protected by default. Marketplace remains disabled until its exact Cloudflare Pages settings are verified.
