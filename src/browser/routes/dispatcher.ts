import type { BrowserControlContext } from "../control-service.js";

type BrowserDispatchParams = {
  method: string;
  path: string;
  query?: Record<string, unknown>;
  body?: unknown;
};

type BrowserDispatchResult = {
  status: number;
  body: unknown;
};

export function createBrowserRouteDispatcher(_ctx: BrowserControlContext) {
  return {
    async dispatch(_params: BrowserDispatchParams): Promise<BrowserDispatchResult> {
      return {
        status: 503,
        body: {
          error: "browser control is disabled",
        },
      };
    },
  };
}
