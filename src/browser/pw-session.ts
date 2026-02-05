export type BrowserConsoleMessage = {
  type: string;
  text: string;
  timestamp: string;
  location?: { url?: string; lineNumber?: number; columnNumber?: number };
};

export type BrowserPageError = {
  message: string;
  name?: string;
  stack?: string;
  timestamp: string;
};

export type BrowserNetworkRequest = {
  id: string;
  timestamp: string;
  method: string;
  url: string;
  resourceType?: string;
  status?: number;
  ok?: boolean;
  failureText?: string;
};

type SnapshotForAIResult = { full: string; incremental?: string };
type SnapshotForAIOptions = { timeout?: number; track?: string };

export type WithSnapshotForAI = {
  _snapshotForAI?: (options?: SnapshotForAIOptions) => Promise<SnapshotForAIResult>;
};

const disabled = () => {
  throw new Error("Browser automation is disabled in this build.");
};

export function getPageForTargetId(..._args: unknown[]): never {
  return disabled();
}

export function listPagesViaPlaywright(..._args: unknown[]): never {
  return disabled();
}

export function createPageViaPlaywright(..._args: unknown[]): never {
  return disabled();
}

export function closePlaywrightBrowserConnection(..._args: unknown[]): never {
  return disabled();
}

export function closePageByTargetIdViaPlaywright(..._args: unknown[]): never {
  return disabled();
}

export function focusPageByTargetIdViaPlaywright(..._args: unknown[]): never {
  return disabled();
}

export function rememberRoleRefsForTarget(..._args: unknown[]): never {
  return disabled();
}

export function storeRoleRefsForTarget(..._args: unknown[]): never {
  return disabled();
}

export function restoreRoleRefsForTarget(..._args: unknown[]): never {
  return disabled();
}

export function ensurePageState(..._args: unknown[]): never {
  return disabled();
}

export function ensureContextState(..._args: unknown[]): never {
  return disabled();
}

export function refLocator(..._args: unknown[]): never {
  return disabled();
}
