# Benchmark Manifests

This directory holds the checked default manifest files used by the repository's
named benchmark suites.

Current manifests:

* `doc_parse.tsv`
  default row list for the direct `doc_parse` library benchmark
* `product_path.tsv`
  default row list for the same-process product-path attribution benchmark

Recommended public entrypoint:

```bash
./samples/bench.sh
```

Suite examples:

```bash
./samples/bench.sh --suite doc-parse --kind library --iterations 10 --warmup 2
./samples/bench.sh --suite product-path --kind stage --iterations 10 --warmup 2
```

Internal rerun helpers still accept explicit `--manifest PATH` overrides when a
maintainer needs to run a narrowed or experimental manifest.
