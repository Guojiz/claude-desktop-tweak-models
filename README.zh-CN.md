# Claude Desktop Tweak Models

中文说明 | [English](README.md)

这是一个用于 Windows 版 Claude Desktop 的补丁辅助工具。它会放宽 Claude Desktop 本地对模型 ID 的校验，让开发者模式里的第三方模型设置可以使用来自 Anthropic 兼容网关的自定义模型 ID，而不是只能填写看起来像 Anthropic 自家 Claude 模型的名称。

这个项目用于 **Claude Desktop**，不是 **Claude Code**。

如果你想按步骤配置第三方模型，可以直接看：[在 Claude Desktop 中配置第三方 Anthropic 兼容模型](docs/third-party-models.zh-CN.md)。

## 目录

- [开发原因](#开发原因)
- [它能做什么](#它能做什么)
- [兼容的模型 ID](#兼容的模型-id)
- [第三方模型配置教程](docs/third-party-models.zh-CN.md)
- [示例：智谱 GLM-5.2](#示例智谱-glm-52)
- [使用方法](#使用方法)
- [重要说明](#重要说明)
- [网络说明](#网络说明)
- [还原方法](#还原方法)
- [许可证](#许可证)

## 开发原因

我想通过 Claude Desktop 的开发者模式，使用第三方模型设置来接入国产 / 第三方大模型。

但是在配置第三方提供方后，我发现 **Model ID** 这一项似乎只能填写 Anthropic 自家的模型 ID。如果填写别家模型的 ID，Claude Desktop 就会报错。

这也可能是因为我更新了 Claude Desktop，导致后来的版本加上了限制。但无论如何，这已经有点偏离第三方模型设置的初衷了。按我的理解，这个设置本来就应该允许 Anthropic 兼容网关提供自己的模型 ID。

所以我做了这个补丁。

## 它能做什么

- 允许 Gateway / Mantle 使用不符合 Claude / Anthropic 命名规则的模型 ID。
- 打补丁后保持 Electron ASAR 完整性元数据有效。
- 禁用 Claude Desktop 内部更新器，避免补丁立刻被覆盖。
- 为 `api.anthropic.com` 添加 hosts 屏蔽块。
- 通过 Windows 策略禁用 Microsoft Store 自动下载应用。
- 不保存、不打印，也不要求输入 API key。

## 兼容的模型 ID

这个补丁不限定某一个服务商，也不限定某一个模型名称。

它的目标是让 Claude Desktop 可以接受由 **Anthropic 兼容 API / 网关** 提供的模型 ID，例如：

- 通过 Claude 兼容接口暴露的国产模型；
- 会把 Anthropic 风格请求转发 / 转换到其他模型的自定义网关；
- 在 Claude Desktop 第三方推理设置里配置的第三方模型提供方。

这个补丁只修改 Claude Desktop 本地的模型 ID 校验逻辑。它**不会**把任意普通 API 变成 Anthropic 兼容 API。

## 示例：智谱 GLM-5.2

下面只是一个配置示例。其他 Anthropic 兼容网关可能会使用不同的 URL、认证方式和模型 ID。

在 Claude Desktop 的第三方推理配置中可以这样填写：

- Provider：`Gateway`
- Gateway base URL：`https://open.bigmodel.cn/api/anthropic`
- Gateway auth scheme：`x-api-key`
- Model ID：`glm-5.2`
- Display name：`GLM-5.2`
- Model discovery：关闭

智谱的 Claude 兼容网关文档：

<https://docs.bigmodel.cn/cn/guide/develop/claude/introduction>

## 使用方法

在这个仓库目录里，以**管理员身份**打开 PowerShell，然后复制运行下面这行命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1
```

脚本会搜索已经安装的 Claude Desktop Windows 包，对它进行补丁修改，更新完整性哈希，应用更新保护，然后重启 Claude。

## 重要说明

- 这个工具会修改本地已安装的 Claude Desktop 应用包。
- 它对版本比较敏感，是基于 Windows MSIX 版 Claude Desktop 的包结构制作的。
- 未来 Claude Desktop 更新后，压缩后的函数名可能会改变，验证逻辑也可能会移动。
- 如果 Claude 被更新或修复，需要重新运行脚本。
- 脚本会在 `backups/` 目录下创建本地备份；这些备份会被 Git 有意忽略。
- 脚本文件名目前仍然带有 Zhipu GLM-5.2，是因为最初测试对象是这个模型。但文档和目标用途已经扩展为：Anthropic 兼容的自定义模型 ID。

## 网络说明

这个补丁只是让 Claude Desktop 接受并使用自定义 Gateway 配置。

它不能解决网络连通性、账号权限、服务商额度或 API 兼容性问题。你的电脑仍然需要能访问你在 Gateway 中配置的 URL。

以上面的智谱示例来说，需要能访问：

```text
https://open.bigmodel.cn/api/anthropic
```

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
# Claude auto-update block - keep patched Zhipu GLM-5.2 setup
```

并修改或删除这个 Windows 注册表项：

```text
HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore\AutoDownload
```

## 许可证

MIT
