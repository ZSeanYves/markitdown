# Benchmark Comparison

This document describes the current overlap-only comparison benchmark between
this repository and Microsoft MarkItDown.

It is intentionally limited in scope. The goal of the first phase is to compare
success rate, wall-clock cost, and output-size behavior on overlapping formats,
not to declare semantic equivalence.

## Current Scope

The current comparison benchmark:

* compares the local runner and the Python Microsoft MarkItDown runner
* uses explicit output paths for both sides
* records measured rows to `results.jsonl`
* records aggregate metrics to `summary.tsv`
* supports warmup and repeated measured iterations

The current comparison benchmark does **not**:

* compare metadata semantics
* compare asset-export semantics
* compare image-context behavior
* compare Markdown body similarity
* enable OCR plugins
* enable Azure Document Intelligence
* include YAML, Markdown passthrough, or TSV in the first overlap-only phase

## Current Overlap-only Corpus

The checked-in corpus is:

* `samples/benchmark/compare_corpus.tsv`

The current first-phase formats are:

* DOCX
* PPTX
* XLSX
* PDF
* HTML
* CSV

These were chosen because they are part of the current overlap surface between
the two tools without requiring sidecar parity, asset parity, or optional
cloud/plugin flows.

## Runner Setup

This repository runner is invoked with:

```bash
moon run cli -- normal <input> <output.md>
```

The Python runner is expected to come from a user-prepared virtual environment.
Recommended setup:

```bash
python -m venv .venv-markitdown-compare
. .venv-markitdown-compare/bin/activate
pip install 'markitdown[all]==0.1.5'
```

The comparison harness resolves the Python runner in this order:

1. `MARKITDOWN_COMPARE_CMD`
2. `MARKITDOWN_COMPARE_PY_BIN` via `python -m markitdown`
3. default `.venv-markitdown-compare/bin/markitdown`

## Environment Isolation

The Python runner is isolated by the comparison harness with:

* `TMPDIR`
* `XDG_CACHE_HOME`
* `HOME`

It also avoids passing OCR / Azure / OpenAI-related execution options and does
not enable plugin paths.

## Output Layout

Comparison artifacts are written under:

```bash
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
$TMP_ROOT/bench/compare
```

Runner-separated outputs live under:

* `.../mb/<format>/<sample>/iter-N/`
* `.../python/<format>/<sample>/iter-N/`

Top-level result files are:

* `results.jsonl`
* `summary.tsv`

## Interpretation

Treat this benchmark as a runner-level comparison harness, not as a quality
oracle.

What it is good for:

* success-rate comparison on overlapping inputs
* rough performance comparison on the same machine
* spotting large regressions or startup surprises

What it is not good for:

* proving Markdown semantic equivalence
* comparing provenance quality
* comparing image / asset / metadata fidelity
* comparing OCR or cloud-assisted behavior
