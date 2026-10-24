# Branch protection policy

The `main` branch must be protected in GitHub. This document specifies policy;
actual protection is external repository state and must be read back after a
change.

## Required settings

- Require pull requests before merging; allow zero approvals while there is
  one active maintainer, then require one when a backup reviewer is available.
- Preserve the exact continuous check names
  `MoonBit core (ubuntu-24.04)` and `MoonBit core (macos-15)`.
  They now run the Native-only CI matrix for Linux x86_64 and macOS arm64.
  Renaming a workflow or job does not automatically update required checks.
- Keep manually dispatched `Native release candidate` and
  `Published Native consumer confirmation` as release evidence, not mandatory
  PR checks. The latter needs an already-published exact package version.
- Require branches to be up to date, dismiss stale approvals and resolve
  conversations.
- Disallow force pushes and branch deletion; use linear history when
  compatible with the repository's merge strategy.
- Enforce protection for administrators once a backup maintainer exists.
  Record emergency administrative bypasses in the release record.

## Verification

```text
gh api repos/ZSeanYves/markitdown/branches/main/protection
gh api repos/ZSeanYves/markitdown/rulesets
```

Read back the settings after an administrative change and save the date and
response. Repository YAML does not prove that branch protection is enabled,
that either hosted job passed, or that the
[Native P2–P6 gates](../architecture/native-performance-plan.md) are complete.
