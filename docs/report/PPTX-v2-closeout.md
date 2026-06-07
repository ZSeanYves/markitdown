# PPTX v2 Replacement Closeout

Date: 2026-06-07
HEAD: `7898db4`

## Summary

PPTX normal conversion is now routed through `convert/pptx_v2`, which consumes
`doc_parse/pptx_v2.PptxDocument` for lowering. The old v1 runtime directories
were removed:

- `doc_parse/pptx/`
- `convert/pptx/`

There is no dual runtime, v1 fallback, oracle path, or counter path in the PPTX
v2 runtime.

## Migrated Runtime References

- `convert/convert/dispatcher.mbt`: PPTX dispatch now calls
  `@pptx_v2.parse_pptx`.
- `convert/convert/moon.pkg`: imports `convert/pptx_v2`.
- `cli_support/moon.pkg`: imports `convert/pptx_v2` as `@pptx`.
- `convert/zip_core/moon.pkg`: embedded PPTX conversion imports
  `convert/pptx_v2` as `@pptx`.
- `bench/moon.pkg`: product-path bench imports `convert/pptx_v2` as `@pptx`.
- `bench/parser_layer/moon.pkg`: parser bench imports `doc_parse/pptx_v2` as
  `@pptx`.
- `bench/parser_layer/main.mbt`: parser bench now uses
  `parse_pptx_document_from_package`, `inspect_pptx_document_v2`, and v2 warning
  materialization.
- `convert/convert/test/moon.pkg`: direct PPTX converter tests import
  `convert/pptx_v2` as `@pptx`.
- `debug/debug_app.mbt`: route registry string now reports `convert/pptx_v2`.

## Deleted v1 Files

`convert/pptx/`:

- `moon.pkg`
- `pkg.generated.mbti`
- `pptx_bytes.mbt`
- `pptx_chart.mbt`
- `pptx_classify.mbt`
- `pptx_comments.mbt`
- `pptx_geom.mbt`
- `pptx_group_candidates.mbt`
- `pptx_group_tree.mbt`
- `pptx_grouping.mbt`
- `pptx_h2_wbtest.mbt`
- `pptx_image_assets.mbt`
- `pptx_layout_base.mbt`
- `pptx_noise.mbt`
- `pptx_notes.mbt`
- `pptx_package.mbt`
- `pptx_paragraph_meta.mbt`
- `pptx_parser.mbt`
- `pptx_parser_inventory.mbt`
- `pptx_profile.mbt`
- `pptx_reading_order.mbt`
- `pptx_rels.mbt`
- `pptx_shape_collect.mbt`
- `pptx_slide.mbt`
- `pptx_table_like.mbt`
- `pptx_table_xml.mbt`
- `pptx_text.mbt`
- `pptx_types.mbt`
- `test/moon.pkg`
- `test/pkg.generated.mbti`
- `test/pptx_test.mbt`

`doc_parse/pptx/`:

- `README.md`
- `moon.pkg`
- `pkg.generated.mbti`
- `pptx_chart.mbt`
- `pptx_comments.mbt`
- `pptx_inspect.mbt`
- `pptx_media.mbt`
- `pptx_notes.mbt`
- `pptx_package.mbt`
- `pptx_rels.mbt`
- `pptx_shape_tree.mbt`
- `pptx_slide.mbt`
- `pptx_table.mbt`
- `pptx_text.mbt`
- `pptx_types.mbt`
- `pptx_xml.mbt`
- `tests/moon.pkg`
- `tests/pkg.generated.mbti`
- `tests/pptx_parser_test.mbt`

## Audit Categories

A. Normal runtime references:

- No remaining old package imports or v1 parser API symbols were found after
  deletion.
- CLI, dispatcher, ZIP embedded PPTX, bench product path, parser bench, debug
  route string, and converter tests were migrated to v2.

B. Test references:

- Old v1 test packages were deleted with the v1 directories.
- Remaining `convert/convert/test` PPTX calls use the `@pptx` alias now bound to
  `convert/pptx_v2`.
- `convert/pptx_v2/test` contains PPTX OOXML path strings only as constructed
  package fixtures.

C. Docs and archive references:

- Historical docs still mention `doc_parse/pptx`, `convert/pptx`, and the
  PPTX-1 parser inventory.
- Notable remaining documentation references are in `docs/parser-defects.md`,
  `docs/convert-defects.md`, `docs/format-limits.md`,
  `docs/archive/pptx-architecture.md`, `doc_parse/README.md`, and
  `doc_parse/ooxml/README.md`.
- These were not edited in this runtime closeout; they are not active package
  dependencies.

D. Generated/interface references:

- Old v1 generated interface files were deleted with their packages.
- Remaining generated interface references point to `doc_parse/pptx_v2` and
  `convert/pptx_v2`.

E. Harmless strings and sample paths:

- Sample input paths such as `samples/main_process/pptx/...` remain.
- ZIP asset names such as `assets/archive/slides_overview.pptx/image01.png`
  remain as expected sample/output strings.
- The debug route string now names `convert/pptx_v2`.

## Boundary Greps

- Deleted directory check:
  `test ! -d doc_parse/pptx && test ! -d convert/pptx` -> pass.
- Old package/API grep:
  `rg -n '"ZSeanYves/markitdown/(doc_parse|convert)/pptx"|@pptx_sem|parse_pptx_presentation_from_package|PptxParserInventorySummary' .`
  -> no hits.
- Convert-layer raw OOXML/path scanning:
  `rg -n '@ox\.|read_part|list_parts|has_part|ppt/|\.rels|presentation\.xml|slide[0-9]+\.xml|read_source_part_bytes' convert/pptx_v2/pptx_v2_lowering.mbt`
  -> no hits.
- PPTX v2 fallback/oracle/counter language:
  `rg -n 'fallback|legacy|oracle|counter' doc_parse/pptx_v2 convert/pptx_v2 -g '*.mbt' -g 'moon.pkg'`
  -> no hits.

## Validation

- `moon info && moon fmt` -> pass. Existing unrelated warning:
  `convert/epub/epub_part_cache.mbt:53` unused function
  `read_epub_part_text_cached`.
- `moon check doc_parse/pptx_v2 convert/pptx_v2` -> pass.
- `moon test doc_parse/pptx_v2/tests` -> pass, 6/6 tests.
- `moon test convert/pptx_v2/test` -> pass, 4/4 tests.
- `bash samples/check.sh --format pptx` -> pass, 108/108 checked.
- `bash samples/check_quality.sh --format pptx` -> pass, 49 checked, 3 skipped,
  0 failed.
- `bash samples/bench.sh --layer convert --format pptx --iterations 1 --warmup 0`
  -> pass, 1 row, median 77.000ms, runner `prebuilt`.
- `moon check` -> pass. Existing unrelated warnings:
  `convert/epub/epub_part_cache.mbt:53` unused function and
  `convert/markdown/test/markdown_passthrough_test.mbt:185` deprecated debug
  warning.

## Parity and Non-Goals

Covered parity slices:

- A: normal product dispatch through `convert/convert`, CLI support, and ZIP
  embedded PPTX routing.
- B: parser package behavior through `doc_parse/pptx_v2/tests`.
- C: lowering behavior through `convert/pptx_v2/test`.
- D: sample and quality-lab PPTX regression gates.
- E: product-path convert bench and parser-layer bench migration.

Remaining parity gaps are deliberate non-target capabilities for this closeout:

- full renderer fidelity
- workbook evaluation
- SmartArt rendering
- OLE rendering
- animation and theme fidelity

## Commit Readiness

The PPTX v2 replacement is ready for formal submit/archive closeout from the
PPTX perspective: old runtime packages are deleted, active runtime wiring points
to v2, and validation passes.

The worktree also contains unrelated pre-existing modifications outside the
PPTX closeout scope. Stage/review the PPTX closeout paths separately or reconcile
the broader worktree before a repository-wide commit.

## Git Snapshot

Final `git status --short --untracked-files=all` and `git diff --stat` are
captured after this report file is present.

### Status

```text
 M bench/moon.pkg
 M bench/parser_layer/main.mbt
 M bench/parser_layer/moon.pkg
 M cli_support/moon.pkg
 M convert/convert/dispatcher.mbt
 M convert/convert/moon.pkg
 M convert/convert/test/moon.pkg
 M convert/epub/epub_parser.mbt
 M convert/html/html_inlines.mbt
 M convert/html/html_parser.mbt
 M convert/html/html_profile.mbt
 M convert/html/html_table.mbt
 M convert/html/test/html_link_test.mbt
 M convert/html/test/html_parser_test.mbt
 M convert/json/json_to_ir.mbt
 M convert/markdown/markdown_parser.mbt
 M convert/markdown/test/markdown_passthrough_test.mbt
 M convert/pdf/pdf_profile.mbt
 M convert/pdf/test/pdf_parse_test.mbt
 D convert/pptx/moon.pkg
 D convert/pptx/pkg.generated.mbti
 D convert/pptx/pptx_bytes.mbt
 D convert/pptx/pptx_chart.mbt
 D convert/pptx/pptx_classify.mbt
 D convert/pptx/pptx_comments.mbt
 D convert/pptx/pptx_geom.mbt
 D convert/pptx/pptx_group_candidates.mbt
 D convert/pptx/pptx_group_tree.mbt
 D convert/pptx/pptx_grouping.mbt
 D convert/pptx/pptx_h2_wbtest.mbt
 D convert/pptx/pptx_image_assets.mbt
 D convert/pptx/pptx_layout_base.mbt
 D convert/pptx/pptx_noise.mbt
 D convert/pptx/pptx_notes.mbt
 D convert/pptx/pptx_package.mbt
 D convert/pptx/pptx_paragraph_meta.mbt
 D convert/pptx/pptx_parser.mbt
 D convert/pptx/pptx_parser_inventory.mbt
 D convert/pptx/pptx_profile.mbt
 D convert/pptx/pptx_reading_order.mbt
 D convert/pptx/pptx_rels.mbt
 D convert/pptx/pptx_shape_collect.mbt
 D convert/pptx/pptx_slide.mbt
 D convert/pptx/pptx_table_like.mbt
 D convert/pptx/pptx_table_xml.mbt
 D convert/pptx/pptx_text.mbt
 D convert/pptx/pptx_types.mbt
 D convert/pptx/test/moon.pkg
 D convert/pptx/test/pkg.generated.mbti
 D convert/pptx/test/pptx_test.mbt
 M convert/xlsx/test/xlsx_test.mbt
 M convert/xlsx/xlsx_parser.mbt
 M convert/xml/test/xml_test.mbt
 M convert/xml/xml_parser.mbt
 M convert/yaml/test/yaml_test.mbt
 M convert/yaml/yaml_to_ir.mbt
 M convert/zip/test/zip_parse_test.mbt
 M convert/zip_core/moon.pkg
 M convert/zip_core/zip_entry_staging.mbt
 M convert/zip_core/zip_to_ir_core.mbt
 M debug/debug_app.mbt
 M doc_parse/html/html_tokenizer.mbt
 M doc_parse/html/pkg.generated.mbti
 M doc_parse/html/tests/html_parser_test.mbt
 M doc_parse/json/tests/json_parser_test.mbt
 M doc_parse/ooxml/ooxml_part_cache_wbtest.mbt
 M doc_parse/ooxml/ooxml_props.mbt
 M doc_parse/ooxml/ooxml_relationships.mbt
 M doc_parse/ooxml/pkg.generated.mbti
 M doc_parse/pdf/api/test/pdf_outline_extract_test.mbt
 D doc_parse/pptx/README.md
 D doc_parse/pptx/moon.pkg
 D doc_parse/pptx/pkg.generated.mbti
 D doc_parse/pptx/pptx_chart.mbt
 D doc_parse/pptx/pptx_comments.mbt
 D doc_parse/pptx/pptx_inspect.mbt
 D doc_parse/pptx/pptx_media.mbt
 D doc_parse/pptx/pptx_notes.mbt
 D doc_parse/pptx/pptx_package.mbt
 D doc_parse/pptx/pptx_rels.mbt
 D doc_parse/pptx/pptx_shape_tree.mbt
 D doc_parse/pptx/pptx_slide.mbt
 D doc_parse/pptx/pptx_table.mbt
 D doc_parse/pptx/pptx_text.mbt
 D doc_parse/pptx/pptx_types.mbt
 D doc_parse/pptx/pptx_xml.mbt
 D doc_parse/pptx/tests/moon.pkg
 D doc_parse/pptx/tests/pkg.generated.mbti
 D doc_parse/pptx/tests/pptx_parser_test.mbt
 M doc_parse/yaml/tests/yaml_parser_test.mbt
 M doc_parse/yaml/yaml_parser.mbt
?? convert/pptx_v2/moon.pkg
?? convert/pptx_v2/pkg.generated.mbti
?? convert/pptx_v2/pptx_v2_lowering.mbt
?? convert/pptx_v2/test/moon.pkg
?? convert/pptx_v2/test/pkg.generated.mbti
?? convert/pptx_v2/test/pptx_v2_lowering_test.mbt
?? doc_parse/pptx_v2/moon.pkg
?? doc_parse/pptx_v2/pkg.generated.mbti
?? doc_parse/pptx_v2/pptx_inspect.mbt
?? doc_parse/pptx_v2/pptx_layout.mbt
?? doc_parse/pptx_v2/pptx_media.mbt
?? doc_parse/pptx_v2/pptx_model.mbt
?? doc_parse/pptx_v2/pptx_notes_comments.mbt
?? doc_parse/pptx_v2/pptx_package.mbt
?? doc_parse/pptx_v2/pptx_presentation.mbt
?? doc_parse/pptx_v2/pptx_shape.mbt
?? doc_parse/pptx_v2/pptx_table.mbt
?? doc_parse/pptx_v2/pptx_text.mbt
?? doc_parse/pptx_v2/pptx_types.mbt
?? doc_parse/pptx_v2/pptx_xml.mbt
?? doc_parse/pptx_v2/tests/moon.pkg
?? doc_parse/pptx_v2/tests/pkg.generated.mbti
?? doc_parse/pptx_v2/tests/pptx_v2_test.mbt
?? docs/report/PPTX-v2-closeout.md
```

### Diff Stat

Note: `git diff --stat` does not include untracked v2 additions or this
untracked closeout report.

```text
 bench/moon.pkg                                     |    2 +-
 bench/parser_layer/main.mbt                        |   16 +-
 bench/parser_layer/moon.pkg                        |    2 +-
 cli_support/moon.pkg                               |    2 +-
 convert/convert/dispatcher.mbt                     |    2 +-
 convert/convert/moon.pkg                           |    2 +-
 convert/convert/test/moon.pkg                      |    2 +-
 convert/epub/epub_parser.mbt                       |    5 +-
 convert/html/html_inlines.mbt                      |   16 +-
 convert/html/html_parser.mbt                       |   61 +-
 convert/html/html_profile.mbt                      |   11 +-
 convert/html/html_table.mbt                        |    8 +-
 convert/html/test/html_link_test.mbt               |    3 +-
 convert/html/test/html_parser_test.mbt             |   17 +-
 convert/json/json_to_ir.mbt                        |   12 +-
 convert/markdown/markdown_parser.mbt               |   21 +-
 .../markdown/test/markdown_passthrough_test.mbt    |    9 +-
 convert/pdf/pdf_profile.mbt                        |    4 +-
 convert/pdf/test/pdf_parse_test.mbt                |    4 +-
 convert/pptx/moon.pkg                              |   13 -
 convert/pptx/pkg.generated.mbti                    |   18 -
 convert/pptx/pptx_bytes.mbt                        |  158 ---
 convert/pptx/pptx_chart.mbt                        |  339 -----
 convert/pptx/pptx_classify.mbt                     |  386 ------
 convert/pptx/pptx_comments.mbt                     |  152 ---
 convert/pptx/pptx_geom.mbt                         |   78 --
 convert/pptx/pptx_group_candidates.mbt             |  233 ----
 convert/pptx/pptx_group_tree.mbt                   |  734 -----------
 convert/pptx/pptx_grouping.mbt                     |  436 -------
 convert/pptx/pptx_h2_wbtest.mbt                    |  476 -------
 convert/pptx/pptx_image_assets.mbt                 |  464 -------
 convert/pptx/pptx_layout_base.mbt                  |  256 ----
 convert/pptx/pptx_noise.mbt                        |  268 ----
 convert/pptx/pptx_notes.mbt                        |  108 --
 convert/pptx/pptx_package.mbt                      |  174 ---
 convert/pptx/pptx_paragraph_meta.mbt               |  100 --
 convert/pptx/pptx_parser.mbt                       |  867 -------------
 convert/pptx/pptx_parser_inventory.mbt             |  334 -----
 convert/pptx/pptx_profile.mbt                      |  140 --
 convert/pptx/pptx_reading_order.mbt                | 1339 --------------------
 convert/pptx/pptx_rels.mbt                         |   76 --
 convert/pptx/pptx_shape_collect.mbt                |   98 --
 convert/pptx/pptx_slide.mbt                        |  191 ---
 convert/pptx/pptx_table_like.mbt                   |  762 -----------
 convert/pptx/pptx_table_xml.mbt                    |  399 ------
 convert/pptx/pptx_text.mbt                         |  232 ----
 convert/pptx/pptx_types.mbt                        |  132 --
 convert/pptx/test/moon.pkg                         |    7 -
 convert/pptx/test/pkg.generated.mbti               |   13 -
 convert/pptx/test/pptx_test.mbt                    |  831 ------------
 convert/xlsx/test/xlsx_test.mbt                    |    4 +-
 convert/xlsx/xlsx_parser.mbt                       |   10 +-
 convert/xml/test/xml_test.mbt                      |    9 +-
 convert/xml/xml_parser.mbt                         |   38 +-
 convert/yaml/test/yaml_test.mbt                    |    1 -
 convert/yaml/yaml_to_ir.mbt                        |    4 +-
 convert/zip/test/zip_parse_test.mbt                |    6 +-
 convert/zip_core/moon.pkg                          |    2 +-
 convert/zip_core/zip_entry_staging.mbt             |    4 +-
 convert/zip_core/zip_to_ir_core.mbt                |   59 +-
 debug/debug_app.mbt                                |    2 +-
 doc_parse/html/html_tokenizer.mbt                  |   73 +-
 doc_parse/html/pkg.generated.mbti                  |   21 +-
 doc_parse/html/tests/html_parser_test.mbt          |   43 +-
 doc_parse/json/tests/json_parser_test.mbt          |    5 +-
 doc_parse/ooxml/ooxml_part_cache_wbtest.mbt        |   17 +-
 doc_parse/ooxml/ooxml_props.mbt                    |    4 +-
 doc_parse/ooxml/ooxml_relationships.mbt            |    3 +-
 doc_parse/ooxml/pkg.generated.mbti                 |   11 +
 .../pdf/api/test/pdf_outline_extract_test.mbt      |    6 +-
 doc_parse/pptx/README.md                           |  204 ---
 doc_parse/pptx/moon.pkg                            |   10 -
 doc_parse/pptx/pkg.generated.mbti                  |  275 ----
 doc_parse/pptx/pptx_chart.mbt                      |  613 ---------
 doc_parse/pptx/pptx_comments.mbt                   |  164 ---
 doc_parse/pptx/pptx_inspect.mbt                    |  153 ---
 doc_parse/pptx/pptx_media.mbt                      |  149 ---
 doc_parse/pptx/pptx_notes.mbt                      |   40 -
 doc_parse/pptx/pptx_package.mbt                    |  155 ---
 doc_parse/pptx/pptx_rels.mbt                       |  129 --
 doc_parse/pptx/pptx_shape_tree.mbt                 |  228 ----
 doc_parse/pptx/pptx_slide.mbt                      |  120 --
 doc_parse/pptx/pptx_table.mbt                      |  148 ---
 doc_parse/pptx/pptx_text.mbt                       |  412 ------
 doc_parse/pptx/pptx_types.mbt                      |  365 ------
 doc_parse/pptx/pptx_xml.mbt                        |  554 --------
 doc_parse/pptx/tests/moon.pkg                      |    5 -
 doc_parse/pptx/tests/pkg.generated.mbti            |   13 -
 doc_parse/pptx/tests/pptx_parser_test.mbt          | 1032 ---------------
 doc_parse/yaml/tests/yaml_parser_test.mbt          |    9 +-
 doc_parse/yaml/yaml_parser.mbt                     |   25 +-
 91 files changed, 279 insertions(+), 14859 deletions(-)
```
