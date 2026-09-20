# Current automation state

Updated: 2026-09-20

## Cloudflare credential

- Hunter has **already created** the Cloudflare automation/deployment token.
- Do **not** ask Hunter to create another Cloudflare token unless the current token is intentionally being rotated or a permission audit proves it cannot perform a required operation.
- Existing safe-preview workflows already use the GitHub secret name `CLOUDFLARE_DEPLOY_TOKEN`.
- Intuition and business-site safe previews use that deploy-token secret for Cloudflare Pages preview operations, so it must not be overwritten casually.
- Normal `SyncGitHubSecrets` now writes/updates `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` while preserving any existing `CLOUDFLARE_DEPLOY_TOKEN`.
- The deploy alias changes only when `SyncGitHubSecrets -IncludeDeployAlias` is explicitly requested after permission verification.
- The token value must never be committed to GitHub or written into documentation.

## What may still need verification

Creation of the Cloudflare token and local TinyThor setup are separate states. The token already exists, but a particular Windows account may or may not already have the DPAPI-encrypted local copy under `%APPDATA%\TinyThorDeploy`.

`CHECK-STATUS.bat` is the first step and is read-only. It checks whether the local encrypted credential/config exist, whether the existing Cloudflare token verifies, whether local project paths are known, and whether expected GitHub secret names are present. It does not change secrets or deploy anything.

`Bootstrap.ps1 -FullSetup` checks for the local encrypted setup. If it already exists, token entry is skipped. If it does not exist, Hunter may be asked to enter the **existing token once** so it can be verified and encrypted locally. That does not mean a new Cloudflare token should be created.

Cross-repository secret sync should be audited rather than assumed. The goal is safe reuse of the existing credential, not creation of multiple new tokens or accidental replacement of a working preview credential.

## Deployment safety

- No production site is deployed by `CHECK-STATUS.bat`, `START-HERE.bat`, or Bootstrap.
- Production deployment remains backup -> D1 export/verification where registered -> Wrangler dry-run -> exact typed confirmation -> deploy.
- Central Admin remains deployment-disabled/protected in the unified manager.
- Unverified projects remain disabled and do not receive the unified API token.
