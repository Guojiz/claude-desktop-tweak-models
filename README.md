# Claude Desktop Tweak Models

[中文说明](README.zh-CN.md) | English

Patch helper for Claude Desktop on Windows. It relaxes Claude Desktop's local model ID validation so third-party model settings can use custom model IDs from Anthropic-compatible gateways, instead of only accepting model names that look like Anthropic's own Claude models.

This project is for **Claude Desktop**, not **Claude Code**.

For a step-by-step Chinese setup guide, see: [Configuring third-party Anthropic-compatible models in Claude Desktop](docs/third-party-models.zh-CN.md).

## Contents

- [Why This Exists](#why-this-exists)
- [What It Does](#what-it-does)
- [Compatible Model IDs](#compatible-model-ids)
- [Chinese Setup Guide](docs/third-party-models.zh-CN.md)
- [Example: Zhipu GLM-5.2](#example-zhipu-glm-52)
- [Usage](#usage)
- [Important Notes](#important-notes)
- [Network Caveat](#network-caveat)
- [Revert](#revert)
- [License](#license)

## Why This Exists

I wanted to use Claude Desktop with domestic / third-party large language models through Claude Desktop's developer-mode third-party model settings.

However, after configuring a third-party provider, I found that the **Model ID** field appeared to accept only Anthropic's own model IDs. If I entered a model ID from another provider, Claude Desktop would throw an error.

This may have been caused by a later Claude Desktop update, but it feels like a departure from the original purpose of the third-party model feature. As far as I understand, this setting should allow Anthropic-compatible gateways to provide their own model IDs.

So I made this patch.

## What It Does

- Allows Gateway / Mantle model IDs that do not match Claude / Anthropic naming patterns.
- Keeps Electron ASAR integrity metadata valid after patching.
- Disables Claude Desktop's internal updater so the patch is not immediately overwritten.
- Adds a hosts block for `api.anthropic.com`.
- Disables Microsoft Store automatic app downloads through Windows policy.
- Does not store, print, or require an API key.

## Compatible Model IDs

This patch is not limited to one provider or one model name.

It is intended for model IDs served through an **Anthropic-compatible API / gateway**, for example:

- a domestic model exposed through a Claude-compatible endpoint;
- a custom gateway that translates Anthropic-style requests;
- a third-party inference provider configured inside Claude Desktop.

The patch only changes Claude Desktop's local model ID validation. It does **not** make an arbitrary API compatible with Anthropic's API format.

## Example: Zhipu GLM-5.2

The following is only an example configuration. Other Anthropic-compatible gateways may use different URLs, auth schemes, and model IDs.

Configure Claude Desktop third-party inference with:

- Provider: `Gateway`
- Gateway base URL: `https://open.bigmodel.cn/api/anthropic`
- Gateway auth scheme: `x-api-key`
- Model ID: `glm-5.2`
- Display name: `GLM-5.2`
- Model discovery: off

Zhipu's Claude-compatible gateway documentation:

<https://docs.bigmodel.cn/cn/guide/develop/claude/introduction>

## Usage

Open **PowerShell as Administrator** in this repository folder, then paste and run:

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
- The script filename currently mentions Zhipu GLM-5.2 because that was the original test case. The documentation and intended use are broader: Anthropic-compatible custom model IDs.

## Network Caveat

This patch only makes Claude Desktop accept and use the custom Gateway configuration.

It does not solve network reachability, account access, provider quota, or API compatibility issues. Your machine still needs to be able to reach the gateway URL you configured.

For the Zhipu example above, that URL is:

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
