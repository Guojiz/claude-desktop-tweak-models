const DEFAULT_CONTEXT_WINDOW = 128_000;

const KNOWN_MODELS = {
  zhipu: {
    "glm-5.2": { name: "GLM-5.2", context: 1_000_000, maxOutput: 131_072, reasoning: true },
    "glm-5.1": { name: "GLM-5.1", context: 1_000_000, maxOutput: 131_072, reasoning: true },
    "glm-5": { name: "GLM-5", context: 200_000, maxOutput: 128_000, reasoning: true },
    "glm-4.7-flash": { name: "GLM-4.7 Flash", context: 128_000, maxOutput: 16_384 },
  },
  dashscope: {
    "qwen-max": { name: "Qwen Max", context: 32_768, maxOutput: 8_192 },
    "qwen-plus": { name: "Qwen Plus", context: 131_072, maxOutput: 8_192 },
    "qwen-turbo": { name: "Qwen Turbo", context: 1_000_000, maxOutput: 8_192 },
  },
  anthropic: {
    "claude-sonnet-4-5": { name: "Claude Sonnet 4.5", context: 200_000, maxOutput: 64_000 },
    "claude-opus-4-1": { name: "Claude Opus 4.1", context: 200_000, maxOutput: 32_000 },
    "claude-haiku-3-5": { name: "Claude Haiku 3.5", context: 200_000, maxOutput: 8_192 },
  },
};

export function humanizeName(id) {
  let name = String(id || "").replace(/-(\d{6,8})$/, "");
  name = name.replace(/[-_]/g, " ").replace(/\b\w/g, (char) => char.toUpperCase());
  return name.replace(/(\d) (\d)/g, "$1.$2");
}

export function lookupKnown(provider, modelId) {
  if (!modelId) return null;
  const providerModels = KNOWN_MODELS[provider] || {};
  const exact = providerModels[modelId];
  if (exact) return exact;
  const lower = String(modelId).toLowerCase();
  for (const [id, entry] of Object.entries(providerModels)) {
    if (id.toLowerCase() === lower) return entry;
  }
  return null;
}

export function listKnownProviderModels(provider) {
  return Object.entries(KNOWN_MODELS[provider] || {}).map(([id, entry]) => ({ id, ...entry }));
}

export function withKnownDefaults(provider, modelId, entry = {}) {
  const known = lookupKnown(provider, modelId) || {};
  return {
    id: modelId,
    name: entry.name || known.name || humanizeName(modelId),
    context: entry.context ?? entry.contextWindow ?? known.context ?? DEFAULT_CONTEXT_WINDOW,
    maxOutput: entry.maxOutput ?? entry.maxTokens ?? known.maxOutput ?? 8_192,
    reasoning: entry.reasoning ?? known.reasoning ?? false,
  };
}
