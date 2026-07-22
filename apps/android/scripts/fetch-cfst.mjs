#!/usr/bin/env node
/**
 * Download CloudflareSpeedTest (CFST) v2.3.5 linux arm64 binary into
 * app/src/main/assets/cfst/ for Android arm64 devices.
 *
 * Upstream does not publish an Android-specific build; the linux_arm64
 * artifact is the same ABI policy used for many Go tools on Android.
 *
 * Usage:
 *   node scripts/fetch-cfst.mjs
 *   node scripts/fetch-cfst.mjs --force
 */
import { createWriteStream, readdirSync } from "node:fs";
import { access, chmod, mkdir, rename, rm } from "node:fs/promises";
import { pipeline } from "node:stream/promises";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Readable } from "node:stream";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(__dirname, "..");
const outDir = path.join(appRoot, "app/src/main/assets/cfst");
const FORCE = process.argv.includes("--force") || process.argv.includes("-f");
const VERSION = "v2.3.5";
const ARCHIVE = `cfst_linux_arm64.tar.gz`;
const url = `https://github.com/XIU2/CloudflareSpeedTest/releases/download/${VERSION}/${ARCHIVE}`;
const plainPath = path.join(outDir, "cfst-arm64");

async function exists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

async function download(url, dest) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download ${url} -> HTTP ${res.status}`);
  await pipeline(Readable.fromWeb(res.body), createWriteStream(dest));
}

function findBinary(dir) {
  const names = readdirSync(dir, { withFileTypes: true });
  for (const entry of names) {
    if (!entry.isFile()) continue;
    const n = entry.name.toLowerCase();
    if (
      n === "cfst" ||
      n === "cfst.exe" ||
      n.startsWith("cloudflarespeedtest") ||
      n === "cloudflare_speedtest" ||
      n === "cloudflare_speedtest.exe"
    ) {
      return path.join(dir, entry.name);
    }
  }
  for (const entry of names) {
    if (entry.isDirectory() && !entry.name.startsWith(".")) {
      const nested = findBinary(path.join(dir, entry.name));
      if (nested) return nested;
    }
  }
  return null;
}

async function main() {
  await mkdir(outDir, { recursive: true });
  if (!FORCE && (await exists(plainPath))) {
    console.log(`already present: ${plainPath}`);
    return;
  }

  console.log(`fetching ${url}`);
  const tmpDir = path.join(outDir, ".tmp-cfst");
  await rm(tmpDir, { recursive: true, force: true });
  await mkdir(tmpDir, { recursive: true });
  const archive = path.join(tmpDir, ARCHIVE);
  await download(url, archive);

  execSync(`tar -xzf "${archive}" -C "${tmpDir}"`, { stdio: "inherit" });

  const bin = findBinary(tmpDir);
  if (!bin) throw new Error(`CFST binary not found in ${archive}`);
  await rename(bin, plainPath);
  await chmod(plainPath, 0o755);
  await rm(tmpDir, { recursive: true, force: true });
  console.log(`wrote ${plainPath}`);
  console.log("Asset ready for CfstInstaller (arm64). Other ABIs are not shipped.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
