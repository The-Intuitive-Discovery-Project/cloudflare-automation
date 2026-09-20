# Unified Cloudflare Deployment Manager

Work branch: `feature/unified-cloudflare-deploy-manager-2026-09-19`

This work adds the safe Cloudflare credential/deployment setup for Hunter's website projects. The PowerShell manager stays separate from production sites until it is reviewed and tested.

## Current credential state

Hunter has already created the Cloudflare automation/deployment token. **Do not create another token** unless the existing token is intentionally rotated or its permissions prove insufficient.

Some existing GitHub workflows already use the secret name `CLOUDFLARE_DEPLOY_TOKEN`. In particular, Intuition and business-site safe-preview workflows use that secret for Cloudflare Pages preview operations. Because those workflows can need broader permissions than ordinary Worker backup/deploy operations, the unified manager now **preserves an existing `CLOUDFLARE_DEPLOY_TOKEN` instead of overwriting it automatically**.

The unified token is synced as `CLOUDFLARE_API_TOKEN` plus `CLOUDFLARE_ACCOUNT_ID`. The deploy-token alias is changed only when `SyncGitHubSecrets -IncludeDeployAlias` is explicitly used after its permissions are verified.

The token itself must never be committed here.

## Safety model

- Back up before any deployment.
- For registered D1-backed Workers, export the remote D1 databases read-only before deployment, verify the export is non-empty, and record a SHA-256 hash.
- Never commit Cloudflare tokens, passwords, or private credentials.
- Store the local Cloudflare token with Windows DPAPI for the current Windows user.
- Send GitHub Actions secrets through `gh secret set` standard input instead of putting secrets on a command line or in a repo file.
- Preserve existing `CLOUDFLARE_DEPLOY_TOKEN` secrets unless an explicit alias update is requested after permission review.
- Require explicit confirmation before deployment.
- `DeployAll` skips protected, disabled, and non-deploy-ready projects.
- Only repositories explicitly marked `credentialSync=true` and `deployReady=true` receive the unified API token.
- Central Admin receives credentials for its backup/automation workflows but deployment through this manager is disabled until complete All-in-One backup coverage is verified.
- Marketplace, TinyThor links, the test site, and empty/planned repositories fail closed until their authoritative deployment source is verified.
- Unknown/new projects start disabled and protected.

## Verified Worker sources

- `intuition` -> repo `The-Intuitive-Discovery-Project/intuition.tinythor.cc` -> Worker `intuition-v2` -> deploy enabled
- `business-site` -> repo `The-Intuitive-Discovery-Project/huntersintuitiveguidance.com` -> Worker `hunters-intuitive-guidance` -> deploy enabled
- `central-admin` -> repo `The-Intuitive-Discovery-Project/central-admin` -> Worker `central-admin` -> credential sync allowed, deployment disabled/protected pending complete backup coverage

## Registered but intentionally not deployable

- `intuition-test-site` -> source exists, deployment target not yet verified
- `marketplace` -> current repository is documentation/planning only; no deployable app source is present
- `tinythor-links` -> rebuild foundation only; authoritative live Worker source is not backed up in the repository yet
- `hunters-classes` -> repository has no usable application source yet
- image generator -> add as an isolated project after its repository and Worker identity are finalized

See `DEPLOYMENT-INVENTORY.md` for the current evidence-based inventory and `TOKEN-PERMISSIONS.md` for the permission audit reference for the existing Cloudflare token.

## PowerShell actions

`Setup`, `RefreshRegistry`, `Audit`, `List`, `DiscoverLocal`, `SetLocalPath`, `Backup`, `SyncGitHubSecrets`, `Deploy`, and `DeployAll`.

`Setup` is only for connecting/verifying the existing Cloudflare token on a Windows account that does not already have the local DPAPI-encrypted TinyThor credential. It refuses to replace an existing local setup unless `Setup -Force` is deliberately used. A forced credential replacement preserves known local project paths.

`Backup` creates a Git bundle snapshot and, for registered D1-backed Workers, exports the listed remote databases before deployment. A failed or empty D1 export blocks deployment.

`SyncGitHubSecrets` sends the unified token only to verified deployment repositories. By default it writes `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` and leaves any existing `CLOUDFLARE_DEPLOY_TOKEN` unchanged. Use `SyncGitHubSecrets -IncludeDeployAlias` only when intentionally making the unified token serve the preview/deploy alias too, after confirming it has every permission those workflows require.

`CHECK-STATUS.bat` is the read-only first step: it checks local setup, Cloudflare token verification, project paths, GitHub login, and expected secret names without changing secrets or deploying anything.

Production Worker deployment remains source/data backup -> Wrangler dry-run -> exact typed confirmation -> deploy. Unsupported, disabled, protected, or unverified targets fail closed.
