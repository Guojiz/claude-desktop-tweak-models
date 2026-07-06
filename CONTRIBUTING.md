# Contributing

Thank you for considering a contribution.

This project patches Claude Desktop behavior so custom Claude-compatible model IDs can be used with third-party providers. Contributions should keep the tool understandable, reversible, and safe for users who are editing a local desktop app.

## Good contributions

Useful contributions include:

- clearer Windows setup notes;
- safer patch and restore logic;
- compatibility notes for new Claude Desktop versions;
- provider configuration examples without secrets;
- tests or dry-run checks;
- better error messages;
- documentation fixes.

## Do not contribute

Please do not include:

- Claude Desktop application binaries;
- copied proprietary source files from Claude Desktop;
- API keys, tokens, cookies, or account data;
- provider credentials;
- screenshots that expose private accounts;
- changes that make the patch hard to reverse.

## Before opening a pull request

1. Open an issue first for large behavior changes.
2. Keep the change small and focused.
3. Explain which Claude Desktop version or provider behavior you tested.
4. Include the before and after behavior.
5. Make sure rollback or restore behavior still works.

## AI-assisted contributions

AI-generated drafts are welcome, but please review them before submission and say when a change was drafted with AI assistance.
