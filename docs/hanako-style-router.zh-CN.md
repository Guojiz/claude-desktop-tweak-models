# Hanako-style local model router

这个 router 的目标不是替代现有破解补丁，而是在补丁之上增加一层本地模型路由。

补丁仍然有价值：当 Claude Desktop 的前端校验已经被放开时，你可以直接把真实模型 ID 填进 Claude，例如 `glm-5.2`。但 Claude Desktop 更新后，补丁可能失效；这时 router 可以把同一个真实模型临时暴露成 Claude 接受的模型名，例如 `claude-sonnet-4-5`，内部仍然转发到 `zhipu/glm-5.2`。

## 设计来源

路由核心按 openhanako 的 provider routing 模式迁移：

- `provider-catalog`: 保存 provider 配置。
- `provider-registry`: 合并内置 provider 声明和用户配置。
- `model-ref`: 运行时强制使用 `{ provider, id }` 复合键，不按裸模型名猜 provider。
- `model-sync`: 把 provider 的模型列表投影成 router runtime catalog。

Claude 适配层只做一件事：把 Claude 看到的 model id 映射回内部的 `{ provider, id }`。

## 配置

复制示例配置：

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude-desktop-tweak-models"
Copy-Item ".\router\router.config.example.json" "$env:USERPROFILE\.claude-desktop-tweak-models\router.config.json"
```

设置 API key：

```powershell
$env:BIGMODEL_API_KEY="你的智谱 API key"
```

启动：

```powershell
node .\router\claude-model-router.mjs
```

打开状态页：

```text
http://127.0.0.1:4318/
```

状态页会显示“填入 Claude 的 Model ID”。把这一列复制到 Claude Desktop 的第三方模型配置里。

## 伪装模式

`claudeExposure.mode` 控制 Claude 看到什么模型名：

```json
{
  "claudeExposure": {
    "mode": "auto",
    "patchStatus": "unknown",
    "spoofModel": "claude-sonnet-4-5"
  }
}
```

可选值：

- `real`: Claude 看到真实模型 ID，例如 `glm-5.2`。适合补丁有效时。
- `provider-ref`: Claude 看到 `provider/model`，例如 `zhipu/glm-5.2`。
- `spoof`: Claude 看到 Claude 模型名，例如 `claude-sonnet-4-5`，内部转发到真实模型。
- `auto`: `patchStatus` 为 `patched` 时走 `real`，否则走 `spoof`。

单个模型也可以覆盖：

```json
{
  "id": "glm-5.2",
  "name": "GLM-5.2",
  "claude": {
    "mode": "spoof",
    "spoofModel": "claude-sonnet-4-5"
  }
}
```

## Claude Desktop 里怎么填

如果状态页显示：

```text
Claude Model ID: claude-sonnet-4-5
Routes to: zhipu/glm-5.2
```

就在 Claude Desktop 的第三方模型配置里填：

```text
Base URL: http://127.0.0.1:4318
Model ID: claude-sonnet-4-5
```

如果你确认破解补丁仍然有效，可以把 `patchStatus` 改成 `patched`，或者把单个模型的 `claude.mode` 改成 `real`，然后状态页会提示你填真实模型 ID。

## 网络提醒

智谱 BigModel 的接口可能受 IP 路由影响。之前实测可用状态是 VPN 开启，同时开启“中国大陆流量绕过/排除大陆流量”。如果 Claude 能连上本地 router，但上游没有回复，优先检查 VPN 和 BigModel 网络出口。
