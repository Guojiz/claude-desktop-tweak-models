# Claude Desktop Tweak Models

中文说明 | [English](README.md)

这是一个 Windows 版 Claude Desktop 小工具。它放开 Claude Desktop 本地的第三方模型 ID 校验，让 Developer Mode 里的 Gateway / Mantle provider 可以填写服务商真实模型名，例如 `glm-5.2`，不用伪装成 `claude-*` 或 `anthropic/claude-*`。

本项目用于 **Claude Desktop**，不是 Claude Code。它也不是本地 Gateway。

## 全自动用法

打开 PowerShell，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/Guojiz/claude-desktop-tweak-models/main/Run-Latest.ps1)"
```

脚本会打开一个小界面。先点 **Detect** 检测 Claude Desktop，再点 **Apply Patch** 自动修复。因为 Claude Desktop 安装在受保护的 Windows 应用目录里，系统可能会弹出管理员权限确认，请允许。

补丁完成后，重新打开 Claude Desktop，在 Claude 自己的第三方推理设置里配置 provider。

## Developer Mode 顺序

推荐顺序：

1. 先打开一次 Claude Desktop。
2. 在 Claude Desktop 设置里开启 Developer Mode。
3. 进入 third-party inference / models / providers 相关页面一次。
4. 再运行本工具，点击 **Apply Patch**。工具会在补丁前自动关闭正在运行的 Claude Desktop 进程。
5. 重新打开 Claude Desktop，然后添加或保存 provider。

如果你已经先运行了本工具，也没关系。先完成补丁，重新打开 Claude Desktop，再开启 Developer Mode 并配置 provider。这个工具不会替你开启 Developer Mode；它只修补 Claude Desktop 本地的模型 ID 校验。

## 它会做什么

- 自动寻找已安装的 Windows 版 Claude Desktop。
- 修改受保护文件前，自动关闭正在运行的 Claude Desktop 进程。
- 搜索 `ion-dist` 里的前端 JavaScript 文件。
- 修补前端 Gateway / Mantle 模型路由校验。
- 修补 `app.asar` 里的同一层主进程校验。
- 当 Claude 报 Electron ASAR 完整性哈希不匹配时，自动修复相关哈希元数据。
- 在 `backups/<Claude package name>/` 下备份被修改的文件。
- 提供 Detect、Apply Patch、Restore 三个界面按钮。
- 不保存、不打印、也不要求输入 API key。

## 它不会做什么

- 不创建或运行本地 Gateway。
- 不替你配置智谱、OpenAI-compatible 或 Anthropic-compatible 接口。
- 不替你开启 Developer Mode。
- 不写入 hosts 屏蔽 `api.anthropic.com`。
- 不禁用 Claude Desktop、Microsoft Store 或系统更新。

## 配置第三方模型

补丁完成后，在 Claude Desktop 里操作：

1. 打开 Settings。
2. 如果需要，启用 Developer Mode。
3. 进入 third-party inference / models / providers 相关页面。
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

## 控制台命令

从仓库运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Patch-Claude-ThirdParty-Models.ps1
```

只检测状态：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Patch-Claude-ThirdParty-Models.ps1 -NoGui -DryRun
```

恢复备份：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Patch-Claude-ThirdParty-Models.ps1 -NoGui -Revert
```

`Protect-Claude-Zhipu-GLM52.ps1` 只作为早期 GLM-5.2 测试场景留下的兼容旧文件名保留。

## 排错

- 如果 Detect 显示找不到 Claude Desktop，先安装 Claude Desktop，打开一次，再重新运行脚本。
- 如果 Apply Patch 请求管理员权限，请允许。Claude 的安装目录受 Windows 保护。
- 如果 Claude 后续自动更新，补丁可能被覆盖，重新运行脚本即可。
- 如果脚本提示找不到已知校验片段，说明 Claude Desktop 更新了打包代码，需要更新补丁匹配规则。

## 许可

MIT
