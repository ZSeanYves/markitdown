#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_ROOT="$ROOT/samples/quality_examples"

source "$ROOT/samples/helpers/shared/cli_runner.sh"

usage() {
  cat <<'EOF'
Usage: bash samples/helpers/generate_quality_examples.sh [format...]

Generates the source-attributed quality example corpus under
`samples/quality_examples/` from samples selected only from
`markitdown-quality-lab/external_quality/`.

If one or more format labels are provided, only those format directories are
refreshed.
EOF
}

FORMAT_FILTERS=()
if [[ $# -gt 0 ]]; then
  case "${1-}" in
    -h|--help)
      usage
      exit 0
      ;;
  esac
  for format in "$@"; do
    FORMAT_FILTERS+=("$format")
  done
fi

format_selected() {
  local format="$1"
  if [[ ${#FORMAT_FILTERS[@]} -eq 0 ]]; then
    return 0
  fi
  local selected
  for selected in "${FORMAT_FILTERS[@]}"; do
    if [[ "$selected" == "$format" ]]; then
      return 0
    fi
  done
  return 1
}

rows() {
  cat <<'EOF'
asciidoc|asciidoctor|asciidoc_asciidoctor_readme_realworld|Asciidoctor documentation|MIT|https://github.com/asciidoctor/asciidoctor/blob/main/README.adoc|markitdown-quality-lab/external_quality/asciidoc/asciidoctor/README.adoc||Attribute-heavy real-world AsciiDoc with headings, lists, code boundaries, and image macros.
csv|csv-spectrum|csv_quotes_and_newlines_csv_spectrum|csv-spectrum fixtures|BSD-2-Clause|https://github.com/max-mapper/csv-spectrum/blob/master/csvs/quotes_and_newlines.csv|markitdown-quality-lab/external_quality/csv/csv-spectrum/quotes_and_newlines.csv||Quoted newlines plus escaped quotes make this a compact but non-trivial CSV lowering example.
docx|openxml-sdk|docx_notes_openxmlsdk|Open XML SDK tests|MIT|https://github.com/dotnet/Open-XML-SDK/blob/main/test/DocumentFormat.OpenXml.Tests.Assets/assets/TestFiles/Notes.docx|markitdown-quality-lab/external_quality/docx/openxml-sdk/Notes.docx||Mixed long-form body sections, note-style paragraphs, and embedded images show both structure and asset export.
eml|apache-james-mime4j|eml_apache_james_simple_attachment|Apache James Mime4j test messages|Apache-2.0|https://github.com/apache/james-mime4j/blob/master/core/src/test/resources/testmsgs/simple-attachment.msg|markitdown-quality-lab/external_quality/eml/apache-james-mime4j/simple-attachment.msg||Multipart mail with an attachment shows MIME tree summarization on the main path.
epub|idpf-epub-testsuite|epub_nav_idpf_epub30_test_0150|IDPF EPUB testsuite|CC-BY-4.0|https://github.com/IDPF/epub-testsuite/tree/main/content/30/epub30-test-0150|markitdown-quality-lab/external_quality/epub/idpf-epub-testsuite/epub30-test-0150.epub||Navigation-document, landmarks, page-list, and custom-nav content make this a strong EPUB structure showcase.
html|mdn|html_mdn_figure_element|MDN Web Docs HTML reference pages|CC-BY-SA|https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/figure|markitdown-quality-lab/external_quality/html/mdn/mdn_figure_element.html||Real-world documentation HTML with figure and figcaption semantics, code examples, links, and spec tables.
ipynb|jupyter-nbformat|ipynb_nbformat_test4_mixed_outputs|Jupyter nbformat test notebooks|BSD-3-Clause|https://github.com/jupyter/nbformat/blob/main/tests/test4.ipynb|markitdown-quality-lab/external_quality/ipynb/jupyter-nbformat/test4.ipynb||Mixed notebook cells and outputs cover markdown, streams, HTML, JavaScript, and persisted image assets in one sample.
json|csv-spectrum-repo|json_csv_spectrum_embedded_json_string|csv-spectrum JSON companion fixtures|BSD-2-Clause|https://github.com/maxogden/csv-spectrum/tree/master/json|markitdown-quality-lab/external_quality/json/csv-spectrum-repo/json.json||Compact JSON array data with embedded JSON-like strings shows value preservation inside table projection.
jsonl|jsonl-datasets|jsonl_jsonl_datasets_product_events|tinytoolkit jsonl-datasets samples|CC0-1.0|https://github.com/tinytoolkit-org/jsonl-datasets/blob/main/tabular/product-events-10.jsonl|markitdown-quality-lab/external_quality/jsonl/jsonl-datasets/product-events-10.jsonl||Flat events plus nested property objects make this a readable but realistic JSONL showcase.
markdown|pandas|markdown_pandas_readme|pandas repository README|BSD-3-Clause|https://github.com/pandas-dev/pandas/blob/main/README.md|markitdown-quality-lab/external_quality/markdown/pandas/README.md||Real-world Markdown with headings, links, tables, lists, badges, and raw HTML boundaries.
ndjson|jsonlines|ndjson_jsonlines_rfc7464_bom|jsonlines test fixtures|BSD-3-Clause|https://github.com/wbolster/jsonlines/blob/master/tests/test_jsonlines.py|markitdown-quality-lab/external_quality/ndjson/jsonlines/rfc7464_bom.ndjson||RFC7464 record separators plus BOM normalization provide a non-trivial NDJSON example.
ocr|self_synthetic|quality_ocr_self_synthetic_samples_layout_ocr_layout_self_heading_paragraph_0001|Project-owned synthetic OCR seed pages|project-owned synthetic|local-generated|markitdown-quality-lab/external_quality/ocr/self_synthetic/samples/layout/ocr_layout_self_heading_paragraph_0001.png||Heading-plus-body OCR layout gives a readable positive example for direct image OCR quality.
odp|odf-toolkit|odp_odf_toolkit_presentation_assets|ODF Toolkit official test documents|Apache-2.0|https://github.com/tdf/odftoolkit/blob/master/odfdom/src/test/resources/test-input/Presentation1.odp|markitdown-quality-lab/external_quality/odp/odf-toolkit/Presentation1.odp||Multi-slide ODP with visible list content and embedded objects demonstrates both slide ordering and asset materialization.
ods|odf-toolkit|ods_odf_toolkit_spreadsheet_table|ODF Toolkit official test documents|Apache-2.0|https://github.com/tdf/odftoolkit/blob/master/odfdom/src/test/resources/test-input/TestSpreadsheetTable.ods|markitdown-quality-lab/external_quality/ods/odf-toolkit/TestSpreadsheetTable.ods||Wide typed spreadsheet content makes this a stronger ODS quality example than a tiny smoke sample.
odt|odf-toolkit|odt_odf_toolkit_feature_images|ODF Toolkit official test documents|Apache-2.0|https://github.com/tdf/odftoolkit/blob/master/odfdom/src/test/resources/test-input/feature_images.odt|markitdown-quality-lab/external_quality/odt/odf-toolkit/feature_images.odt||Image-heavy ODT with mixed text and table output shows both layout lowering and asset export.
pdf|pdfjs|pdf_highlight_popup_pdfjs|PDF.js tests|Apache-2.0|https://github.com/mozilla/pdf.js/blob/master/test/pdfs/highlight_popup.pdf|markitdown-quality-lab/external_quality/pdf/pdfjs/highlight_popup.pdf||Visible text plus annotation and bookmark appendices makes this a compact but feature-rich PDF showcase.
pptx|python-pptx|pptx_group_table_image_python_pptx_test_slides|python-pptx tests|MIT|https://github.com/scanny/python-pptx/blob/master/tests/test_files/test_slides.pptx|markitdown-quality-lab/external_quality/pptx/python-pptx/test_slides.pptx||Group text, slide image output, and explicit table content make this a strong PPTX conversion-chain example.
rst|docutils|rst_docutils_quickstart_primer|Docutils reStructuredText documentation|Public-Domain|https://github.com/docutils/docutils|markitdown-quality-lab/external_quality/rst/docutils/quickstart.rst||Real documentation prose with literal blocks, directives, and inline markup gives broader RST coverage.
srt|martinlindhe-subtitles|srt_martinlindhe_sample_timing|Martin Lindhe subtitles test fixtures|MIT|https://github.com/martinlindhe/subtitles|markitdown-quality-lab/external_quality/srt/martinlindhe-subtitles/sample.srt||Readable subtitle timing and multiline captions are enough to show the current SRT path clearly.
tex|latex2e|tex_latex2e_sample2e_sections_and_quotes|LaTeX2e sample documents|LPPL-1.3c|https://github.com/latex3/latex2e|markitdown-quality-lab/external_quality/tex/latex2e/sample2e.tex||Section structure, quote environments, comments, and raw macro boundaries make this a solid TeX showcase.
toml|pydantic|toml_pydantic_pyproject|Pydantic project TOML config|MIT|https://raw.githubusercontent.com/pydantic/pydantic/main/pyproject.toml|markitdown-quality-lab/external_quality/toml/pydantic/pyproject.toml||Real-world pyproject TOML covers nested tables, inline tables, URLs, and dependency groups.
tsv|pandas|tsv_pandas_utf16_bom|pandas parser test data|BSD-3-Clause|https://github.com/pandas-dev/pandas/blob/main/pandas/tests/io/parser/data/utf16_ex.txt|markitdown-quality-lab/external_quality/tsv/pandas/utf16_ex.tsv||UTF-16LE BOM input with a wide table makes this a good TSV encoding showcase.
txt|pandas|txt_pandas_utf16_bom|pandas parser test data|BSD-3-Clause|https://github.com/pandas-dev/pandas/blob/main/pandas/tests/io/parser/data/utf16_ex.txt|markitdown-quality-lab/external_quality/txt/pandas/utf16_ex.txt||UTF-16LE BOM text input demonstrates encoding handling on the plain-text route.
vtt|martinlindhe-subtitles|vtt_martinlindhe_sample_timing|Martin Lindhe subtitles test fixtures|MIT|https://github.com/martinlindhe/subtitles|markitdown-quality-lab/external_quality/vtt/martinlindhe-subtitles/sample.vtt||Concise VTT timing and multiline cue coverage makes this a clean WebVTT example.
xlsx|apache-poi|xlsx_excel_tables_apache_poi_exceltables|Apache POI tests|Apache-2.0|https://github.com/apache/poi/blob/trunk/test-data/spreadsheet/ExcelTables.xlsx|markitdown-quality-lab/external_quality/xlsx/apache-poi/ExcelTables.xlsx||Real Excel table parts plus hidden trailing columns make this an effective XLSX quality sample.
xml|cpython|xml_namespace_cpython_simple_ns|CPython XML tests|PSF-2.0|https://github.com/python/cpython/blob/main/Lib/test/xmltestdata/simple-ns.xml|markitdown-quality-lab/external_quality/xml/cpython/simple-ns.xml||Namespace, PI, comment, tail text, and empty elements keep the XML showcase readable while still non-trivial.
yaml|yaml-test-suite|yaml_yaml_test_suite_block_scalars|YAML Test Suite|MIT|https://github.com/yaml/yaml-test-suite/blob/main/src/5BVJ.yaml|markitdown-quality-lab/external_quality/yaml/yaml-test-suite/block_scalars.yaml||Literal and folded block scalars produce a positive YAML example with visible structured lowering.
zip|repo_local|zip_duplicate_asset_names_repo_sample|markitdown repo samples|Apache-2.0|https://github.com/ZSeanYves/markitdown/blob/main/external_quality/repo_local/zip/zip_duplicate_asset_names.zip|markitdown-quality-lab/external_quality/repo_local/zip/zip_duplicate_asset_names.zip||Nested HTML entries with duplicate image names show archive traversal, caption recovery, and asset-name remapping.
EOF
}

resolve_markitdown_cli

run_quality_example_cli() {
  local mode="$1"
  local input_path="$2"
  local output_path="$3"
  local format_override="$4"
  local -a args=("balance")
  if [[ -n "$format_override" ]]; then
    args+=("--format" "$format_override")
  fi
  case "$mode" in
    markdown)
      ;;
    rag)
      args+=("--rag")
      ;;
    debug)
      args+=("--debug")
      ;;
    *)
      echo "unsupported showcase mode: $mode" >&2
      return 1
      ;;
  esac
  args+=("$input_path" "$output_path")
  run_markitdown_cli "${args[@]}"
}

cleanup_format_dir_if_needed() {
  local format_dir="$1"
  local marker="$format_dir/.generated-by-quality-examples"
  if [[ -f "$marker" ]]; then
    rm -rf "$format_dir"
  fi
}

rows | while IFS='|' read -r \
  format \
  source_dir_name \
  sample_id \
  source_name \
  license \
  original_url \
  input_path \
  cli_format_override \
  selection_note; do
  if ! format_selected "$format"; then
    continue
  fi

  format_dir="$OUT_ROOT/$format"
  cleanup_format_dir_if_needed "$format_dir"
  sample_dir="$format_dir/$source_dir_name"
  original_dir="$sample_dir/original"
  markdown_dir="$sample_dir/markdown"
  rag_dir="$sample_dir/rag"
  debug_dir="$sample_dir/debug"

  mkdir -p "$format_dir" "$original_dir" "$markdown_dir" "$rag_dir" "$debug_dir"
  printf 'generated\n' > "$format_dir/.generated-by-quality-examples"

  input_abs="$ROOT/$input_path"
  input_name="$(basename "$input_path")"
  cp "$input_abs" "$original_dir/$input_name"

  source_file="$sample_dir/SOURCE.md"
  {
    printf '# Source\n\n'
    printf -- '- Format: `%s`\n' "$format"
    printf -- '- Source directory: `%s`\n' "$source_dir_name"
    printf -- '- Selected sample: `%s`\n' "$sample_id"
    printf -- '- Source name: %s\n' "$source_name"
    printf -- '- License: `%s`\n' "$license"
    printf -- '- Original URL: %s\n' "$original_url"
    printf -- '- External-quality path: `%s`\n' "$input_path"
    printf -- '- Selection note: %s\n' "$selection_note"
  } > "$source_file"

  run_quality_example_cli \
    "markdown" \
    "$input_abs" \
    "$markdown_dir/output.md" \
    "$cli_format_override" \
    >/dev/null

  run_quality_example_cli \
    "rag" \
    "$input_abs" \
    "$rag_dir/output.rag.json" \
    "$cli_format_override" \
    >/dev/null

  run_quality_example_cli \
    "debug" \
    "$input_abs" \
    "$debug_dir/output.debug.json" \
    "$cli_format_override" \
    >/dev/null

  printf 'generated quality example for %s/%s\n' "$format" "$source_dir_name"
done
