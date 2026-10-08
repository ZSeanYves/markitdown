# Governance Tooling

Phase 0 governance is deliberately implemented as small standard-library
scripts so it can run before MoonBit dependencies or optional Python runtimes
are installed.

## Baseline

```bash
MOONBIT_NEW_NATIVE=0 python3 tools/governance/collect_baseline.py --write
MOONBIT_NEW_NATIVE=0 python3 tools/governance/collect_baseline.py --check
moon run tools/governance/check_toolchain.mbtx
moon run tools/governance/check_toolchain.mbtx --self-test
python3 tools/governance/check_architecture.py
```

`--write` is an intentional baseline update and must be reviewed with the JSON
and fixture hash diff. `--check` verifies upstream, toolchain, benchmark lock,
quality-lab SHA and fixture inputs; it does not fail merely because a source
PR changes the package inventory. CI always runs from a clean checkout.

`warning-baseline.json` records the reviewed zero-diagnostic result for the 0.8
source migration. `check_documentation.py` validates its owner, expiry,
remediation rule and explicit prohibition on silent grandfathering. The release
gate remains `moon check --target all --warn-list +73 --deny-warn`; any new
diagnostic must be classified before merge.

## PR policy

```bash
python3 tools/governance/check_pr_policy.py --event-path "$GITHUB_EVENT_PATH"
python3 -m unittest discover -s tools/governance/tests -p 'test_*.py'
```

The policy checks required PR sections and requires an explanation when
generated interfaces or golden/snapshot files change. GitHub branch protection
must require the governance job; a local script alone cannot enforce merge
policy.

## Phase 1 architecture

`check_architecture.py` compares `lib/pkg.generated.mbti` with the reviewed
0.8 golden, rejects internal package types in that interface, limits the API
adapter to an explicit import allowlist, prevents mutable `pub(all)` records in
the facade, enforces separate total-visibility and mutable-record ceilings for
legacy packages, and freezes the three reviewed direct dependencies. An
intentional API or dependency change updates the corresponding machine file in
the same R3 PR with an RFC, compatibility impact and regeneration command.

The maintenance inventory deliberately has no product external commands after
the 0.8 text-only migration. OCR, audio transcription, PDF rasterization,
model downloads and their installers are retired; Python remains available only
for the pinned benchmark oracle environment.

## Documentation

`check_documentation.py` separates maintained narrative documentation from
generated fixture/showcase evidence. It verifies local links across maintained
docs and every README, keeps the two root README files byte-identical, rejects
retired guides and benchmark paths, and cross-checks published medians against
the committed trusted benchmark summaries.

```bash
python3 tools/governance/check_documentation.py
```
