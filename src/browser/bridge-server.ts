export type BrowserBridge = {
  server: null;
  port: number;
  baseUrl: string;
  state: null;
};

export async function startBrowserBridgeServer(): Promise<BrowserBridge> {
  throw new Error("Browser automation is disabled in this build.");
}

export async function stopBrowserBridgeServer(): Promise<void> {}
