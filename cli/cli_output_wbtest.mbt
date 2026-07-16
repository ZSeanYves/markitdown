///|
fn cli_output_read_contract_bytes(path : String) -> Bytes raise {
  @fs.read_file_to_bytes(path) catch {
    e => fail("read contract sample failed: " + path + " : " + e.to_string())
  }
}

///|
fn cli_output_nested_office_zip_bytes() -> Bytes raise {
  @therm.build_store_zip_bytes([
    (
      "nested.docx",
      cli_output_read_contract_bytes(
        "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
      ),
    ),
    (
      "nested.xlsx",
      cli_output_read_contract_bytes(
        "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
      ),
    ),
    (
      "nested.pptx",
      cli_output_read_contract_bytes(
        "samples/fixtures/contracts/pptx/pptx_image_single.pptx",
      ),
    ),
  ])
}

///|
fn cli_output_assert_contains_all(
  text : String,
  needles : Array[String],
) -> Unit raise {
  for needle in needles {
    assert_true(text.contains(needle))
  }
}

///|
fn cli_output_zero_pad_int(value : Int, width : Int) -> String {
  let raw = value.to_string()
  if raw.length() >= width {
    raw
  } else {
    "0".repeat(width - raw.length()) + raw
  }
}

///|
fn cli_output_pdf_stream_object(stream : String) -> String {
  [
    "<< /Length " + stream.length().to_string() + " >>",
    "stream",
    stream,
    "endstream",
  ].join("\n")
}

///|
fn cli_output_minimal_pdf_bytes(
  object_bodies : Array[String],
  root_object_number : Int,
) -> Bytes {
  let sections : Array[String] = ["%PDF-1.4\n"]
  let offsets : Array[Int] = [0]
  let mut current_offset = sections[0].length()

  for index in 0..<object_bodies.length() {
    let object_payload = (index + 1).to_string() +
      " 0 obj\n" +
      object_bodies[index] +
      "\nendobj\n"
    offsets.push(current_offset)
    sections.push(object_payload)
    current_offset += object_payload.length()
  }

  let xref_offset = current_offset
  let xref_lines : Array[String] = [
    "xref",
    "0 " + (object_bodies.length() + 1).to_string(),
    "0000000000 65535 f ",
  ]
  for index in 1..<offsets.length() {
    xref_lines.push(cli_output_zero_pad_int(offsets[index], 10) + " 00000 n ")
  }
  sections.push(
    xref_lines.join("\n") +
    "\n" +
    [
      "trailer",
      "<< /Size " +
      (object_bodies.length() + 1).to_string() +
      " /Root " +
      root_object_number.to_string() +
      " 0 R >>",
      "startxref",
      xref_offset.to_string(),
      "%%EOF",
      "",
    ].join("\n"),
  )
  @utf8.encode(sections.join(""))
}

///|
fn cli_output_generated_link_pdf_bytes() -> Bytes {
  let contents = "BT /F1 12 Tf 1 0 0 1 50 700 Tm (Visit the example website for details.) Tj ET"
  cli_output_minimal_pdf_bytes(
    [
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      cli_output_pdf_stream_object(contents),
      "<< /Type /Annot /Subtype /Link /Rect [49 688 308 706] /Border [0 0 0] /A << /S /URI /URI (https://example.com) >> >>",
      "<< /Type /Page /Parent 5 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R /Annots [3 0 R] >>",
      "<< /Type /Pages /Kids [4 0 R] /Count 1 >>",
      "<< /Type /Catalog /Pages 5 0 R >>",
    ],
    6,
  )
}

///|
fn cli_output_generated_table_pdf_bytes() -> Bytes {
  let contents = [
    "BT /F1 12 Tf 1 0 0 1 40 560 Tm (Product) Tj ET", "BT /F1 12 Tf 1 0 0 1 180 560 Tm (Region) Tj ET",
    "BT /F1 12 Tf 1 0 0 1 300 560 Tm (Status) Tj ET", "BT /F1 12 Tf 1 0 0 1 40 538 Tm (Alpha) Tj ET",
    "BT /F1 12 Tf 1 0 0 1 180 538 Tm (East) Tj ET", "BT /F1 12 Tf 1 0 0 1 300 538 Tm (Open) Tj ET",
    "BT /F1 12 Tf 1 0 0 1 40 516 Tm (Beta) Tj ET", "BT /F1 12 Tf 1 0 0 1 180 516 Tm (West) Tj ET",
    "BT /F1 12 Tf 1 0 0 1 300 516 Tm (Closed) Tj ET",
  ].join("\n")
  cli_output_minimal_pdf_bytes(
    [
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      cli_output_pdf_stream_object(contents),
      "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Catalog /Pages 4 0 R >>",
    ],
    5,
  )
}

///|
test "root cli converts txt csv tsv json jsonl ndjson xml yaml and markdown through the current product shell" {
  let root = test_tmp_root() + "/main-cli"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let txt_path = root + "/demo.txt"
  let csv_path = root + "/demo.csv"
  let tsv_path = root + "/demo.tsv"
  let json_path = root + "/demo.json"
  let jsonl_path = root + "/demo.jsonl"
  let ndjson_path = root + "/demo.ndjson"
  let xml_path = root + "/demo.xml"
  let yaml_path = root + "/demo.yaml"
  let markdown_path = root + "/demo.md"
  let markdown_long_path = root + "/demo.markdown"
  write_utf8_text(txt_path, "alpha\n\nbeta")
  write_utf8_text(csv_path, "name,score\nalice,7\n")
  write_utf8_text(tsv_path, "name\tscore\nbob\t9\n")
  write_utf8_text(json_path, "{\"name\":\"Alice\",\"role\":\"Engineer\"}\n")
  write_utf8_text(
    jsonl_path, "{\"name\":\"Alice\",\"score\":7}\n{\"name\":\"Bob\",\"score\":9}\n",
  )
  write_utf8_text(
    ndjson_path, "{\"name\":\"Carol\",\"score\":5}\n{\"name\":\"Dave\",\"score\":8}\n",
  )
  write_utf8_text(xml_path, "<root><item>Hello</item></root>\n")
  write_utf8_text(yaml_path, "name: Alice\nrole: Engineer\n")
  write_utf8_text(markdown_path, "# Markdown Demo\n\nBody line.\n")
  write_utf8_text(markdown_long_path, "---\ntitle: Demo\n---\n\n# Title\n")

  let txt = match run_cli(cli_options(txt_path, None, Some(Txt), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current txt cli failed: " + msg)
  }
  let csv = match run_cli(cli_options(csv_path, None, Some(Csv), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current csv cli failed: " + msg)
  }
  let tsv = match run_cli(cli_options(tsv_path, None, Some(Tsv), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current tsv cli failed: " + msg)
  }
  let json = match run_cli(cli_options(json_path, None, Some(Json), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current json cli failed: " + msg)
  }
  let jsonl = match
    run_cli(cli_options(jsonl_path, None, Some(Jsonl), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current jsonl cli failed: " + msg)
  }
  let ndjson = match
    run_cli(cli_options(ndjson_path, None, Some(Ndjson), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current ndjson cli failed: " + msg)
  }
  let xml = match run_cli(cli_options(xml_path, None, Some(Xml), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current xml cli failed: " + msg)
  }
  let yaml = match run_cli(cli_options(yaml_path, None, Some(Yaml), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current yaml cli failed: " + msg)
  }
  let markdown = match
    run_cli(cli_options(markdown_path, None, None, Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current markdown cli failed: " + msg)
  }
  let markdown_long = match
    run_cli(cli_options(markdown_long_path, None, None, Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current .markdown cli failed: " + msg)
  }

  assert_eq(txt, "alpha\n\nbeta")
  assert_true(csv.contains("| name | score |"))
  assert_true(csv.contains("| alice | 7 |"))
  assert_true(tsv.contains("| name | score |"))
  assert_true(tsv.contains("| bob | 9 |"))
  assert_true(json.contains("| Key | Value |"))
  assert_true(json.contains("| name | Alice |"))
  assert_true(jsonl.contains("| name | score |"))
  assert_true(jsonl.contains("| Alice | 7 |"))
  assert_true(ndjson.contains("| name | score |"))
  assert_true(ndjson.contains("| Dave | 8 |"))
  assert_eq(xml, "# <root>\n\n- item: Hello")
  assert_true(yaml.contains("| Key | Value |"))
  assert_true(yaml.contains("| name | Alice |"))
  assert_eq(markdown, "# Markdown Demo\n\nBody line.")
  assert_true(markdown_long.contains("---\ntitle: Demo\n---"))
  assert_true(markdown_long.contains("# Title"))
}

///|
test "main cli emits debug json on the canonical renderer path" {
  let root = test_tmp_root() + "/main-cli-json"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let txt_path = root + "/debug.txt"
  write_utf8_text(txt_path, "plain")
  let rendered = match
    run_cli(cli_options(txt_path, None, Some(Txt), DebugJson)) {
    Ok(value) => value
    Err(msg) => fail("debug json cli failed: " + msg)
  }

  assert_true(rendered.contains("\"event_count\": 1"))
  assert_true(rendered.contains("\"renderer_name\": \"DebugJsonRenderer\""))
  assert_true(rendered.contains("\"render_input_kind\": \"event_stream\""))
  assert_true(rendered.contains("\"source_ref\""))
}

///|
test "main cli provenance sidecar preserves conversion output semantics" {
  let root = test_tmp_root() + "/main-cli-provenance"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_path = root + "/demo.json"
  let output_path = root + "/demo.md"
  let provenance_path = root + "/demo.provenance.json"
  write_utf8_text(input_path, "{\"name\":\"Alice\",\"role\":\"Engineer\"}\n")

  let rendered = match
    run_cli(
      cli_options(
        input_path,
        Some(output_path),
        Some(Json),
        Markdown,
        provenance_output=Some(provenance_path),
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("expected cli provenance sidecar conversion: " + msg)
  }

  assert_true(rendered.contains("| Key | Value |"))
  assert_true(read_utf8_text(output_path).contains("| Key | Value |"))
  let sidecar = read_utf8_text(provenance_path)
  assert_true(sidecar.contains("\"selected_route\":"))
  assert_true(sidecar.contains("\"route_reason\":"))
  assert_true(sidecar.contains("\"route_probe_summary\":"))
  assert_true(sidecar.contains("\"effective_parser_mode\":"))
  assert_true(sidecar.contains("\"render_input_kind\":"))
  assert_true(sidecar.contains("\"ocr_provider_selection_target\":"))
  assert_true(sidecar.contains("\"ocr_provider_requested_kind\":"))
  assert_true(sidecar.contains("\"ocr_provider_resolved_kind\":"))
  assert_true(sidecar.contains("\"audio_backend_transport\":"))
  assert_true(sidecar.contains("\"audio_backend_name\":"))
  assert_true(sidecar.contains("\"audio_backend_version\":"))
  assert_true(!sidecar.contains("\"ocr_provider_fallback\":"))
  assert_true(!sidecar.contains("\"dependency_diagnostics\":"))
}

///|
test "main cli rejects unsupported accurate mode without writing output" {
  let root = test_tmp_root() + "/main-cli-accurate-fallback"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_path = root + "/demo.toml"
  let output_path = root + "/demo.md"
  let provenance_path = root + "/demo.provenance.json"
  write_utf8_text(
    input_path, "title = \"MarkItDown\"\nenabled = true\ncount = 3\n",
  )

  match
    run_cli_without_emitting_warnings(
      make_cli_options(
        input_path,
        Some(output_path),
        Some(provenance_path),
        Some(Toml),
        @parser.default_ocr_options(),
        Accurate,
        Accurate,
        @convert.output_mode_for_output_format(Markdown),
        false,
        Markdown,
      ),
    ) {
    Err(msg) => {
      assert_true(msg.contains("accurate mode is unsupported for `toml`"))
      assert_true(msg.contains("use balance mode"))
    }
    Ok(_) => fail("unsupported accurate mode must fail closed")
  }
  assert_true(!@fs.path_exists(output_path))
  assert_true(!@fs.path_exists(provenance_path))
}

///|
test "main cli persists pptx local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-pptx-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let out_dir = root + "/out"
  let out_path = out_dir + "/pptx_image_single.md"
  ensure_dir_tree(out_dir)
  let persisted = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/pptx/pptx_image_single.pptx",
        Some(out_path),
        Some(Pptx),
        Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current pptx local asset cli failed: " + msg)
  }
  assert_true(persisted.contains("![slide-1-image-1](assets/image01.png)"))
  let persisted_markdown = read_utf8_text(out_path)
  assert_true(
    persisted_markdown.contains("![slide-1-image-1](assets/image01.png)"),
  )
  assert_true(@fs.path_exists(out_dir + "/assets/image01.png"))
}

///|
test "main cli persists markdown local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-markdown-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_dir = root + "/input"
  let image_dir = input_dir + "/img"
  let out_dir = root + "/out"
  ensure_dir_tree(image_dir)
  ensure_dir_tree(out_dir)
  let input_path = input_dir + "/sample.md"
  let output_path = out_dir + "/sample.md"
  write_utf8_text(
    input_path, "![single](img/img_red.jpg)\n\n![remote](https://example.com/remote.png)\n",
  )
  let source_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/html/img_red.jpg",
  ) catch {
    e => fail("read markdown asset sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(image_dir + "/img_red.jpg", source_bytes) catch {
    e => fail("write markdown asset sample failed: " + e.to_string())
  }

  let rendered = match
    run_cli(
      cli_options(input_path, Some(output_path), Some(Markdown), Markdown),
    ) {
    Ok(value) => value
    Err(msg) => fail("current markdown cli asset persistence failed: " + msg)
  }

  assert_true(rendered.contains("![single](assets/image01.jpg)"))
  assert_true(rendered.contains("![remote](https://example.com/remote.png)"))
  let persisted_markdown = read_utf8_text(output_path)
  assert_true(persisted_markdown.contains("![single](assets/image01.jpg)"))
  assert_true(
    persisted_markdown.contains("![remote](https://example.com/remote.png)"),
  )
  let copied_asset_path = out_dir + "/assets/image01.jpg"
  assert_true(@fs.path_exists(copied_asset_path))
  assert_true(!@fs.path_exists(out_dir + "/assets/image02.png"))
  let copied_bytes = @fs.read_file_to_bytes(copied_asset_path) catch {
    e => fail("read copied markdown asset failed: " + e.to_string())
  }
  assert_true(copied_bytes.to_array() == source_bytes.to_array())
}

///|
test "main cli persists markdown inline local assets with surrounding text" {
  let root = test_tmp_root() + "/main-cli-markdown-inline-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let input_dir = root + "/input"
  let out_dir = root + "/out"
  ensure_dir_tree(input_dir + "/img")
  ensure_dir_tree(out_dir)
  let input_path = input_dir + "/sample.md"
  let output_path = out_dir + "/sample.md"
  write_utf8_text(input_path, "Before ![inline](img/img_red.jpg) after.\n")
  let source_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/html/img_red.jpg",
  ) catch {
    e => fail("read markdown inline asset sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(input_dir + "/img/img_red.jpg", source_bytes) catch {
    e => fail("write markdown inline asset sample failed: " + e.to_string())
  }
  let rendered = run_cli(
    cli_options(input_path, Some(output_path), Some(Markdown), Markdown),
  ).unwrap()
  assert_true(rendered.contains("Before ![inline](assets/image01.jpg) after."))
  let copied = @fs.read_file_to_bytes(out_dir + "/assets/image01.jpg") catch {
    e => fail("read persisted markdown inline asset failed: " + e.to_string())
  }
  assert_true(copied.to_array() == source_bytes.to_array())
}

///|
test "main cli converts zip through the root container pipeline and persists local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-zip"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let zip_input = "samples/fixtures/contracts/zip/zip_html_local_image.zip"
  let out_dir = root + "/out"
  let out_md = out_dir + "/archive.md"
  ensure_dir_tree(out_dir)

  let rendered = match
    run_cli(cli_options(zip_input, Some(out_md), Some(Zip), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current zip cli failed: " + msg)
  }

  assert_true(rendered.contains("# site/page.html"))
  assert_true(
    rendered.contains("![single](assets/archive/site_page.html/image01.png)"),
  )
  let persisted_markdown = read_utf8_text(out_md)
  assert_true(
    persisted_markdown.contains(
      "![single](assets/archive/site_page.html/image01.png)",
    ),
  )
  let copied_asset_path = out_dir + "/assets/archive/site_page.html/image01.png"
  assert_true(@fs.path_exists(copied_asset_path))
  assert_true(
    !@fs.path_exists(out_dir + "/assets/archive/site_page.html/image02.png"),
  )
}

///|
test "main cli expands nested office entries from zip and persists rewritten assets at output boundary" {
  let root = test_tmp_root() + "/main-cli-zip-office"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let zip_input = root + "/nested-office.zip"
  let out_dir = root + "/out"
  let out_md = out_dir + "/archive.md"
  ensure_dir_tree(out_dir)
  @fs.write_bytes_to_file(zip_input, cli_output_nested_office_zip_bytes()) catch {
    e => fail("write nested office zip failed: " + e.to_string())
  }

  let rendered = match
    run_cli(cli_options(zip_input, Some(out_md), Some(Zip), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("nested office zip cli failed: " + msg)
  }

  cli_output_assert_contains_all(rendered, [
    "# nested.docx", "![Figure alt text](assets/archive/nested.docx/image01.png)",
    "# nested.xlsx", "## Sheet1", "# nested.pptx", "![slide-1-image-1](assets/archive/nested.pptx/image01.png)",
  ])
  let persisted_markdown = read_utf8_text(out_md)
  cli_output_assert_contains_all(persisted_markdown, [
    "![Figure alt text](assets/archive/nested.docx/image01.png)", "![slide-1-image-1](assets/archive/nested.pptx/image01.png)",
  ])
  assert_true(
    @fs.path_exists(out_dir + "/assets/archive/nested.docx/image01.png"),
  )
  assert_true(
    @fs.path_exists(out_dir + "/assets/archive/nested.pptx/image01.png"),
  )
}

///|
test "main cli preserves namespaced office asset rewrites for repo zip fixtures" {
  let root = test_tmp_root() + "/main-cli-zip-office-namespaced"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let zip_input = "samples/fixtures/contracts/zip/zip_assets_namespace.zip"
  let out_dir = root + "/out"
  let out_md = out_dir + "/archive.md"
  ensure_dir_tree(out_dir)

  let rendered = match
    run_cli(cli_options(zip_input, Some(out_md), Some(Zip), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("namespaced office zip cli failed: " + msg)
  }

  cli_output_assert_contains_all(rendered, [
    "# docs/report.docx", "![Figure alt text](assets/archive/docs_report.docx/image01.png)",
    "# slides/overview.pptx", "## Slide 1", "![Figure alt text](assets/archive/slides_overview.pptx/image01.png)",
  ])
  assert_true(!rendered.contains("> Skipped: unsupported file type: docx"))
  assert_true(!rendered.contains("> Skipped: unsupported file type: pptx"))
  let persisted_markdown = read_utf8_text(out_md)
  cli_output_assert_contains_all(persisted_markdown, [
    "![Figure alt text](assets/archive/docs_report.docx/image01.png)", "![Figure alt text](assets/archive/slides_overview.pptx/image01.png)",
  ])
  assert_true(
    @fs.path_exists(out_dir + "/assets/archive/docs_report.docx/image01.png"),
  )
  assert_true(
    @fs.path_exists(
      out_dir + "/assets/archive/slides_overview.pptx/image01.png",
    ),
  )
}

///|
test "main cli persists ipynb inline image assets at output boundary" {
  let root = test_tmp_root() + "/main-cli-ipynb-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_path = root + "/sample.ipynb"
  let out_dir = root + "/out"
  let output_path = out_dir + "/sample.md"
  ensure_dir_tree(out_dir)
  write_utf8_text(
    input_path,
    "{\n" +
    "  \"nbformat\": 4,\n" +
    "  \"nbformat_minor\": 5,\n" +
    "  \"metadata\": {\"language_info\": {\"name\": \"python\"}},\n" +
    "  \"cells\": [\n" +
    "    {\n" +
    "      \"cell_type\": \"markdown\",\n" +
    "      \"attachments\": {\n" +
    "        \"dot.png\": {\n" +
    "          \"image/png\": \"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0MsAAAAASUVORK5CYII=\"\n" +
    "        }\n" +
    "      },\n" +
    "      \"source\": [\"![dot](attachment:dot.png)\\n\"]\n" +
    "    },\n" +
    "    {\n" +
    "      \"cell_type\": \"code\",\n" +
    "      \"execution_count\": 1,\n" +
    "      \"source\": \"display('ok')\\n\",\n" +
    "      \"outputs\": [\n" +
    "        {\n" +
    "          \"output_type\": \"display_data\",\n" +
    "          \"data\": {\n" +
    "            \"image/png\": \"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0MsAAAAASUVORK5CYII=\",\n" +
    "            \"text/plain\": [\"<Image>\\n\"]\n" +
    "          }\n" +
    "        }\n" +
    "      ]\n" +
    "    }\n" +
    "  ]\n" +
    "}\n",
  )

  let rendered = match
    run_cli(cli_options(input_path, Some(output_path), Some(Ipynb), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current ipynb cli asset persistence failed: " + msg)
  }

  assert_true(
    rendered.contains("![notebook image](assets/ipynb-cell02-output01.png)"),
  )
  let persisted_markdown = read_utf8_text(output_path)
  assert_true(
    persisted_markdown.contains(
      "![dot](assets/ipynb-cell01-attachment-dot-png.png)",
    ),
  )
  assert_true(
    persisted_markdown.contains(
      "![notebook image](assets/ipynb-cell02-output01.png)",
    ),
  )
  assert_true(
    @fs.path_exists(out_dir + "/assets/ipynb-cell01-attachment-dot-png.png"),
  )
  assert_true(@fs.path_exists(out_dir + "/assets/ipynb-cell02-output01.png"))
}

///|
test "main cli persists odt local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-odt-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let out_dir = root + "/out"
  let out_path = out_dir + "/odt_basic_assets.md"
  ensure_dir_tree(out_dir)
  let persisted = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/odt/odt_basic_assets.odt",
        Some(out_path),
        Some(Odt),
        Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("odt local asset cli failed: " + msg)
  }
  assert_true(persisted.contains("![red-dot](assets/odt-red.png)"))
  let persisted_markdown = read_utf8_text(out_path)
  assert_true(persisted_markdown.contains("![red-dot](assets/odt-red.png)"))
  assert_true(@fs.path_exists(out_dir + "/assets/odt-red.png"))
}

///|
test "main cli persists odp local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-odp-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let out_dir = root + "/out"
  let out_path = out_dir + "/odp_basic_assets.md"
  ensure_dir_tree(out_dir)
  let persisted = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/odp/odp_basic_assets.odp",
        Some(out_path),
        Some(Odp),
        Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("odp local asset cli failed: " + msg)
  }
  assert_true(persisted.contains("![red-dot](assets/odp-slide1-red.png)"))
  let persisted_markdown = read_utf8_text(out_path)
  assert_true(
    persisted_markdown.contains("![red-dot](assets/odp-slide1-red.png)"),
  )
  assert_true(@fs.path_exists(out_dir + "/assets/odp-slide1-red.png"))
}

///|
test "main cli keeps epub local assets output boundary only and remote data assets no fetch" {
  let root = test_tmp_root() + "/main-cli-epub-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let out_dir = root + "/out"
  let local_md = out_dir + "/local.md"
  let remote_md = out_dir + "/remote.md"
  ensure_dir_tree(out_dir)

  let local_rendered = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/epub/epub_local_image_basic.epub",
        Some(local_md),
        Some(Epub),
        Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current epub local asset cli failed: " + msg)
  }
  assert_true(
    local_rendered.contains(
      "![cover art](assets/archive/OPS_chapter.xhtml/image01.png)",
    ),
  )
  let persisted_local = read_utf8_text(local_md)
  assert_true(
    persisted_local.contains(
      "![cover art](assets/archive/OPS_chapter.xhtml/image01.png)",
    ),
  )
  assert_true(
    @fs.path_exists(out_dir + "/assets/archive/OPS_chapter.xhtml/image01.png"),
  )

  let remote_rendered = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/epub/epub_remote_data_image_boundary.epub",
        Some(remote_md),
        Some(Epub),
        Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current epub remote asset cli failed: " + msg)
  }
  assert_true(remote_rendered.contains("# Boundary Chapter"))
  let persisted_remote = read_utf8_text(remote_md)
  assert_true(persisted_remote.contains("# Boundary Chapter"))
  assert_true(!persisted_remote.contains("https://example.com/a.png"))
  assert_true(!persisted_remote.contains("data:image/png"))
  assert_true(
    !@fs.path_exists(out_dir + "/assets/archive/OPS_chapter.xhtml/image02.png"),
  )
}

///|
test "main cli restores docx xlsx pptx and native-text pdf" {
  let root = test_tmp_root() + "/main-cli-unsupported"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let docx_path = root + "/sample.docx"
  let pptx_path = root + "/sample.pptx"
  let xlsx_path = root + "/sample.xlsx"
  let pdf_path = root + "/sample.pdf"
  let docx_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
  ) catch {
    e => fail("read docx sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(docx_path, docx_bytes) catch {
    e => fail("write docx sample failed: " + e.to_string())
  }
  let pptx_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/pptx/pptx_hidden_slide_basic.pptx",
  ) catch {
    e => fail("read pptx sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(pptx_path, pptx_bytes) catch {
    e => fail("write pptx sample failed: " + e.to_string())
  }
  let xlsx_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
  ) catch {
    e => fail("read xlsx sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(xlsx_path, xlsx_bytes) catch {
    e => fail("write xlsx sample failed: " + e.to_string())
  }
  let pdf_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/pdf/root_native_text_baseline.pdf",
  ) catch {
    e => fail("read pdf sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(pdf_path, pdf_bytes) catch {
    e => fail("write pdf sample failed: " + e.to_string())
  }

  let docx = run_cli(cli_options(docx_path, None, None, Markdown))
  let pptx = run_cli(cli_options(pptx_path, None, None, Markdown))
  let xlsx = run_cli(cli_options(xlsx_path, None, None, Markdown))
  let epub = run_cli(
    cli_options(
      "samples/fixtures/contracts/epub/epub_basic_package.epub",
      None,
      None,
      Markdown,
    ),
  )
  let pdf = run_cli(cli_options(pdf_path, None, None, Markdown))
  match docx {
    Ok(value) => {
      assert_true(
        value.contains(
          "Figure alt text [Asset not materialized on stdout: word/media/image1.png]",
        ),
      )
      assert_true(value.contains("*Figure title text*"))
    }
    Err(msg) => fail("docx should be restored: " + msg)
  }
  match pptx {
    Ok(value) => {
      assert_true(value.contains("## Slide 1"))
      assert_true(value.contains("### Third"))
      assert_true(!value.contains("(hidden)"))
      assert_true(!value.contains("## Slide 2"))
    }
    Err(msg) => fail("pptx should be restored: " + msg)
  }
  match xlsx {
    Ok(value) => {
      assert_true(value.contains("## Sheet1"))
      assert_true(value.contains("| Name | Value | 备注 |"))
      assert_true(value.contains("## Data"))
    }
    Err(msg) => fail("xlsx should be restored: " + msg)
  }
  match epub {
    Ok(value) => {
      assert_true(value.contains("# OPS/chapter.xhtml"))
      assert_true(value.contains("# Basic Chapter"))
    }
    Err(msg) => fail("epub should be restored: " + msg)
  }
  match pdf {
    Ok(value) =>
      assert_eq(
        value.trim_end().to_owned(),
        read_utf8_text(
          "samples/fixtures/contracts/pdf/root_native_text_baseline.expected.md",
        )
        .trim_end()
        .to_owned(),
      )
    Err(msg) => fail("pdf should be restored on main cli: " + msg)
  }
}

///|
test "main cli accurate pdf keeps born-digital markdown stable and removes repeated header footer text" {
  let balanced_text = match
    run_cli(
      cli_options(
        "samples/fixtures/contracts/pdf/text_simple.pdf",
        None,
        Some(Pdf),
        Markdown,
      ),
    ) {
    Ok(value) => value.trim_end().to_owned()
    Err(msg) => fail("balanced text pdf cli render failed: " + msg)
  }
  let accurate_text = match
    run_cli(
      make_cli_options(
        "samples/fixtures/contracts/pdf/text_simple.pdf",
        None,
        None,
        Some(Pdf),
        @parser.default_ocr_options(),
        Accurate,
        Accurate,
        @convert.output_mode_for_output_format(Markdown),
        false,
        Markdown,
        rag_options=@rag.default_rag_options(),
      ),
    ) {
    Ok(value) => value.trim_end().to_owned()
    Err(msg) => fail("accurate text pdf cli render failed: " + msg)
  }
  assert_true(balanced_text.contains("MarkItDown"))
  assert_true(accurate_text.contains("MarkItDown"))

  let accurate_header_footer = match
    run_cli(
      make_cli_options(
        "samples/fixtures/contracts/pdf/pdf_header_footer_variants_phase15.pdf",
        None,
        None,
        Some(Pdf),
        @parser.default_ocr_options(),
        Accurate,
        Accurate,
        @convert.output_mode_for_output_format(Markdown),
        false,
        Markdown,
        rag_options=@rag.default_rag_options(),
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("accurate header/footer pdf cli render failed: " + msg)
  }
  assert_true(accurate_header_footer.contains("Body paragraph page 1"))
  assert_true(accurate_header_footer.contains("Body paragraph page 2"))
  assert_true(accurate_header_footer.contains("Body paragraph page 3"))
  assert_true(!accurate_header_footer.contains("Company Confidential"))
  assert_true(!accurate_header_footer.contains("Quarterly Summary"))
}

///|
test "main cli lowers generated native pdf uri links into markdown links" {
  let root = test_tmp_root() + "/pdf-link"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let pdf_path = root + "/uri-link.pdf"
  @fs.write_bytes_to_file(pdf_path, cli_output_generated_link_pdf_bytes()) catch {
    e => fail("write generated link pdf failed: " + e.to_string())
  }

  let markdown = match
    run_cli(cli_options(pdf_path, None, Some(Pdf), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("generated link pdf cli render failed: " + msg)
  }
  assert_true(
    markdown.contains(
      "[Visit the example website for details.](https://example.com)",
    ),
  )
}

///|
test "main cli lowers generated native pdf tables into markdown tables" {
  let root = test_tmp_root() + "/pdf-table"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let pdf_path = root + "/table.pdf"
  @fs.write_bytes_to_file(pdf_path, cli_output_generated_table_pdf_bytes()) catch {
    e => fail("write generated table pdf failed: " + e.to_string())
  }

  let markdown = match
    run_cli(cli_options(pdf_path, None, Some(Pdf), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("generated table pdf cli render failed: " + msg)
  }
  cli_output_assert_contains_all(markdown, [
    "| Product | Region | Status |", "| Alpha | East | Open |", "| Beta | West | Closed |",
  ])
}

///|
test "main cli persists html local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-html-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_dir = root + "/input"
  let image_dir = input_dir + "/img"
  let out_dir = root + "/out"
  ensure_dir_tree(image_dir)
  ensure_dir_tree(out_dir)
  let input_path = input_dir + "/sample.html"
  let output_path = out_dir + "/sample.md"
  write_utf8_text(
    input_path,
    "<p><img src=\"img/img_red.jpg\" alt=\"single\"></p>\n" +
    "<p><img src=\"https://example.com/remote.png\" alt=\"remote\"></p>\n",
  )
  let source_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/html/img_red.jpg",
  ) catch {
    e => fail("read html asset sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(image_dir + "/img_red.jpg", source_bytes) catch {
    e => fail("write html asset sample failed: " + e.to_string())
  }

  let rendered = match
    run_cli(cli_options(input_path, Some(output_path), Some(Html), Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current html cli asset persistence failed: " + msg)
  }

  assert_true(rendered.contains("![single](assets/image01.jpg)"))
  assert_true(rendered.contains("[remote]"))
  let persisted_markdown = read_utf8_text(output_path)
  assert_true(persisted_markdown.contains("![single](assets/image01.jpg)"))
  assert_true(persisted_markdown.contains("[remote]"))
  let copied_asset_path = out_dir + "/assets/image01.jpg"
  assert_true(@fs.path_exists(copied_asset_path))
  assert_true(!@fs.path_exists(out_dir + "/assets/image02.png"))
  let copied_bytes = @fs.read_file_to_bytes(copied_asset_path) catch {
    e => fail("read copied html asset failed: " + e.to_string())
  }
  assert_true(copied_bytes.to_array() == source_bytes.to_array())
}

///|
test "main cli degrades missing local assets without broken references" {
  let root = test_tmp_root() + "/main-cli-missing-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let cases = [
    (
      "html",
      "<h1>Document</h1><p><img src=\"img/missing.png\" alt=\"diagram\"></p>",
      @input.DetectedFormat::Html,
      "diagram [Asset unavailable: img/missing.png]",
    ),
    (
      "rst",
      "Document\n========\n\n.. image:: images/missing.png\n   :alt: diagram\n",
      Rst,
      "diagram [Asset unavailable: images/missing.png]",
    ),
  ]
  for item in cases {
    let input_path = root + "/input." + item.0
    let output_path = root + "/out-" + item.0 + ".md"
    write_utf8_text(input_path, item.1)
    let rendered = run_cli(
      cli_options(input_path, Some(output_path), Some(item.2), Markdown),
    ).unwrap()
    assert_true(rendered.contains(item.3))
    assert_true(!rendered.contains("!["))
    assert_true(read_utf8_text(output_path).contains(item.3))
    let stdout_rendered = run_cli(
      cli_options(input_path, None, Some(item.2), Markdown),
    ).unwrap()
    assert_true(stdout_rendered.contains("Asset not materialized on stdout"))
    assert_true(!stdout_rendered.contains("!["))
  }
}

///|
test "main cli degrades ipynb attachment references with missing payload" {
  let root = test_tmp_root() + "/main-cli-ipynb-missing-attachment"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let input_path = root + "/input.ipynb"
  let output_path = root + "/out.md"
  write_utf8_text(
    input_path,
    "{\"nbformat\":4,\"nbformat_minor\":5,\"metadata\":{},\"cells\":[{" +
    "\"cell_type\":\"markdown\",\"metadata\":{},\"source\":[\"![logo](attachment:logo.jpg)\"]," +
    "\"attachments\":{\"logo.jpg\":{\"image/jpeg\":\"\"}}}]}",
  )
  let rendered = run_cli(
    cli_options(input_path, Some(output_path), Some(Ipynb), Markdown),
  ).unwrap()
  assert_true(rendered.contains("Asset unavailable"))
  assert_true(!rendered.contains("!["))
}

///|
test "main cli converts yaml and yml through isolated product shell" {
  let root = test_tmp_root() + "/main-cli-yaml"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let yaml_path = root + "/demo.yaml"
  let yml_path = root + "/demo.yml"
  write_utf8_text(yaml_path, "name: Alice\nrole: Engineer\n")
  write_utf8_text(yml_path, "kind: sample\nstatus: true\n")

  let yaml = match run_cli(cli_options(yaml_path, None, None, Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current yaml cli failed: " + msg)
  }
  let yml = match run_cli(cli_options(yml_path, None, None, Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current yml cli failed: " + msg)
  }

  assert_true(yaml.contains("| Key | Value |"))
  assert_true(yaml.contains("| name | Alice |"))
  assert_true(yml.contains("| Key | Value |"))
  assert_true(yml.contains("| kind | sample |"))
}

///|
test "main cli persists TeX RST and AsciiDoc sidecar images" {
  let root = test_tmp_root() + "/main-cli-text-markup-assets"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let source_bytes = @fs.read_file_to_bytes(
    "samples/fixtures/contracts/pptx/pptx_image_single.assets/image01.png",
  ) catch {
    e => fail("read text markup asset sample failed: " + e.to_string())
  }
  let cases = [
    ("tex", "\\includegraphics{local.png}", @input.DetectedFormat::Tex),
    ("rst", ".. image:: local.png\n   :alt: Local image\n", Rst),
    ("asciidoc", "image::local.png[Local image]\n", Asciidoc),
  ]
  for item in cases {
    let case_root = root + "/" + item.0
    let output_root = case_root + "/out"
    ensure_dir_tree(output_root)
    let input_path = case_root + "/input." + item.0
    let output_path = output_root + "/result.md"
    write_utf8_text(input_path, item.1)
    @fs.write_bytes_to_file(case_root + "/local.png", source_bytes) catch {
      e => fail("write text markup sidecar failed: " + e.to_string())
    }
    let rendered = run_cli(
      cli_options(input_path, Some(output_path), Some(item.2), Markdown),
    ).unwrap()
    let expected_asset = "assets/" + item.0 + "-local.png"
    assert_true(rendered.contains(expected_asset))
    let persisted = output_root + "/" + expected_asset
    assert_true(@fs.path_exists(persisted))
    let persisted_bytes = @fs.read_file_to_bytes(persisted) catch {
      e => fail("read persisted text markup sidecar failed: " + e.to_string())
    }
    assert_true(persisted_bytes.to_array() == source_bytes.to_array())
  }
}

///|
test "CLI ZIP asset lookup normalizes safe dot segments" {
  assert_eq(
    normalized_zip_asset_entry("./ObjectReplacements/Object 1"),
    "ObjectReplacements/Object 1",
  )
  assert_eq(
    normalized_zip_asset_entry("Pictures/./image.png"),
    "Pictures/image.png",
  )
}

///|
test "batch task skipped status has a stable manifest name" {
  assert_eq(batch_task_status_name(Skipped), "skipped")
}
