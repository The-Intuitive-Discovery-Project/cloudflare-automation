# Cloudflare GitHub secret usage audit

Audited: 2026-09-20

Purpose: prevent the unified automation setup from breaking existing workflows by assuming every repository uses the same Cloudflare secret for the same job.

## Findings

### Intuition
Repository: `The-Intuitive-Discovery-Project/intuition.tinythor.cc`

- `safe-preview.yml` maps `CLOUDFLARE_API_TOKEN` from the GitHub secret `CLOUDFLARE_DEPLOY_TOKEN`.
- That workflow verifies/creates the shared isolated Cloudflare Pages preview project and deploys a Pages preview.
- Conclusion: an existing `CLOUDFLARE_DEPLOY_TOKEN` must not be overwritten with a narrower Worker/D1 token unless Pages capability is deliberately verified.

### Hunter's Intuitive Guidance
Repository: `The-Intuitive-Discovery-Project/huntersintuitiveguidance.com`

- `safe-preview.yml` also maps its runtime Cloudflare token from `CLOUDFLARE_DEPLOY_TOKEN` and uses it for the isolated Pages preview project.
- Production workflows such as `deploy-books.yml` use `CLOUDFLARE_API_TOKEN` plus `CLOUDFLARE_ACCOUNT_ID` for Worker dry-run/deployment.
- Conclusion: this repository currently has two secret-name roles. Preserve existing values unless an intentional replacement is requested.

### Central Admin
Repository: `The-Intuitive-Discovery-Project/central-admin`

- `safe-preview.yml` uses `CLOUDFLARE_DEPLOY_TOKEN` for restricted Cloudflare validation/dry-run behavior.
- `deploy-central-admin-main-only.yml` uses `CLOUDFLARE_API_TOKEN` for guarded production Worker deployment and pre-deploy backup.
- `nightly-data-backup.yml` on current `main` also uses `CLOUDFLARE_API_TOKEN` for the complete read-only All-in-One backup.
- Draft PR #41 adds a fallback from `CLOUDFLARE_API_TOKEN` to the existing `CLOUDFLARE_DEPLOY_TOKEN`; it remains unmerged pending D1/KV read-permission confidence.
- Conclusion: the unified API-token secret is important for both backup and production-deploy gates, while the existing deploy-token alias should be preserved until its separate permission role is fully understood.

## Automation policy derived from this audit

Normal `SyncGitHubSecrets` must be missing-only:

1. List existing Actions secret names first.
2. Add `CLOUDFLARE_API_TOKEN` only when missing.
3. Add `CLOUDFLARE_ACCOUNT_ID` only when missing.
4. Preserve existing values unless `-Force` is deliberately supplied.
5. Never create or replace `CLOUDFLARE_DEPLOY_TOKEN` by default.
6. `-IncludeDeployAlias` may create a missing deploy alias only after permission review.
7. Replacing an existing deploy alias requires `-IncludeDeployAlias -Force`.
8. Secret values are never printed or committed.

This policy lets the unified manager fill genuine gaps without disrupting working preview/deployment credentials that may have different Cloudflare permission scopes.
