export const zhipuPlugin = {
  id: "zhipu",
  displayName: "Zhipu AI (GLM)",
  authType: "api-key",
  defaultBaseUrl: "https://open.bigmodel.cn/api/paas/v4",
  defaultApi: "openai-completions",
};

export const dashscopePlugin = {
  id: "dashscope",
  displayName: "DashScope",
  authType: "api-key",
  defaultBaseUrl: "https://dashscope.aliyuncs.com/compatible-mode/v1",
  defaultApi: "openai-completions",
};

export const openaiPlugin = {
  id: "openai",
  displayName: "OpenAI",
  authType: "api-key",
  defaultBaseUrl: "https://api.openai.com/v1",
  defaultApi: "openai-completions",
};

export const anthropicPlugin = {
  id: "anthropic",
  displayName: "Anthropic",
  authType: "api-key",
  defaultBaseUrl: "https://api.anthropic.com",
  defaultApi: "anthropic-messages",
};

export const openrouterPlugin = {
  id: "openrouter",
  displayName: "OpenRouter",
  authType: "api-key",
  defaultBaseUrl: "https://openrouter.ai/api/v1",
  defaultApi: "openai-completions",
};

export const BUILTIN_PLUGINS = [
  zhipuPlugin,
  dashscopePlugin,
  openaiPlugin,
  anthropicPlugin,
  openrouterPlugin,
];
