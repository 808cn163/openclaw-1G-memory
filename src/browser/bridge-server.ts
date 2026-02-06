import { createServer, type Server } from "node:http";
import type { ResolvedBrowserConfig } from "./config.js";

export type BrowserBridge = {
  server: Server;
  port: number;
  baseUrl: string;
  state: {
    server: Server;
    port: number;
    resolved: ResolvedBrowserConfig;
    profiles: Map<string, unknown>;
  };
};

export async function startBrowserBridgeServer(params: {
  resolved: ResolvedBrowserConfig;
  host?: string;
  port?: number;
  authToken?: string;
  onEnsureAttachTarget?: (_profile: unknown) => Promise<void>;
}): Promise<BrowserBridge> {
  const host = params.host ?? "127.0.0.1";
  const port = params.port ?? 0;

  const server = createServer((_req, res) => {
    res.statusCode = 410;
    res.setHeader("content-type", "application/json; charset=utf-8");
    res.end(JSON.stringify({ error: "Browser automation is disabled in this build." }));
  });

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, host, () => resolve());
  });

  const address = server.address();
  const resolvedPort = typeof address === "object" && address ? address.port : port;
  const state = {
    server,
    port: resolvedPort,
    resolved: params.resolved,
    profiles: new Map<string, unknown>(),
  };

  return {
    server,
    port: resolvedPort,
    baseUrl: `http://${host}:${resolvedPort}`,
    state,
  };
}

export async function stopBrowserBridgeServer(server: Server): Promise<void> {
  await new Promise<void>((resolve) => {
    server.close(() => resolve());
  });
}
