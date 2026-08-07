# Git Hooks

## Pre-commit Hook

This optional pre-commit hook runs `moon check` before finalizing a commit. It
does not format files, run tests, validate documentation, or replace the CI
matrix.

### Usage Instructions

To use this pre-commit hook:

1. Make the hook executable if it isn't already:
   ```bash
   chmod +x .githooks/pre-commit
   ```

2. Configure Git to use the hooks in the .githooks directory:
   ```bash
   git config core.hooksPath .githooks
   ```

3. The hook will run when you execute `git commit`. Run the complete commands
   in [CONTRIBUTING.md](../CONTRIBUTING.md) before opening a pull request.
