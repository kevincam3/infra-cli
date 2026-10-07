# Releasing infra-cli

Releases are fully automated. Every push to `main` runs
`.github/workflows/ci.yml`: the `check` job runs `pnpm verify`, and once it
passes the `release` job runs semantic-release. There is no local release
command and nothing to run by hand.

## What triggers a release

semantic-release reads the Conventional Commits pushed since the last tag
and decides the version bump:

- `fix:` → patch
- `feat:` → minor
- `feat!:` or `BREAKING CHANGE:` footer → major
- `chore:`, `docs:`, `refactor:`, `test:`, etc. → no release

If none of the new commits warrant a release, the workflow still runs and
succeeds, but publishes nothing.

## What the release job does

1. Checks out the full history (`fetch-depth: 0`) so semantic-release can
   find the last tag.
2. Installs pnpm and Node at the versions pinned in `package.json`.
3. Strips the `pnpm-workspace.yaml` settings that do not work in CI and runs
   `pnpm install --frozen-lockfile --ignore-scripts`.
4. Runs `pnpm exec semantic-release`, authenticated with the workflow's
   built-in `GITHUB_TOKEN`. No personal token or `gh` login is involved.

semantic-release (configured under `release` in `package.json`) then:

- Computes the next version from commit history.
- Generates the changelog into `CHANGELOG.md`.
- Updates the `package.json` version and publishes `@kevincam3/infra-cli`
  to GitHub Packages.
- Commits both files with `chore(release): X.Y.Z [skip ci]` and pushes the
  commit to `main`.
- Pushes the tag and creates a GitHub Release with notes.

## Before pushing to main

- All commits follow Conventional Commits; the `commit-msg` hook enforces
  this with commitlint.
- `pnpm verify` passes. The `pre-merge-commit` and `pre-push` hooks run it
  automatically, and the `ci` workflow runs it again on GitHub.

If `check` fails, the `release` job is skipped and nothing is published.
Re-running the failed job from the Actions UI (or `gh run rerun <id>
--failed`) lets the release continue once it passes. Runs on `main` are
never cancelled by a newer push; they queue behind each other.

## After a release

The release commit is pushed to `main` by the workflow, so local `main` is
one commit behind afterwards. Run `git pull` before the next push.

## Troubleshooting

**The workflow succeeded but nothing was released** — the commit subjects
since the last tag are not release-worthy. Only `fix:`, `feat:`, and
breaking changes trigger releases by default.

**The push to `main` is rejected as non-fast-forward** — a release commit
landed on `origin/main` after your last pull. `git pull --rebase` and push
again.

**Checking a run** — `gh run list --workflow ci --branch main` lists recent runs;
`gh run view <id> --log` shows the semantic-release output.
