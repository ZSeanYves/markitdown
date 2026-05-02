# Benchmark Comparison

This document describes the current overlap-only comparison benchmark between
`markitdown-mb` and Microsoft MarkItDown.

It is a runner-level comparison harness, not a semantic-equivalence claim.

## Current Scope

The current comparison benchmark:

* compares the local MoonBit runner and the Python MarkItDown runner
* uses explicit output paths for both sides
* records measured rows to `results.jsonl`
* records aggregate metrics to `summary.tsv`
* supports warmup and repeated measured iterations

It does not currently compare:

* Markdown semantic equivalence
* metadata semantics
* asset-export semantics
* image-context behavior
* OCR or cloud/plugin-assisted execution

## Compared Corpus

The checked-in overlap corpus is:

* `samples/benchmark/compare_corpus.tsv`

Current overlap formats:

* DOCX
* PPTX
* XLSX
* PDF
* HTML
* CSV
* Markdown
* TXT

This benchmark does not try to cover every format supported by the repository.
It only covers the current overlap surface that is practical to compare at the
runner level.

For TXT specifically, the overlap check is runner-level only: it is useful for
success-rate, elapsed-time, and output-size comparison on simple plain-text
inputs, but it is not a claim that every tool makes the same literal-escaping
choices for markdown-like text.

For Markdown specifically, the overlap check is also runner-level only: it is
useful for passthrough stability and rough elapsed-time/output-size comparison
on conservative Markdown samples, but it is not a claim of full Markdown
semantic equivalence across tools.

## Runner Setup

Repository runner:

```bash
moon run cli -- normal <input> <output.md>
```

When available, the comparison harness now builds once and defaults to the
prebuilt native CLI runner instead:

```bash
_build/native/debug/build/cli/cli.exe normal <input> <output.md>
```

`MARKITDOWN_MB_CMD` can override the repository runner command. If the harness
falls back to `moon run`, the measured time includes wrapper overhead.

Python runner resolution order:

1. `MARKITDOWN_COMPARE_CMD`
2. `markitdown` found in `PATH`
3. `MARKITDOWN_COMPARE_PY_BIN` via `python -m markitdown`

The harness does not create a repository-local Python virtual environment.

One simple install option in a user-managed environment is:

```bash
python -m pip install 'markitdown[all]==0.1.5'
```

## Environment Isolation

The comparison harness isolates the Python runner with:

* `TMPDIR`
* `XDG_CACHE_HOME`
* `HOME`

It also avoids passing OCR / Azure / OpenAI / plugin-related execution options.

## Output Layout

Artifacts are written under:

```bash
TMP_ROOT="${MARKITDOWN_TMP_DIR:-$ROOT/.tmp}"
$TMP_ROOT/bench/compare
```

Runner-specific outputs live under:

* `.../mb/<format>/<sample>/iter-N/`
* `.../python/<format>/<sample>/iter-N/`

Top-level files:

* `results.jsonl`
* `summary.tsv`

## Interpretation

This benchmark is useful for:

* success-rate comparison on overlapping inputs
* rough same-machine elapsed-time comparison
* output-size comparison

It is not useful for:

* proving Markdown semantic parity
* proving provenance parity
* proving asset / metadata parity
* evaluating OCR or cloud-assisted paths
