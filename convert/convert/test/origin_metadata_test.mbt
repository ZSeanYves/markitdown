///|
/// Regression intent:
/// - HTML/DOCX minimal closure should satisfy block+asset provenance invariants
/// - catches accidental decoupling between IR emission and origin metadata wiring
test "origin_metadata/html_docx_minimal_closure" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/html_docx_minimal_closure"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/html")
  ensure_dir(out_dir + "/docx")

  let html_doc = @html.parse_html(
    resolve_sample_path("samples/main_process/html/assets/html_img_single.html"),
    out_dir + "/html",
    6,
  )
  assert_block_origin_alignment(html_doc)
  assert_doc_level_origins(html_doc)
  assert_image_assets_are_indexed(html_doc)
  assert_image_caption_mirrors_asset_origin(html_doc)
  match first_image_block(html_doc) {
    Some(img) => {
      if img.alt_text != Some("single") {
        fail("html single image alt_text should be Some(single)")
      }
      if img.title != None {
        fail("html single image title should be None")
      }
      if img.caption != None {
        fail("html single image caption should be None")
      }
      match img.origin {
        Some(origin) => {
          if origin.object_ref != Some("html:inline-img") {
            fail("html single image origin object_ref should be inline-img")
          }
          if origin.key_path != Some("$.html.asset[img/img_red.jpg]") {
            fail("html single image origin key_path should track source path")
          }
        }
        None => fail("html single image origin should be present")
      }
      assert_asset_origin_has_min_source(html_doc, img.path)
      assert_asset_origin_source_path(
        html_doc,
        img.path,
        Some("img/img_red.jpg"),
      )
    }
    None => fail("expected one html image block")
  }

  let docx_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/golden.docx"),
    out_dir + "/docx",
    6,
  )
  assert_block_origin_alignment(docx_doc)
  assert_doc_level_origins(docx_doc)
  assert_image_assets_are_indexed(docx_doc)
  assert_image_caption_mirrors_asset_origin(docx_doc)
  match first_image_block(docx_doc) {
    Some(img) => {
      if img.alt_text != Some("截屏2026-02-18 15.08.23") {
        fail("docx golden image alt_text should come from wp:docPr descr")
      }
      if img.title != None {
        fail("docx golden image title should be None")
      }
      if img.caption != None {
        fail("docx golden image caption should be None")
      }
      assert_docx_image_origin_present(img, "golden.docx")
      match docx_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => {
          if asset_origin.relationship_id != Some("rId4") {
            fail("docx golden image relationship_id should be rId4")
          }
          if asset_origin.source_path != Some("word/media/image1.png") {
            fail(
              "docx golden image source_path should be word/media/image1.png",
            )
          }
          if asset_origin.nearby_caption != None {
            fail("docx golden image nearby_caption should be None")
          }
        }
        None => fail("docx golden asset origin should exist")
      }
    }
    None => fail("expected one docx image block")
  }
}

///|
/// Regression intent:
/// validates HTML image context mapping boundary:
/// alt/title/figcaption are mapped, while missing fields remain None.
test "image_context/html_alt_title_figcaption" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/image_context_html_alt_title_figcaption"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/html-context")

  let html_alt_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/metadata/html_img_alt_basic.html",
    ),
    out_dir + "/html-context",
    6,
  )
  match first_image_block(html_alt_doc) {
    Some(img) => {
      if img.alt_text != Some("red diagram") {
        fail("html alt image alt_text should be Some(red diagram)")
      }
      if img.title != None {
        fail("html alt image title should be None")
      }
      if img.caption != None {
        fail("html alt image caption should be None")
      }
      match img.origin {
        Some(origin) => {
          if origin.object_ref != Some("html:inline-img") {
            fail("html alt image origin object_ref should be inline-img")
          }
          if origin.key_path != Some("$.html.asset[img/img_red.jpg]") {
            fail("html alt image origin key_path should track source path")
          }
        }
        None => fail("html alt image origin should be present")
      }
      match html_alt_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => {
          if asset_origin.nearby_caption != None {
            fail("html alt sample nearby_caption should be None")
          }
          if asset_origin.source_path != Some("img/img_red.jpg") {
            fail("html alt sample source_path should be img/img_red.jpg")
          }
        }
        None => fail("html alt sample asset origin should exist")
      }
    }
    None => fail("expected one html image block for alt sample")
  }

  let html_title_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/metadata/html_img_title_basic.html",
    ),
    out_dir + "/html-context",
    6,
  )
  match first_image_block(html_title_doc) {
    Some(img) => {
      if img.alt_text != Some("red diagram") {
        fail("html title image alt_text should be Some(red diagram)")
      }
      if img.title != Some("Figure title text") {
        fail("html title image title should be Figure title text")
      }
      if img.caption != None {
        fail("html title image caption should be None")
      }
      match img.origin {
        Some(origin) => {
          if origin.object_ref != Some("html:inline-img") {
            fail("html title image origin object_ref should be inline-img")
          }
          if origin.key_path != Some("$.html.asset[img/img_red.jpg]") {
            fail("html title image origin key_path should track source path")
          }
        }
        None => fail("html title image origin should be present")
      }
      assert_asset_origin_has_min_source(html_title_doc, img.path)
      assert_asset_origin_source_path(
        html_title_doc,
        img.path,
        Some("img/img_red.jpg"),
      )
    }
    None => fail("expected one html image block for title sample")
  }

  let html_fig_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/metadata/html_figure_figcaption_basic.html",
    ),
    out_dir + "/html-context",
    6,
  )
  match first_image_block(html_fig_doc) {
    Some(img) => {
      if img.alt_text != Some("figure image") {
        fail("html figure image alt_text should be Some(figure image)")
      }
      if img.title != Some("Figure title") {
        fail("html figure image title should be Figure title")
      }
      if img.caption != Some("Figure caption text.") {
        fail("html figure image caption should be Figure caption text.")
      }
      match img.origin {
        Some(origin) => {
          if origin.object_ref != Some("html:figure-img") {
            fail("html figure image origin object_ref should be figure-img")
          }
          if origin.key_path != Some("$.html.asset[img/img_red.jpg]") {
            fail("html figure image origin key_path should track source path")
          }
        }
        None => fail("html figure image origin should be present")
      }
      match html_fig_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => {
          if asset_origin.nearby_caption != Some("Figure caption text.") {
            fail("html figure nearby_caption should match figure caption")
          }
          if asset_origin.source_path != Some("img/img_red.jpg") {
            fail("html figure source_path should be img/img_red.jpg")
          }
        }
        None => fail("html figure sample asset origin should exist")
      }
    }
    None => fail("expected one html image block for figure sample")
  }

  let html_missing_alt_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/metadata/html_img_missing_alt_negative.html",
    ),
    out_dir + "/html-context",
    6,
  )
  match first_image_block(html_missing_alt_doc) {
    Some(img) => {
      if img.alt_text != None {
        fail("html missing-alt image alt_text should be None")
      }
      if img.title != None {
        fail("html missing-alt image title should be None")
      }
      if img.caption != None {
        fail("html missing-alt image caption should be None")
      }
      assert_asset_origin_has_min_source(html_missing_alt_doc, img.path)
      assert_asset_origin_source_path(
        html_missing_alt_doc,
        img.path,
        Some("img/img_red.jpg"),
      )
    }
    None => fail("expected one html image block for missing-alt sample")
  }
}

///|
test "image_context/docx_alt_title_and_no_alt" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/image_context_docx_alt_title_and_no_alt"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/docx-alt-title")
  ensure_dir(out_dir + "/docx-no-alt")

  let alt_title_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/metadata/docx_image_alt_title_basic.docx",
    ),
    out_dir + "/docx-alt-title",
    6,
  )
  match first_image_block(alt_title_doc) {
    Some(img) => {
      if img.alt_text != Some("Figure alt text") {
        fail("docx alt-title image alt_text should prefer wp:docPr descr")
      }
      if img.title != Some("Figure title text") {
        fail("docx alt-title image title should prefer wp:docPr title")
      }
      if img.caption != None {
        fail("docx alt-title image caption should be None")
      }
      assert_docx_image_origin_present(img, "docx_image_alt_title_basic.docx")
      match alt_title_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => {
          if asset_origin.relationship_id != Some("rId4") {
            fail("docx alt-title relationship_id should be rId4")
          }
          if asset_origin.source_path != Some("word/media/image1.png") {
            fail("docx alt-title source_path should be word/media/image1.png")
          }
          if asset_origin.nearby_caption != None {
            fail("docx alt-title nearby_caption should be None")
          }
        }
        None => fail("docx alt-title asset origin should exist")
      }
    }
    None => fail("expected one docx image block for alt-title sample")
  }

  let no_alt_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/metadata/docx_image_no_alt_negative.docx",
    ),
    out_dir + "/docx-no-alt",
    6,
  )
  match first_image_block(no_alt_doc) {
    Some(img) => {
      if img.alt_text != Some("image") {
        fail("docx no-alt image should preserve legacy alt fallback")
      }
      if img.title != None {
        fail("docx no-alt image title should be None")
      }
      if img.caption != None {
        fail("docx no-alt image caption should be None")
      }
      assert_docx_image_origin_present(img, "docx_image_no_alt_negative.docx")
      match no_alt_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => {
          if asset_origin.relationship_id != Some("rId4") {
            fail("docx no-alt relationship_id should be rId4")
          }
          if asset_origin.source_path != Some("word/media/image1.png") {
            fail("docx no-alt source_path should be word/media/image1.png")
          }
          if asset_origin.nearby_caption != None {
            fail("docx no-alt nearby_caption should be None")
          }
        }
        None => fail("docx no-alt asset origin should exist")
      }
    }
    None => fail("expected one docx image block for no-alt sample")
  }
}

///|
test "origin_metadata/html_asset_source_path_dedupe_and_remote_downgrade" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/html_asset_source_path_dedupe_and_remote_downgrade"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let input_dir = out_dir + "/input"
  let image_dir = input_dir + "/img"
  let html_out_dir = out_dir + "/html"
  ensure_dir(input_dir)
  ensure_dir(image_dir)
  ensure_dir(html_out_dir)

  let image_bytes = @fs.read_file_to_bytes(
    resolve_sample_path("samples/main_process/html/assets/img/img_red.jpg"),
  ) catch {
    e => fail("read html image sample failed: " + e.to_string())
  }
  @fs.write_bytes_to_file(image_dir + "/img_red.jpg", image_bytes) catch {
    e => fail("write html image sample failed: " + e.to_string())
  }

  let input_path = input_dir + "/dedupe_remote.html"
  write_utf8_text(
    input_path,
    "<p><img src=\"img/img_red.jpg?cache=1#frag\" alt=\"first\"></p>\n" +
    "<p><img src=\"img/img_red.jpg?cache=2\" alt=\"second\"></p>\n" +
    "<p><img src=\"https://example.com/remote.jpg\" alt=\"remote\"></p>\n" +
    "<p><img src=\"data:image/png;base64,AAAA\" alt=\"inline\"></p>\n",
  )

  let doc = @html.parse_html(input_path, html_out_dir, 6)
  assert_block_origin_alignment(doc)
  assert_doc_level_origins(doc)
  assert_image_assets_are_indexed(doc)

  let image_paths : Array[String] = []
  let paragraph_texts : Array[String] = []
  for block in doc.blocks.val {
    match block {
      @cor.Block::ImageBlock(img) => image_paths.push(img.path)
      @cor.Block::Paragraph(text) => paragraph_texts.push(text)
      _ => ()
    }
  }

  if image_paths.length() != 2 {
    fail("expected two emitted html image blocks for duplicated local src")
  }
  if image_paths[0] != image_paths[1] {
    fail("duplicated local html src should reuse the same exported asset path")
  }
  assert_asset_origin_source_path(doc, image_paths[0], Some("img/img_red.jpg"))

  if paragraph_texts.length() != 2 {
    fail("expected two fallback paragraphs for remote/data-uri html images")
  }
  if paragraph_texts[0] != "[remote]" {
    fail("remote html image should degrade to [remote] paragraph")
  }
  if paragraph_texts[1] != "[inline]" {
    fail("data-uri html image should degrade to [inline] paragraph")
  }
}

///|
test "origin_metadata/pptx_xlsx_minimal_closure" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/pptx_xlsx_minimal_closure"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pptx")
  ensure_dir(out_dir + "/xlsx")

  let pptx_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_image_single_caption_like.pptx",
    ),
    out_dir + "/pptx",
    6,
  )
  assert_block_origin_alignment(pptx_doc)
  assert_slide_level_origins(pptx_doc)
  assert_image_assets_are_indexed(pptx_doc)
  assert_image_caption_mirrors_asset_origin(pptx_doc)
  match first_image_block(pptx_doc) {
    Some(img) => {
      if img.alt_text != Some("slide-1-image-1") {
        fail("pptx image alt_text should drop path-like descr values")
      }
      if img.title != None {
        fail("pptx image title should be None")
      }
      if img.caption != Some("Figure 1. Revenue trend") {
        fail("pptx image caption should be Figure 1. Revenue trend")
      }
      match img.origin {
        Some(origin) =>
          if origin.slide != Some(1) {
            fail("pptx image origin slide should be Some(1)")
          }
        None => fail("pptx image origin should exist")
      }
      assert_asset_origin_has_min_source(pptx_doc, img.path)
      match pptx_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => {
          if asset_origin.nearby_caption != Some("Figure 1. Revenue trend") {
            fail("pptx nearby_caption should match figure caption")
          }
          if asset_origin.relationship_id != Some("rId2") {
            fail("pptx relationship_id should be rId2")
          }
          if asset_origin.source_path != Some("ppt/media/image1.png") {
            fail("pptx source_path should be ppt/media/image1.png")
          }
        }
        None => fail("pptx asset origin should exist")
      }
    }
    None => fail("expected one pptx image block")
  }

  let xlsx_doc = @xlsx.parse_xlsx(
    resolve_sample_path("samples/main_process/xlsx/sheet_simple.xlsx"),
    out_dir + "/xlsx",
    6,
  )
  assert_block_origin_alignment(xlsx_doc)
  assert_sheet_level_origins(xlsx_doc)
  match xlsx_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      if table.header_rows != 1 {
        fail("xlsx should keep header_rows=1 explicit table semantics")
      }
    _ => fail("xlsx should emit RichTable for sheet tables")
  }
}

///|
test "metadata_sidecar/document_properties_ooxml_and_non_ooxml" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/metadata_sidecar_document_properties"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/docx")
  ensure_dir(out_dir + "/pptx")
  ensure_dir(out_dir + "/xlsx")
  ensure_dir(out_dir + "/html")

  let docx_path = resolve_sample_path("samples/main_process/docx/golden.docx")
  let docx_doc = @doc.parse_docx(docx_path, out_dir + "/docx", 6)
  let docx_json = @cor.emit_metadata_json_with_document_properties(
    docx_doc,
    "golden.docx",
    "docx",
    "golden.md",
    read_ooxml_metadata_document_properties(docx_path),
  )
  assert_metadata_has_document_object(docx_json, "docx")

  let pptx_path = resolve_sample_path(
    "samples/main_process/pptx/metadata/pptx_image_single_caption_like.pptx",
  )
  let pptx_doc = @pptx.parse_pptx(pptx_path, out_dir + "/pptx", 6)
  let pptx_json = @cor.emit_metadata_json_with_document_properties(
    pptx_doc,
    "pptx_image_single_caption_like.pptx",
    "pptx",
    "pptx_image_single_caption_like.md",
    read_ooxml_metadata_document_properties(pptx_path),
  )
  assert_metadata_has_document_object(pptx_json, "pptx")

  let xlsx_path = resolve_sample_path(
    "samples/main_process/xlsx/sheet_simple.xlsx",
  )
  let xlsx_doc = @xlsx.parse_xlsx(xlsx_path, out_dir + "/xlsx", 6)
  let xlsx_json = @cor.emit_metadata_json_with_document_properties(
    xlsx_doc,
    "sheet_simple.xlsx",
    "xlsx",
    "sheet_simple.md",
    read_ooxml_metadata_document_properties(xlsx_path),
  )
  assert_metadata_has_document_object(xlsx_json, "xlsx")
  if !xlsx_json.contains("\"table\": {") {
    fail("xlsx metadata should expose table payload for RichTable blocks")
  }
  if !xlsx_json.contains("\"header_rows\": 1") {
    fail("xlsx metadata should keep explicit header_rows")
  }

  let missing_docprops_path = resolve_sample_path(
    "samples/main_process/docx/docx_blockquote_basic.docx",
  )
  let missing_docprops_doc = @doc.parse_docx(
    missing_docprops_path,
    out_dir + "/docx",
    6,
  )
  let missing_docprops_json = @cor.emit_metadata_json_with_document_properties(
    missing_docprops_doc,
    "docx_blockquote_basic.docx",
    "docx",
    "docx_blockquote_basic.md",
    read_ooxml_metadata_document_properties(missing_docprops_path),
  )
  assert_metadata_has_document_object(missing_docprops_json, "docx")

  let html_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/metadata/html_img_alt_basic.html",
    ),
    out_dir + "/html",
    6,
  )
  let html_json = @cor.emit_metadata_json(
    html_doc, "html_img_alt_basic.html", "html", "html_img_alt_basic.md",
  )
  if !html_json.contains("\"document\": null") {
    fail("non-OOXML metadata should keep document null")
  }

  let csv_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_basic.csv"),
    "",
    6,
  )
  let csv_json = @cor.emit_metadata_json(
    csv_doc, "csv_basic.csv", "csv", "csv_basic.md",
  )
  if !csv_json.contains("\"format\": \"csv\"") {
    fail("csv metadata should contain csv format")
  }
  if !csv_json.contains("\"source_name\": \"csv_basic.csv\"") {
    fail("csv metadata should contain source_name")
  }
  if !csv_json.contains("\"block_count\": 1") {
    fail("csv metadata should contain one table block")
  }
  if !csv_json.contains("\"asset_count\": 0") {
    fail("csv metadata should contain zero assets")
  }
  if !csv_json.contains("\"document\": null") {
    fail("csv metadata should keep document null")
  }
  if !csv_json.contains("\"table\": {") {
    fail("csv metadata should expose table payload for RichTable blocks")
  }
  if !csv_json.contains("\"header_rows\": 1") {
    fail("csv metadata should keep explicit header_rows")
  }

  let json_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_object_basic.json"),
    "",
    6,
  )
  let json_json = @cor.emit_metadata_json(
    json_doc, "json_object_basic.json", "json", "json_object_basic.md",
  )
  if !json_json.contains("\"format\": \"json\"") {
    fail("json metadata should contain json format")
  }
  if !json_json.contains("\"source_name\": \"json_object_basic.json\"") {
    fail("json metadata should contain source_name")
  }
  if !json_json.contains("\"block_count\": 1") {
    fail("json metadata should contain one block")
  }
  if !json_json.contains("\"asset_count\": 0") {
    fail("json metadata should contain zero assets")
  }
  if !json_json.contains("\"document\": null") {
    fail("json metadata should keep document null")
  }
  if !json_json.contains("\"table\": {") {
    fail("json metadata should expose table payload for RichTable blocks")
  }
  if !json_json.contains("\"header_rows\": 1") {
    fail("json metadata should keep explicit header_rows")
  }

  let yaml_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_mapping_basic.yaml"),
    "",
    6,
  )
  let yaml_json = @cor.emit_metadata_json(
    yaml_doc, "yaml_mapping_basic.yaml", "yaml", "yaml_mapping_basic.md",
  )
  if !yaml_json.contains("\"format\": \"yaml\"") {
    fail("yaml metadata should contain yaml format")
  }
  if !yaml_json.contains("\"source_name\": \"yaml_mapping_basic.yaml\"") {
    fail("yaml metadata should contain source_name")
  }
  if !yaml_json.contains("\"block_count\": 1") {
    fail("yaml metadata should contain one block")
  }
  if !yaml_json.contains("\"asset_count\": 0") {
    fail("yaml metadata should contain zero assets")
  }
  if !yaml_json.contains("\"document\": null") {
    fail("yaml metadata should keep document null")
  }
  let yaml_metadata_basic_doc = @yaml.parse_yaml(
    resolve_sample_path(
      "samples/main_process/yaml/metadata/yaml_metadata_basic.yaml",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      yaml_metadata_basic_doc, "yaml_metadata_basic.yaml", "yaml", "yaml_metadata_basic.md",
    ),
    "yaml_metadata_basic.metadata.json",
  )
  let yaml_metadata_table_doc = @yaml.parse_yaml(
    resolve_sample_path(
      "samples/main_process/yaml/metadata/yaml_metadata_table.yaml",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      yaml_metadata_table_doc, "yaml_metadata_table.yaml", "yaml", "yaml_metadata_table.md",
    ),
    "yaml_metadata_table.metadata.json",
  )
  let yaml_metadata_nested_doc = @yaml.parse_yaml(
    resolve_sample_path(
      "samples/main_process/yaml/metadata/yaml_metadata_nested.yaml",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      yaml_metadata_nested_doc, "yaml_metadata_nested.yaml", "yaml", "yaml_metadata_nested.md",
    ),
    "yaml_metadata_nested.metadata.json",
  )

  let yml_path = resolve_sample_path(
    "samples/main_process/yaml/yml_extension_basic.yml",
  )
  let yml_doc = @yaml.parse_yaml(yml_path, "", 6)
  let yml_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/yaml/expected/yml_extension_basic.md",
    ),
  )
  if @cor.emit_markdown(yml_doc) != yml_expected {
    fail("yaml .yml extension should preserve deterministic markdown output")
  }

  let markdown_path = resolve_sample_path(
    "samples/main_process/markdown/markdown_basic_heading_paragraph.md",
  )
  let markdown_doc = @md.parse_markdown(markdown_path, "", 6)
  let markdown_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_basic_heading_paragraph.md",
    ),
  )
  if @cor.emit_markdown(markdown_doc) != markdown_expected {
    fail("markdown dispatcher output should preserve original markdown body")
  }
  let markdown_json = @cor.emit_metadata_json(
    markdown_doc, "markdown_basic_heading_paragraph.md", "markdown", "markdown_basic_heading_paragraph.md",
  )
  if !markdown_json.contains("\"format\": \"markdown\"") {
    fail("markdown metadata should contain markdown format")
  }
  if !markdown_json.contains(
      "\"source_name\": \"markdown_basic_heading_paragraph.md\"",
    ) {
    fail("markdown metadata should contain source_name")
  }
  if !markdown_json.contains("\"block_count\": 2") {
    fail("markdown metadata should contain conservative block_count=2")
  }
  if !markdown_json.contains("\"asset_count\": 0") {
    fail("markdown metadata should contain zero assets")
  }
  if !markdown_json.contains("\"document\": null") {
    fail("markdown metadata should keep document null")
  }

  let txt_doc = @txt.parse_txt(
    resolve_sample_path("samples/main_process/txt/txt_paragraphs.txt"),
    "",
    6,
  )
  let txt_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/txt/expected/txt_paragraphs.md"),
  )
  if @cor.emit_markdown(txt_doc) != txt_expected {
    fail("txt output should preserve paragraph-only plain-text semantics")
  }
  let txt_json = @cor.emit_metadata_json(
    txt_doc, "txt_paragraphs.txt", "txt", "txt_paragraphs.md",
  )
  if !txt_json.contains("\"format\": \"txt\"") {
    fail("txt metadata should contain txt format")
  }
  if !txt_json.contains("\"source_name\": \"txt_paragraphs.txt\"") {
    fail("txt metadata should contain source_name")
  }
  if !txt_json.contains("\"block_count\": 2") {
    fail("txt metadata should contain two paragraph blocks")
  }
  if !txt_json.contains("\"asset_count\": 0") {
    fail("txt metadata should contain zero assets")
  }
  if !txt_json.contains("\"document\": null") {
    fail("txt metadata should keep document null")
  }

  let txt_literal_doc = @txt.parse_txt(
    resolve_sample_path(
      "samples/main_process/txt/txt_markdown_like_literal.txt",
    ),
    "",
    6,
  )
  let txt_literal_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/txt/expected/txt_markdown_like_literal.md",
    ),
  )
  if @cor.emit_markdown(txt_literal_doc) != txt_literal_expected {
    fail("txt markdown-like literals should stay escaped in markdown output")
  }

  let xml_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_basic.xml"),
    "",
    6,
  )
  let xml_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_basic.md"),
  )
  if @cor.emit_markdown(xml_doc) != xml_expected {
    fail("xml output should preserve source as fenced xml markdown")
  }
  let xml_json = @cor.emit_metadata_json(
    xml_doc, "xml_basic.xml", "xml", "xml_basic.md",
  )
  if !xml_json.contains("\"format\": \"xml\"") {
    fail("xml metadata should contain xml format")
  }
  if !xml_json.contains("\"source_name\": \"xml_basic.xml\"") {
    fail("xml metadata should contain source_name")
  }
  if !xml_json.contains("\"block_count\": 2") {
    fail("xml metadata should contain structured heading and list blocks")
  }
  if !xml_json.contains("\"asset_count\": 0") {
    fail("xml metadata should contain zero assets")
  }
  if !xml_json.contains("\"document\": null") {
    fail("xml metadata should keep document null")
  }

  let frontmatter_path = resolve_sample_path(
    "samples/main_process/markdown/markdown_frontmatter_passthrough.markdown",
  )
  let frontmatter_doc = @md.parse_markdown(frontmatter_path, "", 6)
  let frontmatter_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_frontmatter_passthrough.md",
    ),
  )
  if @cor.emit_markdown(frontmatter_doc) != frontmatter_expected {
    fail("markdown .markdown extension should preserve frontmatter sample")
  }

  let markdown_bom_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_bom_utf8.md"),
    "",
    6,
  )
  let markdown_bom_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_bom_utf8.md",
    ),
  )
  if @cor.emit_markdown(markdown_bom_doc) != markdown_bom_expected {
    fail("markdown should strip utf8 bom from passthrough output")
  }

  let markdown_crlf_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_crlf.md"),
    "",
    6,
  )
  let markdown_crlf_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_crlf.md",
    ),
  )
  if @cor.emit_markdown(markdown_crlf_doc) != markdown_crlf_expected {
    fail("markdown should normalize crlf input to stable newline output")
  }
}
