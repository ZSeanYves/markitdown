# doc_parse Library Benchmark Manifest

This directory contains the checked manifest for the library-only
`doc_parse/*` benchmark harness.

Runner entrypoint:

```bash
./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
```

Focused helper compatibility:

```bash
./samples/bench_doc_parse.sh --iterations 10 --warmup 2
```

The harness is intentionally different from the smoke/compare/batch suites:

* it calls `doc_parse/*` APIs directly
* it does not call `convert/*`
* it runs many iterations inside one native process
* it writes summary artifacts to `.tmp/bench/doc_parse/`

Manifest columns:

* `format`: package family selector such as `json`, `markdown`, or `xlsx`
* `path`: checked sample path inside the repository
* `label`: stable row label used in benchmark outputs
* `size_class`: lightweight size grouping such as `small` or `large`
* `stages`: comma-separated stages to benchmark for that format

Stage interpretation:

* text / markup / scanner packages usually expose `parse` or `scan`
* package/container foundations expose `open`
* OOXML semantic foundations expose semantic `parse` on a pre-opened package
* `inspect` and `validate` run on already opened/parsed models so the harness
  can separate traversal cost from parse/open cost

The first harness round focuses on:

* `text`
* `csv`
* `tsv`
* `json`
* `yaml`
* `xml`
* `html`
* `markdown`
* `zip`
* `ooxml`
* `epub`
* `xlsx`
* `docx`
* `pptx`

`pdf` is intentionally deferred in this first library-only harness pass.
