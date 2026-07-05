# Claude Desktop Tweak Models

中文说明 | [English](README.md)

这是一个 Windows 版 Claude Desktop 小工具。它只放开 Claude Desktop 前端里的第三方模型名校验，让 Developer Mode 里的 Gateway / Mantle provider 可以填写服务商真实模型名，例如 `glm-5.2`，而不是必须伪装成 `claude-*` 或 `anthropic/claude-*`。

本项目用于 **Claude Desktop**，不是 Claude Code。

## 快速开始

打开 PowerShell，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/Guojiz/claude-desktop-tweak-models/main/Run-Latest.ps1)"
```

脚本会打开一个简单界面。先点 **Detect** 检测 Claude Desktop，再点 **Apply Patch** 应用补丁。因为 Claude Desktop 位于受保护的 Windows 应用目录，应用补丁时系统可能会弹出管理员权限确认。

## 它会做什么

- 自动寻找已安装的 Windows 版 Claude Desktop。
- 搜索 `ion-dist` 里的前端 JavaScript 文件。
- 只备份包含 Gateway / Mantle 模型路由校验的前端文件。
- 把这个本地前端校验改成允许自定义模型 ID。
- 提供 Detect、Apply Patch、Restore 三个界面按钮。
- 不保存、不打印、也不要求输入 API key。

## 它不会做什么

- 不创建或运行本地网关。
- 不替你配置智谱、OpenAI-compatible 或 Anthropic-compatible 接口。
- 不修改 `app.asar`。
- 不修改 `Claude.exe` 完整性元数据。
- 不写入 hosts 屏蔽 `api.anthropic.com`。
- 不禁用 Claude Desktop、Microsoft Store 或系统更新。

## 配置第三方模型

补丁完成后，在 Claude Desktop 里操作：

1. 打开 Settings。
2. 如有需要，启用 Developer Mode。
3. 进入 third-party inference / models / providers 一类页面。
4. 用 Claude Desktop 原生界面添加你的 provider。
5. 填写服务商提供的 base URL、鉴权方式、API key 和真实模型 ID。

智谱 Claude-compatible endpoint 示例：

```text
Provider: Gateway
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway auth scheme: x-api-key
Model ID: glm-5.2
Display name: GLM-5.2
Model discovery: off
```

智谱官方 Claude 兼容文档：

https://docs.bigmodel.cn/cn/guide/develop/claude/introduction

## 从仓库运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1
```

只做控制台检测：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1 -NoGui -DryRun
```

恢复备份的前端文件：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1 -NoGui -Revert
```

## 注意

- 这个工具会修改本地已安装的 Claude Desktop 前端文件。
- Claude Desktop 使用压缩后的前端 JavaScript，所以这个补丁对版本敏感。
- 如果 Claude 更新后校验逻辑移动，需要重新运行脚本或更新补丁匹配规则。
- 备份保存在 `backups/<Claude package name>/`，不会提交到 Git。

## 许可

MIT
