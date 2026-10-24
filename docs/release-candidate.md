# Native release candidate

The 0.8 candidate is unreleased. The
[Native plan](architecture/native-performance-plan.md) controls P0–P6 exit
conditions. P1 target/tooling changes and local correctness evidence do not
establish completion of P2–P6.

## Checkout and installation

The continuous workflow is `.github/workflows/ci.yml`. Required check names
remain `MoonBit core (ubuntu-24.04)` and `MoonBit core (macos-15)` for branch
protection. It pins MoonBit `0.1.20261021` /
`moonc v0.10.17+093cb8f9c`, asserts runner architecture, and configures Native
check/interfaces/formatting, debug/release tests and builds, local installation
and independent library consumption.

```text
moon check --target native --warn-list +73 --deny-warn
moon test --target native --no-parallelize
moon test --target native --release --no-parallelize
moon build --target native .
moon build --target native --release .
moon info
moon fmt
```

These commands must be run serially; review generated interfaces and
formatting diffs. A configured workflow is not hosted execution evidence.

## Candidate workflow

`.github/workflows/rc.yml` is manually dispatched with a local or fixed Git
source and a suite. A Git source requires a full 40-character commit SHA.
It calls `native_install.mbtx`, then runs the corpus against the installed
executable recorded in `installed-binary.txt`. Both supported platforms
upload installation and regression evidence, including failures.

```text
moon run --target native tools/regression/native_install.mbtx -- --source local --root /absolute/path/to/markitdown --evidence /absolute/path/to/new-install-evidence
moon run --target native tools/regression/native_install.mbtx -- --source git --root /absolute/path/to/markitdown --git-url https://github.com/ZSeanYves/markitdown.git --rev <full-40-character-sha> --evidence /absolute/path/to/new-git-evidence
```

Do not identify an uncommitted local candidate as a successfully installed
fixed remote commit. `--prepare-only true` records preparation only and does
not pass installation.

## Full RC and post-publication

The candidate workflow covers installation and corpus execution. P5 also
requires the [formal performance protocol](performance.md), 60-minute
reliability workloads, independent-process concurrency, and applicable
coverage/mutation/sanitizer/fuzz gates on Linux x86_64 and macOS arm64.
Unavailable tooling stays explicitly unaccepted. P2–P4 must complete their
execution/budget, format and PDF contracts first.

Publication is a separate action. After publication,
`.github/workflows/native-consumer.yml` verifies an exact registry version,
a fresh installed CLI and a consumer without local dependency overrides.
Missing registry assets fail that lane; local evidence cannot replace it.

The release record must identify source and package hashes, corpus revision
and dirty state, exact package coordinate, toolchain, platforms, commands,
summaries, known limitations and rollback version. Until P5 passes, do not
claim candidate acceptance; until P6 passes, do not claim formal delivery.
