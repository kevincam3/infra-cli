# Releasing infra-cli

Releases are cut locally with `pnpm release` from the `main` branch.
There is no CI publish step.

## Prerequisites

- `pnpm install` has run (semantic-release lives in `devDependencies`).
- You're authenticated as **kevincam3** in `gh`:
  ```bash
  gh auth status
  ```
  If not, `gh auth login` and pick the `kevincam3` account. The preflight
  script pulls the token automatically via `gh auth token --user kevincam3`,
  so you do not need to set `GITHUB_TOKEN` yourself.
- Working tree is clean and `main` is at parity with `origin/main`.
- All commits since the last tag follow Conventional Commits — that's how
  semantic-release decides the version bump:
  - `fix:` → patch
  - `feat:` → minor
  - `feat!:` or `BREAKING CHANGE:` footer → major
  - `chore:`, `docs:`, `refactor:`, `test:`, etc. → no release

## Cutting the release

```bash
pnpm release
```

The preflight script will:

1. Resolve `GITHUB_TOKEN` (env var if set, otherwise `gh`).
2. Verify branch is `main`, tree is clean, and you're not behind `origin`.
3. Print the commits since the last tag and prompt:
   ```
   Proceed with release? [y/N]
   ```
4. On `y`, exec `pnpm exec semantic-release --no-ci` with the token
   injected into its environment.

semantic-release then:

- Computes the next version from commit history.
- Generates the changelog into `CHANGELOG.md`.
- Updates `package.json` version (no npm publish — `npmPublish: false`).
- Commits both files with `chore(release): X.Y.Z [skip ci]`.
- Pushes the tag and creates a GitHub Release with notes.

## Aborting

Answering anything other than `y` / `yes` at the prompt aborts before any
git or GitHub state changes. The preflight also aborts (with a
descriptive error) on any of:

- Missing `GITHUB_TOKEN` and no `gh` token for `kevincam3`.
- Wrong branch.
- Dirty working tree (uncommitted or untracked files).
- Local `main` behind `origin/main`.
- No new commits since the last tag.

## Troubleshooting

**"no oauth token found for github.com account 'kevincam3'"** — run
`gh auth login`, choose `github.com`, HTTPS, and authenticate as
**kevincam3**. If you have multiple accounts, `gh auth switch --user kevincam3`
makes it active (not strictly required since the script targets the user
explicitly).

**"Process finished with exit code 1" trailing the output** — that's
PhpStorm's run console, not the script. Run `pnpm release` from a regular
terminal (or PhpStorm's terminal panel) to avoid it.

**semantic-release says "no release" even though you committed** — your
commit subjects are likely not Conventional. Only `fix:`, `feat:`, and
breaking-change footers trigger releases by default.
