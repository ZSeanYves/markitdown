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
test "p5 tall keeps lightweight parsers under per-format formats ownership without root facades" {
  for dir in ["txt", "csv", "tsv", "json", "yaml", "xml", "markdown"] {
    assert_true(@fs.path_exists("formats/" + dir + "/moon.pkg"))
    assert_true(@fs.path_exists("formats/" + dir + "/parser.mbt"))
  }

  assert_true(!@fs.path_exists("formats/format_facades.mbt"))
  for
    path in [
      "formats/txt_parser.mbt", "formats/csv_parser.mbt", "formats/tsv_parser.mbt",
      "formats/json_parser.mbt", "formats/yaml_parser.mbt", "formats/xml_parser.mbt",
      "formats/markdown_parser.mbt",
    ] {
    assert_true(!@fs.path_exists(path))
  }

  assert_file_contains_all("formats/delimited_text/parser.mbt", [
    "pub fn csv_lite_parser()", "pub fn tsv_lite_parser()", "fn delimited_parser(",
  ])
  assert_file_contains_all("formats/csv/parser.mbt", [
    "@delimited_text.csv_lite_parser()",
  ])
  assert_file_contains_all("formats/tsv/parser.mbt", [
    "@delimited_text.tsv_lite_parser()",
  ])
  assert_file_contains_none("formats/tsv/moon.pkg", [
    "ZSeanYves/markitdown/formats/csv",
  ])
}

///|
test "p5 mall keeps medium parsers under per-format formats ownership without root facades" {
  for dir in ["zip", "epub", "html"] {
    assert_true(@fs.path_exists("formats/" + dir + "/moon.pkg"))
    assert_true(@fs.path_exists("formats/" + dir + "/parser.mbt"))
  }

  for
    path in [
      "formats/zip_parser.mbt", "formats/epub_parser.mbt", "formats/html_parser.mbt",
    ] {
    assert_true(!@fs.path_exists(path))
  }
  assert_file_contains_all("formats/registry.mbt", [
    "@input.DetectedFormat::Zip", "@fzip.zip_container_parser(fn() { builtin_registry() })",
    "@input.DetectedFormat::Epub", "@fepub.epub_container_parser(fn() { builtin_registry() })",
    "@input.DetectedFormat::Html", "@fhtml.html_lite_parser()",
  ])
}

///|
test "p5 hall keeps ooxml parsers under per-format formats ownership without root facades" {
  for dir in ["docx", "pptx", "xlsx"] {
    assert_true(@fs.path_exists("formats/" + dir + "/moon.pkg"))
    assert_true(@fs.path_exists("formats/" + dir + "/parser.mbt"))
  }

  assert_true(@fs.path_exists("formats/docx/parser_wbtest.mbt"))
  assert_true(@fs.path_exists("formats/xlsx/parser_wbtest.mbt"))

  for
    path in [
      "formats/docx_parser.mbt", "formats/pptx_parser.mbt", "formats/xlsx_parser.mbt",
    ] {
    assert_true(!@fs.path_exists(path))
  }
  assert_file_contains_all("formats/registry.mbt", [
    "@input.DetectedFormat::Docx", "docx_parser()", "@input.DetectedFormat::Pptx",
    "pptx_parser()", "@input.DetectedFormat::Xlsx", "xlsx_parser()",
  ])
  assert_file_contains_all("formats/docx/parser.mbt", [
    "@light_common.empty_parser_diagnostics(", "@light_common.bool_string(",
  ])
  assert_file_contains_all("formats/pptx/parser.mbt", [
    "@light_common.empty_parser_diagnostics(", "@light_common.bool_string(",
  ])
  assert_file_contains_all("formats/xlsx/parser.mbt", [
    "@light_common.empty_parser_diagnostics(",
  ])
}

///|
test "p5 contract helpers consolidate under a single root contracts file" {
  assert_true(@fs.path_exists("formats/format_contracts.mbt"))
  for
    path in [
      "formats/office_contract_docx.mbt", "formats/office_contract_pptx.mbt", "formats/office_contract_xlsx.mbt",
    ] {
    assert_true(!@fs.path_exists(path))
  }

  assert_file_contains_all("formats/format_contracts.mbt", [
    "pub fn docx_parser_contract_capability()", "pub fn docx_parser_contract()",
    "pub fn pptx_parser_contract_capability()", "pub fn pptx_parser_contract()",
    "pub fn xlsx_parser_contract_capability()", "pub fn xlsx_parser_contract()",
  ])
  assert_file_contains_none("formats/registry.mbt", [
    "docx_parser_contract()", "pptx_parser_contract()", "xlsx_parser_contract()",
  ])
}

///|
test "p5 pdfall keeps pdf native stack under per-format formats ownership with consolidated root facades" {
  for
    path in [
      "formats/pdf/moon.pkg", "formats/pdf/parser.mbt", "formats/pdf/backend.mbt",
      "formats/pdf/to_ir.mbt", "formats/pdf/model.mbt", "formats/pdf/geometry.mbt",
      "formats/pdf/cjk_decode.mbt", "formats/pdf/gb2312_data.mbt", "formats/pdf/backend_wbtest.mbt",
    ] {
    assert_true(@fs.path_exists(path))
  }

  for
    path in [
      "formats/pdf_native_parser.mbt", "formats/pdf_native_backend.mbt", "formats/pdf_native_to_ir.mbt",
      "formats/pdf_native_model.mbt", "formats/pdf_shared_geometry.mbt",
    ] {
    assert_true(!@fs.path_exists(path))
  }

  assert_true(!@fs.path_exists("formats/pdf_native_backend_wbtest.mbt"))
  assert_true(!@fs.path_exists("formats/pdf_native_cjk_decode.mbt"))
  assert_true(!@fs.path_exists("formats/pdf_native_cjk_decode_test.mbt"))
  assert_true(!@fs.path_exists("formats/pdf_native_backend_test.mbt"))
  assert_true(!@fs.path_exists("formats/pdf_native_to_ir_test.mbt"))
  assert_true(!@fs.path_exists("formats/pdf_native_test.mbt"))
  assert_file_contains_all("formats/registry.mbt", [
    "@input.DetectedFormat::Pdf", "pdf_native_parser()",
  ])
}

///|
test "p5 ocrall keeps image ocr parser/provider stack under per-format formats ownership without root facades" {
  for
    path in [
      "formats/ocr/moon.pkg", "formats/ocr/parser.mbt", "formats/ocr/model.mbt",
      "formats/ocr/provider.mbt", "formats/ocr/tesseract.mbt", "formats/ocr/tesseract_tsv.mbt",
      "formats/ocr/provider_test.mbt", "formats/ocr/runtime_wbtest.mbt", "formats/ocr/tesseract_test.mbt",
      "formats/ocr/tesseract_tsv_test.mbt",
    ] {
    assert_true(@fs.path_exists(path))
  }

  for
    path in [
      "formats/ocr_parser.mbt", "formats/ocr_model.mbt", "formats/ocr_provider.mbt",
      "formats/ocr_tesseract.mbt", "formats/ocr_tesseract_tsv.mbt",
    ] {
    assert_true(!@fs.path_exists(path))
  }

  assert_true(!@fs.path_exists("formats/ocr_provider_test.mbt"))
  assert_true(!@fs.path_exists("formats/ocr_runtime_wbtest.mbt"))
  assert_true(!@fs.path_exists("formats/ocr_tesseract_test.mbt"))
  assert_true(!@fs.path_exists("formats/ocr_tesseract_tsv_test.mbt"))

  assert_file_contains_all("formats/ocr/parser.mbt", [
    "image_ocr_parser only accepts detected image formats", "image OCR is not enabled for ",
  ])

  assert_file_contains_all("formats/registry.mbt", [
    "@input.DetectedFormat::Pdf", "pdf_native_parser()", "@input.DetectedFormat::Image(@input.ImageFormat::Png)",
    "image_ocr_parser()",
  ])
  assert_file_contains_none("formats/registry.mbt", [
    "@input.DetectedFormat::Pdf,\n    image_ocr_parser()",
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

  assert_contains_all(container_pkg, [
    "ZSeanYves/markitdown/core", "ZSeanYves/markitdown/input",
  ])
  assert_contains_none(container_pkg, [
    "ZSeanYves/markitdown/parser", "ZSeanYves/markitdown/formats", "ZSeanYves/markitdown/runtime",
    "ZSeanYves/markitdown/convert",
  ])

  assert_contains_all(office_pkg, [
    "ZSeanYves/markitdown/core", "ZSeanYves/markitdown/parser",
  ])
  assert_contains_none(office_pkg, [
    "ZSeanYves/markitdown/formats", "ZSeanYves/markitdown/doc_parse", "ZSeanYves/markitdown/convert",
    "ZSeanYves/markitdown/render", "ZSeanYves/markitdown/pipeline", "ZSeanYves/markitdown/runtime",
  ])
  assert_true(!@fs.path_exists("doc_parse"))
  assert_true(!@fs.path_exists("office"))
  assert_true(!@fs.path_exists("office_shared"))

  assert_contains_all(cli_pkg, ["ZSeanYves/markitdown/format_readers/zip"])
  assert_contains_none(registry_impl, [
    "docx_parser_contract()", "pptx_parser_contract()", "xlsx_parser_contract()",
  ])

  assert_files_avoid_strings(
    [
      "format_readers/csv/moon.pkg", "format_readers/ooxml/docx/moon.pkg", "format_readers/epub/moon.pkg",
      "format_readers/html/moon.pkg", "format_readers/json/moon.pkg", "format_readers/markdown/moon.pkg",
      "format_readers/ooxml/package/moon.pkg", "format_readers/pdf_native/moon.pkg",
      "format_readers/ooxml/pptx/moon.pkg", "format_readers/text/moon.pkg", "format_readers/tsv/moon.pkg",
      "format_readers/xml/moon.pkg", "format_readers/yaml/moon.pkg", "format_readers/zip/moon.pkg",
    ],
    [
      "ZSeanYves/markitdown/convert", "ZSeanYves/markitdown/pipeline", "ZSeanYves/markitdown/render",
      "ZSeanYves/markitdown/runtime",
    ],
  )
}
