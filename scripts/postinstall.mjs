#!/usr/bin/env node
// Drops example infra.config.sh, .env.infisical-auth.dev, and .env.infisical-auth.prod into the consumer's
// project directory on install. Skips files that already exist so this is
// safe to re-run. Never fails the install — worst case it logs a warning.
//
// In a pnpm workspace, INIT_CWD is the workspace root even when the install
// was filtered to a specific package. We detect this and scaffold into each
// workspace package that declares @kevincam3/infra-cli as a dependency.

import { copyFileSync, existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const PKG_NAME = "@kevincam3/infra-cli";

function findWorkspacePackageDirs(workspaceRoot) {
  const yamlPath = join(workspaceRoot, "pnpm-workspace.yaml");
  if (!existsSync(yamlPath)) return [];

  const lines = readFileSync(yamlPath, "utf8").split("\n");
  const dirs = [];
  let inPackages = false;

  for (const line of lines) {
    if (/^packages\s*:/.test(line)) {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    if (/^\s*-/.test(line)) {
      const pattern = line.replace(/^\s*-\s*['"]?|['"]?\s*$/g, "").trim();
      if (pattern) expandGlob(workspaceRoot, pattern, dirs);
    } else if (line.trim() && !/^\s/.test(line)) {
      break; // end of packages section
    }
  }

  return dirs;
}

function expandGlob(root, pattern, results) {
  if (!pattern.includes("*")) {
    const dir = join(root, pattern);
    if (existsSync(dir)) results.push(dir);
    return;
  }
  // Handle simple single-star globs like 'packages/*'
  const starIdx = pattern.indexOf("*");
  const parentDir = join(root, pattern.slice(0, starIdx).replace(/\/$/, ""));
  const suffix = pattern.slice(starIdx + 1);
  if (!existsSync(parentDir)) return;
  for (const entry of readdirSync(parentDir)) {
    if (!suffix || entry.endsWith(suffix)) {
      const fullPath = join(parentDir, entry);
      try {
        if (statSync(fullPath).isDirectory()) results.push(fullPath);
      } catch {}
    }
  }
}

function hasDep(pkgDir) {
  const pkgJson = join(pkgDir, "package.json");
  if (!existsSync(pkgJson)) return false;
  try {
    const { dependencies = {}, devDependencies = {} } = JSON.parse(readFileSync(pkgJson, "utf8"));
    return PKG_NAME in dependencies || PKG_NAME in devDependencies;
  } catch {
    return false;
  }
}

function scaffoldTo(targetDir, examplesDir, files) {
  for (const { src, dest } of files) {
    const destPath = join(targetDir, dest);
    if (existsSync(destPath)) continue;
    const srcPath = join(examplesDir, src);
    if (!existsSync(srcPath)) continue;
    copyFileSync(srcPath, destPath);
    console.log(`[infra-cli] created ${dest}`);
  }
}

try {
  const initCwd = process.env.INIT_CWD;
  if (!initCwd) process.exit(0);

  const packageDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
  const initCwdResolved = resolve(initCwd);

  // Don't scaffold into the package's own checkout (e.g. when developing it).
  if (initCwdResolved === packageDir) process.exit(0);

  const examplesDir = join(packageDir, "examples");
  const files = [
    { src: "infra.config.sh", dest: "infra.config.sh" },
    { src: "env.infisical-auth.dev", dest: ".env.infisical-auth.dev" },
    { src: "env.infisical-auth.prod", dest: ".env.infisical-auth.prod" },
  ];

  // In pnpm workspaces, INIT_CWD is the workspace root even when --filter is
  // used from a sub-package directory. Find the packages that actually depend
  // on us and scaffold there; fall back to INIT_CWD if none are found.
  if (existsSync(join(initCwdResolved, "pnpm-workspace.yaml"))) {
    const consumers = findWorkspacePackageDirs(initCwdResolved).filter(hasDep);
    const targets = consumers.length > 0 ? consumers : [initCwdResolved];
    for (const dir of targets) scaffoldTo(dir, examplesDir, files);
  } else {
    scaffoldTo(initCwdResolved, examplesDir, files);
  }
} catch (err) {
  console.warn(`[infra-cli] postinstall skipped: ${err.message}`);
}
