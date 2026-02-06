export type BrowserControlContext = {
  enabled: false;
  reason: string;
};

const DISABLED_REASON = "Browser automation is disabled in this low-memory build.";

export function createBrowserControlContext(): BrowserControlContext {
  return {
    enabled: false,
    reason: DISABLED_REASON,
  };
}

export async function startBrowserControlServiceFromConfig(): Promise<boolean> {
  return false;
}

export async function startBrowserControlServerFromConfig(): Promise<boolean> {
  return false;
}

export async function stopBrowserControlService(): Promise<void> {
  return;
}

export async function stopBrowserControlServer(): Promise<void> {
  return;
}
