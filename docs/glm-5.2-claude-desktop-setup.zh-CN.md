# GLM-5.2 接入 Claude Desktop 完整教程

这是一份从零开始的配置教程：安装 Claude Desktop 之后，如何开启 Developer Mode，运行本项目补丁工具，然后把智谱 BigModel / GLM-5.2 配到 Claude Desktop 的 third-party inference 里。

本页来自一次真实排错过程。重点不是“随便填一个 OpenAI 接口”，而是弄清楚 Claude Desktop 到底需要什么协议。

## 0. 先看结论

Claude Desktop 的 third-party inference / Gateway 走的是 **Anthropic Messages API**，不是 OpenAI Chat Completions API。

所以接入智谱 GLM-5.2 时，Base URL 应该填：

```text
https://open.bigmodel.cn/api/anthropic
```

不要填：

```text
https://open.bigmodel.cn/api/paas/v4/chat/completions
```

否则 Claude Desktop 会在后面自动拼接 `/v1/messages`，最后变成：

```text
https://open.bigmodel.cn/api/paas/v4/chat/completions/v1/messages
```

这个地址不存在，所以会报 404。

## 1. 安装 Claude Desktop

先安装 Windows 版 Claude Desktop，并至少打开一次。

打开一次的原因是：Claude Desktop 需要先生成自己的本地目录、设置文件和打包资源。补丁工具要检测这些文件。

## 2. 开启 Developer Mode

在 Claude Desktop 中进入菜单：

```text
Help → Troubleshooting → Enable Developer Mode
```

如果你的版本把入口放在设置里，也可以从：

```text
Settings → Developer / Advanced
```

寻找 Developer Mode 开关。

开启后，重新打开 Claude Desktop。然后进入 third-party inference / models / providers 页面一次，让 Claude 生成相关配置。

## 3. 运行本项目补丁工具

打开 PowerShell，直接运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/Guojiz/claude-desktop-tweak-models/main/Run-Latest.ps1)"
```

弹出工具窗口后：

1. 点击 **Detect**。
2. 确认检测到 Claude Desktop。
3. 点击 **Apply Patch**。
4. 如果 Windows 弹出管理员权限确认，允许。
5. 补丁完成后，重新打开 Claude Desktop。

这个工具不会帮你配置 API Key，也不会创建本地网关。它只修补 Claude Desktop 本地对第三方模型 ID 的限制，让你可以填写真实模型名，例如 `glm-5.2`。

## 4. 配置 BigModel / GLM-5.2

进入 Claude Desktop 的 third-party inference 设置页。

### Connection

按下面填写：

```text
Connection: Gateway
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway API key: 填你的智谱 BigModel API Key
Gateway auth scheme: bearer
Custom inference headers: 留空
Credential kind: Static API key
```

然后点击 **Test connection**。

如果看到类似下面的绿色提示，就说明接口已经通了：

```text
Inference — 1-token completion ... via static key
```

### Models

建议关闭 Model discovery。

```text
Model discovery: off
```

然后手动添加模型：

```text
Model ID: glm-5.2
Display name: GLM-5.2
Tier alias: opus
Default for tier: on
Offer 1M-context variant: off
```

最后点击：

```text
Save Changes
Apply Changes
```

如果你想单独使用百万上下文版本，可以再手动添加一个模型：

```text
Model ID: glm-5.2[1m]
Display name: GLM-5.2 1M
Tier alias: opus
Default for tier: 按需要开启
```

也可以尝试打开 **Offer 1M-context variant**，但最稳的方式是手动添加 `glm-5.2[1m]`。

## 5. 常见错误与原因

### 错误一：404，路径里出现 `/chat/completions/v1/messages`

典型报错：

```text
Gateway rejected model "glm-5.2" (HTTP 404)
https://open.bigmodel.cn/api/paas/v4/chat/completions/v1/messages
```

原因：你把 OpenAI Chat Completions endpoint 填进了 Claude Desktop。

Claude Desktop 会自动请求：

```text
/v1/messages
```

所以必须填写 Anthropic-compatible Base URL：

```text
https://open.bigmodel.cn/api/anthropic
```

### 错误二：Test connection 成功，但 Model discovery found 0 models

这通常不是大问题。

Claude Desktop 的模型发现会请求类似：

```text
/v1/models
```

但有些 Anthropic-compatible 服务并不会完整返回模型列表，或者不会把 `glm-5.2` 放进 discovery 结果里。

处理方式：关闭 Model discovery，手动填写模型 ID。

```text
Model discovery: off
Model ID: glm-5.2
```

只要 **Test connection** 是绿色成功，手动模型通常就可以用。

### 错误三：模型 ID 被 Claude Desktop 拒绝

如果 Claude Desktop 不允许保存 `glm-5.2`，说明本项目补丁没有生效，或者 Claude 自动更新后覆盖了补丁。

处理方式：重新运行本项目工具，再点 **Apply Patch**。

### 错误四：Cowork / Code 提示 Virtual Machine Platform not available

这个问题和 GLM-5.2 接口配置无关。

Claude 的 Cowork / Code 功能在 Windows 上可能需要系统虚拟化组件，例如 Virtual Machine Platform。可以在管理员 PowerShell 中尝试开启：

```powershell
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:HypervisorPlatform /all /norestart
```

然后重启电脑。

如果你使用的是云电脑，还可能遇到嵌套虚拟化限制。也就是说，Windows 里看起来可以安装 Hyper-V，但云厂商没有给这台机器开放真正可用的 nested virtualization，Claude 的本地 VM 功能仍然可能无法运行。

这不影响普通聊天模型配置，但会影响 Claude 的本地 Cowork / Code 工作区。

## 6. 为什么本项目仍然需要

智谱 BigModel 已经提供 Anthropic-compatible endpoint，因此它可以直接接 Claude Desktop 的 Gateway。

但是 Claude Desktop 本地仍可能限制第三方模型 ID，例如只接受类似 `claude-*` 的模型路由。本项目的作用就是放开这一层本地校验，让 `glm-5.2`、`glm-5.2[1m]` 这类真实模型 ID 可以保存并显示。

它不是本地代理，也不是协议转换器。

正确链路是：

```text
Claude Desktop
  ↓
本项目补丁：放开本地模型 ID 校验
  ↓
Claude Desktop Gateway
  ↓
https://open.bigmodel.cn/api/anthropic/v1/messages
  ↓
GLM-5.2
```

## 7. 最终推荐配置

普通版本：

```text
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway auth scheme: bearer
Model discovery: off
Model ID: glm-5.2
Display name: GLM-5.2
Tier alias: opus
Default for tier: on
```

百万上下文版本：

```text
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway auth scheme: bearer
Model discovery: off
Model ID: glm-5.2[1m]
Display name: GLM-5.2 1M
Tier alias: opus
```

## 8. 相关文档

智谱 BigModel Claude / Anthropic 兼容文档：

```text
https://docs.bigmodel.cn/cn/guide/develop/claude/introduction
```

Claude Desktop third-party inference / Gateway 文档：

```text
https://claude.com/docs/third-party/claude-desktop/gateway
```
