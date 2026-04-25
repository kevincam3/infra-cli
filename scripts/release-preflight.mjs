#!/usr/bin/env node
// Preflight for `pnpm release`. Aborts before semantic-release runs if:
//   1. GITHUB_TOKEN cannot be obtained (env or `gh` for the expected account)
//   2. Not on the release branch
//   3. Working tree is dirty
//   4. Local branch is behind origin (needs pull)
// Then shows commits since the last tag, prompts for confirmation, and execs
// semantic-release with GITHUB_TOKEN injected into its environment.

import { execSync, spawnSync } from "node:child_process";
import { stdin, stdout } from "node:process";
import { createInterface } from "node:readline/promises";

const RELEASE_BRANCH = "main";
const GH_ACCOUNT = "kevincam3";

const sh = (cmd) => execSync(cmd, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();

const c = process.stderr.isTTY
  ? {
      red: (s) => `\x1b[31m${s}\x1b[0m`,
      dim: (s) => `\x1b[2m${s}\x1b[0m`,
      bold: (s) => `\x1b[1m${s}\x1b[0m`,
    }
  : { red: (s) => s, dim: (s) => s, bold: (s) => s };

// Accepts either a single string (one line) or an array of lines for multi-line errors.
const fail = (msg) => {
  const lines = Array.isArray(msg) ? msg : [msg];
  console.error(`${c.red("✗")} ${c.bold(lines[0])}`);
  for (const line of lines.slice(1)) console.error(line === "" ? "" : `  ${line}`);
  process.exit(1);
};

try {
  let githubToken = process.env.GITHUB_TOKEN;
  if (!githubToken) {
    try {
      githubToken = sh(`gh auth token --user ${GH_ACCOUNT}`);
      process.stderr.write(c.dim(`using GITHUB_TOKEN from gh (${GH_ACCOUNT})\n`));
    } catch {
      fail([
        `GITHUB_TOKEN is not set and no gh token found for account '${GH_ACCOUNT}'.`,
        "",
        "Either:",
        `  • ${c.bold(`gh auth login`)} as ${c.bold(GH_ACCOUNT)} (one-time setup)`,
        `  • ${c.bold("GITHUB_TOKEN=<pat> pnpm release")} with a PAT (${c.bold("Contents: write")})`,
      ]);
    }
  }

  const branch = sh("git rev-parse --abbrev-ref HEAD");
  if (branch !== RELEASE_BRANCH) {
    fail(`Must be on '${RELEASE_BRANCH}' to release (currently on '${branch}').`);
  }

  const dirty = sh("git status --porcelain");
  if (dirty) {
    fail([
      "Working tree has uncommitted or untracked changes.",
      "",
      ...dirty.split("\n").map((l) => c.dim(`${l.slice(0, 2).trim().padEnd(2)} ${l.slice(3)}`)),
      "",
      "Commit, stash, or clean before releasing.",
    ]);
  }

  process.stderr.write(c.dim(`fetching origin/${RELEASE_BRANCH}...`));
  sh(`git fetch origin ${RELEASE_BRANCH}`);
  process.stderr.write(c.dim(" done\n"));

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

  const result = spawnSync("pnpm", ["exec", "semantic-release", "--no-ci"], {
    stdio: "inherit",
    env: { ...process.env, GITHUB_TOKEN: githubToken },
  });
  process.exit(result.status ?? 1);
} catch (err) {
  if (err?.stderr) process.stderr.write(err.stderr.toString());
  fail(err?.message ?? "preflight failed");
}
