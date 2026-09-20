# Unified Cloudflare Deployment Manager

Work branch: `feature/unified-cloudflare-deploy-manager-2026-09-19`

This work adds the safe one-time Cloudflare credential/deployment setup for Hunter's website projects. The PowerShell manager stays separate from production sites until it is reviewed and tested.

## Safety model

- Back up before any deployment.
- Never commit Cloudflare tokens, passwords, or private credentials.
- Store the local Cloudflare token with Windows DPAPI for the current Windows user.
- Send GitHub Actions secrets through `gh secret set` standard input instead of putting secrets on a command line or in a repo file.
- Require explicit confirmation before deployment.
- `DeployAll` skips protected and non-deploy-ready projects.
- Only repositories explicitly marked `credentialSync=true` and `deployReady=true` receive the shared Cloudflare token.
- Central Admin stays protected.
- Marketplace, TinyThor links, the test site, and empty/planned repositories fail closed until their authoritative deployment source is verified.
- Unknown/new projects start disabled and protected.

## Verified deployable targets

- `intuition` -> repo `The-Intuitive-Discovery-Project/intuition.tinythor.cc` -> Worker `intuition-v2`
- `business-site` -> repo `The-Intuitive-Discovery-Project/huntersintuitiveguidance.com` -> Worker `hunters-intuitive-guidance`
- `central-admin` -> repo `The-Intuitive-Discovery-Project/central-admin` -> Worker `central-admin` (protected)

## Registered but intentionally not deployable

- `intuition-test-site` -> source exists, deployment target not yet verified
- `marketplace` -> current repository is documentation/planning only; no deployable app source is present
- `tinythor-links` -> rebuild foundation only; authoritative live Worker source is not backed up in the repository yet
- `hunters-classes` -> repository has no usable application source yet
- image generator -> add as an isolated project after its repository and Worker identity are finalized

See `DEPLOYMENT-INVENTORY.md` for the current evidence-based inventory.

## PowerShell actions

`Setup`, `RefreshRegistry`, `Audit`, `List`, `DiscoverLocal`, `SetLocalPath`, `Backup`, `SyncGitHubSecrets`, `Deploy`, and `DeployAll`.

The one-time `Setup` asks for the Cloudflare Account ID and deployment API token, verifies the token, and encrypts it locally. `RefreshRegistry` can later add or change registered projects without asking for the Cloudflare token again and without erasing saved local paths.

`SyncGitHubSecrets` sends the token only to verified deployment repositories. It writes both `CLOUDFLARE_API_TOKEN` and the compatibility alias `CLOUDFLARE_DEPLOY_TOKEN`, plus `CLOUDFLARE_ACCOUNT_ID`, so existing workflows can keep working while secret names are standardized gradually.

Production Worker deployment remains backup -> Wrangler dry-run -> exact typed confirmation -> deploy. Unsupported or unverified deployment types fail closed.
