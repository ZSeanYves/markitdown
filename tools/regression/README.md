# MoonX regression

The repository has one external validation path. It executes the exact package
coordinate through MoonX and reads the checked-in manifests from the sibling
`markitdown-quality-lab` checkout. A source-built executable is never substituted
for a package consumer run.

```text
moonx tools/regression/moonx_smoke.mbtx ZSeanYves/markitdown@0.8.0 --target wasm
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@0.8.0 --target wasm --suite all
moonx tools/regression/moonx_benchmark.mbtx ZSeanYves/markitdown@0.8.0 --target wasm
```

`run_moonx_regression.mbtx` accepts `--suite main|quality|accurate|all`,
`--format FORMAT`, and `--case ID`. Main rows compare deterministic Markdown
goldens and require non-empty RAG output. Quality and accurate rows execute the
declared `expected_signals` against Markdown, debug, or provenance output; the
runner covers content, order, counts, links, tables, images, and asset presence.

Every case receives its own command log under `.tmp/moonx-regression/cases/`.
The final `summary.tsv` records the exact coordinate, target, suite, counts,
elapsed time, and status. Failures retain the output and the first failed signal
for inspection.

The coordinate must include an exact version. `@latest`, a local binary, a
worktree, and an unpublished package are rejected. Before publication, a MoonX
download error is expected evidence of the missing registry asset, not a reason
to reintroduce a local compatibility runner.
