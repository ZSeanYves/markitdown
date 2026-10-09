# Text compatibility lab

The former local compatibility harness and its Python/shell adapters were
retired. Corpus ownership now belongs to the sibling
`markitdown-quality-lab` checkout; the repository consumes its manifests as
data through the pure MoonBit runner.

Run the current lab after publication:

```text
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@<exact-version> --suite main
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@<exact-version> --suite quality
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@<exact-version> --suite accurate
```

The runner compares main Markdown goldens and evaluates quality/accurate
signals for text, structure, order, diagnostics, links, tables, and assets.
There is no upstream-runtime oracle and no second conversion path in this
repository. Historical lab decisions remain in the RFC and Git history.
