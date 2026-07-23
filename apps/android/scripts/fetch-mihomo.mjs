#!/usr/bin/env node
/**
 * Download mihomo android arm64 binary into
 * app/src/main/jniLibs/arm64-v8a/libmihomo.so for Android arm64 devices.
 *
 * Android 10+ rejects exec from filesDir with EACCES. Packaging as lib*.so lets
 * PackageManager extract it into the executable native lib directory (same policy
 * as fetch-cfst.mjs → libcfst.so).
 *
 * Usage:
 *   node scripts/fetch-mihomo.mjs
 *   node scripts/fetch-mihomo.mjs --force
 */
import { createWriteStream, createReadStream } from "node:fs";
import { access, chmod, copyFile, mkdir, rm } from "node:fs/promises";
import { pipeline } from "node:stream/promises";
import { createGunzip } from "node:zlib";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Readable } from "node:stream";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(__dirname, "..");
const outDir = path.join(appRoot, "app/src/main/jniLibs/arm64-v8a");
const FORCE = process.argv.includes("--force") || process.argv.includes("-f");
const plainPath = path.join(outDir, "libmihomo.so");
// Legacy asset path kept as optional seed when already present offline.
const legacyAsset = path.join(appRoot, "app/src/main/assets/mihomo/mihomo-arm64");

async function exists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

async function latestVersion() {
  const res = await fetch(
    "https://github.com/MetaCubeX/mihomo/releases/latest/download/version.txt",
  );
  if (!res.ok) throw new Error(`version.txt HTTP ${res.status}`);
  return (await res.text()).trim();
}

async function download(url, dest) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download ${url} -> HTTP ${res.status}`);
  await pipeline(Readable.fromWeb(res.body), createWriteStream(dest));
}

async function main() {
  await mkdir(outDir, { recursive: true });
  if (!FORCE && (await exists(plainPath))) {
    console.log(`already present: ${plainPath}`);
    return;
  }

  if (!FORCE && (await exists(legacyAsset))) {
    console.log(`seeding from legacy asset: ${legacyAsset}`);
    await copyFile(legacyAsset, plainPath);
    await chmod(plainPath, 0o755);
    console.log(`wrote ${plainPath}`);
    return;
  }

  const version = await latestVersion();
  // Official asset name uses arm64-v8 (see MetaCubeX/mihomo releases).
  const name = "mihomo-android-arm64-v8";
  const url = `https://github.com/MetaCubeX/mihomo/releases/download/${version}/${name}-${version}.gz`;
  console.log(`fetching ${url}`);
  const tmp = path.join(outDir, ".tmp-mihomo.gz");
  await download(url, tmp);
  await pipeline(createReadStream(tmp), createGunzip(), createWriteStream(plainPath));
  await chmod(plainPath, 0o755);
  await rm(tmp, { force: true });
  console.log(`wrote ${plainPath}`);
  console.log("Native lib ready for ViaSixVpnService / MihomoInstaller.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
