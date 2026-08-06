# Branch Protection Policy

The `main` branch must be protected in GitHub. The settings below are the
required Phase 0 policy; the actual repository setting is an external GitHub
state and should be verified with the command shown after each change.

## Required settings

- Require pull requests before merging; allow zero approvals while the project
  has one active maintainer, then raise to one when a backup reviewer is added.
- Require these CI checks: `Phase 0 governance`, `MoonBit core (ubuntu-24.04)`,
  `MoonBit core (macos-15)`, `Python and shell tools`, `Coverage`, `Main
  regression (Linux)`, `Main regression (macOS)`, `Quality regression`,
  `Accurate regression`, and `Performance`.
- Require branches to be up to date before merging.
- Dismiss stale approvals after new commits; require conversation resolution.
- Disallow force pushes and branch deletion; require linear history when it is
  compatible with the repository's merge strategy.
- Enforce the policy for administrators after a backup maintainer exists. Until
  then, document any emergency administrative bypass in the release record.

## Verification

```bash
gh api repos/ZSeanYves/markitdown/branches/main/protection
gh api repos/ZSeanYves/markitdown/rulesets
```

The Phase 0 implementation adds repository-side CODEOWNERS, CI and PR policy
files. GitHub branch protection remains a repository-admin action and must not
be inferred from those files alone. It was applied to `main` on 2026-08-05 and
verified through the API: strict status checks are enabled, pull requests are
required with zero approvals during the single-maintainer period, force pushes
and deletion are disabled, linear history and conversation resolution are
enabled, and administrator enforcement remains false until a backup reviewer
is assigned.
