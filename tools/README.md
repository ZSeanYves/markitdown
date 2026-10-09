# Tools

`tools/regression/` is the only repository-owned tool surface. Every executable
entrypoint is MoonBit (`.mbtx`) and runs the published package through MoonX.
There is no local CLI fallback, Python oracle, environment installer, shell
adapter, compatibility laboratory, or package wrapper in this tree.

The entrypoints are:

- `moonx_smoke.mbtx`: help, capability, and one text conversion smoke check.
- `run_moonx_regression.mbtx`: manifest-driven main, quality, and accurate
  regression suites with exact Markdown goldens and declared semantic signals.
- `moonx_benchmark.mbtx`: a small fixed latency sample over representative text,
  markup, structured data, and PDF inputs.

The external corpus is supplied by the sibling
`markitdown-quality-lab/` checkout. Evidence is written under `.tmp/`, which
is ignored by Git. The package coordinate must be exact, for example
`ZSeanYves/markitdown@0.8.0`; an unpublished coordinate fails closed at the
MoonX download boundary and is recorded as a release prerequisite.
