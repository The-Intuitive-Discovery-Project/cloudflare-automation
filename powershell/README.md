# Unified Cloudflare Deployment Manager

Work branch: `feature/unified-cloudflare-deploy-manager-2026-09-19`

This work adds the safe one-time Cloudflare credential/deployment setup for Hunter's website projects. The first PowerShell build is being kept separate from production sites while it is tested.

## Safety model

- Back up before any deployment.
- Never commit Cloudflare tokens, passwords, or private credentials.
- Store the local Cloudflare token with Windows DPAPI for the current Windows user.
- Send GitHub Actions secrets through `gh secret set` standard input instead of putting secrets on a command line or in a repo file.
- Require explicit confirmation before deployment.
- `DeployAll` must skip protected projects.
- Central Admin stays protected while other work is in progress.
- Marketplace stays protected/disabled until its known-good Cloudflare Pages build/output settings are verified; do not fall back to the previously failing Workers deployment path.
- Unknown/new projects start disabled and protected.

## Registered targets

- `intuition` -> repo `The-Intuitive-Discovery-Project/intuition.tinythor.cc` -> Worker `intuition-v2`
- `business-site` -> repo `The-Intuitive-Discovery-Project/huntersintuitiveguidance.com` -> Worker `hunters-intuitive-guidance`
- `central-admin` -> repo `The-Intuitive-Discovery-Project/central-admin` -> Worker `central-admin` (protected)
- `marketplace` -> repo `The-Intuitive-Discovery-Project/marketplace` -> Pages project `classes-guides-preview` (protected/disabled pending verification)
- `tinythor-links` -> repo `The-Intuitive-Discovery-Project/links` -> deployment target still needs verification
- image generator -> reserved placeholder until its repository and Worker name are finalized

## Planned/implemented PowerShell actions

`Setup`, `Audit`, `List`, `DiscoverLocal`, `SetLocalPath`, `Backup`, `SyncGitHubSecrets`, `Deploy`, and `DeployAll`.

The one-time Setup asks for the Cloudflare Account ID and deployment API token, verifies the token, and encrypts it locally. GitHub secret sync then places `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` into registered repos so future CI/CD deployment does not require repeatedly copying credentials.

Cloudflare account-owned API tokens are the preferred durable CI/CD credential. Wrangler can authenticate with `CLOUDFLARE_API_TOKEN` plus `CLOUDFLARE_ACCOUNT_ID`. Existing Worker deployment can use Workers Editor access; creating a new Worker requires Workers Admin. Route/custom-domain changes additionally require Workers Routes permission for the affected zone. Pages deployment requires Pages Write.
