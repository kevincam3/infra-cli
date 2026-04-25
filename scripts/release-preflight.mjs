#!/usr/bin/env node
// Preflight for `pnpm release`. Aborts before semantic-release runs if:
//   1. GITHUB_TOKEN is missing
//   2. Not on the release branch
//   3. Working tree is dirty
//   4. Local branch is behind origin (needs pull)
// Then shows commits since the last tag and prompts for confirmation.

import { execSync } from "node:child_process";
import { stdin, stdout } from "node:process";
import { createInterface } from "node:readline/promises";

const RELEASE_BRANCH = "main";

const sh = (cmd) => execSync(cmd, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();

const fail = (msg) => {
  console.error(`✖ ${msg}`);
  process.exit(1);
};

try {
  if (!process.env.GITHUB_TOKEN) {
    fail(
      "GITHUB_TOKEN is not set. Either run `GITHUB_TOKEN=$(gh auth token) pnpm release` " +
        "(requires `gh auth login` once) or export a PAT with `Contents: write` on this repo.",
    );
  }

  const branch = sh("git rev-parse --abbrev-ref HEAD");
  if (branch !== RELEASE_BRANCH) {
    fail(`Must be on '${RELEASE_BRANCH}' to release (currently on '${branch}').`);
  }

  const dirty = sh("git status --porcelain");
  if (dirty) {
    console.error("Working tree has uncommitted or untracked changes:");
    console.error(dirty);
    fail("Commit, stash, or clean before releasing.");
  }

  console.log(`Fetching origin/${RELEASE_BRANCH}...`);
  sh(`git fetch origin ${RELEASE_BRANCH}`);

  const behind = Number(sh(`git rev-list --count HEAD..origin/${RELEASE_BRANCH}`));
  if (behind > 0) {
    fail(`Local '${RELEASE_BRANCH}' is ${behind} commit(s) behind origin. Pull first.`);
  }

  let lastTag = "";
  try {
    lastTag = sh("git describe --tags --abbrev=0");
  } catch {
    // No tags yet — this is the first release.
  }

  const range = lastTag ? `${lastTag}..HEAD` : "HEAD";
  const commits = sh(`git log --oneline ${range}`);
  if (!commits) fail("No new commits since the last release.");

  console.log();
  console.log(`Commits to be released ${lastTag ? `since ${lastTag}` : "(first release)"}:`);
  console.log(commits);
  console.log();

  if (!stdin.isTTY) {
    fail("Preflight requires an interactive terminal.");
  }

  const rl = createInterface({ input: stdin, output: stdout });
  const ans = (await rl.question("Proceed with release? [y/N] ")).trim().toLowerCase();
  rl.close();

  if (ans !== "y" && ans !== "yes") fail("Aborted.");
} catch (err) {
  if (err?.stderr) process.stderr.write(err.stderr.toString());
  fail(err?.message ?? "preflight failed");
}
