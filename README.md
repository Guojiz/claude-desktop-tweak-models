# Claude Desktop Tweak Models

[中文说明](README.zh-CN.md) | English

Small Windows helper for Claude Desktop. It relaxes Claude Desktop's local model ID validation for third-party Gateway / Mantle providers, so a provider can use its real model name, such as `glm-5.2`, instead of a route that must look like an Anthropic model.

This project is for **Claude Desktop**, not Claude Code. It is not a local gateway.

## Fully Automatic

Open PowerShell and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/Guojiz/claude-desktop-tweak-models/main/Run-Latest.ps1)"
```

The helper opens a small Windows UI. Click **Detect** to inspect your Claude Desktop installation, then **Apply Patch**. Windows may ask for administrator permission because Claude Desktop is installed under the protected Windows app package folder.

After the patch finishes, reopen Claude Desktop and use Claude Desktop's own third-party inference settings.

## Developer Mode Order

Recommended order:

1. Open Claude Desktop once.
2. Enable Developer Mode in Claude Desktop settings.
3. Open the third-party inference / models / providers page once.
4. Run this helper and click **Apply Patch**.
5. Reopen Claude Desktop, then add or save your provider.

If you already ran the helper first, that is also fine. Apply the patch, reopen Claude Desktop, enable Developer Mode, then configure the provider. The helper does not enable Developer Mode for you; it only patches Claude Desktop's local model ID validation.

## What It Does

- Finds the installed Windows Claude Desktop package.
- Stops running Claude Desktop processes before editing protected files.
- Searches frontend JavaScript files under `ion-dist`.
- Patches the frontend Gateway / Mantle model-route validation check.
- Patches the same validation check inside `app.asar`.
- Repairs Electron ASAR integrity hash metadata when Claude reports a mismatch.
- Backs up changed files under `backups/<Claude package name>/`.
- Provides a simple UI with Detect, Apply Patch, and Restore buttons.
- Does not store, print, or request any API key.

## What It Does Not Do

- It does not create or run a local gateway.
- It does not configure Zhipu, OpenAI-compatible, or Anthropic-compatible endpoints for you.
- It does not enable Developer Mode for you.
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

## Console Commands

Run from a clone:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1
```

Check status only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1 -NoGui -DryRun
```

Restore backups:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1 -NoGui -Revert
```

## Troubleshooting

- If Detect says Claude Desktop was not found, install Claude Desktop, open it once, then rerun the helper.
- If Apply Patch asks for administrator permission, approve it. The installed package is protected by Windows.
- If Claude updates later, rerun the helper because the patched files may be replaced.
- If the script says no known validation snippet was found, Claude Desktop changed its bundled code and this patch pattern needs an update.

## License

MIT
