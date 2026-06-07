# Performance

This page documents the current benchmark entrypoint and how to interpret
results.

## Entry Point

The public benchmark entrypoint is:

```bash
bash samples/bench.sh --help
```

Actual benchmark runs are layer-scoped:

```bash
bash samples/bench.sh --layer parser --format html --iterations 1 --warmup 0
bash samples/bench.sh --layer convert --format html --iterations 1 --warmup 0
bash samples/bench.sh --layer cli --profile normal --format pdf --iterations 1 --warmup 0
bash samples/bench.sh --layer compare --format pdf --iterations 1 --warmup 0
```

External benchmark rows are expected to come from
`markitdown-quality-lab/external_bench/`.

## Layers

| Layer | Meaning |
| --- | --- |
| `parser` | measures parser-layer APIs where a direct parser benchmark exists |
| `convert` | measures `convert/convert.parse_to_ir` without spawning the CLI |
| `cli` | measures the native CLI process path |
| `compare` | compares overlap cases with an external Microsoft MarkItDown runner |

The compare layer depends on an externally managed Python MarkItDown
installation and should fail clearly when that runner is unavailable.

## Interpretation Rules

Benchmark results are:

* same-machine observations
* sample-scoped
* runner-scoped
* useful for regression triage and local direction

They are not:

* universal speed guarantees
* complete corpus coverage claims
* release promises

## Current TODO

After the DOCX v2 runtime switch, the next performance documentation task is a
fresh DOCX v2 snapshot using the current benchmark rows and the current
quality-lab checkout. Do not backfill numbers from old DOCX v1-era runs.
