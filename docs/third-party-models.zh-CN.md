# 在 Claude Desktop 中配置第三方 Anthropic 兼容模型

[返回中文 README](../README.zh-CN.md) | [English README](../README.md)

这是一份配置说明，目标是帮助用户理解如何在 Claude Desktop 的第三方模型设置中填写 Anthropic 兼容网关的信息。

本项目用于 Claude Desktop，不是 Claude Code，也不是 MCP。MCP 是给 Claude 连接工具和数据源的；这里讨论的是第三方模型后端。

## 目录

- [基本思路](#基本思路)
- [准备条件](#准备条件)
- [配置入口](#配置入口)
- [需要填写的字段](#需要填写的字段)
- [示例：智谱 GLM-5.2](#示例智谱-glm-52)
- [测试方法](#测试方法)
- [常见问题](#常见问题)
- [安全提醒](#安全提醒)

## 基本思路

Claude Desktop 的开发者模式中可能提供第三方模型或第三方推理设置。用户可以在那里填写一个 Anthropic 兼容网关，让 Claude Desktop 把请求发送到其他模型服务。

本仓库的补丁只处理一个问题：让 Claude Desktop 接受第三方网关自己的模型 ID。它不会提供账号、额度、网络代理，也不会保证某个服务商一定兼容。

## 准备条件

你需要：

1. Windows 版 Claude Desktop。
2. 能在 Claude Desktop 中看到开发者模式或第三方模型设置。
3. 一个 Anthropic 兼容 API / 网关。
4. 该服务商提供的访问凭证、base URL、认证方式和模型 ID。
5. 已按 README 运行本仓库的补丁脚本。

## 配置入口

不同版本的 Claude Desktop 入口名称可能略有不同，通常在设置里的 Developer、Developer Mode、Third-party inference、Models 或 Providers 附近。

如果页面里出现 Gateway、Base URL、Auth scheme、Model ID、Display name 等字段，就说明基本找对地方了。

## 需要填写的字段

常见字段如下：

- Provider：通常选择 `Gateway`
- Gateway base URL：第三方服务提供的 Anthropic 兼容接口地址
- Gateway auth scheme：以服务商文档为准，常见形式包括 `x-api-key`
- Model ID：服务商提供的真实模型编码
- Display name：你希望在 Claude Desktop 中显示的名称
- Model discovery：如果服务商没有适配模型发现接口，可以先关闭

关键点：Model ID 不是随便写的名字，而是服务商文档里给出的模型编码。

## 示例：智谱 GLM-5.2

下面只是一个例子，其他服务商请替换为自己的网关信息。

```text
Provider: Gateway
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway auth scheme: x-api-key
Model ID: glm-5.2
Display name: GLM-5.2
Model discovery: off
```

智谱官方文档说明，它提供 Claude API 兼容接口，迁移时主要替换 base URL、访问凭证，并使用智谱模型编码。

相关文档：

<https://docs.bigmodel.cn/cn/guide/develop/claude/introduction>

## 测试方法

配置完成后，新建一个对话，选择刚刚添加的第三方模型，然后发送一句简单测试：

```text
Hello, please reply with one short sentence.
```

如果能正常回复，说明模型 ID、网络连接、认证方式和网关兼容性大概率已经跑通。

## 常见问题

### Model ID 仍然报错

可能是补丁没有成功应用，或者 Claude Desktop 更新后覆盖了补丁。可以重新按 README 的使用方法运行。

### 认证失败

检查访问凭证、认证方式、账号权限和额度。

### 找不到模型

检查 Model ID 是否与服务商文档一致，以及账号是否有权限使用该模型。

### 网络连接失败

本项目不解决网络连通性。你的电脑仍然需要能访问所配置的网关地址。

## 安全提醒

第三方网关会接收你的请求内容。不要把密码、密钥、未公开代码、私人文件或敏感资料发送给不可信服务。

优先使用官方平台或可信服务商提供的接口。
