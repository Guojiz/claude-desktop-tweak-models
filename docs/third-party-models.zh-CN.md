# 在 Claude Desktop 中配置第三方模型

[返回中文 README](../README.zh-CN.md) | [English README](../README.md)

这个项目只解决 Claude Desktop 本地前端校验过严的问题：某些版本会要求 Gateway / Mantle 的 Model ID 看起来像 Anthropic 模型名。补丁后，可以填写服务商真实模型 ID，例如 `glm-5.2`。

它不是 MCP，不是 Claude Code，也不是网关服务。

## 步骤

1. 先运行本仓库的补丁脚本。
2. 打开 Claude Desktop。
3. 打开 Settings。
4. 启用 Developer Mode。
5. 进入 third-party inference / models / providers 页面。
6. 添加 provider，并填写服务商提供的信息。

常见字段：

- Provider: 通常选择 `Gateway`
- Gateway base URL: 服务商提供的 Anthropic / Claude 兼容接口地址
- Gateway auth scheme: 以服务商文档为准，例如 `x-api-key`
- API key: 服务商平台生成的密钥
- Model ID: 服务商真实模型编码
- Display name: Claude Desktop 中显示的名称
- Model discovery: 如果服务商没有适配模型发现接口，可以先关闭

## 智谱 GLM 示例

```text
Provider: Gateway
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway auth scheme: x-api-key
Model ID: glm-5.2
Display name: GLM-5.2
Model discovery: off
```

智谱官方文档：

https://docs.bigmodel.cn/cn/guide/develop/claude/introduction

## 测试

配置完成后，新建对话并选择刚刚添加的模型，发送一句简单测试：

```text
Hello, please reply with one short sentence.
```

如果能正常回复，说明模型 ID、网络、鉴权和服务商兼容接口基本可用。

## 常见问题

### Model ID 仍然报错

重新运行补丁脚本并确认 Detect 结果。如果 Claude Desktop 已更新，可能需要更新补丁匹配规则。

### 认证失败

检查 API key、鉴权方式、账号权限和额度。

### 网络连接失败

本项目不解决网络连通性。你的电脑仍然需要能访问所配置的服务商接口。

## 安全提醒

第三方网关会接收你的请求内容。不要把密码、密钥、未公开代码、私人文件或敏感资料发送给不可信服务。
