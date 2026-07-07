import { lookupKnown, withKnownDefaults } from "./known-models.mjs";
import { validateProviderModels } from "./provider-model-validation.mjs";

// Adapted from openhanako/core/model-sync.ts, projected to this router runtime
// instead of Pi SDK models.json.

const DEFAULT_CLAUDE_SPOOF_MODELS = [
  "claude-sonnet-4-5",
  "claude-opus-4-1",
  "claude-haiku-3-5",
  "claude-3-5-sonnet-latest",
  "claude-3-5-haiku-latest",
];

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

export function getModelId(modelEntry) {
  if (typeof modelEntry === "object" && modelEntry !== null) return modelEntry.id;
  return modelEntry;
}

function getModelType(provider, modelEntry) {
  const isObject = typeof modelEntry === "object" && modelEntry !== null;
  const id = getModelId(modelEntry);
  return (isObject && modelEntry.type) || lookupKnown(provider, id)?.type || "chat";
}

function filterChatModelEntries(provider, models) {
  return (models || []).filter((entry) => getModelType(provider, entry) === "chat");
}

function normalizeProviderConfig(config = {}) {
  return {
    ...config,
    base_url: config.base_url || config.baseUrl || "",
    api_key: config.api_key || config.apiKey || "",
    display_name: config.display_name || config.displayName,
  };
}

function normalizeModelEntry(modelEntry) {
  if (typeof modelEntry === "object" && modelEntry !== null) return modelEntry;
  return { id: modelEntry };
}

function configExposure(config = {}) {
  const exposure = config.claudeExposure || config.exposure || {};
  return {
    mode: exposure.mode || "auto",
    patchStatus: exposure.patchStatus || "unknown",
    spoofModel: exposure.spoofModel || exposure.spoof_model || DEFAULT_CLAUDE_SPOOF_MODELS[0],
    spoofModels: exposure.spoofModels || exposure.spoof_models || DEFAULT_CLAUDE_SPOOF_MODELS,
  };
}

function modelExposure(modelEntry, globalExposure, index) {
  const entry = normalizeModelEntry(modelEntry);
  const local = entry.claude || entry.exposure || {};
  const mode = local.mode || globalExposure.mode;
  const patchStatus = local.patchStatus || globalExposure.patchStatus;
  const spoofModels = local.spoofModels || local.spoof_models || globalExposure.spoofModels;
  const autoSpoof = Array.isArray(spoofModels) && spoofModels.length > 0
    ? spoofModels[index % spoofModels.length]
    : globalExposure.spoofModel;
  return {
    mode,
    patchStatus,
    exposedId: local.id || local.exposedId || local.exposed_id || entry.exposedId || entry.exposed_id,
    spoofModel: local.spoofModel || local.spoof_model || entry.spoofModel || entry.spoof_model || autoSpoof,
    aliases: local.aliases || entry.aliases || [],
  };
}

function resolveExposureMode(exposure) {
  if (exposure.mode !== "auto") return exposure.mode;
  return exposure.patchStatus === "patched" ? "real" : "spoof";
}

export function getClaudeExposedModelId(providerId, modelEntry, globalExposure, index = 0) {
  const entry = normalizeModelEntry(modelEntry);
  const id = entry.id;
  const exposure = modelExposure(entry, globalExposure, index);
  if (exposure.exposedId) return exposure.exposedId;
  const mode = resolveExposureMode(exposure);
  if (mode === "provider-ref") return `${providerId}/${id}`;
  if (mode === "spoof") return exposure.spoofModel;
  return id;
}

function buildRoute(modelEntry, providerId, provider, globalExposure, index) {
  const entry = normalizeModelEntry(modelEntry);
  const id = entry.id;
  const known = withKnownDefaults(providerId, id, entry);
  const exposedId = getClaudeExposedModelId(providerId, entry, globalExposure, index);
  const exposure = modelExposure(entry, globalExposure, index);
  return {
    id,
    provider: providerId,
    upstreamModel: entry.upstreamModel || entry.upstream_model || id,
    exposedId,
    displayName: entry.name || entry.displayName || known.name,
    contextWindow: known.context,
    maxOutput: known.maxOutput,
    reasoning: known.reasoning,
    aliases: [...new Set([...(Array.isArray(exposure.aliases) ? exposure.aliases : []), exposedId])],
    claudeExposure: {
      mode: resolveExposureMode(exposure),
      configuredMode: exposure.mode,
      patchStatus: exposure.patchStatus,
      spoofModel: exposure.spoofModel,
    },
    api: provider.api || "openai-completions",
    baseUrl: provider.base_url,
  };
}

export function syncModels(providers, opts = {}) {
  const config = opts.config || {};
  const globalExposure = configExposure(config);
  const routes = [];
  const warnings = [];
  const seenExposedIds = new Map();

  for (const [providerId, rawProvider] of Object.entries(providers || {})) {
    const provider = normalizeProviderConfig(rawProvider);
    if (!provider.base_url) continue;
    if (!Array.isArray(provider.models) || provider.models.length === 0) continue;
    validateProviderModels(providerId, provider.models, { baseUrl: provider.base_url });

    const chatModels = filterChatModelEntries(providerId, provider.models);
    chatModels.forEach((modelEntry, index) => {
      const id = getModelId(modelEntry);
      if (!id) return;
      const route = buildRoute(modelEntry, providerId, provider, globalExposure, routes.length + index);
      if (seenExposedIds.has(route.exposedId)) {
        warnings.push({
          code: "DUPLICATE_EXPOSED_MODEL_ID",
          exposedId: route.exposedId,
          first: seenExposedIds.get(route.exposedId),
          duplicate: { provider: providerId, id },
        });
      } else {
        seenExposedIds.set(route.exposedId, { provider: providerId, id });
      }
      routes.push(route);
    });
  }

  return {
    routes,
    warnings,
    exposure: globalExposure,
  };
}

export function buildProvidersFromConfig(config = {}, registry) {
  const providers = {};
  const rawProviders = registry?.getAllProvidersRaw?.() || {};
  for (const [providerId, provider] of Object.entries(rawProviders)) {
    providers[providerId] = normalizeProviderConfig(provider);
  }

  for (const [providerId, provider] of Object.entries(config.providers || {})) {
    const entry = registry?.get?.(providerId);
    const normalized = normalizeProviderConfig({
      ...entry,
      ...providers[providerId],
      ...provider,
      base_url: provider.base_url || provider.baseUrl || providers[providerId]?.base_url || entry?.baseUrl,
      api: provider.api || providers[providerId]?.api || entry?.api,
      api_key: provider.api_key || provider.apiKey || resolveConfigSecret(provider.auth) || providers[providerId]?.api_key,
      auth_type: provider.auth_type || provider.authType || providers[providerId]?.auth_type || entry?.authType,
    });
    normalized.headers = {
      ...(providers[providerId]?.headers || {}),
      ...(provider.headers || {}),
    };
    normalized.models = [
      ...(Array.isArray(normalized.models) ? normalized.models : []),
      ...modelsForProvider(config.models, providerId),
    ];
    providers[providerId] = normalized;
  }

  return providers;
}

function modelsForProvider(models, providerId) {
  if (!Array.isArray(models)) return [];
  return models
    .filter((model) => isPlainObject(model) && model.provider === providerId)
    .map((model) => {
      const { provider: _provider, ...rest } = model;
      return rest;
    });
}

function resolveConfigSecret(auth = {}) {
  if (!auth) return "";
  if (auth.value) return auth.value;
  if (auth.env) return process.env[auth.env] || "";
  return "";
}

export function resolveRoute(routes, requestedModel) {
  if (!requestedModel) return null;
  const direct = routes.find((route) => route.exposedId === requestedModel);
  if (direct) return direct;
  const alias = routes.find((route) => route.aliases?.includes(requestedModel));
  if (alias) return alias;
  const parsed = requestedModel.includes("/") ? requestedModel.split("/") : null;
  if (parsed?.length === 2) {
    const [provider, id] = parsed;
    return routes.find((route) => route.provider === provider && route.id === id) || null;
  }
  return null;
}

export function chooseDefaultRoute(routes, config = {}) {
  const defaultRef = config.defaultModel || config.default_model;
  if (typeof defaultRef === "string") return resolveRoute(routes, defaultRef) || routes[0] || null;
  if (defaultRef && typeof defaultRef === "object") {
    return routes.find((route) => route.provider === defaultRef.provider && route.id === defaultRef.id) || routes[0] || null;
  }
  return routes[0] || null;
}
