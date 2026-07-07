#!/usr/bin/env node
import http from "node:http";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import { ProviderRegistry } from "./src/provider-registry.mjs";
import {
  buildProvidersFromConfig,
  chooseDefaultRoute,
  resolveRoute,
  syncModels,
} from "./src/model-sync.mjs";

const DEFAULT_PORT = 4318;
const DEFAULT_HOST = "127.0.0.1";

function expandHome(value) {
  if (!value) return value;
  return value.replace(/^~(?=$|[\\/])/, homedir());
}

function defaultRouterHome() {
  return path.join(homedir(), ".claude-desktop-tweak-models");
}

function defaultConfigPath() {
  return path.join(defaultRouterHome(), "router.config.json");
}

function parseArgs(argv) {
  const args = {
    config: process.env.CLAUDE_ROUTER_CONFIG || defaultConfigPath(),
    host: process.env.CLAUDE_ROUTER_HOST,
    port: process.env.CLAUDE_ROUTER_PORT ? Number(process.env.CLAUDE_ROUTER_PORT) : undefined,
    home: process.env.CLAUDE_ROUTER_HOME || defaultRouterHome(),
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--config") args.config = argv[++i];
    else if (arg === "--host") args.host = argv[++i];
    else if (arg === "--port") args.port = Number(argv[++i]);
    else if (arg === "--home") args.home = argv[++i];
    else if (arg === "--help" || arg === "-h") {
      console.log("Usage: node router/claude-model-router.mjs [--config path] [--host 127.0.0.1] [--port 4318]");
      process.exit(0);
    }
  }

  return args;
}

async function loadConfig(configPath) {
  const resolved = expandHome(configPath);
  if (!existsSync(resolved)) throw new Error(`Router config not found: ${resolved}`);
  const raw = await readFile(resolved, "utf8");
  const config = JSON.parse(raw);
  validateConfig(config);
  return config;
}

function validateConfig(config) {
  if (!config || typeof config !== "object") throw new Error("Config must be a JSON object.");
  if (!config.providers || typeof config.providers !== "object") throw new Error("Config requires providers.");
}

function jsonResponse(res, status, body, extraHeaders = {}) {
  const payload = JSON.stringify(body, null, 2);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(payload),
    ...extraHeaders,
  });
  res.end(payload);
}

function htmlResponse(res, body) {
  res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
  res.end(body);
}

async function readJsonBody(req) {
  let body = "";
  for await (const chunk of req) body += chunk;
  if (!body.trim()) return {};
  return JSON.parse(body);
}

function normalizeBaseUrl(baseUrl) {
  return String(baseUrl || "").replace(/\/+$/, "");
}

function appendPath(baseUrl, suffix) {
  const cleanBase = normalizeBaseUrl(baseUrl);
  const cleanSuffix = suffix.startsWith("/") ? suffix : `/${suffix}`;
  if (cleanBase.endsWith(cleanSuffix)) return cleanBase;
  return `${cleanBase}${cleanSuffix}`;
}

function contentToText(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content.map((part) => {
    if (typeof part === "string") return part;
    if (part.type === "text") return part.text || "";
    return "";
  }).join("\n");
}

function toOpenAiMessages(anthropicRequest) {
  const messages = [];
  if (anthropicRequest.system) {
    const system = Array.isArray(anthropicRequest.system)
      ? anthropicRequest.system.map((part) => typeof part === "string" ? part : part.text || "").join("\n")
      : String(anthropicRequest.system);
    if (system.trim()) messages.push({ role: "system", content: system });
  }
  for (const message of anthropicRequest.messages || []) {
    messages.push({
      role: message.role === "assistant" ? "assistant" : "user",
      content: contentToText(message.content),
    });
  }
  return messages;
}

function textAnthropicMessage(model, text, usage = {}) {
  return {
    id: `msg_${Date.now()}`,
    type: "message",
    role: "assistant",
    model,
    content: [{ type: "text", text }],
    stop_reason: "end_turn",
    stop_sequence: null,
    usage: {
      input_tokens: usage.input_tokens || 0,
      output_tokens: usage.output_tokens || 0,
    },
  };
}

function checkLocalAuth(config, req) {
  const expected = config.routerApiKey || process.env.CLAUDE_ROUTER_API_KEY;
  if (!expected) return true;
  const authorization = req.headers.authorization || "";
  const apiKey = req.headers["x-api-key"];
  return authorization === `Bearer ${expected}` || apiKey === expected;
}

function buildAuthHeaders(provider, req) {
  const apiKey = provider.api_key || provider.apiKey || "";
  const scheme = provider.auth?.scheme || (provider.api === "anthropic-messages" ? "x-api-key" : "bearer");
  const headers = { ...(provider.headers || {}) };
  if (provider.api === "anthropic-messages") {
    headers["anthropic-version"] = provider.anthropicVersion || req.headers["anthropic-version"] || "2023-06-01";
  }
  if (!apiKey) return headers;
  if (scheme === "x-api-key") headers["x-api-key"] = apiKey;
  else if (scheme === "api-key") headers["api-key"] = apiKey;
  else headers.authorization = `Bearer ${apiKey}`;
  return headers;
}

function buildRuntime(config, routerHome) {
  const registry = new ProviderRegistry(routerHome);
  const providers = buildProvidersFromConfig(config, registry);
  const synced = syncModels(providers, { config });
  return { registry, providers, routes: synced.routes, warnings: synced.warnings, exposure: synced.exposure };
}

function listModels(runtime) {
  return {
    object: "list",
    data: runtime.routes.map((route) => ({
      id: route.exposedId,
      object: "model",
      display_name: route.displayName || route.exposedId,
      created: 0,
      owned_by: route.provider,
    })),
  };
}

function statusPayload(runtime, config) {
  return {
    ok: true,
    exposure: runtime.exposure,
    fillInClaude: runtime.routes.map((route) => ({
      claudeModelId: route.exposedId,
      routesTo: `${route.provider}/${route.id}`,
      upstreamModel: route.upstreamModel,
      exposureMode: route.claudeExposure.mode,
    })),
    defaultModel: chooseDefaultRoute(runtime.routes, config)?.exposedId || null,
    warnings: runtime.warnings,
  };
}

function renderStatusPage(runtime, config) {
  const status = statusPayload(runtime, config);
  const rows = status.fillInClaude.map((row) => `
    <tr>
      <td><code>${escapeHtml(row.claudeModelId)}</code></td>
      <td><code>${escapeHtml(row.routesTo)}</code></td>
      <td>${escapeHtml(row.exposureMode)}</td>
      <td><code>${escapeHtml(row.upstreamModel)}</code></td>
    </tr>`).join("");
  const warningRows = runtime.warnings.map((warning) => `<li><code>${escapeHtml(warning.code)}</code>: ${escapeHtml(warning.exposedId || "")}</li>`).join("");
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Claude Model Router</title>
  <style>
    body { font-family: system-ui, -apple-system, Segoe UI, sans-serif; margin: 24px; color: #202124; }
    table { border-collapse: collapse; width: 100%; margin-top: 16px; }
    th, td { border-bottom: 1px solid #ddd; padding: 10px 8px; text-align: left; }
    code { background: #f4f4f4; padding: 2px 5px; border-radius: 4px; }
    .ok { color: #137333; font-weight: 650; }
    .warn { color: #b06000; }
  </style>
</head>
<body>
  <h1>Claude Model Router</h1>
  <p class="ok">运行中。把下面的 Claude Model ID 填到 Claude Desktop 第三方模型配置里。</p>
  <p>当前暴露模式: <code>${escapeHtml(status.exposure.mode)}</code>；默认模型: <code>${escapeHtml(status.defaultModel || "")}</code></p>
  <table>
    <thead><tr><th>填入 Claude 的 Model ID</th><th>真实路由</th><th>模式</th><th>上游模型</th></tr></thead>
    <tbody>${rows}</tbody>
  </table>
  ${warningRows ? `<h2 class="warn">Warnings</h2><ul>${warningRows}</ul>` : ""}
</body>
</html>`;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function proxyAnthropic(req, res, provider, route, body) {
  const url = appendPath(provider.base_url || provider.baseUrl, provider.messagesPath || "/v1/messages");
  const upstreamBody = JSON.stringify({ ...body, model: route.upstreamModel || route.id });
  const upstream = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...buildAuthHeaders(provider, req),
    },
    body: upstreamBody,
  });

  if (body.stream && upstream.headers.get("content-type")?.includes("text/event-stream")) {
    res.writeHead(upstream.status, {
      "content-type": "text/event-stream; charset=utf-8",
      "cache-control": "no-cache",
      connection: "keep-alive",
    });
    for await (const chunk of upstream.body) res.write(chunk);
    res.end();
    return;
  }

  const text = await upstream.text();
  const contentType = upstream.headers.get("content-type") || "application/json; charset=utf-8";
  if (contentType.includes("application/json")) {
    try {
      const data = JSON.parse(text);
      if (data && typeof data === "object") data.model = route.exposedId;
      jsonResponse(res, upstream.status, data);
      return;
    } catch {
      // fall through
    }
  }
  res.writeHead(upstream.status, { "content-type": contentType });
  res.end(text);
}

async function proxyOpenAi(req, res, provider, route, body) {
  const url = appendPath(provider.base_url || provider.baseUrl, provider.chatCompletionsPath || "/chat/completions");
  const upstreamBody = {
    model: route.upstreamModel || route.id,
    messages: toOpenAiMessages(body),
    stream: Boolean(body.stream),
    max_tokens: body.max_tokens,
    temperature: body.temperature,
  };

  const upstream = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...buildAuthHeaders(provider, req),
    },
    body: JSON.stringify(upstreamBody),
  });

  if (body.stream) {
    await streamOpenAiAsAnthropic(res, upstream, route.exposedId);
    return;
  }

  const data = await upstream.json().catch(async () => ({ error: { message: await upstream.text() } }));
  if (!upstream.ok) {
    jsonResponse(res, upstream.status, data);
    return;
  }

  const text = data.choices?.[0]?.message?.content || "";
  jsonResponse(res, 200, textAnthropicMessage(route.exposedId, text, {
    input_tokens: data.usage?.prompt_tokens || 0,
    output_tokens: data.usage?.completion_tokens || 0,
  }));
}

async function streamOpenAiAsAnthropic(res, upstream, model) {
  if (!upstream.ok) {
    const text = await upstream.text();
    jsonResponse(res, upstream.status, { error: { message: text } });
    return;
  }

  res.writeHead(200, {
    "content-type": "text/event-stream; charset=utf-8",
    "cache-control": "no-cache",
    connection: "keep-alive",
  });

  const message = textAnthropicMessage(model, "");
  message.content = [];
  message.stop_reason = null;
  writeSse(res, "message_start", { type: "message_start", message });
  writeSse(res, "content_block_start", {
    type: "content_block_start",
    index: 0,
    content_block: { type: "text", text: "" },
  });

  let buffer = "";
  for await (const chunk of upstream.body) {
    buffer += Buffer.from(chunk).toString("utf8");
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() || "";
    for (const line of lines) {
      if (!line.startsWith("data:")) continue;
      const payload = line.slice(5).trim();
      if (!payload || payload === "[DONE]") continue;
      const data = JSON.parse(payload);
      const delta = data.choices?.[0]?.delta?.content;
      if (!delta) continue;
      writeSse(res, "content_block_delta", {
        type: "content_block_delta",
        index: 0,
        delta: { type: "text_delta", text: delta },
      });
    }
  }

  writeSse(res, "content_block_stop", { type: "content_block_stop", index: 0 });
  writeSse(res, "message_delta", {
    type: "message_delta",
    delta: { stop_reason: "end_turn", stop_sequence: null },
    usage: { output_tokens: 0 },
  });
  writeSse(res, "message_stop", { type: "message_stop" });
  res.end();
}

function writeSse(res, event, data) {
  res.write(`event: ${event}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

async function handleMessages(req, res, runtime, config) {
  if (!checkLocalAuth(config, req)) {
    jsonResponse(res, 401, { error: { message: "Invalid local router credential." } });
    return;
  }

  const body = await readJsonBody(req);
  const route = resolveRoute(runtime.routes, body.model) || chooseDefaultRoute(runtime.routes, config);
  if (!route) {
    jsonResponse(res, 400, { error: { message: "No routable model configured." } });
    return;
  }

  const provider = runtime.providers[route.provider];
  if (!provider) {
    jsonResponse(res, 400, { error: { message: `Missing provider: ${route.provider}` } });
    return;
  }

  res.setHeader("x-claude-router-selected-model", `${route.provider}/${route.id}`);
  res.setHeader("x-claude-router-exposed-model", route.exposedId);

  if (provider.api === "anthropic-messages" || provider.kind === "anthropic") {
    await proxyAnthropic(req, res, provider, route, body);
  } else if (provider.api === "openai-completions" || provider.kind === "openai") {
    await proxyOpenAi(req, res, provider, route, body);
  } else if (provider.kind === "chatgpt") {
    jsonResponse(res, 501, {
      error: {
        message: "ChatGPT plan / no-API-key providers require a provider plugin adapter. The route slot is reserved but not implemented.",
      },
    });
  } else {
    jsonResponse(res, 400, { error: { message: `Unsupported provider api: ${provider.api || provider.kind}` } });
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const config = await loadConfig(args.config);
  const host = args.host || config.host || DEFAULT_HOST;
  const port = Number(args.port || config.port || DEFAULT_PORT);
  let runtime = buildRuntime(config, expandHome(args.home));

  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, `http://${req.headers.host || `${host}:${port}`}`);

      if (req.method === "GET" && url.pathname === "/") {
        htmlResponse(res, renderStatusPage(runtime, config));
        return;
      }

      if (req.method === "POST" && url.pathname === "/reload") {
        runtime = buildRuntime(config, expandHome(args.home));
        jsonResponse(res, 200, statusPayload(runtime, config));
        return;
      }

      if (req.method === "GET" && (url.pathname === "/health" || url.pathname === "/status")) {
        jsonResponse(res, 200, statusPayload(runtime, config));
        return;
      }

      if (req.method === "GET" && url.pathname === "/v1/models") {
        jsonResponse(res, 200, listModels(runtime));
        return;
      }

      if (req.method === "POST" && url.pathname === "/v1/messages") {
        await handleMessages(req, res, runtime, config);
        return;
      }

      jsonResponse(res, 404, { error: { message: `Unknown route: ${req.method} ${url.pathname}` } });
    } catch (error) {
      jsonResponse(res, 500, { error: { message: error?.message || String(error) } });
    }
  });

  server.listen(port, host, () => {
    console.log(`Claude model router listening on http://${host}:${port}`);
    console.log(`Config: ${expandHome(args.config)}`);
    console.log("Open the status UI in a browser, then copy the shown Claude Model ID into Claude Desktop.");
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
