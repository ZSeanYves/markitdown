# Governance Tooling

Phase 0 governance is deliberately implemented as small standard-library
scripts so it can run before MoonBit dependencies or optional Python runtimes
are installed.

## Baseline

```bash
MOONBIT_NEW_NATIVE=0 python3 tools/governance/collect_baseline.py --write
MOONBIT_NEW_NATIVE=0 python3 tools/governance/collect_baseline.py --check
python3 tools/governance/check_toolchain.py
```

`--write` is an intentional baseline update and must be reviewed with the JSON
and fixture hash diff. `--check` verifies upstream, toolchain, benchmark lock,
quality-lab SHA and fixture inputs; it does not fail merely because a source
PR changes the package inventory. CI always runs from a clean checkout.

## PR policy

```bash
python3 tools/governance/check_pr_policy.py --event-path "$GITHUB_EVENT_PATH"
python3 -m unittest discover -s tools/governance/tests -p 'test_*.py'
```

The policy checks required PR sections and requires an explanation when
generated interfaces or golden/snapshot files change. GitHub branch protection
must require the governance job; a local script alone cannot enforce merge
policy.
