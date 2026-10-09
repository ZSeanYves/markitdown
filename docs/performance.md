# Performance evidence

Performance acceptance is a MoonX consumer measurement. The repository no
longer contains a local benchmark executable or a Python reference environment,
so a measurement cannot accidentally mix source checkout behavior with the
published package behavior.

Run the fixed sample after publication:

```text
moonx tools/regression/moonx_benchmark.mbtx ZSeanYves/markitdown@<exact-version> --target wasm
moonx tools/regression/moonx_benchmark.mbtx ZSeanYves/markitdown@<exact-version> --target native
```

The entrypoint records one elapsed time per representative text, Markdown,
HTML, JSON, and text-layer PDF input under `.tmp/moonx-benchmark/summary.tsv`.
It is a reproducible consumer smoke benchmark, not a universal latency promise.
Compare runs only when the package version, MoonX target, toolchain, host, input
hashes, and sampling policy are the same. Wasm and Native have separate
baselines; Native timing does not close a Wasm gate.

The release workflow treats an unavailable package, failed conversion, missing
output, or incomplete evidence as a blocked RC prerequisite. It does not turn a
registry miss into a local fallback result.
