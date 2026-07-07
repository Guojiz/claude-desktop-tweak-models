import { ProviderCatalogStore } from "./provider-catalog.mjs";
import { BUILTIN_PLUGINS } from "./provider-plugins.mjs";
import { validateProviderModels } from "./provider-model-validation.mjs";

// Adapted from openhanako/core/provider-registry.ts.

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function normalizeProviderAuthType(value) {
  const normalized = String(value || "api-key").trim();
  return normalized || "api-key";
}

export function normalizeProviderHeaders(value) {
  if (!isPlainObject(value)) return {};
  const headers = {};
  for (const [key, headerValue] of Object.entries(value)) {
    if (typeof key !== "string" || !key.trim()) continue;
    if (headerValue === undefined || headerValue === null) continue;
    headers[key.trim()] = String(headerValue);
  }
  return headers;
}

function getModelId(modelEntry) {
  if (typeof modelEntry === "object" && modelEntry !== null) return modelEntry.id;
  return modelEntry;
}

function normalizeProviderUserConfig(value) {
  if (!isPlainObject(value)) return { _config_error: "malformed_provider_config" };
  const next = { ...value };
  if (Object.prototype.hasOwnProperty.call(next, "models") && !Array.isArray(next.models)) {
    delete next.models;
    next._config_error = next._config_error || "invalid_models_config";
  } else if (Array.isArray(next.models)) {
    const models = [];
    for (const model of next.models) {
      if (typeof model === "string" && model.trim()) {
        models.push(model.trim());
        continue;
      }
      if (isPlainObject(model) && typeof model.id === "string" && model.id.trim()) {
        models.push({ ...model, id: model.id.trim() });
        continue;
      }
      next._config_error = next._config_error || "invalid_models_config";
    }
    next.models = models;
  }
  return next;
}

function normalizeProviderUserConfigMap(providers) {
  if (!isPlainObject(providers)) return {};
  const normalized = {};
  for (const [providerId, config] of Object.entries(providers)) {
    if (!providerId) continue;
    normalized[providerId] = normalizeProviderUserConfig(config);
  }
  return normalized;
}

function mergeModelMetadata(base, patch) {
  return { ...(base || {}), ...(patch || {}) };
}

export class ProviderRegistry {
  constructor(routerHome) {
    this._routerHome = routerHome;
    this._catalog = new ProviderCatalogStore(routerHome);
    this._plugins = new Map();
    this._builtinPlugins = new Map();
    this._entries = new Map();
    for (const plugin of BUILTIN_PLUGINS) {
      this._plugins.set(plugin.id, plugin);
      this._builtinPlugins.set(plugin.id, plugin);
    }
  }

  register(plugin) {
    if (!plugin?.id) throw new Error("ProviderPlugin must have an id");
    this._plugins.set(plugin.id, plugin);
    this._entries.clear();
  }

  reload() {
    this._entries.clear();
    const userConfig = this.getAllProvidersRaw();

    for (const [id, plugin] of this._plugins) {
      const config = userConfig[id] || {};
      this._entries.set(id, this._merge(plugin, config, this._builtinPlugins.get(id) === plugin));
    }

    for (const [id, config] of Object.entries(userConfig)) {
      if (this._entries.has(id)) continue;
      const syntheticPlugin = {
        id,
        displayName: config.display_name || config.displayName || id,
        authType: normalizeProviderAuthType(config.auth_type || config.authType),
        defaultBaseUrl: config.base_url || config.baseUrl || "",
        defaultApi: config.api || "openai-completions",
        source: { kind: "user" },
      };
      this._entries.set(id, this._merge(syntheticPlugin, config, false));
    }
  }

  _merge(plugin, userConfig, isBuiltin) {
    return {
      id: plugin.id,
      displayName: userConfig.display_name || userConfig.displayName || plugin.displayName || plugin.id,
      authType: normalizeProviderAuthType(userConfig.auth_type || userConfig.authType || plugin.authType),
      baseUrl: userConfig.base_url || userConfig.baseUrl || plugin.defaultBaseUrl || "",
      api: userConfig.api || plugin.defaultApi || "openai-completions",
      headers: normalizeProviderHeaders(userConfig.headers || plugin.headers),
      authJsonKey: plugin.authJsonKey || plugin.id,
      isBuiltin,
      source: plugin.source || { kind: isBuiltin ? "builtin" : "user" },
    };
  }

  getAll() {
    if (this._entries.size === 0) this.reload();
    return this._entries;
  }

  get(providerId) {
    if (this._entries.size === 0) this.reload();
    return this._entries.get(providerId) || null;
  }

  getAllProvidersRaw() {
    return normalizeProviderUserConfigMap(this._catalog.getProviders());
  }

  importProviders(providers, meta = {}) {
    const existing = this.getAllProvidersRaw();
    this._catalog.saveProviders({ ...existing, ...normalizeProviderUserConfigMap(providers) }, meta);
    this._entries.clear();
  }

  resolveChatProvider(providerId) {
    const entry = this.get(providerId);
    if (!entry) return null;
    return {
      originalProviderId: providerId,
      providerId: entry.id,
      displayProviderId: entry.id,
      projection: "router-runtime",
      allowListSource: "provider.models",
      entry,
    };
  }

  getChatProjection(providerId) {
    return this.resolveChatProvider(providerId)?.projection || "router-runtime";
  }

  getChatModelIds(providerId) {
    const models = this.getAllProvidersRaw()[providerId]?.models || [];
    return models.map(getModelId).filter(Boolean);
  }

  getCredentials(providerId) {
    const entry = this.get(providerId);
    const raw = this.getAllProvidersRaw()[providerId] || {};
    if (!entry && !raw) return null;
    return {
      apiKey: raw.api_key || raw.apiKey || "",
      baseUrl: raw.base_url || raw.baseUrl || entry?.baseUrl || "",
      api: raw.api || entry?.api || "openai-completions",
      headers: normalizeProviderHeaders(raw.headers || entry?.headers),
      authType: raw.auth_type || raw.authType || entry?.authType || "api-key",
    };
  }

  saveProvider(providerId, data) {
    const userConfig = this.getAllProvidersRaw();
    const nextProvider = { ...(userConfig[providerId] || {}), ...(data || {}) };
    const baseUrl = nextProvider.base_url || nextProvider.baseUrl || this.get(providerId)?.baseUrl;
    validateProviderModels(providerId, nextProvider.models, { baseUrl });
    userConfig[providerId] = nextProvider;
    const deletedProviders = this._catalog.getDeletedProviders().filter((id) => id !== providerId);
    this._catalog.saveProviders(userConfig, { deletedProviders });
    this._entries.clear();
  }

  addModel(providerId, model) {
    const rawProvider = this.getAllProvidersRaw()[providerId] || {};
    const models = Array.isArray(rawProvider.models) ? rawProvider.models : [];
    const newId = getModelId(model);
    if (!newId || models.some((item) => getModelId(item) === newId)) return;
    this.saveProvider(providerId, { models: [...models, model] });
  }

  removeModel(providerId, modelId) {
    const rawProvider = this.getAllProvidersRaw()[providerId];
    if (!Array.isArray(rawProvider?.models)) return;
    this.saveProvider(providerId, { models: rawProvider.models.filter((item) => getModelId(item) !== modelId) });
  }

  updateModelEntry(providerId, modelId, meta) {
    const rawProvider = this.getAllProvidersRaw()[providerId] || {};
    const models = Array.isArray(rawProvider.models) ? rawProvider.models : [];
    let found = false;
    const nextModels = models.map((model) => {
      const id = getModelId(model);
      if (id !== modelId) return model;
      found = true;
      return mergeModelMetadata(typeof model === "object" ? model : { id }, meta);
    });
    if (!found) nextModels.push({ id: modelId, ...(meta || {}) });
    this.saveProvider(providerId, { models: nextModels });
  }
}
