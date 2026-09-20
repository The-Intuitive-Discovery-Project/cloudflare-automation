# Deployment inventory

Audited: 2026-09-20

This file records only deployment facts verified from the current GitHub repositories. Unknown targets stay disabled and do not receive the shared Cloudflare deployment token.

## Verified deployable Workers

### Intuition
- Repository: `The-Intuitive-Discovery-Project/intuition.tinythor.cc`
- Wrangler config: `wrangler.jsonc`
- Worker name: `intuition-v2`
- D1 binding: `intuition-progress`
- Existing safe-preview workflow already uses `CLOUDFLARE_DEPLOY_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
- Registry state: deploy-ready, credential sync allowed.

### Hunter's Intuitive Guidance / Articles
- Repository: `The-Intuitive-Discovery-Project/huntersintuitiveguidance.com`
- Wrangler config: `wrangler.jsonc`
- Worker name: `hunters-intuitive-guidance`
- Known D1 databases include `hunters-articles` and `hunter-business-analytics`.
- Repository contains Cloudflare deployment/maintenance workflows and a safe-preview workflow.
- Registry state: deploy-ready, credential sync allowed.

### Central Admin
- Repository: `The-Intuitive-Discovery-Project/central-admin`
- Wrangler config: `wrangler.jsonc`
- Worker name: `central-admin`
- Registry state: deploy-ready but protected; DeployAll must skip it.
- The repository currently has a scheduled backup workflow and dedicated production deployment workflow. Production deployment remains separately guarded.

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
- Repository currently has no usable `main` branch/application source.
- Registry state: protected, disabled, no shared token sync.

## Credential rule

`SyncGitHubSecrets` only sends the Cloudflare token to projects marked both `deployReady=true` and `credentialSync=true`. It writes both `CLOUDFLARE_API_TOKEN` and the compatibility alias `CLOUDFLARE_DEPLOY_TOKEN`, plus `CLOUDFLARE_ACCOUNT_ID`, so existing workflows can keep working while the repositories are standardized gradually.

## Next safe targets

1. Finish the one-time Cloudflare token setup on Hunter's Windows PC.
2. Run `RefreshRegistry`, `DiscoverLocal`, and `Audit`.
3. Sync credentials only to the verified Worker repositories.
4. Verify project-specific data backup commands before any production deployment.
5. Add the image generator as a new isolated project only after its repository/Worker identity is finalized.
