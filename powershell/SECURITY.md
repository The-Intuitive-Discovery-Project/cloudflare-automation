# Security notes

- The Cloudflare API token is never committed to this repository.
- On Windows, Setup stores the token as a DPAPI-encrypted SecureString under `%APPDATA%\TinyThorDeploy\cloudflare-token.txt`; it is tied to the current Windows user context.
- GitHub Actions secrets are sent with `gh secret set` via standard input rather than written into project files.
- The manager does not print the token.
- `SyncGitHubSecrets` only targets projects marked both `deployReady=true` and `credentialSync=true`.
- For compatibility with existing workflows, the same approved deployment token is stored under both `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_DEPLOY_TOKEN`; the Account ID is stored separately as `CLOUDFLARE_ACCOUNT_ID`.
- Registered D1 databases are exported read-only before deployment. The export must be non-empty and gets a SHA-256 verification record; otherwise deployment is blocked.
- Production deployment always follows source/data backup -> dry-run -> exact typed confirmation -> deploy.
- Protected projects are skipped by DeployAll.
- Disabled projects cannot be deployed even with `-Force`; Central Admin is deliberately both disabled and protected until complete All-in-One backup coverage is verified.
- Non-deploy-ready projects fail closed even if someone accidentally enables them in a local config.
- Unknown deployment types fail closed.
- `RefreshRegistry` updates project metadata without replacing the encrypted token or known local paths.
- The token should use the minimum practical Cloudflare permissions documented in `TOKEN-PERMISSIONS.md`; database/KV backup access is read-only.
