import type { EmbeddingProvider, EmbeddingProviderOptions } from "./embeddings.js";
import { requireApiKey, resolveApiKeyForProvider } from "../agents/model-auth.js";
import { isTruthyEnvValue } from "../infra/env.js";
import { createSubsystemLogger } from "../logging/subsystem.js";

export type SiliconFlowEmbeddingClient = {
  baseUrl: string;
  headers: Record<string, string>;
  model: string;
};

export const DEFAULT_SILICONFLOW_EMBEDDING_MODEL = "BAAI/bge-m3";
const DEFAULT_SILICONFLOW_BASE_URL = "https://api.siliconflow.cn/v1";
const debugEmbeddings = isTruthyEnvValue(process.env.OPENCLAW_DEBUG_MEMORY_EMBEDDINGS);
const log = createSubsystemLogger("memory/embeddings");

const debugLog = (message: string, meta?: Record<string, unknown>) => {
  if (!debugEmbeddings) {
    return;
  }
  const suffix = meta ? ` ${JSON.stringify(meta)}` : "";
  log.raw(`${message}${suffix}`);
};

function normalizeSiliconFlowModel(model: string): string {
  const trimmed = model.trim();
  if (!trimmed) {
    return DEFAULT_SILICONFLOW_EMBEDDING_MODEL;
  }
  if (trimmed.startsWith("siliconflow/")) {
    return trimmed.slice("siliconflow/".length);
  }
  return trimmed;
}

export async function createSiliconFlowEmbeddingProvider(
  options: EmbeddingProviderOptions,
): Promise<{ provider: EmbeddingProvider; client: SiliconFlowEmbeddingClient }> {
  const client = await resolveSiliconFlowEmbeddingClient(options);
  const url = `${client.baseUrl.replace(/\/$/, "")}/embeddings`;

  const embed = async (input: string[]): Promise<number[][]> => {
    if (input.length === 0) {
      return [];
    }
    const res = await fetch(url, {
      method: "POST",
      headers: client.headers,
      body: JSON.stringify({ model: client.model, input }),
    });
    if (!res.ok) {
      const text = await res.text();
      throw new Error(`siliconflow embeddings failed: ${res.status} ${text}`);
    }
    const payload = (await res.json()) as {
      data?: Array<{ embedding?: number[] }>;
    };
    const data = payload.data ?? [];
    return data.map((entry) => entry.embedding ?? []);
  };

  return {
    provider: {
      id: "siliconflow",
      model: client.model,
      embedQuery: async (text) => {
        const [vec] = await embed([text]);
        return vec ?? [];
      },
      embedBatch: embed,
    },
    client,
  };
}

export async function resolveSiliconFlowEmbeddingClient(
  options: EmbeddingProviderOptions,
): Promise<SiliconFlowEmbeddingClient> {
  const override = options.siliconflow;
  const overrideKey = override?.apiKey?.trim();
  const apiKey = overrideKey
    ? overrideKey
    : requireApiKey(
        await resolveApiKeyForProvider({
          provider: "siliconflow",
          cfg: options.config,
          agentDir: options.agentDir,
        }),
        "siliconflow",
      );

  const providerConfig = options.config.models?.providers?.siliconflow;
  const baseUrl = providerConfig?.baseUrl?.trim() || DEFAULT_SILICONFLOW_BASE_URL;
  const headerOverrides = Object.assign({}, providerConfig?.headers);
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${apiKey}`,
    ...headerOverrides,
  };
  const model = normalizeSiliconFlowModel(override?.model ?? options.model);
  debugLog("memory embeddings: siliconflow client", {
    baseUrl,
    model,
    embedEndpoint: `${baseUrl.replace(/\/$/, "")}/embeddings`,
  });
  return { baseUrl, headers, model };
}
