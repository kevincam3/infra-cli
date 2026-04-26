#!/usr/bin/env node
import figlet from "figlet";

const text = process.argv.slice(2).join(" ");
if (!text) process.exit(0);

try {
  process.stdout.write(figlet.textSync(text, { font: "Slant" }) + "\n");
} catch {
  process.stdout.write(text + "\n");
}
