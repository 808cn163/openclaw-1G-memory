import type { OpenClawConfig } from "../config/config.js";
import { createGeminiEmbeddingProvider, type GeminiEmbeddingClient } from "./embeddings-gemini.js";
import { createOpenAiEmbeddingProvider, type OpenAiEmbeddingClient } from "./embeddings-openai.js";
import {
  createSiliconFlowEmbeddingProvider,
  type SiliconFlowEmbeddingClient,
} from "./embeddings-siliconflow.js";

export type { GeminiEmbeddingClient } from "./embeddings-gemini.js";
export type { OpenAiEmbeddingClient } from "./embeddings-openai.js";
export type { SiliconFlowEmbeddingClient } from "./embeddings-siliconflow.js";

export type EmbeddingProvider = {
  id: string;
  model: string;
  embedQuery: (text: string) => Promise<number[]>;
  embedBatch: (texts: string[]) => Promise<number[][]>;
};

export type EmbeddingProviderResult = {
  provider: EmbeddingProvider;
  requestedProvider: "openai" | "gemini" | "siliconflow" | "auto";
  fallbackFrom?: "openai" | "gemini" | "siliconflow";
  fallbackReason?: string;
  openAi?: OpenAiEmbeddingClient;
  gemini?: GeminiEmbeddingClient;
  siliconflow?: SiliconFlowEmbeddingClient;
};

export type EmbeddingProviderOptions = {
  config: OpenClawConfig;
  agentDir?: string;
  provider: "openai" | "gemini" | "siliconflow" | "auto";
  remote?: {
    baseUrl?: string;
    apiKey?: string;
    headers?: Record<string, string>;
  };
  siliconflow?: {
    apiKey?: string;
    model?: string;
  };
  model: string;
  fallback: "openai" | "gemini" | "siliconflow" | "none";
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

  const createProvider = async (id: "openai" | "gemini" | "siliconflow") => {
    if (id === "gemini") {
      const { provider, client } = await createGeminiEmbeddingProvider(options);
      return { provider, gemini: client };
    }
    if (id === "siliconflow") {
      const { provider, client } = await createSiliconFlowEmbeddingProvider(options);
      return { provider, siliconflow: client };
    }
    const { provider, client } = await createOpenAiEmbeddingProvider(options);
    return { provider, openAi: client };
  };

  const formatPrimaryError = (err: unknown) => formatError(err);

  if (requestedProvider === "auto") {
    const missingKeyErrors: string[] = [];

    for (const provider of ["openai", "gemini", "siliconflow"] as const) {
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
