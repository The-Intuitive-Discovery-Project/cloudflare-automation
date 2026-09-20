# Deployment inventory

Audited: 2026-09-20

This file records only deployment facts verified from the current GitHub repositories. Unknown targets stay disabled and do not receive the shared Cloudflare deployment token.

## Verified Worker sources

### Intuition
- Repository: `The-Intuitive-Discovery-Project/intuition.tinythor.cc`
- Wrangler config: `wrangler.jsonc`
- Worker name: `intuition-v2`
- Registered pre-deploy D1 backup: `intuition-progress`
- Existing safe-preview workflow already uses `CLOUDFLARE_DEPLOY_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
- Registry state: deploy-ready, enabled, credential sync allowed.

### Hunter's Intuitive Guidance / Articles
- Repository: `The-Intuitive-Discovery-Project/huntersintuitiveguidance.com`
- Wrangler config: `wrangler.jsonc`
- Worker name: `hunters-intuitive-guidance`
- Registered pre-deploy D1 backups: `hunters-articles`, `hunter-business-analytics`.
- Repository contains Cloudflare deployment/maintenance workflows and a safe-preview workflow.
- Registry state: deploy-ready, enabled, credential sync allowed.

### Central Admin
- Repository: `The-Intuitive-Discovery-Project/central-admin`
- Wrangler config: `wrangler.jsonc`
- Worker name: `central-admin`
- Worker source is verified and credential sync is allowed so its backup/automation workflows can use the unified token.
- Known D1 bindings include `intuition-progress`, `tinythor-links`, `hunters-articles`, and `hunter-business-analytics`.
- Its complete All-in-One backup additionally includes Marketplace data/private KV that is not yet represented by the generic deploy-manager backup registry.
- Registry state: protected **and disabled for deployment** until complete All-in-One backup coverage is verified. `-Force` does not bypass the disabled flag.
- The repository's dedicated production deployment workflow remains separate and guarded.

## Present but not deploy-ready

### Intuition test site
- Repository: `The-Intuitive-Discovery-Project/intuition-test-site`
- Static test content is present.
- No Wrangler production configuration was found in the audited source.
- Registry state: protected, disabled, no shared token sync until a deployment target is deliberately verified.

### Marketplace
- Repository: `The-Intuitive-Discovery-Project/marketplace`
- Current repository is documentation/planning plus local utility scripts; no deployable application source or Wrangler configuration is present.
- The repository's own status file says the existing application source still needs to be audited before implementation continues.
- Registry state: protected, disabled, no shared token sync.

### TinyThor links
- Repository: `The-Intuitive-Discovery-Project/links`
- Current repository contains only rebuild documentation and ignore rules.
- Its README explicitly says the authoritative live Worker source/database structure is not stored there yet.
- Registry state: protected, disabled, no shared token sync. Back up the live Worker/source before any replacement work.

### Hunter's classes
- Repository: `The-Intuitive-Discovery-Project/hunters-classes`
- Repository currently has no usable application source.
- Registry state: protected, disabled, no shared token sync.

## Backup rule

For an enabled Worker with registered D1 databases, `Backup` and `Deploy` first create a Git source bundle and export every listed remote D1 database. Each SQL export must be non-empty and gets SHA-256 verification metadata. A failed export blocks deployment.

This generic D1 protection is sufficient for Intuition and the business site based on their currently verified bindings. Central Admin remains deployment-disabled because its broader All-in-One backup contract includes additional Marketplace/KV data.

## Credential rule

`SyncGitHubSecrets` only sends the Cloudflare token to projects marked both `deployReady=true` and `credentialSync=true`. It writes both `CLOUDFLARE_API_TOKEN` and the compatibility alias `CLOUDFLARE_DEPLOY_TOKEN`, plus `CLOUDFLARE_ACCOUNT_ID`, so existing workflows can keep working while the repositories are standardized gradually.

See `TOKEN-PERMISSIONS.md` for the current least-privilege token plan.

## Next safe targets

1. Finish the one-time Cloudflare token setup on Hunter's Windows PC.
2. Run `RefreshRegistry`, `DiscoverLocal`, and `Audit`.
3. Sync credentials only to the verified Worker repositories.
4. Manually test `Backup -Project intuition` before the first managed deployment.
5. Verify the business-site backup the same way.
6. Leave Central Admin deployment disabled until the manager can reproduce its complete All-in-One backup contract.
7. Add the image generator as a new isolated project only after its repository/Worker identity is finalized.
