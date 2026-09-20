# Security notes

- The Cloudflare API token is never committed to this repository.
- On Windows, Setup stores the token as a DPAPI-encrypted SecureString under `%APPDATA%\TinyThorDeploy\cloudflare-token.txt`; it is tied to the current Windows user context.
- GitHub Actions secrets are sent with `gh secret set` via standard input rather than written into project files.
- The manager does not print the token.
- Production deployment always follows backup -> dry-run -> exact typed confirmation -> deploy.
- Protected projects are skipped by DeployAll.
- Unknown deployment types fail closed.
- Cloudflare Pages deployment is fail-closed until the exact project/output directory has been verified.
