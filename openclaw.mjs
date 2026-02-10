#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import module from "node:module";
import os from "node:os";
import { fileURLToPath } from "node:url";

const LOW_MEMORY_HOST_TOTAL_MB = 1536;
const DEFAULT_LOW_MEMORY_OLD_SPACE_MB = 896;
const HEAP_GUARD_ENV = "OPENCLAW_HEAP_GUARD";

function parseMaxOldSpaceOption(value) {
  const text = String(value);
  const match = text.match(/(?:^|\s)--max-old-space-size(?:=|\s+)(\d+)(?:\s|$)/);
  if (!match) {
    return null;
  }
  const parsed = Number.parseInt(match[1], 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function resolveConfiguredHeapSizeMb() {
  const values = [...process.execArgv, process.env.NODE_OPTIONS ?? ""];
  let maxOldSpaceMb = null;
  for (const value of values) {
    const parsed = parseMaxOldSpaceOption(value);
    if (parsed && (!maxOldSpaceMb || parsed > maxOldSpaceMb)) {
      maxOldSpaceMb = parsed;
    }
  }
  return maxOldSpaceMb;
}

function sanitizeNodeOptions(options) {
  const cleaned = options
    .replace(/(?:^|\s)--max-old-space-size(?:=|\s+)\d+(?=\s|$)/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return cleaned;
}

function sanitizeExecArgv(args) {
  const sanitized = [];
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--max-old-space-size") {
      index += 1;
      continue;
    }
    if (arg.startsWith("--max-old-space-size=")) {
      continue;
    }
    sanitized.push(arg);
  }
  return sanitized;
}

function resolveAutotunedHeapSizeMb() {
  const forced = Number.parseInt(process.env.OPENCLAW_FORCE_MAX_OLD_SPACE_SIZE ?? "", 10);
  if (Number.isFinite(forced) && forced > 0) {
    return forced;
  }

  const totalMb = Math.floor(os.totalmem() / (1024 * 1024));
  if (totalMb > LOW_MEMORY_HOST_TOTAL_MB) {
    return null;
  }
  return DEFAULT_LOW_MEMORY_OLD_SPACE_MB;
}

function maybeReexecWithHeapGuard() {
  if (process.env[HEAP_GUARD_ENV] === "1") {
    return;
  }

  const heapSizeMb = resolveAutotunedHeapSizeMb();
  if (!heapSizeMb) {
    return;
  }

  const configuredHeapSizeMb = resolveConfiguredHeapSizeMb();
  if (configuredHeapSizeMb && configuredHeapSizeMb >= heapSizeMb) {
    return;
  }

  const sanitizedExecArgv = sanitizeExecArgv(process.execArgv);
  const sanitizedNodeOptions = sanitizeNodeOptions(process.env.NODE_OPTIONS ?? "");

  const scriptPath = fileURLToPath(import.meta.url);
  const child = spawnSync(
    process.execPath,
    [
      `--max-old-space-size=${heapSizeMb}`,
      ...sanitizedExecArgv,
      scriptPath,
      ...process.argv.slice(2),
    ],
    {
      stdio: "inherit",
      env: {
        ...process.env,
        [HEAP_GUARD_ENV]: "1",
        OPENCLAW_FORCE_MAX_OLD_SPACE_SIZE: String(heapSizeMb),
        NODE_OPTIONS: sanitizedNodeOptions,
      },
    },
  );

  if (child.error) {
    throw child.error;
  }
  process.exit(child.status ?? 1);
}

maybeReexecWithHeapGuard();

// https://nodejs.org/api/module.html#module-compile-cache
if (module.enableCompileCache && !process.env.NODE_DISABLE_COMPILE_CACHE) {
  try {
    module.enableCompileCache();
  } catch {
    // Ignore errors
  }
}

await import("./dist/entry.js");
