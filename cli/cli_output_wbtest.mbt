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

  let txt = match
    run_cli(
      cli_options(
        txt_path,
        None,
        Some(@input.DetectedFormat::Txt),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current txt cli failed: " + msg)
  }
  let csv = match
    run_cli(
      cli_options(
        csv_path,
        None,
        Some(@input.DetectedFormat::Csv),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current csv cli failed: " + msg)
  }
  let tsv = match
    run_cli(
      cli_options(
        tsv_path,
        None,
        Some(@input.DetectedFormat::Tsv),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current tsv cli failed: " + msg)
  }
  let json = match
    run_cli(
      cli_options(
        json_path,
        None,
        Some(@input.DetectedFormat::Json),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current json cli failed: " + msg)
  }
  let jsonl = match
    run_cli(
      cli_options(
        jsonl_path,
        None,
        Some(@input.DetectedFormat::Jsonl),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current jsonl cli failed: " + msg)
  }
  let ndjson = match
    run_cli(
      cli_options(
        ndjson_path,
        None,
        Some(@input.DetectedFormat::Ndjson),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current ndjson cli failed: " + msg)
  }
  let xml = match
    run_cli(
      cli_options(
        xml_path,
        None,
        Some(@input.DetectedFormat::Xml),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current xml cli failed: " + msg)
  }
  let yaml = match
    run_cli(
      cli_options(
        yaml_path,
        None,
        Some(@input.DetectedFormat::Yaml),
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("current yaml cli failed: " + msg)
  }
  let markdown = match
    run_cli(
      cli_options(markdown_path, None, None, @convert.OutputFormat::Markdown),
    ) {
    Ok(value) => value
    Err(msg) => fail("current markdown cli failed: " + msg)
  }
  let markdown_long = match
    run_cli(
      cli_options(
        markdown_long_path,
        None,
        None,
        @convert.OutputFormat::Markdown,
      ),
    ) {
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
    run_cli(
      cli_options(
        txt_path,
        None,
        Some(@input.DetectedFormat::Txt),
        @convert.OutputFormat::DebugJson,
      ),
    ) {
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
        Some(@input.DetectedFormat::Json),
        @convert.OutputFormat::Markdown,
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
test "main cli accurate fallback provenance preserves output semantics" {
  let root = test_tmp_root() + "/main-cli-accurate-fallback"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_path = root + "/demo.toml"
  let output_path = root + "/demo.md"
  let provenance_path = root + "/demo.provenance.json"
  write_utf8_text(
    input_path, "title = \"MarkItDown\"\nenabled = true\ncount = 3\n",
  )

  let rendered = match
    run_cli_without_emitting_warnings(
      make_cli_options(
        input_path,
        Some(output_path),
        Some(provenance_path),
        Some(@input.DetectedFormat::Toml),
        @parser.default_ocr_options(),
        @convert.FidelityMode::Accurate,
        @convert.ConvertMode::Accurate,
        @convert.output_mode_for_output_format(@convert.OutputFormat::Markdown),
        false,
        @convert.OutputFormat::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(msg) => fail("expected cli accurate fallback conversion: " + msg)
  }

  assert_true(rendered.contains("| Key | Value |"))
  assert_true(read_utf8_text(output_path).contains("| Key | Value |"))
  let sidecar = read_utf8_text(provenance_path)
  assert_true(
    sidecar.contains("\"route_reason\": \"accurate_unsupported_fell_back\""),
  )
  assert_true(sidecar.contains("\"fidelity_mode\": \"balanced\""))
  assert_true(sidecar.contains("\"requested_fidelity_mode\": ["))
  assert_true(sidecar.contains("\"accurate\""))
  assert_true(sidecar.contains("\"accurate_unsupported_fell_back\""))
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
        Some(@input.DetectedFormat::Pptx),
        @convert.OutputFormat::Markdown,
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
      cli_options(
        input_path,
        Some(output_path),
        Some(@input.DetectedFormat::Markdown),
        @convert.OutputFormat::Markdown,
      ),
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
test "main cli converts zip through the root container pipeline and persists local assets only at output boundary" {
  let root = test_tmp_root() + "/main-cli-zip"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let zip_input = "samples/fixtures/contracts/zip/zip_html_local_image.zip"
  let out_dir = root + "/out"
  let out_md = out_dir + "/archive.md"
  ensure_dir_tree(out_dir)

  let rendered = match
    run_cli(
      cli_options(
        zip_input,
        Some(out_md),
        Some(@input.DetectedFormat::Zip),
        @convert.OutputFormat::Markdown,
      ),
    ) {
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
    run_cli(
      cli_options(
        input_path,
        Some(output_path),
        Some(@input.DetectedFormat::Ipynb),
        @convert.OutputFormat::Markdown,
      ),
    ) {
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
        Some(@input.DetectedFormat::Odt),
        @convert.OutputFormat::Markdown,
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
        Some(@input.DetectedFormat::Odp),
        @convert.OutputFormat::Markdown,
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
        Some(@input.DetectedFormat::Epub),
        @convert.OutputFormat::Markdown,
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
        Some(@input.DetectedFormat::Epub),
        @convert.OutputFormat::Markdown,
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

  let docx = run_cli(
    cli_options(docx_path, None, None, @convert.OutputFormat::Markdown),
  )
  let pptx = run_cli(
    cli_options(pptx_path, None, None, @convert.OutputFormat::Markdown),
  )
  let xlsx = run_cli(
    cli_options(xlsx_path, None, None, @convert.OutputFormat::Markdown),
  )
  let epub = run_cli(
    cli_options(
      "samples/fixtures/contracts/epub/epub_basic_package.epub",
      None,
      None,
      @convert.OutputFormat::Markdown,
    ),
  )
  let pdf = run_cli(
    cli_options(pdf_path, None, None, @convert.OutputFormat::Markdown),
  )
  match docx {
    Ok(value) => {
      assert_true(value.contains("![Figure alt text](assets/image01.png)"))
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
    run_cli(
      cli_options(
        input_path,
        Some(output_path),
        Some(@input.DetectedFormat::Html),
        @convert.OutputFormat::Markdown,
      ),
    ) {
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
test "main cli converts yaml and yml through isolated product shell" {
  let root = test_tmp_root() + "/main-cli-yaml"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let yaml_path = root + "/demo.yaml"
  let yml_path = root + "/demo.yml"
  write_utf8_text(yaml_path, "name: Alice\nrole: Engineer\n")
  write_utf8_text(yml_path, "kind: sample\nstatus: true\n")

  let yaml = match
    run_cli(cli_options(yaml_path, None, None, @convert.OutputFormat::Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current yaml cli failed: " + msg)
  }
  let yml = match
    run_cli(cli_options(yml_path, None, None, @convert.OutputFormat::Markdown)) {
    Ok(value) => value
    Err(msg) => fail("current yml cli failed: " + msg)
  }

  assert_true(yaml.contains("| Key | Value |"))
  assert_true(yaml.contains("| name | Alice |"))
  assert_true(yml.contains("| Key | Value |"))
  assert_true(yml.contains("| kind | sample |"))
}
