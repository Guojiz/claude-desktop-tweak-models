# Claude Desktop Tweak Models

[中文说明](README.zh-CN.md) | English

Patch and first-run helper for Claude Desktop on Windows. It relaxes Claude Desktop's local model ID validation so third-party model settings can use custom model IDs from Anthropic-compatible gateways, instead of only accepting model names that look like Anthropic's own Claude models.

This project is for **Claude Desktop**, not **Claude Code**.

For a step-by-step Chinese setup guide, see: [Configuring third-party Anthropic-compatible models in Claude Desktop](docs/third-party-models.zh-CN.md).

## Quick Start

Open PowerShell, then paste and run this one-liner:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/Guojiz/claude-desktop-tweak-models/main/Run-Latest.ps1)"
```

You do not need to start PowerShell as Administrator. The helper requests UAC permission at the beginning when it needs to modify Claude Desktop's protected Windows app package.

If Claude Desktop is not installed or Windows does not expose the package, the helper shows an English setup prompt and can download and run the official Windows installer from Anthropic. If automatic install fails, it opens the public download page:

<https://claude.ai/download>

## What It Does

- Finds the installed Claude Desktop Windows package.
- Downloads and runs the official Windows installer when Claude Desktop is missing and you approve the prompt.
- Creates a minimal Claude user config folder when Claude has not been configured yet.
- Saves an English first-run guide beside the Claude user config.
- Allows Gateway / Mantle model IDs that do not match Claude / Anthropic naming patterns.
- Keeps Electron ASAR integrity metadata valid after patching.
- Disables Claude Desktop's internal updater so the patch is not immediately overwritten.
- Adds a hosts block for `api.anthropic.com`.
- Disables Microsoft Store automatic app downloads through Windows policy.
- Does not store, print, or require an API key.

## First-Run Setup

After the helper opens Claude Desktop:

1. Open Settings.
2. Enable Developer Mode if it is not already enabled.
3. Open the third-party inference / models / providers section.
4. Add a Gateway provider.
5. Fill in the gateway details from your provider.

Example:

- Provider: `Gateway`
- Gateway base URL: `https://open.bigmodel.cn/api/anthropic`
- Gateway auth scheme: `x-api-key`
- Model ID: `glm-5.2`
- Display name: `GLM-5.2`
- Model discovery: off

Zhipu's Claude-compatible gateway documentation:

<https://docs.bigmodel.cn/cn/guide/develop/claude/introduction>

## Usage From a Clone

If you already cloned this repository, open PowerShell in this repository folder, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1
```

The script searches for the installed Claude Desktop Windows package, prepares first-run user files, patches Claude, updates integrity hashes, applies update protection, and restarts Claude.

## Important Notes

- This modifies the locally installed Claude Desktop application package.
- It is version-sensitive and was built against the Windows MSIX Claude Desktop package layout.
- A future Claude Desktop release may rename minified functions or move validation logic.
- If Claude is updated or repaired, rerun the script.
- The script creates local backups under `backups/`; those backups are intentionally ignored by Git.
- The script cannot safely enter or store your provider API key. Enter keys only in Claude Desktop or your trusted provider UI.

## Revert

The script saves original files in `backups/<Claude package name>/` before patching. To revert manually, stop Claude and restore:

- `Claude.exe.original` to the installed `Claude.exe`
- `app.asar.original` to the installed `app.asar`

Then remove the hosts block marked:

```text
# Claude auto-update block - keep patched third-party model setup
```

and change or delete:

```text
HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore\AutoDownload
```

## License

MIT
