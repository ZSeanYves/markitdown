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
fn read_utf8_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @cor.utf8_bytes_to_string(bytes) catch {
    e => fail("utf8 decode failed: " + e.to_string())
  }
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }

  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }

    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }

  ignore(flush(part, current))
}

///|
fn test_tmp_root() -> String {
  match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
}

///|
fn ensure_test_tmp_root() -> Unit raise {
  ensure_dir_tree(test_tmp_root())
}

///|
fn origin_tmp_root() -> String raise {
  ensure_test_tmp_root()
  let dir = test_tmp_root() + "/origin"
  ensure_dir(dir)
  dir
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
fn read_epub_metadata_document_properties(
  path : String,
) -> @cor.MetadataDocumentProperties? raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read EPUB sample failed: " + e.to_string())
  }
  let pkg = @epubpkg.open_epub_package(bytes, @cor.basename(path)) catch {
    e => fail("open EPUB sample failed: " + e.to_string())
  }
  let meta = pkg.metadata

  Some(
    @cor.metadata_document_properties(
      meta.title,
      None,
      meta.creator,
      None,
      None,
      meta.date,
      meta.modified,
      Some("EPUB"),
      None,
      None,
      None,
      None,
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
fn assert_asset_origin_source_path(
  doc : @cor.Document,
  path : String,
  expected : String?,
) -> Unit raise {
  fn show_string_opt(value : String?) -> String {
    match value {
      Some(v) => "Some(" + v + ")"
      None => "None"
    }
  }

  match doc.asset_origins.val.get(path) {
    None => fail("missing asset origin for path: " + path)
    Some(origin) =>
      if origin.source_path != expected {
        fail(
          "unexpected asset origin source_path for " +
          path +
          ": " +
          show_string_opt(origin.source_path) +
          " != " +
          show_string_opt(expected),
        )
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
fn block_origin_at(doc : @cor.Document, index : Int) -> @cor.Origin raise {
  match doc.block_origins.val[index] {
    Some(origin) => origin
    None => fail("expected block origin at index: " + index.to_string())
  }
}

///|
fn assert_metadata_snapshot(
  actual : String,
  expected_name : String,
) -> Unit raise {
  let expected = read_utf8_text(
    resolve_sample_path("samples/test/metadata/" + expected_name),
  )
  assert_eq(
    trim_one_trailing_newline(actual),
    trim_one_trailing_newline(expected),
  )
}

///|
fn trim_one_trailing_newline(text : String) -> String {
  if text.has_suffix("\n") {
    text[:text.length() - 1].to_owned()
  } else {
    text
  }
}

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
      if img.origin != None {
        fail("docx golden image origin should be None")
      }
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
    resolve_sample_path("samples/metadata/docx/docx_image_alt_title_basic.docx"),
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
      if img.origin != None {
        fail("docx alt-title image origin should be None")
      }
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
    resolve_sample_path("samples/metadata/docx/docx_image_no_alt_negative.docx"),
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
      if img.origin != None {
        fail("docx no-alt image origin should be None")
      }
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
    resolve_sample_path("samples/assets/html/img/img_red.jpg"),
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
      if img.alt_text != Some("tmpug_opwhs.png") {
        fail("pptx image alt_text should come from p:cNvPr descr")
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

  let yml_path = resolve_sample_path(
    "samples/main_process/yaml/yml_extension_basic.yml",
  )
  let yml_doc = @yaml.parse_yaml(yml_path, "", 6)
  let yml_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/yaml/yml_extension_basic.md",
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
      "samples/main_process/expected/markdown/markdown_basic_heading_paragraph.md",
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
    resolve_sample_path("samples/main_process/expected/txt/txt_paragraphs.md"),
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
      "samples/main_process/expected/txt/txt_markdown_like_literal.md",
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
    resolve_sample_path("samples/main_process/expected/xml/xml_basic.md"),
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
  if !xml_json.contains("\"block_count\": 1") {
    fail("xml metadata should contain one code block")
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
      "samples/main_process/expected/markdown/markdown_frontmatter_passthrough.md",
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
      "samples/main_process/expected/markdown/markdown_bom_utf8.md",
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
      "samples/main_process/expected/markdown/markdown_crlf.md",
    ),
  )
  if @cor.emit_markdown(markdown_crlf_doc) != markdown_crlf_expected {
    fail("markdown should normalize crlf input to stable newline output")
  }
}

///|
test "origin_metadata/structured_text_block_origins" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/structured_text_block_origins"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let csv_path = out_dir + "/quoted_newline.csv"
  write_utf8_text(csv_path, "Name,Note\nAlice,\"line1\nline2\"\nBob,ok\n")

  let csv_doc = @csv.parse_csv(csv_path, "", 6)
  let csv_origin = block_origin_at(csv_doc, 0)
  if csv_origin.line_start != Some(1) {
    fail("csv table block should start at line 1")
  }
  if csv_origin.line_end != Some(4) {
    fail("csv table block should end at physical line 4")
  }
  if csv_origin.row_index != Some(1) {
    fail("csv table block should start at row_index=1")
  }
  if csv_origin.column_index != Some(1) {
    fail("csv table block should start at column_index=1")
  }
  if csv_origin.key_path != None {
    fail("csv table block should not set key_path")
  }

  let tsv_doc = @csv.parse_tsv(
    resolve_sample_path("samples/main_process/tsv/tsv_basic.tsv"),
    "",
    6,
  )
  let tsv_origin = block_origin_at(tsv_doc, 0)
  if tsv_origin.line_start != Some(1) {
    fail("tsv table block should start at line 1")
  }
  if tsv_origin.line_end != Some(3) {
    fail("tsv table block should end at line 3")
  }
  if tsv_origin.row_index != Some(1) {
    fail("tsv table block should start at row_index=1")
  }
  if tsv_origin.column_index != Some(1) {
    fail("tsv table block should start at column_index=1")
  }
  if tsv_origin.key_path != None {
    fail("tsv table block should not set key_path")
  }

  let json_object_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_object_basic.json"),
    "",
    6,
  )
  if block_origin_at(json_object_doc, 0).key_path != Some("$") {
    fail("json object block should keep root key_path")
  }

  let json_list_doc = @json.parse_json(
    resolve_sample_path(
      "samples/main_process/json/json_array_scalars_list.json",
    ),
    "",
    6,
  )
  for i in 0..<json_list_doc.block_origins.val.length() {
    if block_origin_at(json_list_doc, i).key_path != Some("$") {
      fail("json scalar list item should keep root key_path")
    }
  }

  let yaml_mapping_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_mapping_basic.yaml"),
    "",
    6,
  )
  if block_origin_at(yaml_mapping_doc, 0).key_path != Some("$") {
    fail("yaml mapping block should keep root key_path")
  }

  let yaml_list_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_sequence_scalars.yaml"),
    "",
    6,
  )
  for i in 0..<yaml_list_doc.block_origins.val.length() {
    if block_origin_at(yaml_list_doc, i).key_path != Some("$") {
      fail("yaml scalar list item should keep root key_path")
    }
  }

  let markdown_code_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_code_fence.md"),
    "",
    6,
  )
  let markdown_code_origin = block_origin_at(markdown_code_doc, 0)
  if markdown_code_origin.line_start != Some(1) {
    fail("markdown code fence block should start at line 1")
  }
  if markdown_code_origin.line_end != Some(5) {
    fail("markdown code fence block should end at line 5")
  }

  let markdown_frontmatter_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_frontmatter_passthrough.markdown",
    ),
    "",
    6,
  )
  if block_origin_at(markdown_frontmatter_doc, 0).line_start != Some(1) {
    fail("markdown frontmatter block should start at line 1")
  }
  if block_origin_at(markdown_frontmatter_doc, 0).line_end != Some(5) {
    fail("markdown frontmatter block should end at line 5")
  }
  if block_origin_at(markdown_frontmatter_doc, 1).line_start != Some(7) {
    fail("markdown frontmatter heading block should start at line 7")
  }
  if block_origin_at(markdown_frontmatter_doc, 1).line_end != Some(7) {
    fail("markdown frontmatter heading block should end at line 7")
  }
  if block_origin_at(markdown_frontmatter_doc, 2).line_start != Some(9) {
    fail("markdown frontmatter trailing paragraph should start at line 9")
  }
  if block_origin_at(markdown_frontmatter_doc, 2).line_end != Some(9) {
    fail("markdown frontmatter trailing paragraph should end at line 9")
  }

  let markdown_no_newline_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_no_trailing_newline.md",
    ),
    "",
    6,
  )
  let markdown_no_newline_origin = block_origin_at(markdown_no_newline_doc, 0)
  if markdown_no_newline_origin.line_start != Some(1) {
    fail("markdown no-trailing-newline block should start at line 1")
  }
  if markdown_no_newline_origin.line_end != Some(1) {
    fail("markdown no-trailing-newline block should end at line 1")
  }

  let markdown_crlf_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_crlf.md"),
    "",
    6,
  )
  if block_origin_at(markdown_crlf_doc, 0).line_start != Some(1) {
    fail("markdown crlf heading block should start at line 1")
  }
  if block_origin_at(markdown_crlf_doc, 0).line_end != Some(1) {
    fail("markdown crlf heading block should end at line 1")
  }
  if block_origin_at(markdown_crlf_doc, 1).line_start != Some(3) {
    fail("markdown crlf paragraph block should start at line 3")
  }
  if block_origin_at(markdown_crlf_doc, 1).line_end != Some(3) {
    fail("markdown crlf paragraph block should end at line 3")
  }

  let markdown_bom_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_bom_utf8.md"),
    "",
    6,
  )
  if block_origin_at(markdown_bom_doc, 0).line_start != Some(1) {
    fail("markdown bom heading block should start at line 1")
  }
  if block_origin_at(markdown_bom_doc, 0).line_end != Some(1) {
    fail("markdown bom heading block should end at line 1")
  }
  if block_origin_at(markdown_bom_doc, 1).line_start != Some(3) {
    fail("markdown bom paragraph block should start at line 3")
  }
  if block_origin_at(markdown_bom_doc, 1).line_end != Some(3) {
    fail("markdown bom paragraph block should end at line 3")
  }

  let txt_doc = @txt.parse_txt(
    resolve_sample_path("samples/main_process/txt/txt_paragraphs.txt"),
    "",
    6,
  )
  if txt_doc.blocks.val.length() != 2 {
    fail("txt_paragraphs should emit exactly two paragraph blocks")
  }

  let txt_first = block_origin_at(txt_doc, 0)
  if txt_first.line_start != Some(1) {
    fail("txt first paragraph should start at line 1")
  }
  if txt_first.line_end != Some(2) {
    fail("txt first paragraph should end at line 2")
  }
  if txt_first.key_path != None {
    fail("txt paragraph should not set key_path")
  }

  let txt_second = block_origin_at(txt_doc, 1)
  if txt_second.line_start != Some(4) {
    fail("txt second paragraph should start at line 4")
  }
  if txt_second.line_end != Some(5) {
    fail("txt second paragraph should end at line 5")
  }

  let txt_many_doc = @txt.parse_txt(
    resolve_sample_path("samples/main_process/txt/txt_many_paragraphs.txt"),
    "",
    6,
  )
  if txt_many_doc.blocks.val.length() != 5 {
    fail("txt_many_paragraphs should ignore repeated blank lines")
  }
  let txt_many_last = block_origin_at(txt_many_doc, 4)
  if txt_many_last.line_start != Some(14) {
    fail("txt many-paragraph final block should start at line 14")
  }
  if txt_many_last.line_end != Some(14) {
    fail("txt many-paragraph final block should end at line 14")
  }
}

///|
test "metadata_sidecar/structured_text_origin_snapshots" {
  let html_single_out_dir = origin_tmp_root() +
    "/metadata_sidecar_html_img_single"
  recreate_clean_dir(html_single_out_dir)
  defer cleanup_temp_dir(html_single_out_dir)
  ensure_dir(html_single_out_dir + "/html")
  let html_single_doc = @html.parse_html(
    resolve_sample_path("samples/metadata/html/html_img_single.html"),
    html_single_out_dir + "/html",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      html_single_doc, "html_img_single.html", "html", "html_img_single.md",
    ),
    "html_img_single.metadata.json",
  )

  let html_figure_out_dir = origin_tmp_root() +
    "/metadata_sidecar_html_figure_figcaption_basic"
  recreate_clean_dir(html_figure_out_dir)
  defer cleanup_temp_dir(html_figure_out_dir)
  ensure_dir(html_figure_out_dir + "/html")
  let html_figure_doc = @html.parse_html(
    resolve_sample_path(
      "samples/metadata/html/html_figure_figcaption_basic.html",
    ),
    html_figure_out_dir + "/html",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      html_figure_doc, "html_figure_figcaption_basic.html", "html", "html_figure_figcaption_basic.md",
    ),
    "html_figure_figcaption_basic.metadata.json",
  )

  let pptx_single_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_image_single_caption_like"
  recreate_clean_dir(pptx_single_out_dir)
  defer cleanup_temp_dir(pptx_single_out_dir)
  ensure_dir(pptx_single_out_dir + "/pptx")
  let pptx_single_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/metadata/pptx/pptx_image_single_caption_like.pptx",
    ),
    pptx_single_out_dir + "/pptx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      pptx_single_doc, "pptx_image_single_caption_like.pptx", "pptx", "pptx_image_single_caption_like.md",
    ),
    "pptx_image_single_caption_like.metadata.json",
  )

  let pptx_alt_title_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_image_alt_title_basic"
  recreate_clean_dir(pptx_alt_title_out_dir)
  defer cleanup_temp_dir(pptx_alt_title_out_dir)
  ensure_dir(pptx_alt_title_out_dir + "/pptx")
  let pptx_alt_title_doc = @pptx.parse_pptx(
    resolve_sample_path("samples/metadata/pptx/pptx_image_alt_title_basic.pptx"),
    pptx_alt_title_out_dir + "/pptx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      pptx_alt_title_doc, "pptx_image_alt_title_basic.pptx", "pptx", "pptx_image_alt_title_basic.md",
    ),
    "pptx_image_alt_title_basic.metadata.json",
  )

  let pptx_no_alt_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_image_no_alt_negative"
  recreate_clean_dir(pptx_no_alt_out_dir)
  defer cleanup_temp_dir(pptx_no_alt_out_dir)
  ensure_dir(pptx_no_alt_out_dir + "/pptx")
  let pptx_no_alt_doc = @pptx.parse_pptx(
    resolve_sample_path("samples/metadata/pptx/pptx_image_no_alt_negative.pptx"),
    pptx_no_alt_out_dir + "/pptx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      pptx_no_alt_doc, "pptx_image_no_alt_negative.pptx", "pptx", "pptx_image_no_alt_negative.md",
    ),
    "pptx_image_no_alt_negative.metadata.json",
  )

  let docx_golden_out_dir = origin_tmp_root() + "/metadata_sidecar_docx_golden"
  recreate_clean_dir(docx_golden_out_dir)
  defer cleanup_temp_dir(docx_golden_out_dir)
  ensure_dir(docx_golden_out_dir + "/docx")
  let docx_golden_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/golden.docx"),
    docx_golden_out_dir + "/docx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(docx_golden_doc, "golden.docx", "docx", "golden.md"),
    "golden.metadata.json",
  )

  let docx_alt_title_out_dir = origin_tmp_root() +
    "/metadata_sidecar_docx_image_alt_title_basic"
  recreate_clean_dir(docx_alt_title_out_dir)
  defer cleanup_temp_dir(docx_alt_title_out_dir)
  ensure_dir(docx_alt_title_out_dir + "/docx")
  let docx_alt_title_doc = @doc.parse_docx(
    resolve_sample_path("samples/metadata/docx/docx_image_alt_title_basic.docx"),
    docx_alt_title_out_dir + "/docx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      docx_alt_title_doc, "docx_image_alt_title_basic.docx", "docx", "docx_image_alt_title_basic.md",
    ),
    "docx_image_alt_title_basic.metadata.json",
  )

  let docx_no_alt_out_dir = origin_tmp_root() +
    "/metadata_sidecar_docx_image_no_alt_negative"
  recreate_clean_dir(docx_no_alt_out_dir)
  defer cleanup_temp_dir(docx_no_alt_out_dir)
  ensure_dir(docx_no_alt_out_dir + "/docx")
  let docx_no_alt_doc = @doc.parse_docx(
    resolve_sample_path("samples/metadata/docx/docx_image_no_alt_negative.docx"),
    docx_no_alt_out_dir + "/docx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      docx_no_alt_doc, "docx_image_no_alt_negative.docx", "docx", "docx_image_no_alt_negative.md",
    ),
    "docx_image_no_alt_negative.metadata.json",
  )

  let csv_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_basic.csv"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(csv_doc, "csv_basic.csv", "csv", "csv_basic.md"),
    "csv_basic.metadata.json",
  )
  let csv_metadata_basic_doc = @csv.parse_csv(
    resolve_sample_path("samples/metadata/csv/csv_metadata_basic.csv"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      csv_metadata_basic_doc, "csv_metadata_basic.csv", "csv", "csv_metadata_basic.md",
    ),
    "csv_metadata_basic.metadata.json",
  )
  let csv_metadata_ragged_doc = @csv.parse_csv(
    resolve_sample_path("samples/metadata/csv/csv_metadata_ragged_rows.csv"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      csv_metadata_ragged_doc, "csv_metadata_ragged_rows.csv", "csv", "csv_metadata_ragged_rows.md",
    ),
    "csv_metadata_ragged_rows.metadata.json",
  )

  let tsv_doc = @csv.parse_tsv(
    resolve_sample_path("samples/main_process/tsv/tsv_basic.tsv"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(tsv_doc, "tsv_basic.tsv", "tsv", "tsv_basic.md"),
    "tsv_basic.metadata.json",
  )
  let tsv_metadata_basic_doc = @csv.parse_tsv(
    resolve_sample_path("samples/metadata/tsv/tsv_metadata_basic.tsv"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      tsv_metadata_basic_doc, "tsv_metadata_basic.tsv", "tsv", "tsv_metadata_basic.md",
    ),
    "tsv_metadata_basic.metadata.json",
  )

  let json_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_object_basic.json"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      json_doc, "json_object_basic.json", "json", "json_object_basic.md",
    ),
    "json_object_basic.metadata.json",
  )

  let yaml_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_mapping_basic.yaml"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      yaml_doc, "yaml_mapping_basic.yaml", "yaml", "yaml_mapping_basic.md",
    ),
    "yaml_mapping_basic.metadata.json",
  )

  let epub_out_dir = origin_tmp_root() + "/metadata_sidecar_epub_metadata_basic"
  recreate_clean_dir(epub_out_dir)
  defer cleanup_temp_dir(epub_out_dir)
  let epub_doc = @epub.parse_epub(
    resolve_sample_path("samples/metadata/epub/epub_metadata_basic.epub"),
    epub_out_dir,
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      epub_doc,
      "epub_metadata_basic.epub",
      "epub",
      "epub_metadata_basic.md",
      read_epub_metadata_document_properties(
        resolve_sample_path("samples/metadata/epub/epub_metadata_basic.epub"),
      ),
    ),
    "epub_metadata_basic.metadata.json",
  )

  let markdown_code_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_code_fence.md"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_code_doc, "markdown_code_fence.md", "markdown", "markdown_code_fence.md",
    ),
    "markdown_code_fence.metadata.json",
  )

  let markdown_frontmatter_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_frontmatter_passthrough.markdown",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_frontmatter_doc, "markdown_frontmatter_passthrough.markdown", "markdown",
      "markdown_frontmatter_passthrough.md",
    ),
    "markdown_frontmatter_passthrough.metadata.json",
  )

  let markdown_no_newline_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_no_trailing_newline.md",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_no_newline_doc, "markdown_no_trailing_newline.md", "markdown", "markdown_no_trailing_newline.md",
    ),
    "markdown_no_trailing_newline.metadata.json",
  )

  let markdown_basic_doc = @md.parse_markdown(
    resolve_sample_path("samples/metadata/markdown/markdown_metadata_basic.md"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_basic_doc, "markdown_metadata_basic.md", "markdown", "markdown_metadata_basic.md",
    ),
    "markdown_metadata_basic.metadata.json",
  )

  let markdown_multiline_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/metadata/markdown/markdown_metadata_heading_or_multiline.md",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_multiline_doc, "markdown_metadata_heading_or_multiline.md", "markdown",
      "markdown_metadata_heading_or_multiline.md",
    ),
    "markdown_metadata_heading_or_multiline.metadata.json",
  )
}

///|
async test "origin_metadata/pdf_minimal_closure" {
  let root_dir = origin_tmp_root()

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
  let root_dir = origin_tmp_root()

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
      if img.alt_text != Some("tmpug_opwhs.png") {
        fail("pptx caption-like image alt_text should come from p:cNvPr descr")
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
    resolve_sample_path("samples/metadata/pptx/pptx_image_alt_title_basic.pptx"),
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
    resolve_sample_path("samples/metadata/pptx/pptx_image_no_alt_negative.pptx"),
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
