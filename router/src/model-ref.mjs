// Adapted from openhanako/shared/model-ref.ts.
// Runtime model references are composite keys: { provider, id }.

export function parseModelRef(ref) {
  if (!ref) return null;
  if (typeof ref === "object") {
    if (!ref.id) return null;
    return { id: ref.id, provider: ref.provider || "" };
  }
  if (typeof ref !== "string") return null;
  const value = ref.trim();
  if (!value) return null;
  const slashIndex = value.indexOf("/");
  if (slashIndex > 0 && slashIndex < value.length - 1) {
    return { provider: value.slice(0, slashIndex), id: value.slice(slashIndex + 1) };
  }
  return { id: value, provider: "" };
}

export function requireModelRef(ref) {
  const parsed = parseModelRef(ref);
  if (!parsed || !parsed.id || !parsed.provider) {
    throw new Error(`requireModelRef: missing id or provider (got ${JSON.stringify(ref)})`);
  }
  return parsed;
}

export function findModel(available, id, provider) {
  if (!available) return null;
  if (typeof id === "object" && id !== null) return findModel(available, id.id, id.provider);
  if (!id || !provider) {
    throw new Error(`findModel: id and provider both required (got id=${id}, provider=${provider})`);
  }
  return available.find((model) => model.id === id && model.provider === provider) || null;
}

export function modelRefEquals(a, b) {
  if (!a || !b) return false;
  if (!a.id || !b.id || !a.provider || !b.provider) return false;
  return a.id === b.id && a.provider === b.provider;
}

export function modelRefKey(ref) {
  if (!ref?.id || !ref?.provider) {
    throw new Error(`modelRefKey: missing id or provider (got ${JSON.stringify(ref)})`);
  }
  return `${ref.provider}/${ref.id}`;
}
