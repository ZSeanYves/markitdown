# Branch Protection Policy

The `main` branch must be protected in GitHub. The settings below are the
required 0.8 repository policy; the actual repository setting is an external
GitHub state and should be verified with the command shown after each change.

## Required settings

- Require pull requests before merging; allow zero approvals while the project
  has one active maintainer, then raise to one when a backup reviewer is added.
- Require the two continuous source checks: `MoonBit core (ubuntu-24.04)` and
  `MoonBit core (macos-15)`. The manually dispatched `MoonX consumer gate` and
  `MoonX release candidate` workflows are release evidence rather than pull
  request checks because they require an exact published package coordinate.
- Require branches to be up to date before merging.
- Dismiss stale approvals after new commits; require conversation resolution.
- Disallow force pushes and branch deletion; require linear history when it is
  compatible with the repository's merge strategy.
- Enforce the policy for administrators after a backup maintainer exists. Until
  then, document any emergency administrative bypass in the release record.

## Verification

```text
gh api repos/ZSeanYves/markitdown/branches/main/protection
gh api repos/ZSeanYves/markitdown/rulesets
```

Repository files describe the required policy, but GitHub branch protection
remains a repository-admin action and must not be inferred from CI files alone.
Re-run the API checks after changing the repository rules. Keep the exact
settings and verification date in the release record rather than copying an
old CI job name into this document.
