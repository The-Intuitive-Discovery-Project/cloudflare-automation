# Current automation state

Updated: 2026-09-20

## Cloudflare credential

- Hunter has **already created** the Cloudflare deployment token.
- Do **not** ask Hunter to create another Cloudflare token unless the current token is intentionally being rotated or a permission audit proves it cannot perform a required operation.
- Central Admin's restricted Cloudflare workflow is already wired to the GitHub secret name `CLOUDFLARE_DEPLOY_TOKEN` plus `CLOUDFLARE_ACCOUNT_ID`.
- The unified manager also supports `CLOUDFLARE_API_TOKEN`; `SyncGitHubSecrets` writes both token names for compatibility.
- The token value must never be committed to GitHub or written into documentation.

## What may still need verification

Creation of the Cloudflare token and local TinyThor setup are separate states. The token already exists, but a particular Windows account may or may not already have the DPAPI-encrypted local copy under `%APPDATA%\TinyThorDeploy`.

`Bootstrap.ps1 -FullSetup` now checks for that local encrypted setup. If it already exists, token entry is skipped. If it does not exist, Hunter may be asked to enter the **existing token once** so it can be verified and encrypted locally. That does not mean a new Cloudflare token should be created.

Cross-repository secret sync should be audited rather than assumed. The goal is one existing Cloudflare token reused through approved GitHub secrets, not multiple new tokens.

## Deployment safety

- No production site is deployed by `START-HERE.bat` or Bootstrap.
- Production deployment remains backup -> D1 export/verification where registered -> Wrangler dry-run -> exact typed confirmation -> deploy.
- Central Admin remains deployment-disabled/protected in the unified manager.
- Unverified projects remain disabled and do not receive the shared token.
