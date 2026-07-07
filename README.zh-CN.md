# Claude Desktop Tweak Models

中文说明 | [English](README.md)

这是一个 **Windows 版 Claude Desktop 第三方模型兼容性辅助工具**。它用于放开 Claude Desktop 本地的模型 ID 校验，让 Developer Mode 里的 Gateway / Mantle provider 可以填写服务商真实模型名，例如 `glm-5.2`，不用伪装成 `claude-*` 或 `anthropic/claude-*`。

本项目只面向 **Windows 版 Claude Desktop**。它不是 Claude Code，也不是网页 Claude。

补丁有效时，最简单的方式仍然是直接填写真实第三方模型 ID。若 Claude Desktop 更新导致补丁失效，可以使用可选的 Hanako-style 本地 router，把真实上游模型伪装成 Claude 接受的模型名。见 [docs/hanako-style-router.zh-CN.md](docs/hanako-style-router.zh-CN.md)。

## 使用边界

- 本工具只处理 Claude Desktop 本地的模型 ID 校验问题。
- 本工具不会替你申请、保存、打印或上传 API key。
- 本工具不会替你创建第三方模型服务。
- 本工具不会替你开启 Developer Mode。
- 第三方模型接口、费用、稳定性和服务条款由对应服务商负责。

## 项目关系声明

本项目是一个非官方的本地兼容性补丁，用于个人研究、兼容性测试和本地实验。它不替代 Claude 订阅，不提供免费访问，不包含或分发 Claude Desktop 本体，也不提供任何 API key。本项目不是 Anthropic、Claude 或任何第三方模型服务商的官方项目，也不是 Claude Desktop / Claude Code 官方代码库的一部分。仓库中出现的 Claude、Anthropic、Gateway、Mantle、智谱等名称，仅用于说明兼容对象、配置场景和用户操作界面。使用者应自行确认自己的使用方式是否符合 Claude Desktop、Anthropic 以及相关第三方模型服务条款。

## 快速用法

打开 PowerShell，直接运行这一行命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/Guojiz/claude-desktop-tweak-models/main/Run-Latest.ps1')"
```

工具会打开一个小界面。先点 **Detect** 检测 Claude Desktop，再点 **Apply Patch** 应用修改。系统可能会弹出管理员权限确认，请允许。

完成后，重新打开 Claude Desktop，在 Claude 自己的 third-party inference / models / providers 页面配置 provider。

如果你想完整照着配置 GLM-5.2，请看：[GLM-5.2 接入 Claude Desktop 完整教程](docs/glm-5.2-claude-desktop-setup.zh-CN.md)。

## 推荐顺序

1. 先打开一次 Claude Desktop。
2. 在 Claude Desktop 设置里开启 Developer Mode。
3. 进入 third-party inference / models / providers 相关页面一次。
4. 运行上面的一行命令，点击 **Apply Patch**。
5. 重新打开 Claude Desktop，然后添加或保存 provider。

如果你已经先运行了本工具，也没关系。先完成修改，重新打开 Claude Desktop，再开启 Developer Mode 并配置 provider。

## 可选本地 router

`router/` 下的可选 router 按 openhanako 的 provider routing 结构实现：provider catalog、provider registry、`{ provider, id }` 复合模型引用，以及 runtime model projection。Claude 看到的是可配置的模型 ID；router 内部仍然保存真实 provider/model。

当你需要多个 provider，或者 Claude Desktop 更新导致真实第三方模型 ID 再次保存失败时，可以使用它。启动后的状态页会告诉你应该把哪个 Model ID 填进 Claude Desktop。

## 它会做什么

- 自动寻找已安装的 Windows 版 Claude Desktop。
- 修改前自动关闭正在运行的 Claude Desktop 进程。
- 检查 Claude Desktop 打包后的前端文件。
- 调整 Gateway / Mantle 的模型 ID 校验逻辑。
- 在 `backups/<Claude package name>/` 下备份被修改的文件。
- 提供 Detect、Apply Patch、Restore 三个界面按钮。
- 不保存、不打印、也不要求输入 API key。

## 它不会做什么

- 补丁工具本身不创建或运行本地 Gateway；`router/` 下的可选 router 是单独功能。
- 不替你配置智谱、OpenAI-compatible 或 Anthropic-compatible 接口。
- 不替你开启 Developer Mode。
- 不写入 hosts。
- 不禁用 Claude Desktop、Microsoft Store 或系统更新。

## 配置第三方模型

完成修改后，在 Claude Desktop 里操作：

1. 打开 Settings。
2. 如果需要，启用 Developer Mode。
3. 进入 third-party inference / models / providers 相关页面。
4. 用 Claude Desktop 原生界面添加你的 provider。
5. 填写服务商提供的 base URL、鉴权方式、API key 和真实模型 ID。

智谱 Claude-compatible endpoint 示例：

```text
Provider: Gateway
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway auth scheme: bearer
Model ID: glm-5.2
Display name: GLM-5.2
Model discovery: off
```

完整配置与排错请看：[GLM-5.2 接入 Claude Desktop 完整教程](docs/glm-5.2-claude-desktop-setup.zh-CN.md)。

智谱官方 Claude 兼容文档：

https://docs.bigmodel.cn/cn/guide/develop/claude/introduction

## 控制台用法

如果你已经克隆了仓库，也可以直接运行主脚本：

```powershell
.\Patch-Claude-ThirdParty-Models.ps1
```

常用参数：

```powershell
.\Patch-Claude-ThirdParty-Models.ps1 -NoGui -DryRun
.\Patch-Claude-ThirdParty-Models.ps1 -NoGui -Revert
```

`Protect-Claude-Zhipu-GLM52.ps1` 只作为早期 GLM-5.2 测试场景留下的兼容旧文件名保留。

## 排错

- 如果 Detect 显示找不到 Claude Desktop，先安装 Claude Desktop，打开一次，再重新运行脚本。
- 如果 Apply Patch 请求管理员权限，请允许。
- 如果 Claude 后续自动更新，修改可能被覆盖，重新运行脚本即可。
- 如果脚本提示找不到已知校验片段，说明 Claude Desktop 更新了打包结构，需要更新匹配规则。
- 如果模型能保存但发消息不回复，检查网络路线。实测推荐：VPN 开启，同时开启“中国大陆流量绕过 / 排除大陆流量”，让 `downloads.claude.ai` 可下载 Claude 运行时，让 `open.bigmodel.cn` 走国内线路。

## 贡献与合作

欢迎提交 Issue、PR 或新的适配记录，尤其是：

- 新版 Claude Desktop 打包结构变化；
- 其他 Anthropic-compatible 模型服务配置样例；
- Windows 版本差异；
- 更清晰的教程截图或排错说明；
- 检测逻辑、恢复逻辑和文档改进。

## 许可

MIT License。详见 [LICENSE](LICENSE)。