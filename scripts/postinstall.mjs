#!/usr/bin/env node
// Drops example infra.config.sh and .env.infisical-auth into the consumer's
// project directory on install. Skips files that already exist so this is
// safe to re-run. Never fails the install — worst case it logs a warning.

import { copyFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

try {
  const initCwd = process.env.INIT_CWD;
  if (!initCwd) process.exit(0);

  const packageDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const targetDir = resolve(initCwd);

  // Don't scaffold into the package's own checkout (e.g. when developing it).
  if (targetDir === packageDir) process.exit(0);

  const examplesDir = join(packageDir, 'examples');

  const files = [
    { src: 'infra.config.sh', dest: 'infra.config.sh' },
    { src: 'env.infisical-auth', dest: '.env.infisical-auth' },
  ];

  for (const { src, dest } of files) {
    const destPath = join(targetDir, dest);
    if (existsSync(destPath)) continue;

    const srcPath = join(examplesDir, src);
    if (!existsSync(srcPath)) continue;

    copyFileSync(srcPath, destPath);
    console.log(`[infra-cli] created ${dest}`);
  }
} catch (err) {
  console.warn(`[infra-cli] postinstall skipped: ${err.message}`);
}
