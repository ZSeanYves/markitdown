# Release Checklist

Use this checklist for every 0.8, 0.9 RC and 1.x release. The release owner
must attach command output or artifact links for each checked item.

## Source and baseline

- [ ] Version, changelog, migration guide and capability matrix agree.
- [ ] MarkItDown upstream tag/commit and quality-lab SHA are recorded.
- [ ] MoonBit toolchain matches `tools/governance/toolchain.json`.
- [ ] `python3 tools/governance/collect_baseline.py --check` passes.
- [ ] `python3 tools/governance/check_documentation.py` passes and current
      benchmark claims point to committed trusted summaries.
- [ ] Dependency lock, license, NOTICE and SBOM diffs are reviewed.

## Verification

- [ ] `moon fmt --check` passes.
- [ ] `moon info` produces no unexpected interface diff.
- [ ] `moon check --target all --warn-list +73 --deny-warn` passes.
- [ ] Native debug/release passes on Linux x86_64 and macOS arm64 with the
      declared backend environment.
- [ ] Contract, regression, coverage, fuzz seed and sanitizer gates pass.
- [ ] Official external comparison uses MarkItDown 0.1.7 and meets the stated
      per-case/per-format performance gates.

## Artifacts and operations

- [ ] CLI `--version` equals the module version.
- [ ] Linux x86_64 and macOS arm64 archives build from clean checkouts.
- [ ] SHA-256, signatures/attestations and complete SBOM are uploaded.
- [ ] Archive paths, modes, timestamps and file order are reproducible.
- [ ] Fresh-machine install, conversion, upgrade and rollback smoke tests pass.
- [ ] Release soak has no open P0/P1 issue.
- [ ] Support window, known limitations and security contact are published.

## Rollback

Keep the previous verified archive, checksum, SBOM and install command. If a
release fails post-publication verification, mark it withdrawn, publish the
previous version as the recommended rollback, and add a regression fixture
before reopening the release line.
