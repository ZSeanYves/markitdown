///|
/// Media-focused origin/metadata regressions split from the all-format suite.
async test "origin_metadata/pdf_minimal_closure" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/pdf_minimal_closure"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pdf")

  let pdf_doc = @pdf.parse_pdf(
    resolve_sample_path("samples/main_process/pdf/assets/pdf_image_xobject.pdf"),
    out_dir + "/pdf",
    6,
    None,
    false,
    false,
    false,
  )
  assert_block_origin_alignment(pdf_doc)
  assert_page_level_origins(pdf_doc)
  assert_image_assets_are_indexed(pdf_doc)
  assert_image_caption_mirrors_asset_origin(pdf_doc)
  match first_image_block(pdf_doc) {
    Some(img) => {
      if img.title != None {
        fail("pdf image title should be None")
      }
      if img.caption != None {
        fail("pdf image caption should be None")
      }
      match img.origin {
        Some(origin) =>
          if origin.page != Some(1) {
            fail("pdf image origin page should be Some(1)")
          }
        None => fail("pdf image origin should exist")
      }
      assert_asset_origin_has_min_source(pdf_doc, img.path)
    }
    None => fail("expected one pdf image block")
  }
}

///|
async test "origin_metadata/pdf_uri_annotation_links_are_indexed" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/pdf_uri_annotation_links_are_indexed"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pdf")

  let doc = @pdf.parse_pdf(
    resolve_sample_path(
      "samples/main_process/pdf/metadata/pdf_metadata_uri_link.pdf",
    ),
    out_dir + "/pdf",
    6,
    None,
    false,
    false,
    false,
  )
  let markdown = @cor.emit_markdown(doc)
  if !markdown.contains(
      "[Visit the example website for details.](https://example.com)",
    ) {
    fail("pdf URI annotation sample should keep Markdown link output")
  }

  let json = @cor.emit_metadata_json(
    doc, "pdf_metadata_uri_link.pdf", "pdf", "pdf_metadata_uri_link.md",
  )
  if !json.contains("\"link_count\": 1") {
    fail("pdf metadata should count the URI annotation link")
  }
  if !json.contains("\"source_kind\": \"pdf_uri_annotation\"") {
    fail("pdf metadata should classify URI annotation link source")
  }
  if !json.contains("\"inline_index\": 0") {
    fail("pdf full-block URI annotation link should keep inline index")
  }
  if !json.contains("\"url\": \"https://example.com\"") {
    fail("pdf metadata should keep URI annotation target")
  }
  if !json.contains("\"page\": 1") {
    fail("pdf URI annotation link should retain page provenance")
  }
}

///|
test "image_context/pptx_caption_association" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/image_context_pptx_caption_association"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pptx-image-context")

  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_image_single_caption_like.pptx",
    ),
    out_dir + "/pptx-image-context",
    6,
  )
  match first_image_block(doc) {
    Some(img) => {
      if img.alt_text != Some("slide-1-image-1") {
        fail(
          "pptx caption-like image alt_text should drop path-like descr values",
        )
      }
      if img.title != None {
        fail("pptx caption-like image title should be None")
      }
      if img.caption != Some("Figure 1. Revenue trend") {
        fail(
          "pptx caption-like image caption should be Figure 1. Revenue trend",
        )
      }
      match img.origin {
        Some(origin) =>
          if origin.slide != Some(1) {
            fail("pptx caption-like image origin slide should be Some(1)")
          }
        None => fail("pptx image origin should exist")
      }
      match doc.asset_origins.val.get(img.path) {
        Some(asset_origin) =>
          if asset_origin.nearby_caption != Some("Figure 1. Revenue trend") {
            fail("pptx caption-like nearby_caption should match figure caption")
          }
        None => fail("pptx image asset origin should exist")
      }
    }
    None => fail("expected one pptx image block")
  }
}

///|
test "image_context/pptx_alt_title_and_no_alt" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/image_context_pptx_alt_title_and_no_alt"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pptx-alt-title")
  ensure_dir(out_dir + "/pptx-no-alt")

  let alt_title_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_image_alt_title_basic.pptx",
    ),
    out_dir + "/pptx-alt-title",
    6,
  )
  match first_image_block(alt_title_doc) {
    Some(img) => {
      if img.alt_text != Some("Figure alt text") {
        fail("pptx alt-title image alt_text should prefer p:cNvPr descr")
      }
      if img.title != Some("Figure title text") {
        fail("pptx alt-title image title should prefer p:cNvPr title")
      }
      if img.caption != None {
        fail("pptx alt-title image caption should be None")
      }
      match alt_title_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => {
          if asset_origin.relationship_id != Some("rId2") {
            fail("pptx alt-title relationship_id should be rId2")
          }
          if asset_origin.source_path != Some("ppt/media/image1.png") {
            fail("pptx alt-title source_path should be ppt/media/image1.png")
          }
          if asset_origin.nearby_caption != None {
            fail("pptx alt-title nearby_caption should be None")
          }
        }
        None => fail("pptx alt-title asset origin should exist")
      }
    }
    None => fail("expected one pptx image block for alt-title sample")
  }

  let no_alt_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_image_no_alt_negative.pptx",
    ),
    out_dir + "/pptx-no-alt",
    6,
  )
  match first_image_block(no_alt_doc) {
    Some(img) => {
      if img.alt_text != Some("slide-1-image-1") {
        fail("pptx no-alt image should fall back to synthetic alt")
      }
      if img.title != None {
        fail("pptx no-alt image title should be None")
      }
      if img.caption != None {
        fail("pptx no-alt image caption should be None")
      }
      match no_alt_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => {
          if asset_origin.relationship_id != Some("rId2") {
            fail("pptx no-alt relationship_id should be rId2")
          }
          if asset_origin.source_path != Some("ppt/media/image1.png") {
            fail("pptx no-alt source_path should be ppt/media/image1.png")
          }
          if asset_origin.nearby_caption != None {
            fail("pptx no-alt nearby_caption should be None")
          }
        }
        None => fail("pptx no-alt asset origin should exist")
      }
    }
    None => fail("expected one pptx image block for no-alt sample")
  }
}

///|
async test "image_context/pdf_caption_like" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/image_context_pdf_caption_like"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pdf-context")

  let single_caption_doc = @pdf.parse_pdf(
    resolve_sample_path(
      "samples/main_process/pdf/metadata/pdf_image_single_caption_like.pdf",
    ),
    out_dir + "/pdf-context",
    6,
    None,
    false,
    false,
    false,
  )
  match first_image_block(single_caption_doc) {
    Some(img) => {
      if img.caption != Some("Figure 1. PDF caption") {
        fail("pdf single-caption image caption should be Figure 1. PDF caption")
      }
      match img.origin {
        Some(origin) =>
          if origin.page != Some(1) {
            fail("pdf no-caption image origin page should be Some(1)")
          }
        None => fail("pdf single-caption image origin should exist")
      }
      match single_caption_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) =>
          if asset_origin.nearby_caption != Some("Figure 1. PDF caption") {
            fail(
              "pdf single-caption nearby_caption should be Figure 1. PDF caption",
            )
          }
        None => fail("pdf single-caption asset origin should exist")
      }
    }
    None => fail("expected one image block for pdf caption sample")
  }

  let no_caption_doc = @pdf.parse_pdf(
    resolve_sample_path(
      "samples/main_process/pdf/metadata/pdf_image_no_caption_negative.pdf",
    ),
    out_dir + "/pdf-context",
    6,
    None,
    false,
    false,
    false,
  )
  match first_image_block(no_caption_doc) {
    Some(img) => {
      if img.caption != None {
        fail("pdf no-caption image caption should be None")
      }
      match img.origin {
        Some(origin) =>
          if origin.page != Some(1) {
            fail("pdf no-caption image origin page should be Some(1)")
          }
        None => fail("pdf no-caption image origin should exist")
      }
      match no_caption_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) =>
          if asset_origin.nearby_caption != None {
            fail("pdf no-caption nearby_caption should be None")
          }
        None => fail("pdf no-caption asset origin should exist")
      }
    }
    None => fail("expected one image block for pdf no-caption sample")
  }
}

///|
async test "origin_metadata/pdf_conservative_table_first_pass" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/pdf_conservative_table_first_pass"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pdf")
  let input = out_dir + "/pdf/simple_table.pdf"
  write_metadata_simple_table_pdf(input)

  let doc = @pdf.parse_pdf(
    input,
    out_dir + "/pdf",
    6,
    None,
    false,
    false,
    false,
  )

  let mut saw_table = false
  let mut table_block_index = -1
  for i = 0; i < doc.blocks.val.length(); i = i + 1 {
    match doc.blocks.val[i] {
      @cor.Block::RichTable(table) => {
        saw_table = true
        table_block_index = i
        if table.header_rows != 1 {
          fail("pdf conservative table sample should keep header_rows=1")
        }
        if table.rows.length() != 3 {
          fail("pdf conservative table sample should keep 3 rows")
        }
      }
      _ => ()
    }
  }
  if !saw_table {
    fail("pdf conservative table sample should emit RichTable")
  }

  let origin = block_origin_at(doc, table_block_index)
  if origin.page != Some(1) {
    fail("pdf conservative table origin page should be Some(1)")
  }
  if origin.line_start == None || origin.line_end == None {
    fail("pdf conservative table origin should keep line_start/line_end")
  }

  let pdf_json = @cor.emit_metadata_json(
    doc, "simple_table.pdf", "pdf", "simple_table.md",
  )
  if !pdf_json.contains("\"table\": {") {
    fail("pdf metadata should expose table payload for RichTable blocks")
  }
  if !pdf_json.contains("\"header_rows\": 1") {
    fail("pdf metadata should keep explicit header_rows")
  }
}

///|
async test "origin_metadata/pdf_headerless_numeric_table_second_pass" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/pdf_headerless_numeric_table_second_pass"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pdf")
  let input = out_dir + "/pdf/headerless_numeric_table.pdf"
  write_metadata_headerless_numeric_table_pdf(input)

  let doc = @pdf.parse_pdf(
    input,
    out_dir + "/pdf",
    6,
    None,
    false,
    false,
    false,
  )

  let mut saw_table = false
  let mut table_block_index = -1
  for i = 0; i < doc.blocks.val.length(); i = i + 1 {
    match doc.blocks.val[i] {
      @cor.Block::RichTable(table) => {
        saw_table = true
        table_block_index = i
        if table.header_rows != 0 {
          fail("pdf headerless numeric table should keep header_rows=0")
        }
        if table.rows.length() != 3 {
          fail("pdf headerless numeric table should keep 3 rows")
        }
      }
      _ => ()
    }
  }
  if !saw_table {
    fail("pdf headerless numeric table should emit RichTable")
  }

  let origin = block_origin_at(doc, table_block_index)
  if origin.page != Some(1) {
    fail("pdf headerless numeric table origin page should be Some(1)")
  }
  if origin.line_start == None || origin.line_end == None {
    fail("pdf headerless numeric table origin should keep line_start/line_end")
  }

  let pdf_json = @cor.emit_metadata_json(
    doc, "headerless_numeric_table.pdf", "pdf", "headerless_numeric_table.md",
  )
  if !pdf_json.contains("\"table\": {") {
    fail("pdf headerless table metadata should expose table payload")
  }
  if !pdf_json.contains("\"header_rows\": 0") {
    fail("pdf headerless table metadata should keep header_rows=0")
  }
}
