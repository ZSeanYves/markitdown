# Format Matrix

| format | tiny count | small count | medium count | large count | huge count | total bytes | source mix | coverage notes | missing / risks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| txt | 1 | 1 | 1 | 1 | 1 | 14371150 | copied_from_external_bench=2, copied_from_samples=1, generated_tracked=2 | tiny/small external+repo anchors; large/huge are generated tracked text loads | none; No missing classes. |
| csv | 1 | 1 | 1 | 1 | 1 | 14735349 | copied_from_external_bench=3, copied_from_samples=1, generated_tracked=1 | real-world external CSV covers small to large; huge is deterministic and tracked | none; No missing classes. |
| tsv | 1 | 1 | 1 | 1 | 1 | 14884865 | copied_from_external_bench=1, copied_from_samples=1, generated_tracked=3 | repo tiny + external seed + generated medium/large/huge | none; External bench lacks honest larger TSV byte ranges, so generated tracked rows fill the gap. |
| json | 1 | 1 | 1 | 1 | 1 | 15901464 | copied_from_external_bench=3, copied_from_samples=1, generated_tracked=1 | repo tiny plus SPDX/World Bank external rows; huge is generated | none; No missing classes. |
| yaml | 1 | 1 | 1 | 1 | 1 | 14273768 | copied_from_external_bench=2, generated_tracked=3 | external tiny/small plus generated medium to huge | none; External YAML pool is shallow in byte scale, so generated tracked rows provide coverage. |
| xml | 1 | 1 | 1 | 1 | 1 | 17987991 | copied_from_external_bench=1, copied_from_samples=1, generated_tracked=3 | repo tiny, generated small/medium/huge, external large World Bank payload | none; No missing classes. |
| markdown | 1 | 1 | 1 | 1 | 1 | 14276578 | copied_from_samples=1, generated_tracked=4 | repo tiny plus generated small/medium/large/huge | none; External bench has no Markdown coverage, so the full tracked corpus is local and deterministic. |
| html | 1 | 1 | 1 | 1 | 1 | 13949113 | copied_from_external_bench=2, copied_from_samples=1, generated_tracked=2 | repo tiny, generated small/huge, external W3C medium/large payloads | none; No missing classes. |
| zip | 1 | 1 | 1 | 1 | 1 | 568869 | copied_from_external_bench=1, copied_from_samples=3, missing_candidate=1 | repo tiny/small/medium plus external entry-rich large archive | huge; Huge ZIP is still missing; this round avoids adding a synthetic container stress payload. |
| epub | 1 | 1 | 1 | 1 | 1 | 1089702 | copied_from_external_bench=2, copied_from_samples=2, missing_candidate=1 | repo tiny/small plus external Gutenberg medium/large payloads | huge; Huge EPUB is still missing. |
| pdf | 1 | 1 | 1 | 1 | 1 | 7060545 | copied_from_external_bench=2, copied_from_samples=2, missing_candidate=1 | repo tiny/small native-text baselines plus external medium/large native-text PDFs | huge; Huge native-text PDF is still missing; OCR/scanned PDFs remain excluded. |
| docx | 1 | 1 | 1 | 1 | 1 | 124689 | copied_from_external_bench=1, copied_from_samples=2, missing_candidate=2 | repo tiny/medium plus external small DOCX | large, huge; Large and huge DOCX remain missing because this round does not synthesize complex OOXML binaries. |
| pptx | 1 | 1 | 1 | 1 | 1 | 724189 | copied_from_external_bench=1, copied_from_samples=3, missing_candidate=1 | repo tiny/small/medium plus external large PPTX | huge; Huge PPTX remains missing. |
| xlsx | 1 | 1 | 1 | 1 | 1 | 53963672 | copied_from_external_bench=3, copied_from_samples=2 | repo tiny/small plus external medium/large/huge workbooks | none; No missing classes. |

## Notes
- `txt`: tiny/small external+repo anchors; large/huge are generated tracked text loads No missing classes.
- `csv`: real-world external CSV covers small to large; huge is deterministic and tracked No missing classes.
- `tsv`: repo tiny + external seed + generated medium/large/huge External bench lacks honest larger TSV byte ranges, so generated tracked rows fill the gap.
- `json`: repo tiny plus SPDX/World Bank external rows; huge is generated No missing classes.
- `yaml`: external tiny/small plus generated medium to huge External YAML pool is shallow in byte scale, so generated tracked rows provide coverage.
- `xml`: repo tiny, generated small/medium/huge, external large World Bank payload No missing classes.
- `markdown`: repo tiny plus generated small/medium/large/huge External bench has no Markdown coverage, so the full tracked corpus is local and deterministic.
- `html`: repo tiny, generated small/huge, external W3C medium/large payloads No missing classes.
- `zip`: repo tiny/small/medium plus external entry-rich large archive Huge ZIP is still missing; this round avoids adding a synthetic container stress payload.
- `epub`: repo tiny/small plus external Gutenberg medium/large payloads Huge EPUB is still missing.
- `pdf`: repo tiny/small native-text baselines plus external medium/large native-text PDFs Huge native-text PDF is still missing; OCR/scanned PDFs remain excluded.
- `docx`: repo tiny/medium plus external small DOCX Large and huge DOCX remain missing because this round does not synthesize complex OOXML binaries.
- `pptx`: repo tiny/small/medium plus external large PPTX Huge PPTX remains missing.
- `xlsx`: repo tiny/small plus external medium/large/huge workbooks No missing classes.
