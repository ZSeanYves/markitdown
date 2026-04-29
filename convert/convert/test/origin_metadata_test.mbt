///|
/// Cross-format provenance/metadata regression suite.
///
/// Why this suite exists:
/// - validates unified IR lightweight provenance contract
/// - guards metadata-sidecar image context mirrors (caption vs nearby_caption)
/// - checks asset indexing invariants shared by main_process / metadata / assets chains
/// 已做了内容删除，在测试结束后不会保留内容，但会残留测试目录
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
/// 递归删除目录；目录不存在时直接返回。
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
/// 重新创建一个干净目录。
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  @fs.create_dir(path)
}

///|
/// defer 用的清理函数：吞掉删除错误，保证自己不 raise。
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
fn read_ooxml_metadata_document_properties(
  path : String,
) -> @cor.MetadataDocumentProperties? raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read OOXML sample failed: " + e.to_string())
  }
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open OOXML sample failed: " + e.to_string())
  }
  let core = @ox.read_core_properties(pkg)
  let app = @ox.read_app_properties(pkg)

  Some(
    @cor.metadata_document_properties(
      core.title,
      core.subject,
      core.creator,
      core.description,
      core.keywords,
      core.created,
      core.modified,
      app.application,
      app.pages,
      app.words,
      app.slides,
      app.sheets,
    ),
  )
}

///|
fn assert_metadata_has_document_object(
  json : String,
  format : String,
) -> Unit raise {
  if !json.contains("\"format\": \"" + format + "\"") {
    fail("metadata should contain format: " + format)
  }
  if !json.contains("\"document\": {") {
    fail("metadata should contain document object for: " + format)
  }
  if !json.contains("\"application\"") {
    fail("metadata document should contain application field: " + format)
  }
}

///|
/// Guard rail for the main_process chain:
/// every emitted block must have a same-index origin slot (Some/None allowed).
fn assert_block_origin_alignment(doc : @cor.Document) -> Unit raise {
  if doc.blocks.val.length() != doc.block_origins.val.length() {
    fail(
      "block/origin length mismatch: blocks=" +
      doc.blocks.val.length().to_string() +
      " origins=" +
      doc.block_origins.val.length().to_string(),
    )
  }
}

///|
/// Guard rail for assets chain:
/// every emitted image block must be discoverable from asset_origins.
fn assert_image_assets_are_indexed(doc : @cor.Document) -> Unit raise {
  for b in doc.blocks.val {
    match b {
      @cor.Block::Image(_, path) =>
        if !doc.asset_origins.val.contains(path) {
          fail("missing asset origin for image path: " + path)
        }
      @cor.Block::ImageBlock(img) =>
        if !doc.asset_origins.val.contains(img.path) {
          fail("missing asset origin for image path: " + img.path)
        }
      _ => ()
    }
  }
}

///|
fn first_image_block(doc : @cor.Document) -> @cor.ImageData? {
  for b in doc.blocks.val {
    match b {
      @cor.Block::ImageBlock(img) => return Some(img)
      _ => ()
    }
  }
  None
}

///|
fn assert_asset_origin_has_min_source(
  doc : @cor.Document,
  path : String,
) -> Unit raise {
  match doc.asset_origins.val.get(path) {
    None => fail("missing asset origin for path: " + path)
    Some(origin) =>
      match origin.source_name {
        Some(_) => ()
        None => fail("asset origin source_name should be present: " + path)
      }
  }
}

///|
/// Guard rail for metadata chain:
/// ImageData.caption should mirror asset nearby_caption when pairing is made.
fn assert_image_caption_mirrors_asset_origin(doc : @cor.Document) -> Unit raise {
  for b in doc.blocks.val {
    match b {
      @cor.Block::ImageBlock(img) =>
        match doc.asset_origins.val.get(img.path) {
          Some(asset_origin) =>
            if asset_origin.nearby_caption != img.caption {
              fail("asset nearby_caption should mirror image caption")
            }
          None => fail("missing asset origin for image path: " + img.path)
        }
      _ => ()
    }
  }
}

///|
fn assert_doc_level_origins(doc : @cor.Document) -> Unit raise {
  for i in 0..<doc.block_origins.val.length() {
    match doc.block_origins.val[i] {
      None => fail("block origin should not be None at index: " + i.to_string())
      Some(origin) => {
        match origin.source_name {
          Some(_) => ()
          None =>
            fail("source_name should be present at index: " + i.to_string())
        }
        match origin.block_index {
          Some(_) => ()
          None =>
            fail("block_index should be present at index: " + i.to_string())
        }
      }
    }
  }
}

///|
fn assert_slide_level_origins(doc : @cor.Document) -> Unit raise {
  let mut has_slide_origin = false
  for i in 0..<doc.block_origins.val.length() {
    match doc.block_origins.val[i] {
      None => fail("block origin should not be None at index: " + i.to_string())
      Some(origin) => {
        match origin.slide {
          Some(_) => has_slide_origin = true
          None => fail("slide should be present at index: " + i.to_string())
        }
        match origin.block_index {
          Some(_) => ()
          None =>
            fail("block_index should be present at index: " + i.to_string())
        }
      }
    }
  }
  if !has_slide_origin {
    fail("expected at least one slide-level origin")
  }
}

///|
fn assert_sheet_level_origins(doc : @cor.Document) -> Unit raise {
  let mut has_sheet_origin = false
  for i in 0..<doc.block_origins.val.length() {
    match doc.block_origins.val[i] {
      None => fail("block origin should not be None at index: " + i.to_string())
      Some(origin) => {
        match origin.sheet {
          Some(_) => has_sheet_origin = true
          None => fail("sheet should be present at index: " + i.to_string())
        }
        match origin.block_index {
          Some(_) => ()
          None =>
            fail("block_index should be present at index: " + i.to_string())
        }
      }
    }
  }
  if !has_sheet_origin {
    fail("expected at least one sheet-level origin")
  }
}

///|
fn assert_page_level_origins(doc : @cor.Document) -> Unit raise {
  let mut has_page_origin = false
  for i in 0..<doc.block_origins.val.length() {
    match doc.block_origins.val[i] {
      None => fail("block origin should not be None at index: " + i.to_string())
      Some(origin) => {
        match origin.page {
          Some(_) => has_page_origin = true
          None => fail("page should be present at index: " + i.to_string())
        }
        match origin.block_index {
          Some(_) => ()
          None =>
            fail("block_index should be present at index: " + i.to_string())
        }
      }
    }
  }
  if !has_page_origin {
    fail("expected at least one page-level origin")
  }
}

///|
/// Regression intent:
/// - HTML/DOCX minimal closure should satisfy block+asset provenance invariants
/// - catches accidental decoupling between IR emission and origin metadata wiring
test "origin_metadata/html_docx_minimal_closure" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/html_docx_minimal_closure"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/html")
  ensure_dir(out_dir + "/docx")

  let html_doc = @html.parse_html(
    resolve_sample_path("samples/assets/html/html_img_single.html"),
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
      if img.origin != None {
        fail("html single image origin should be None")
      }
      assert_asset_origin_has_min_source(html_doc, img.path)
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
}

///|
/// Regression intent:
/// validates HTML image context mapping boundary:
/// alt/title/figcaption are mapped, while missing fields remain None.
test "image_context/html_alt_title_figcaption" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/image_context_html_alt_title_figcaption"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/html-context")

  let html_alt_doc = @html.parse_html(
    resolve_sample_path("samples/metadata/html/html_img_alt_basic.html"),
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
      if img.origin != None {
        fail("html figure image origin should be None")
      }
      match html_alt_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) =>
          if asset_origin.nearby_caption != None {
            fail("html alt sample nearby_caption should be None")
          }
        None => fail("html alt sample asset origin should exist")
      }
    }
    None => fail("expected one html image block for alt sample")
  }

  let html_title_doc = @html.parse_html(
    resolve_sample_path("samples/metadata/html/html_img_title_basic.html"),
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
      if img.origin != None {
        fail("html title image origin should be None")
      }
      assert_asset_origin_has_min_source(html_title_doc, img.path)
    }
    None => fail("expected one html image block for title sample")
  }

  let html_fig_doc = @html.parse_html(
    resolve_sample_path(
      "samples/metadata/html/html_figure_figcaption_basic.html",
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
      if img.origin != None {
        fail("html figure image origin should be None")
      }
      match html_fig_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) =>
          if asset_origin.nearby_caption != Some("Figure caption text.") {
            fail("html figure nearby_caption should match figure caption")
          }
        None => fail("html figure sample asset origin should exist")
      }
    }
    None => fail("expected one html image block for figure sample")
  }

  let html_missing_alt_doc = @html.parse_html(
    resolve_sample_path(
      "samples/metadata/html/html_img_missing_alt_negative.html",
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
    }
    None => fail("expected one html image block for missing-alt sample")
  }
}

///|
test "origin_metadata/pptx_xlsx_minimal_closure" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/pptx_xlsx_minimal_closure"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pptx")
  ensure_dir(out_dir + "/xlsx")

  let pptx_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/metadata/pptx/pptx_image_single_caption_like.pptx",
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
        fail("pptx image alt_text should be Some(slide-1-image-1)")
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
        Some(asset_origin) =>
          if asset_origin.nearby_caption != Some("Figure 1. Revenue trend") {
            fail("pptx nearby_caption should match figure caption")
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
}

///|
test "metadata_sidecar/document_properties_ooxml_and_non_ooxml" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

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
    "samples/metadata/pptx/pptx_image_single_caption_like.pptx",
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
    resolve_sample_path("samples/metadata/html/html_img_alt_basic.html"),
    out_dir + "/html",
    6,
  )
  let html_json = @cor.emit_metadata_json(
    html_doc, "html_img_alt_basic.html", "html", "html_img_alt_basic.md",
  )
  if !html_json.contains("\"document\": null") {
    fail("non-OOXML metadata should keep document null")
  }
}

///|
async test "origin_metadata/pdf_minimal_closure" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/pdf_minimal_closure"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pdf")

  let pdf_doc = @pdf.parse_pdf(
    resolve_sample_path("samples/assets/pdf/pdf_image_xobject.pdf"),
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
test "image_context/pptx_caption_association" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/image_context_pptx_caption_association"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pptx-image-context")

  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/metadata/pptx/pptx_image_single_caption_like.pptx",
    ),
    out_dir + "/pptx-image-context",
    6,
  )
  match first_image_block(doc) {
    Some(img) => {
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
async test "image_context/pdf_caption_like" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/image_context_pdf_caption_like"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pdf-context")

  let single_caption_doc = @pdf.parse_pdf(
    resolve_sample_path(
      "samples/metadata/pdf/pdf_image_single_caption_like.pdf",
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
      "samples/metadata/pdf/pdf_image_no_caption_negative.pdf",
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
