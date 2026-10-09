# 0.8 release candidate

The RC workflow is `.github/workflows/rc.yml`. It is manually dispatched with
an exact published version, a MoonX target, and a regression suite. It checks
the package consumer path, then runs the fixed MoonX benchmark and uploads the
smoke, regression, and timing evidence.

Before publication, the workflow cannot download the package by design. That is
an external release prerequisite, not a reason to run a local compatibility
binary. After publication, both `wasm` and `native` are run independently; the
Wasm result is the portable baseline and Native may add only declared
extensions.

The checkout itself is validated with:

```text
moon fmt --check
moon info
moon check --target all --warn-list +73 --deny-warn
moon test --target native --no-parallelize
moon test --target wasm --no-parallelize
moon build --target native --release --package ZSeanYves/markitdown
moon build --target wasm --release --package ZSeanYves/markitdown
```

The release owner attaches the exact package coordinate, quality-lab revision,
MoonX target, summaries, and rollback version. Missing registry assets,
incomplete manifests, conversion failures, or missing output files fail closed.
