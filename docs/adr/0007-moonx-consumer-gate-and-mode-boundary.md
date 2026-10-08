# ADR 0007: MoonX consumer verification and text mode boundary

## Status

Accepted for the 0.8 text-only release line.

## Decision

The repository keeps three verification lanes that share the same manifests,
judges, and product protocol:

| Lane | Entry | Purpose | Runner identity |
| --- | --- | --- | --- |
| Source gate | `check_balance.sh`, `check_balance_quality.sh`, `check_accurate.sh` | PR and local worktree feedback | fresh Native release or explicit override; local Wasm checks remain separate |
| MoonX consumer gate | `moonx tools/regression/run_moonx_regression.mbtx -- ZSeanYves/markitdown@<exact-version>` | post-publication verification of the package users actually consume | exact registry coordinate, Wasm by default |
| Performance gate | `bench_runner run --preset official-external-compare` | controlled product performance and RSS comparison | Native release binary, with a separate Wasm baseline when that target is measured |

The MoonX lane is the release-facing package acceptance entry. It sets
`MARKITDOWN_CLI_RUNNER=moonx`, requires an exact version (never `@latest`), runs
the existing CLI probe, and then reuses the three existing regression suites.
Its evidence is written under `.tmp/moonx-regression/`. `--target native` is
available only for compatibility checks; Wasm is the default and the supported
MoonX distribution path.

The source gate remains necessary because a registry coordinate cannot represent
unpublished changes. On 2026-10-09, `moonx --target wasm
ZSeanYves/markitdown@0.8.0 --help` failed with `Prebuilt wasm asset does not
exist`. Running every PR against MoonX would therefore either test an old
published package or fail before reaching the changed source. The release gate
must run only after the exact package and its Wasm prebuilt asset are published.

The formal benchmark is deliberately not switched to MoonX. MoonX adds registry
resolution, cache state, process startup, and linear-memory Wasm costs that are
not part of the existing Native product performance contract. Mixing those
variables into `official-external-compare` would make a timing regression
unattributable. MoonX consumer acceptance and Native/Wasm performance baselines
are reported separately.

## Script boundary

New deterministic orchestration is written in `.mbtx`:

- `tools/regression/moonx_smoke.mbtx` checks help, capabilities, and one text
  conversion against the exact package coordinate.
- `tools/regression/run_moonx_regression.mbtx` runs the smoke check and then the
  shared balance, quality, and accurate suites.

The existing shell files remain the implementation of the data-heavy manifest
judges and POSIX file-descriptor/temporary-directory behavior. They are invoked
as a thin compatibility layer by the MBTX entry. Python remains for the
external benchmark oracle and reproducible reference-environment installation;
rewriting those parts only to make the file extensions uniform would change the
oracle and add risk without improving the product contract.

## Mode boundary

Removing OCR and audio removes multimodal routes, model setup, and their test
corpora. It does not remove the text conversion modes:

- `balance` is the safe default semantic route.
- `accurate` enables declared higher-fidelity Office/ODF/PDF text recovery.
- `stream` controls bounded pull/backpressure behavior while preserving the
  same text meaning.

`Markdown`, `Debug`, and `Rag` are output views, not competing parser modes, so
they remain part of the public contract. Unsupported combinations continue to
fail closed. A later API cleanup may rename the two dimensions to
`ConversionProfile` and `OutputView`, but deleting them in the text-only change
would remove real consumers and weaken resource-control guarantees.

This separation matches mature converters: Pandoc keeps a reader → AST → filter
→ writer pipeline, while Unstructured exposes explicit PDF strategies and
Docling exposes configurable pipelines whose OCR and VLM options carry separate
runtime costs. Those projects support keeping semantic strategy and output
representation explicit without treating OCR as the definition of every mode.
