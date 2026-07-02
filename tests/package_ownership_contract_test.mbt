///|
test "canonical architecture guide remains the single docs source of truth" {
  assert_true(
    @fs.path_exists("docs/architecture/mb-markitdown-architecture.md"),
  )
  assert_file_contains_all("docs/architecture/mb-markitdown-architecture.md", [
    "# mb-markitdown 完整架构书", "ParserRegistry", "Core IR", "Renderer", "Markdown 是输出，不是中间表示",
    "ConvertMode",
  ])
  assert_true(!@fs.path_exists("docs/README.md"))
  assert_true(!@fs.path_exists("docs/architecture/package-ownership.md"))
  assert_true(!@fs.path_exists("docs/roadmap.md"))
  assert_true(!@fs.path_exists("docs/supported-formats.md"))
  assert_true(!@fs.path_exists("docs/quality-and-release.md"))
}

///|
test "format packages keep per-format ownership without root facades" {
  for dir in ["txt", "csv", "tsv", "json", "yaml", "toml", "xml", "markdown"] {
    assert_true(@fs.path_exists("formats/" + dir + "/moon.pkg"))
    assert_true(@fs.path_exists("formats/" + dir + "/parser.mbt"))
  }
  for dir in ["zip", "epub", "html", "docx", "pptx", "xlsx"] {
    assert_true(@fs.path_exists("formats/" + dir + "/moon.pkg"))
    assert_true(@fs.path_exists("formats/" + dir + "/parser.mbt"))
  }
  for
    path in [
      "formats/txt_parser.mbt", "formats/csv_parser.mbt", "formats/tsv_parser.mbt",
      "formats/json_parser.mbt", "formats/yaml_parser.mbt", "formats/toml_parser.mbt",
      "formats/xml_parser.mbt", "formats/markdown_parser.mbt", "formats/zip_parser.mbt",
      "formats/epub_parser.mbt", "formats/html_parser.mbt", "formats/docx_parser.mbt",
      "formats/pptx_parser.mbt", "formats/xlsx_parser.mbt",
    ] {
    assert_true(!@fs.path_exists(path))
  }
}

///|
test "root format contracts stay declarative and registry stays runtime only" {
  assert_true(@fs.path_exists("formats/format_contracts.mbt"))
  assert_file_contains_all("formats/format_contracts.mbt", [
    "pub struct ParserContractSpec", "pub fn docx_parser_contract_spec()", "pub fn pptx_parser_contract_spec()",
    "pub fn xlsx_parser_contract_spec()",
  ])
  assert_file_contains_none("formats/format_contracts.mbt", [
    "pub fn docx_parser_contract()", "pub fn pptx_parser_contract()", "pub fn xlsx_parser_contract()",
    "parse_result_with_document_capability", "@fdocx.", "@fpptx.", "@fxlsx.",
  ])
  assert_file_contains_none("formats/registry.mbt", [
    "docx_parser_contract()", "pptx_parser_contract()", "xlsx_parser_contract()",
  ])
}

///|
test "pdf and ocr packages keep active per-format ownership" {
  for
    path in [
      "formats/pdf/moon.pkg", "formats/pdf/parser.mbt", "formats/pdf/backend.mbt",
      "formats/pdf/to_ir.mbt", "formats/pdf/model.mbt", "formats/pdf/geometry.mbt",
      "formats/pdf/cjk_decode.mbt", "formats/pdf/gb2312_data.mbt", "formats/ocr/moon.pkg",
      "formats/ocr/parser.mbt", "formats/ocr/model.mbt", "formats/ocr/provider.mbt",
      "formats/ocr/tesseract.mbt", "formats/ocr/tesseract_tsv.mbt",
    ] {
    assert_true(@fs.path_exists(path))
  }
  assert_file_contains_all("formats/registry.mbt", [
    "@input.DetectedFormat::Pdf", "pdf_native_parser()", "image_ocr_parser()",
  ])
  assert_file_contains_none("formats/pdf/parser.mbt", [
    "image_ocr_parser()", "run_tesseract_provider(",
  ])
}

///|
test "retired package roots stay absent from the active repository tree" {
  assert_true(!@fs.path_exists("doc_parse"))
  assert_true(!@fs.path_exists("office"))
  assert_true(!@fs.path_exists("office_shared"))
  assert_true(@fs.path_exists("format_readers"))
}

///|
test "package ownership guards keep dependency directions light and explicit" {
  let parser_pkg = read_utf8_text("parser/moon.pkg")
  let runtime_pkg = read_utf8_text("runtime/moon.pkg")
  let container_pkg = read_utf8_text("container/moon.pkg")
  let office_pkg = read_utf8_text("format_readers/ooxml/shared/moon.pkg")
  let cli_pkg = read_utf8_text("cli/moon.pkg")
  let registry_impl = read_utf8_text("formats/registry.mbt")

  assert_contains_all(parser_pkg, [
    "ZSeanYves/markitdown/core", "ZSeanYves/markitdown/input",
  ])
  assert_contains_none(parser_pkg, [
    "ZSeanYves/markitdown/formats", "ZSeanYves/markitdown/office", "ZSeanYves/markitdown/doc_parse",
    "ZSeanYves/markitdown/render", "ZSeanYves/markitdown/pipeline", "ZSeanYves/markitdown/runtime",
    "ZSeanYves/markitdown/convert",
  ])

  assert_contains_all(runtime_pkg, [
    "ZSeanYves/markitdown/core", "ZSeanYves/markitdown/input", "ZSeanYves/markitdown/parser",
    "ZSeanYves/markitdown/pipeline",
  ])
  assert_contains_none(runtime_pkg, [
    "ZSeanYves/markitdown/formats", "ZSeanYves/markitdown/render", "ZSeanYves/markitdown/convert",
  ])

  assert_contains_all(container_pkg, ["ZSeanYves/markitdown/input"])
  assert_contains_none(container_pkg, [
    "ZSeanYves/markitdown/core", "ZSeanYves/markitdown/parser", "ZSeanYves/markitdown/formats",
    "ZSeanYves/markitdown/runtime", "ZSeanYves/markitdown/convert",
  ])

  assert_contains_all(office_pkg, [
    "ZSeanYves/markitdown/core", "ZSeanYves/markitdown/parser",
  ])
  assert_contains_none(office_pkg, [
    "ZSeanYves/markitdown/formats", "ZSeanYves/markitdown/doc_parse", "ZSeanYves/markitdown/convert",
    "ZSeanYves/markitdown/render", "ZSeanYves/markitdown/pipeline", "ZSeanYves/markitdown/runtime",
  ])

  assert_contains_all(cli_pkg, ["ZSeanYves/markitdown/format_readers/zip"])
  assert_contains_none(registry_impl, [
    "docx_parser_contract()", "pptx_parser_contract()", "xlsx_parser_contract()",
  ])
}
