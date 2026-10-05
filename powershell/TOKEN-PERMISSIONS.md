# Cloudflare automation token permissions

Verified against Cloudflare documentation on 2026-09-20.

## Current state — token already exists

Hunter has already created the Cloudflare automation/deployment token. This file is a **permission reference/audit checklist**, not an instruction to create another token. Do not create a replacement token unless the existing token is intentionally being rotated or a required permission is missing.

There is also an important compatibility rule: existing Intuition and business-site safe-preview workflows use the GitHub secret name `CLOUDFLARE_DEPLOY_TOKEN` for Cloudflare Pages preview work. The unified manager therefore preserves existing GitHub Cloudflare secret values by default instead of blindly replacing them.

## Required for the unified API token

### Workers

For the current verified Workers, grant **Workers product -> Editor** if the token only needs to update/deploy Workers that already exist.

If the same existing token should also create brand-new Workers later (for example, the isolated image-generator Worker), **Workers product -> Admin** is required. The current manager does not delete Workers.

### D1 backups

Grant **D1 -> Content Read-Only** in the current Developer Platform role model so the manager can export registered databases before deployment.

D1 Write/Edit is not required for the manager's backup flow and should not be granted merely for backups. Any failed or empty export blocks deployment.

### Workers KV backup compatibility

Central Admin's complete All-in-One backup also needs read access to its private KV data. Grant **KV -> Content Read-Only** when that backup is enabled with the unified token.

Do not grant KV write access just to perform backups.

## Additional permissions only when the same token actually performs these jobs

### Routes / Custom Domains

If a deployment is allowed to add, change, or remove a Worker Route or Custom Domain, the token needs the appropriate route/custom-domain permission for the affected zone. The currently enabled Intuition and business-site deployments should not receive route-changing power unless a verified deployment path actually requires it. Central Admin remains deployment-disabled in this manager for now.

### Pages / safe previews

The existing Intuition and business-site safe-preview workflows use `CLOUDFLARE_DEPLOY_TOKEN` to verify/create the dedicated preview Pages project and deploy isolated Pages previews. Therefore, **do not replace an existing `CLOUDFLARE_DEPLOY_TOKEN` with the unified token unless the unified token has the Pages permissions those workflows require**.

Marketplace is not currently a verified Pages deployment target in this manager.

## Safe target profile

For the unified API token used directly by this manager:

- Workers product: **Admin** if future isolated Workers should be creatable; otherwise Editor is enough for existing Workers
- D1 product: **Content Read-Only** / D1 Read
- KV product: **Content Read-Only** / Workers KV Storage Read when Central Admin backup coverage uses this token
- Route/custom-domain write: do not add until a verified project actually needs it
- Pages permissions: needed only if this same token will intentionally replace the existing deploy-token alias used by safe previews

This keeps database and KV backup access read-only and avoids granting unrelated write capabilities just for convenience.

## GitHub secret names and preservation rule

Normal `SyncGitHubSecrets` is **missing-only**. For each approved repository it checks the existing GitHub Actions secret names first:

- if `CLOUDFLARE_API_TOKEN` is missing, it adds the unified token; otherwise it preserves the existing value
- if `CLOUDFLARE_ACCOUNT_ID` is missing, it adds the account ID; otherwise it preserves the existing value
- it never creates or replaces `CLOUDFLARE_DEPLOY_TOKEN` by default

Intentional replacement options are:

```powershell
# Replace existing API-token/account-ID values, but leave the deploy alias alone
.\TinyThorDeploy.ps1 SyncGitHubSecrets -Force

# Create a missing deploy alias after permission verification
.\TinyThorDeploy.ps1 SyncGitHubSecrets -IncludeDeployAlias

# Intentionally replace an existing deploy alias after permission verification
.\TinyThorDeploy.ps1 SyncGitHubSecrets -IncludeDeployAlias -Force
```

The token value itself is never committed to a repository.
