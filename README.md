# Claude Desktop Tweak Models

[中文说明](README.zh-CN.md) | English

A **Windows-only helper for Claude Desktop**. It relaxes Claude Desktop's local model ID validation for third-party Gateway / Mantle providers, so a provider can use its real model name, such as `glm-5.2`, instead of a route that must look like an Anthropic model.

This project is for **Claude Desktop on Windows**. It is not Claude Code, not Claude Web, and not a local gateway.

## Scope

- It only handles Claude Desktop's local model ID validation issue.
- It does not request, store, print, or upload API keys.
- It does not create a third-party model service for you.
- It does not enable Developer Mode for you.
- Third-party model endpoints, pricing, reliability, and terms are controlled by their providers.

## Quick use

Open PowerShell and run the one-line launcher from this repository:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/Guojiz/claude-desktop-tweak-models/main/Run-Latest.ps1')"
```

The helper opens a small Windows UI. Click **Detect** to inspect your Claude Desktop installation, then **Apply Patch** to apply the change. Windows may ask for administrator permission.

After it finishes, reopen Claude Desktop and configure your provider in Claude Desktop's own third-party inference / models / providers page.

## Recommended order

1. Open Claude Desktop once.
2. Enable Developer Mode in Claude Desktop settings.
3. Open the third-party inference / models / providers page once.
4. Run the one-line launcher above and click **Apply Patch**.
5. Reopen Claude Desktop, then add or save your provider.

If you already ran the helper first, that is also fine. Apply the change, reopen Claude Desktop, enable Developer Mode, then configure the provider.

## What it does

- Finds the installed Windows Claude Desktop package.
- Closes running Claude Desktop processes before making changes.
- Checks Claude Desktop's bundled frontend files.
- Adjusts the Gateway / Mantle model ID validation logic.
- Backs up changed files under `backups/<Claude package name>/`.
- Provides a simple UI with Detect, Apply Patch, and Restore buttons.
- Does not store, print, or request any API key.

## What it does not do

- It does not create or run a local gateway.
- It does not configure Zhipu, OpenAI-compatible, or Anthropic-compatible endpoints for you.
- It does not enable Developer Mode for you.
- It does not edit `hosts`.
- It does not disable Claude Desktop, Microsoft Store, or system updates.

## Configure your provider

After applying the change, open Claude Desktop:

1. Open Settings.
2. Enable Developer Mode if needed.
3. Open the third-party inference / models / providers section.
4. Add your provider using Claude Desktop's own UI.
5. Enter the provider's base URL, auth scheme, API key, and real model ID.

Example for a Claude-compatible Zhipu endpoint:

```text
Provider: Gateway
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway auth scheme: bearer
Model ID: glm-5.2
Display name: GLM-5.2
Model discovery: off
```

Zhipu's Claude-compatible gateway documentation:

https://docs.bigmodel.cn/cn/guide/develop/claude/introduction

## Console use

If you cloned the repository locally, you can also run the main script directly:

```powershell
.\Patch-Claude-ThirdParty-Models.ps1
```

Common parameters:

```powershell
.\Patch-Claude-ThirdParty-Models.ps1 -NoGui -DryRun
.\Patch-Claude-ThirdParty-Models.ps1 -NoGui -Revert
```

`Protect-Claude-Zhipu-GLM52.ps1` is kept only as a legacy compatibility filename from the original GLM-5.2 test case.

## Troubleshooting

- If Detect says Claude Desktop was not found, install Claude Desktop, open it once, then rerun the helper.
- If Apply Patch asks for administrator permission, approve it.
- If Claude updates later, rerun the helper because the changed files may be replaced.
- If the script says no known validation snippet was found, Claude Desktop changed its bundled structure and this matching rule needs an update.

## Contributing

Issues, pull requests, and compatibility notes are welcome, especially for:

- Claude Desktop packaging changes;
- other Anthropic-compatible model provider examples;
- Windows version differences;
- clearer screenshots or troubleshooting notes;
- detection, restore, and documentation improvements.

## License

MIT License. See [LICENSE](LICENSE).