import { loadConfig } from "../config/config.js";
import { createSubsystemLogger } from "../logging/subsystem.js";
import { resolveBrowserConfig } from "./config.js";

const log = createSubsystemLogger("browser");
const logService = log.child("service");

export function getBrowserControlState(): null {
  return null;
}

export function createBrowserControlContext(): never {
  throw new Error("Browser automation is disabled in this build.");
}

export async function startBrowserControlServiceFromConfig(): Promise<null> {
  const cfg = loadConfig();
  const resolved = resolveBrowserConfig(cfg.browser, cfg);
  if (!resolved.enabled) {
    return null;
  }
  logService.warn("Browser automation is disabled in this build; ignoring browser.enabled=true.");
  return null;
}

export async function stopBrowserControlService(): Promise<void> {}
