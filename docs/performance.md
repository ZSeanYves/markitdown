# Performance

This page documents the current benchmark v2 entrypoint and interpretation
rules. Benchmark v2 is layer-first and reads benchmark rows only from
quality-lab `external_bench`.

## Benchmark V2

The public benchmark entrypoint is:

```bash
./samples/bench.sh --layer parser|convert|cli|compare
```

Set `MARKITDOWN_QUALITY_LAB` to the quality-lab checkout before running layer
smokes:

```bash
export MARKITDOWN_QUALITY_LAB=/path/to/markitdown-quality-lab
```

Parser layer:

```bash
./samples/bench.sh --layer parser --format html --iterations 1 --warmup 0
./samples/bench.sh --layer parser --format txt --iterations 1 --warmup 0
```

Convert layer:

```bash
./samples/bench.sh --layer convert --format html --iterations 1 --warmup 0
./samples/bench.sh --layer convert --format txt --iterations 1 --warmup 0
```

CLI layer:

```bash
./samples/bench.sh --layer cli --profile normal --format pdf --iterations 1 --warmup 0
./samples/bench.sh --layer cli --profile cold-start --format pdf --iterations 1 --warmup 0
```

Compare layer:

```bash
./samples/bench.sh --layer compare --format pdf --iterations 1 --warmup 0
```

## Layer Notes

Parser layer measures `doc_parse/*` parser APIs directly. External
`format=txt` rows are mapped to the text parser internally. Direct PDF parser
library attribution is currently deferred because the async PDF API shape does
not fit the current typed parser benchmark runner without a wider harness
refactor.

Convert layer calls `convert/convert.parse_to_ir` inside the native benchmark
runner. It does not call the CLI and does not write Markdown output.

CLI layer measures the native CLI process path. The normal and cold-start
profiles are implemented. The batch profile currently fails closed because the
stable batch benchmark contract is not selected yet.

Compare layer is an overlap-only comparison between this repository runner and
Microsoft MarkItDown. It depends on an externally managed Python MarkItDown
installation and fails closed when that runner is unavailable.

## Known Blockers

`moon check bench/convert_layer` may still fail through the PDF vendor
filesystem adapter, where the current async fs API no longer exposes
`@fs.read_file` and `@fs.File` in the shape expected by
`doc_parse/pdf/vendor/mbtpdf/io/pdfiofs/pdfiofs.mbt`. That is a known
convert-layer check blocker and does not imply that the CLI or compare product
PDF path failed.

PDF parser direct attribution remains deferred as described above.

## Interpretation

Benchmark results are same-machine, sample-scoped, and runner-scoped. They are
not a universal speed guarantee.
