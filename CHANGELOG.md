# [3.1.0](https://github.com/kevincam3/infra-cli/compare/v3.0.3...v3.1.0) (2026-05-14)

### Features

- **ci:** automate releases via GitHub Actions ([fe6a388](https://github.com/kevincam3/infra-cli/commit/fe6a3889afd05b02cd267aaac8c38c2128ad860d))

## [3.0.3](https://github.com/kevincam3/infra-cli/compare/v3.0.2...v3.0.3) (2026-05-02)

### Bug Fixes

- **secrets:** remove exporting secrets section banner ([0b70467](https://github.com/kevincam3/infra-cli/commit/0b704674af23fd182d76554d1be6ac1d8217a8e3))

## [3.0.2](https://github.com/kevincam3/infra-cli/compare/v3.0.1...v3.0.2) (2026-05-02)

### Bug Fixes

- **stacks:** isolate secret exports to a subshell per stack ([d2edb38](https://github.com/kevincam3/infra-cli/commit/d2edb38a4a1a8e102fdad00f9c6cee1650ba92b5))

## [3.0.1](https://github.com/kevincam3/infra-cli/compare/v3.0.0...v3.0.1) (2026-05-01)

### Bug Fixes

- **stacks:** suppress unset-variable warnings on stop ([e7f7132](https://github.com/kevincam3/infra-cli/commit/e7f71324f02227253b2f3dc9a9e7a0728afd77ea))

# [3.0.0](https://github.com/kevincam3/infra-cli/compare/v2.0.0...v3.0.0) (2026-05-01)

- feat(secrets)!: auto-prefix exported secrets with service name ([01bc885](https://github.com/kevincam3/infra-cli/commit/01bc885a0ae5cbd9fc31740b7840d21321264704))

### BREAKING CHANGES

- all exported secrets are now prefixed with the service name
  (e.g. DB_PASSWORD from "tooling-postgres" becomes TOOLING_POSTGRES_DB_PASSWORD).
  Docker compose files must be updated to map prefixed env vars to the names
  containers expect:

  environment:
  DB_PASSWORD: ${TOOLING_POSTGRES_DB_PASSWORD}

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

# [2.0.0](https://github.com/kevincam3/infra-cli/compare/v1.2.0...v2.0.0) (2026-04-29)

- feat!: inject Infisical secrets into shell env; split auth files per environment ([68f9c40](https://github.com/kevincam3/infra-cli/commit/68f9c40f62a1808d4de4170d4693d826f0742fa5))

### Features

- **config:** simplify network configuration in infra.config.sh ([ac01aea](https://github.com/kevincam3/infra-cli/commit/ac01aea227472328430389c3efd6d553871f7a52))
- **secrets:** simplify secrets array check in `secrets.sh` ([4f20dbf](https://github.com/kevincam3/infra-cli/commit/4f20dbfbcb322ba96a30925e9968383f45d736ae))

### BREAKING CHANGES

- .env.infisical-auth is replaced by .env.infisical-auth.dev
  and .env.infisical-auth.prod. The SECRETS\_\* entry format loses the
  output_path field (was 5 pipe-separated fields, now 4). Compose files must
  replace env_file: with environment: bare key names. See
  docs/guides/secrets.md for migration steps.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

# [1.2.0](https://github.com/kevincam3/infra-cli/compare/v1.1.0...v1.2.0) (2026-04-26)

### Features

- **cli:** add optional pre-start hook for project-specific bootstrap ([ab9101f](https://github.com/kevincam3/infra-cli/commit/ab9101f5e93742b445adb68ea1b259ab47287152))

# [1.1.0](https://github.com/kevincam3/infra-cli/compare/v1.0.0...v1.1.0) (2026-04-26)

### Features

- **cli:** add ASCII art banner generation and workspace scaffolding for pnpm users ([bb6cc97](https://github.com/kevincam3/infra-cli/commit/bb6cc97f65ae9f36ea61822732c916f0df15f09e))
- **docs:** add comprehensive architecture and usage documentation ([a14fbdd](https://github.com/kevincam3/infra-cli/commit/a14fbdd026d537ef753de6c0730671bd051e9d78))
- **docs:** clarify CLI usage and update cleanup behavior in README ([9cc459e](https://github.com/kevincam3/infra-cli/commit/9cc459e0dc455f628c2f70f46e289f198d29a79d))

# 1.0.0 (2026-04-25)

### Bug Fixes

- enforce private package and update Node.js version requirement ([dd249ed](https://github.com/kevincam3/infra-cli/commit/dd249ed6ac41d96448b6f877e7a5768ceff4fee6))
- refactor conditional checks in cleanup.sh scripts ([1e5df2d](https://github.com/kevincam3/infra-cli/commit/1e5df2d38bf53c666a25d307f5ffb6b4052482d7))
- render user-provided BANNER with printf to preserve backslashes in ASCII art ([fc67ea8](https://github.com/kevincam3/infra-cli/commit/fc67ea89d9a60ad6dda441205674406a76f294e7))
- update package name in package.json ([2dc5842](https://github.com/kevincam3/infra-cli/commit/2dc584274cd5c821bcf1b84f3ac4f507241a9cac))
- update script references to infra.sh ([367cc4e](https://github.com/kevincam3/infra-cli/commit/367cc4ec8fe1e25b4766f972f6cd893ee110fd5a))

### Features

- add postinstall script, expand files array, and update example config ([b7d2686](https://github.com/kevincam3/infra-cli/commit/b7d2686f416eed7cb73569d44056c80c920cca67))
- add support for deduplicating shared services in dev and customizable network creation ([da3dba5](https://github.com/kevincam3/infra-cli/commit/da3dba56d332f54284bc00433c95a24168763847))
- **hooks:** add git hooks for commit linting and staged files ([4b01116](https://github.com/kevincam3/infra-cli/commit/4b01116ec077b1618c279d74eac49aaa2cdb8172))
- initial infra-cli with start/stop subcommands, --env flag, per-project config, Infisical secret export ([abfc173](https://github.com/kevincam3/infra-cli/commit/abfc173a8208138c5e27b6b61745c6cf752c82e8))
- release v1.0.0 for infra-cli ([77640a7](https://github.com/kevincam3/infra-cli/commit/77640a7c029d65880abe55f7d3bca63e11c47316))
- **release:** add preflight check and semantic-release integration ([914249e](https://github.com/kevincam3/infra-cli/commit/914249e6f9a71f395abe62443570211bfe1fcaa4))
- **release:** improve preflight checks and refine release process ([16370a2](https://github.com/kevincam3/infra-cli/commit/16370a2b898928b457a0bad6286cbef23a1ab176))
- scaffold example config on install for Infisical integration ([efe2cc1](https://github.com/kevincam3/infra-cli/commit/efe2cc170aae46c405ad246413e9812ef59dd1f2))
