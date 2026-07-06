# Maintaining

Use this checklist when updating the project.

## Before changing patch behavior

- Confirm the Claude Desktop version affected.
- Keep the patch reversible.
- Prefer dry-run checks before modifying local files.
- Keep provider examples free of secrets.
- Record compatibility notes in the relevant docs or release notes.

## Before accepting a pull request

- Check that no proprietary app files are included.
- Check that no credentials or account data are included.
- Confirm the change is scoped to one behavior.
- Ask for manual test notes when the change affects patching or restore behavior.

## Release notes

For user-facing changes, include:

- what changed;
- who should update;
- tested Claude Desktop versions;
- restore or rollback notes;
- known limitations.
