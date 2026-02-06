import type { BrowserConfig, BrowserProfileConfig, OpenClawConfig } from "../config/config.js";
import {
  DEFAULT_BROWSER_EVALUATE_ENABLED,
  DEFAULT_OPENCLAW_BROWSER_COLOR,
  DEFAULT_OPENCLAW_BROWSER_ENABLED,
  DEFAULT_OPENCLAW_BROWSER_PROFILE_NAME,
} from "./constants.js";

export type ResolvedBrowserConfig = {
  enabled: boolean;
  evaluateEnabled: boolean;
  controlPort: number;
  cdpProtocol: "http" | "https";
  cdpHost: string;
  cdpIsLoopback: boolean;
  remoteCdpTimeoutMs: number;
  remoteCdpHandshakeTimeoutMs: number;
  color: string;
  executablePath?: string;
  headless: boolean;
  noSandbox: boolean;
  attachOnly: boolean;
  defaultProfile: string;
  profiles: Record<string, BrowserProfileConfig>;
};

export type ResolvedBrowserProfile = {
  name: string;
  cdpPort: number;
  cdpUrl: string;
  cdpHost: string;
  cdpIsLoopback: boolean;
  color: string;
  driver: "openclaw" | "extension";
};

export function resolveBrowserConfig(
  cfg: BrowserConfig | undefined,
  _rootConfig?: OpenClawConfig,
): ResolvedBrowserConfig {
  const enabled = cfg?.enabled ?? DEFAULT_OPENCLAW_BROWSER_ENABLED;
  const evaluateEnabled = cfg?.evaluateEnabled ?? DEFAULT_BROWSER_EVALUATE_ENABLED;
  const color = cfg?.color?.trim() || DEFAULT_OPENCLAW_BROWSER_COLOR;

  return {
    enabled,
    evaluateEnabled,
    controlPort: 0,
    cdpProtocol: "http",
    cdpHost: "127.0.0.1",
    cdpIsLoopback: true,
    remoteCdpTimeoutMs: 1500,
    remoteCdpHandshakeTimeoutMs: 3000,
    color,
    executablePath: undefined,
    headless: true,
    noSandbox: false,
    attachOnly: true,
    defaultProfile: DEFAULT_OPENCLAW_BROWSER_PROFILE_NAME,
    profiles: {},
  };
}

export function resolveProfile(
  resolved: ResolvedBrowserConfig,
  profileName: string,
): ResolvedBrowserProfile | null {
  const profile = resolved.profiles[profileName];
  if (!profile) {
    return null;
  }

  const cdpPort = profile.cdpPort ?? 0;
  const cdpHost = resolved.cdpHost;
  const cdpUrl =
    profile.cdpUrl?.trim() || (cdpPort ? `${resolved.cdpProtocol}://${cdpHost}:${cdpPort}` : "");
  return {
    name: profileName,
    cdpPort,
    cdpUrl,
    cdpHost,
    cdpIsLoopback: true,
    color: profile.color ?? resolved.color,
    driver: profile.driver === "extension" ? "extension" : "openclaw",
  };
}
