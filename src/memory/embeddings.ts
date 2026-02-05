import type { OpenClawConfig } from "../config/config.js";
import { createGeminiEmbeddingProvider, type GeminiEmbeddingClient } from "./embeddings-gemini.js";
import { createOpenAiEmbeddingProvider, type OpenAiEmbeddingClient } from "./embeddings-openai.js";

function sanitizeAndNormalizeEmbedding(vec: number[]): number[] {
  const sanitized = vec.map((value) => (Number.isFinite(value) ? value : 0));
  const magnitude = Math.sqrt(sanitized.reduce((sum, value) => sum + value * value, 0));
  if (magnitude < 1e-10) {
    return sanitized;
  }
  return sanitized.map((value) => value / magnitude);
}

export type { GeminiEmbeddingClient } from "./embeddings-gemini.js";
export type { OpenAiEmbeddingClient } from "./embeddings-openai.js";

export type EmbeddingProvider = {
  id: string;
  model: string;
  embedQuery: (text: string) => Promise<number[]>;
  embedBatch: (texts: string[]) => Promise<number[][]>;
};

export type EmbeddingProviderResult = {
  provider: EmbeddingProvider;
  requestedProvider: "openai" | "gemini" | "auto";
  fallbackFrom?: "openai" | "gemini";
  fallbackReason?: string;
  openAi?: OpenAiEmbeddingClient;
  gemini?: GeminiEmbeddingClient;
};

export type EmbeddingProviderOptions = {
  config: OpenClawConfig;
  agentDir?: string;
  provider: "openai" | "gemini" | "auto";
  remote?: {
    baseUrl?: string;
    apiKey?: string;
    headers?: Record<string, string>;
  };
  model: string;
  fallback: "openai" | "gemini" | "none";
};

function isMissingApiKeyError(err: unknown): boolean {
  const message = formatError(err);
  return message.includes("No API key found for provider");
}

export async function createEmbeddingProvider(
  options: EmbeddingProviderOptions,
): Promise<EmbeddingProviderResult> {
  const requestedProvider = options.provider;
  const fallback = options.fallback;

  const createProvider = async (id: "openai" | "gemini") => {
    if (id === "gemini") {
      const { provider, client } = await createGeminiEmbeddingProvider(options);
      return { provider, gemini: client };
    }
    const { provider, client } = await createOpenAiEmbeddingProvider(options);
    return { provider, openAi: client };
  };

  const formatPrimaryError = (err: unknown) => formatError(err);

  if (requestedProvider === "auto") {
    const missingKeyErrors: string[] = [];

    for (const provider of ["openai", "gemini"] as const) {
      try {
        const result = await createProvider(provider);
        return { ...result, requestedProvider };
      } catch (err) {
        const message = formatPrimaryError(err);
        if (isMissingApiKeyError(err)) {
          missingKeyErrors.push(message);
          continue;
        }
        throw new Error(message, { cause: err });
      }
    }

    if (missingKeyErrors.length > 0) {
      throw new Error(missingKeyErrors.join("\n\n"));
    }
    throw new Error("No embeddings provider available.");
  }

  try {
    const primary = await createProvider(requestedProvider);
    return { ...primary, requestedProvider };
  } catch (primaryErr) {
    const reason = formatPrimaryError(primaryErr);
    if (fallback && fallback !== "none" && fallback !== requestedProvider) {
      try {
        const fallbackResult = await createProvider(fallback);
        return {
          ...fallbackResult,
          requestedProvider,
          fallbackFrom: requestedProvider,
          fallbackReason: reason,
        };
      } catch (fallbackErr) {
        // oxlint-disable-next-line preserve-caught-error
        throw new Error(
          `${reason}\n\nFallback to ${fallback} failed: ${formatError(fallbackErr)}`,
          { cause: fallbackErr },
        );
      }
    }
    throw new Error(reason, { cause: primaryErr });
  }
}

function formatError(err: unknown): string {
  if (err instanceof Error) {
    return err.message;
  }
  return String(err);
}
