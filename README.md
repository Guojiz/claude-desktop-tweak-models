# Claude Desktop Tweak Models

[中文说明](README.zh-CN.md) | English

Small Windows helper for Claude Desktop. It relaxes Claude Desktop's local frontend validation for third-party Gateway / Mantle model IDs, so a provider can use its real model name, such as `glm-5.2`, instead of a route that must look like an Anthropic model.

This project is for **Claude Desktop**, not Claude Code.

## Quick Start

Open PowerShell and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/Guojiz/claude-desktop-tweak-models/main/Run-Latest.ps1)"
```

The helper opens a small Windows UI. Click **Detect** to inspect your Claude Desktop installation, then **Apply Patch** to patch the frontend validation check. Windows may ask for administrator permission because Claude Desktop is installed under the protected Windows app package folder.

## What It Does

- Finds the installed Windows Claude Desktop package.
- Searches Claude Desktop frontend JavaScript files under `ion-dist`.
- Backs up only the frontend file(s) that contain the Gateway / Mantle model-route validation check.
- Changes that local frontend check to accept custom model IDs.
- Provides a simple UI with Detect, Apply Patch, and Restore buttons.
- Does not store, print, or request any API key.

## What It Does Not Do

- It does not create or run a local gateway.
- It does not configure Zhipu, OpenAI-compatible, or Anthropic-compatible endpoints.
- It does not modify `app.asar`.
- It does not edit `Claude.exe` integrity metadata.
- It does not block `api.anthropic.com` in `hosts`.
- It does not disable Claude Desktop, Microsoft Store, or system updates.

## Configure Your Provider

After patching, open Claude Desktop:

1. Open Settings.
2. Enable Developer Mode if needed.
3. Open the third-party inference / models / providers section.
4. Add your provider using Claude Desktop's own UI.
5. Enter the provider's base URL, auth scheme, API key, and real model ID.

Example for a Claude-compatible Zhipu endpoint:

```text
Provider: Gateway
Gateway base URL: https://open.bigmodel.cn/api/anthropic
Gateway auth scheme: x-api-key
Model ID: glm-5.2
Display name: GLM-5.2
Model discovery: off
```

Zhipu's Claude-compatible gateway documentation:

https://docs.bigmodel.cn/cn/guide/develop/claude/introduction

## Run From A Clone

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1
```

For a console-only check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1 -NoGui -DryRun
```

To restore backed-up frontend files:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1 -NoGui -Revert
```

## Notes

- This modifies local installed Claude Desktop frontend files.
- It is version-sensitive because Claude Desktop bundles minified JavaScript.
- If Claude updates and the validation logic moves, rerun the helper or update the patch pattern.
- Backups are saved under `backups/<Claude package name>/` and ignored by Git.

## License

MIT
