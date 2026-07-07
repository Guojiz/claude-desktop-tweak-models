import fs from "node:fs";
import path from "node:path";
import { atomicWriteSync, readJsonTextWithoutBom } from "./safe-fs.mjs";

// Adapted from openhanako/core/provider-catalog.ts.

export const PROVIDER_CATALOG_VERSION = 2;
export const PROVIDER_CATALOG_FILE = "provider-catalog.json";

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function cloneData(value) {
  return structuredClone(value);
}

function normalizeDeletedProviders(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((id) => typeof id === "string" && id.trim()).map((id) => id.trim()))];
}

function normalizeProviderMap(value) {
  if (!isPlainObject(value)) return {};
  const providers = {};
  for (const [providerId, config] of Object.entries(value)) {
    const id = typeof providerId === "string" ? providerId.trim() : "";
    if (!id) continue;
    providers[id] = isPlainObject(config) ? cloneData(config) : { _config_error: "malformed_provider_config" };
  }
  return providers;
}

function normalizeCapabilities(value) {
  return isPlainObject(value) ? cloneData(value) : {};
}

export function normalizeProviderCatalog(value = {}) {
  const meta = isPlainObject(value.meta) ? cloneData(value.meta) : {};
  const deletedProviders = normalizeDeletedProviders(meta.deletedProviders);
  return {
    catalogVersion: PROVIDER_CATALOG_VERSION,
    providers: normalizeProviderMap(value.providers),
    capabilities: normalizeCapabilities(value.capabilities),
    meta: {
      ...meta,
      ...(deletedProviders.length > 0 ? { deletedProviders } : {}),
    },
  };
}

export class ProviderCatalogStore {
  constructor(routerHome) {
    if (!routerHome) throw new Error("ProviderCatalogStore requires routerHome");
    this._routerHome = routerHome;
  }

  get catalogPath() {
    return path.join(this._routerHome, PROVIDER_CATALOG_FILE);
  }

  load() {
    try {
      const parsed = JSON.parse(readJsonTextWithoutBom(this.catalogPath));
      if (parsed?.catalogVersion !== PROVIDER_CATALOG_VERSION) {
        throw new Error(`Unsupported provider catalog version: ${parsed?.catalogVersion ?? "missing"}`);
      }
      return normalizeProviderCatalog(parsed);
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      return this.save(normalizeProviderCatalog());
    }
  }

  save(catalog) {
    const normalized = normalizeProviderCatalog(catalog);
    fs.mkdirSync(this._routerHome, { recursive: true });
    atomicWriteSync(this.catalogPath, JSON.stringify(normalized, null, 2) + "\n");
    return normalized;
  }

  getProviders() {
    return cloneData(this.load().providers);
  }

  saveProviders(providers, meta = {}) {
    const current = this.load();
    const nextMeta = {
      ...(current.meta || {}),
      ...meta,
    };
    if (Array.isArray(meta.deletedProviders)) nextMeta.deletedProviders = normalizeDeletedProviders(meta.deletedProviders);
    return this.save({
      ...current,
      providers,
      meta: nextMeta,
    });
  }

  getDeletedProviders() {
    return normalizeDeletedProviders(this.load().meta?.deletedProviders);
  }
}
