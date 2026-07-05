# Claude Desktop Tweak Models

中文说明 | [English](README.md)

这是一个用于 Windows 版 Claude Desktop 的补丁和首启配置辅助工具。它会放宽 Claude Desktop 本地对模型 ID 的校验，让开发者模式里的第三方模型设置可以使用来自 Anthropic 兼容网关的自定义模型 ID，而不是只能填写看起来像 Anthropic 自家 Claude 模型的名称。

这个项目用于 **Claude Desktop**，不是 **Claude Code**。

如果你想按步骤配置第三方模型，可以直接看：[在 Claude Desktop 中配置第三方 Anthropic 兼容模型](docs/third-party-models.zh-CN.md)。

## 快速开始

打开 PowerShell，复制运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/Guojiz/claude-desktop-tweak-models/main/Run-Latest.ps1)"
```

不需要先手动以管理员身份打开 PowerShell。脚本会在一开始请求 UAC 权限，然后再修改受保护的 Claude Desktop Windows 应用包。

如果本机没有安装 Claude Desktop，或 Windows 没有暴露应用包，脚本会显示英文提示窗口；你确认后，它会尝试从 Anthropic 官方入口下载并运行 Windows 安装器。如果自动安装失败，脚本会打开官方下载安装页：

<https://claude.ai/download>

## 它能做什么

- 自动搜索已经安装的 Claude Desktop Windows 包。
- 找不到 Claude Desktop 时，在你确认后从官方入口下载并运行 Windows 安装器。
- 在 Claude 还没有用户配置时，创建最小用户配置目录。
- 在 Claude 用户配置旁边保存一份英文首启配置指南。
- 允许 Gateway / Mantle 使用不符合 Claude / Anthropic 命名规则的模型 ID。
- 打补丁后保持 Electron ASAR 完整性元数据有效。
- 禁用 Claude Desktop 内部更新器，避免补丁立刻被覆盖。
- 为 `api.anthropic.com` 添加 hosts 屏蔽块。
- 通过 Windows 策略禁用 Microsoft Store 自动下载应用。
- 不保存、不打印，也不要求输入 API key。

## 首次使用

脚本打开 Claude Desktop 后：

1. 打开 Settings。
2. 如果 Developer Mode 还没有开启，先开启它。
3. 进入 third-party inference / models / providers 一类的设置页面。
4. 添加 Gateway provider。
5. 填写服务商提供的网关信息。

示例：

- Provider：`Gateway`
- Gateway base URL：`https://open.bigmodel.cn/api/anthropic`
- Gateway auth scheme：`x-api-key`
- Model ID：`glm-5.2`
- Display name：`GLM-5.2`
- Model discovery：关闭

智谱的 Claude 兼容网关文档：

<https://docs.bigmodel.cn/cn/guide/develop/claude/introduction>

## 从仓库运行

在这个仓库目录里打开 PowerShell，然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1
```

脚本会搜索已经安装的 Claude Desktop Windows 包，准备首次使用所需的用户文件，对 Claude 进行补丁修改，更新完整性哈希，应用更新保护，然后重启 Claude。

## 重要说明

- 这个工具会修改本地已安装的 Claude Desktop 应用包。
- 它对版本比较敏感，是基于 Windows MSIX 版 Claude Desktop 的包结构制作的。
- 未来 Claude Desktop 更新后，压缩后的函数名可能会改变，验证逻辑也可能会移动。
- 如果 Claude 被更新或修复，需要重新运行脚本。
- 脚本会在 `backups/` 目录下创建本地备份；这些备份会被 Git 有意忽略。
- 脚本不会也不应该保存你的 API key。密钥只应填写到 Claude Desktop 或可信服务商页面中。

## 还原方法

脚本会在打补丁前，把原始文件保存到：

```text
backups/<Claude package name>/
```

如果要手动还原，先停止 Claude，然后恢复：

- 将 `Claude.exe.original` 还原为已安装目录里的 `Claude.exe`
- 将 `app.asar.original` 还原为已安装目录里的 `app.asar`

然后删除 hosts 里带有下面标记的屏蔽块：

```text
# Claude auto-update block - keep patched third-party model setup
```

并修改或删除这个 Windows 注册表项：

```text
HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore\AutoDownload
```

## 许可证

MIT
