# Performance Evidence

This page is the current public performance record for the unreleased 0.8 line.
It reports one complete, reproducible measurement on a named machine; it is not
a universal latency promise.

## Measurement identity

| Field | Value |
| --- | --- |
| Date | 2026-08-07 |
| Product commit | `8d0dc5e12e8b2265f92e8aa8fcf7a622af2a8db4` |
| Quality-lab commit | `d079e50b3e5ac181283c6c818e931bd2ef936a13` |
| Host | Apple M4, 16 GiB, arm64, macOS 26.5.2 |
| MoonBit | `moon 0.1.20260803`, `moonc v0.10.6+80dc50f24` |
| External reference | Microsoft MarkItDown 0.1.7, Python 3.11.15 |
| Build | native release CLI and native release benchmark runner |
| Sampling | one warmup and five measured samples per row/tool |

The benchmark lock SHA-256 is
`0dcf773e58750199153e164a4d7dd21a9d05304b2db837f9518f44653803795b`.
All rows use the same quality-lab inputs. A comparison contributes to a speed
ratio only after the runner accepts its semantic signals, route/fidelity
contract, provenance, output density, and process result.

## External comparison

Formal run `run-1786101654079-0f0c773a82` selected 25 rows across 11 formats.
All 25 MoonBit CLI rows, 25 engine rows, and 25 comparison rows were trusted.
MarkItDown completed 24 rows; five measured reference samples timed out and are
treated as censored lower-bound comparisons.

- MoonBit CLI median of row medians: **63.941 ms**.
- MoonBit in-process engine median of row medians: **59.604 ms**.
- MarkItDown 0.1.7 median of row medians: **699.717 ms**.
- Every row passed the 2x gate; every format passed the 3x geometric-mean gate.
- MoonBit CLI RSS passed every configured budget with no missing measurement.

| Format | Rows | CLI speedup | Engine speedup |
| --- | ---: | ---: | ---: |
| TXT | 3 | 15.77x | 22.27x |
| CSV | 3 | 11.61x | 13.08x |
| Markdown | 3 | 13.27x | 15.93x |
| HTML | 3 | 16.70x | 18.29x |
| ZIP | 2 | 11.80x | 19.82x |
| EPUB | 2 | 9.61x | 11.16x |
| PDF | 2 | 5.62x | 5.62x |
| DOCX | 1 | 64.11x | 285.79x |
| PPTX | 2 | 38.55x | 73.25x |
| XLSX | 3 | 71.89x | 73.69x |
| IPYNB | 1 | 126.10x | 1281.47x |

Speedup is `MarkItDown median / MoonBit median`. Ratios compare the accepted
semantic contract, not byte-identical Markdown or Python API compatibility.
Large ratios on startup-heavy or censored rows must not be generalized to all
documents.

## Native and optional self measurement

Formal run `run-1786102949457-9591fe380a` measured 53 rows that do not have a
valid external semantic comparison, including ODF, technical text, OCR, and
audio. All 106 CLI/engine cases were trusted, route coverage was complete, no
sample timed out, and all CLI RSS budgets passed.

- MoonBit CLI median of row medians: **52.947 ms**.
- MoonBit engine median of row medians: **44.360 ms**.
- Largest observed CLI peak: **237,552 KiB (231.98 MiB)** on XML.

This run is a new candidate observation, not an approved regression verdict.
The existing quality-lab macOS baseline was captured with different MoonBit,
quality-lab, Python/runtime, OS, and runner fingerprints. The enforcement tool
correctly rejected that cross-fingerprint comparison. A controlled runner must
approve a matching baseline before the project claims a time/RSS delta against
it.

## Evidence and reproduction

The committed runner summaries are under
[`bench/results/2026-08-07-macos-arm64/`](../bench/results/2026-08-07-macos-arm64/).
They are generated artifacts; do not edit their values manually.

```bash
git clone https://github.com/ZSeanYves/markitdown-quality-lab.git \
  markitdown-quality-lab
./tools/env/optional_deps.sh install bench --python /path/to/python3.11
./tools/env/optional_deps.sh install balance
./tools/env/optional_deps.sh install audio --python /path/to/python3.11

moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release \
  --package ZSeanYves/markitdown/internal/bench_runner
RUNNER=_build/native/release/build/internal/bench_runner/bench_runner.exe
$RUNNER doctor
$RUNNER run --preset official-external-compare --progress=json
$RUNNER run --preset official-self-baseline --progress=json
```

Run-to-run comparisons require the same product/quality commits, input hashes,
runner class, tool fingerprints, and sampling policy. Hosted CI uses wider
truth/RSS gates and is not an approved source for the 10% self-baseline limit.
