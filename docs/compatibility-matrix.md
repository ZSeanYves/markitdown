# Compatibility Matrix

This is the Phase 0 compatibility contract. The official comparison target is
Microsoft MarkItDown `v0.1.7` at commit
`fd239d5d2be43d9b68329730206b9312c7d5a388`. The upstream tag and local fixture
hashes are recorded in `tools/governance/phase0-baseline.json`.

## Compatibility axes

| Axis | Required evidence | Comparison rule |
| --- | --- | --- |
| Surface | input types, CLI flags, format detection, capability report, exit codes | Every stable local capability has a documented mapping or an explicit unsupported result |
| Semantic | normalized blocks, headings, tables, links, assets, math, order and diagnostics | Compare structure and stable fields; byte equality is only required for deterministic golden cases |
| Operational | path/text/bytes/reader, stdin/stdout, hints, resource limits and no-network default | Same input class must either produce an equivalent result or a stable typed failure |

The MoonBit API is intentionally not Python source-compatible. The stable API is
the MoonBit façade documented by the root package and CLI. Compatibility claims
must state which of the three axes they cover.

## Format status

| Format/capability | Local status | Upstream v0.1.7 relation | 1.0 decision | Evidence lane |
| --- | --- | --- | --- | --- |
| TXT, CSV, TSV, SRT, VTT | stable/mainstream | built-in comparable | stable | local contracts + malformed/large stream tests |
| JSON, JSONL, NDJSON, IPYNB | stable/mainstream | built-in comparable | stable | local contracts + upstream vectors |
| YAML, TOML, XML | stable/mainstream | built-in or dependency-backed | stable | parser suites + entity/limit/security corpus |
| HTML, Markdown | stable/mainstream | built-in comparable | stable | semantic diff + HTML/CommonMark/GFM suites |
| EML | stable/mainstream | built-in comparable | stable | MIME/charset/attachment corpus |
| `msg` alias | explicit alias | upstream binary MSG is separate | stable alias only | must never be advertised as Outlook binary MSG |
| ZIP, EPUB | stable/bounded | built-in comparable | stable | zip-slip/bomb/depth/size + EPUB contracts |
| DOCX, PPTX, XLSX | stable/mainstream | built-in comparable | stable | OOXML vectors, assets, relationships, formula/math cases |
| ODT, ODS, ODP | stable/mainstream | no equivalent official baseline in all cases | stable | self baseline + semantic contracts |
| PDF | stable/bounded | built-in comparable | stable with capability limits | native text, image, corruption, RSS and external-runtime lanes |
| PNG/JPEG/BMP/WebP/TIFF OCR | optional | optional Python dependency/runtime | optional extension | runtime fingerprint + timeout/failure tests |
| WAV/MP3/M4A | optional | optional Python dependency/runtime | optional extension | runtime fingerprint + child-process tests |
| XLS/BIFF | unsupported | upstream optional converter | explicit unsupported or future extension | do not claim compatibility until native reader exists |
| binary Outlook MSG | unsupported | upstream optional converter | explicit unsupported or separate extension | real MSG corpus and OLE security review required |
| RSS/Atom, Wikipedia, YouTube, Bing SERP | core-disabled | network converters | core unsupported; network extension only | SSRF/resource/credential policy required |
| Azure/cloud services | core-disabled | optional cloud converters | out of core scope | third-party extension responsibility |
| Python plugins | core-disabled | upstream plugin surface | no ambient plugin loading | explicit MoonBit extension registry after 1.0 review |

## Contract corpus policy

- Tracked local inputs are under `samples/fixtures/contracts/` and
  `samples/fixtures/rejections/`; their 180-file hash manifest is tracked by
  `tools/governance/fixtures.sha256`.
- Large third-party and upstream inputs stay in the pinned
  `markitdown-quality-lab` checkout. The CI commit is recorded in the baseline
  manifest; generated outputs are not release artifacts.
- Every new fixture records source, license/provenance, SHA-256, expected
  capability level, privacy status and the behavior it protects.
- A golden update must include a structured old/new diff and an explanation.
  A PR that only changes golden files is rejected by policy.

## Required upstream checks

For each upstream release, rerun:

1. path, bytes, stream, stdin and hint variants;
2. DOCX equations/comments, PPTX chart lookup and SVG fallback;
3. XLSX tables/formulas/large sheets;
4. PDF text, images, links, corruption and encrypted inputs;
5. HTML/CSV encoding/JSON/RSS XML/IPYNB/ZIP/EPUB vectors;
6. CLI output, exit codes, assets, diagnostics and no-network behavior.

Differences are classified as `bug`, `upstream-feature-gap`, `intentional-
enhancement`, or `undefined`. Only classified differences may be baselined.

## Reproduction

```bash
python3 tools/governance/collect_baseline.py --check
python3 -m unittest discover -s tools/governance/tests -p 'test_*.py'
./tools/env/optional_deps.sh install bench
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
_build/native/release/build/bench/runner/runner.exe run --preset official-external-compare
```

