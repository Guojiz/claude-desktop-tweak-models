# Claude Desktop Tweak Models

Patch helper for Claude Desktop on Windows to allow custom Gateway model IDs that do not look like Anthropic model names, such as Zhipu `glm-5.2`.

This is for Claude Desktop, not Claude Code.

## What It Does

- Allows Gateway/Mantle model IDs that do not match Claude/Anthropic naming patterns.
- Preserves Electron ASAR integrity metadata after patching.
- Disables Claude Desktop's internal updater so the patch is not immediately overwritten.
- Adds a hosts block for `api.anthropic.com`.
- Disables Microsoft Store automatic app downloads through Windows policy.
- Does not store, print, or require an API key.

## Zhipu GLM-5.2 Settings

Configure Claude Desktop third-party inference with:

- Provider: `Gateway`
- Gateway base URL: `https://open.bigmodel.cn/api/anthropic`
- Gateway auth scheme: `x-api-key`
- Model ID: `glm-5.2`
- Display name: `GLM-5.2`
- Model discovery: off

Zhipu's Claude-compatible gateway is documented here:

https://docs.bigmodel.cn/cn/guide/develop/claude/introduction

## Usage

Run PowerShell as Administrator:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Protect-Claude-Zhipu-GLM52.ps1
```

The script searches for the installed Claude Desktop Windows package, patches it, updates integrity hashes, applies update protection, and restarts Claude.

## Important Notes

- This modifies the locally installed Claude Desktop application package.
- It is version-sensitive and was built against the Windows MSIX Claude Desktop package layout.
- A future Claude Desktop release may rename minified functions or move validation logic.
- If Claude is updated or repaired, rerun the script.
- The script creates local backups under `backups/`; those backups are intentionally ignored by Git.

## Network Caveat

This patch only makes Claude Desktop accept and use the custom Gateway configuration. It does not solve network reachability. Your machine still needs to be able to reach:

```text
https://open.bigmodel.cn/api/anthropic
```

## Revert

The script saves original files in `backups/<Claude package name>/` before patching. To revert manually, stop Claude and restore:

- `Claude.exe.original` to the installed `Claude.exe`
- `app.asar.original` to the installed `app.asar`

Then remove the hosts block marked:

```text
# Claude auto-update block - keep patched Zhipu GLM-5.2 setup
```

and change or delete:

```text
HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore\AutoDownload
```

## License

MIT
