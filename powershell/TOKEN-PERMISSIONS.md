# Cloudflare automation token permissions

Verified against Cloudflare documentation on 2026-09-20.

## Current state — token already exists

Hunter has already created the Cloudflare deployment token. This file is now a **permission reference/audit checklist**, not an instruction to create another token. Do not create a replacement token unless the existing token is intentionally being rotated or a required permission is missing.

The deployment manager is designed around one account-owned Cloudflare API token. Keep the existing token narrow enough to avoid unnecessary write access, but broad enough to perform the operations the manager actually uses.

## Required now

### Workers

For the current verified Workers, grant **Workers product -> Editor** if the token only needs to update/deploy Workers that already exist.

If the same existing token should also create brand-new Workers later (for example, the isolated image-generator Worker), **Workers product -> Admin** is required. Cloudflare currently requires product-level Admin to create a new Worker; Editor can deploy/update existing Workers but cannot create or delete them.

The current manager does not delete Workers.

### D1 backups

Grant **D1 -> Content Read-Only** in the current Developer Platform role model so the manager can export registered databases before deployment.

Cloudflare's D1 HTTP API documents this underlying permission as **D1 Read**. D1 Write/Edit is not required for the manager's backup flow and should not be granted merely for backups.

The manager only calls read/export operations during its pre-deploy backup step. Any failed or empty export blocks deployment.

### Workers KV backup compatibility

Central Admin's complete All-in-One backup also needs read access to its private KV data. Grant **KV -> Content Read-Only** when that backup is enabled with the unified token. Cloudflare's KV HTTP API calls the underlying accepted permission **Workers KV Storage Read**.

Do not grant KV write access just to perform backups.

## Only when needed

### Routes / Custom Domains

If a deployment is allowed to add, change, or remove a Worker Route or Custom Domain, Cloudflare requires the Worker permission plus **Workers Routes Write** on every affected zone.

The currently enabled Intuition and business-site deployments should not be given zone-route power unless their verified Wrangler configuration actually needs to change a route. Central Admin remains deployment-disabled in this manager for now.

### Pages

Cloudflare Pages uses Pages-specific API-token roles. Grant **Pages Write** only when a verified Pages project is intentionally added to this manager. Marketplace is not currently a verified Pages deployment target and receives no token from this manager.

## Target permission profile for the existing token

For the single durable token used by Hunter's automation, the target permissions are:

- Workers product: **Admin** if future isolated Workers should be creatable; otherwise Editor is enough for existing Workers
- D1 product: **Content Read-Only** / D1 Read
- KV product: **Content Read-Only** / Workers KV Storage Read
- Workers Routes Write: **do not add until a verified project actually needs route/custom-domain changes**
- Pages Write: **do not add until a verified Pages project is registered**

This keeps database and KV backup access read-only and avoids unnecessary route, D1-write, KV-write, or Pages permissions.

## GitHub secret names

After local Setup/verification, `SyncGitHubSecrets` stores the same existing Cloudflare token under both names below for compatibility with existing workflows:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_DEPLOY_TOKEN`

It also stores the non-secret Cloudflare account identifier as:

- `CLOUDFLARE_ACCOUNT_ID`

The token value itself is never committed to a repository.
