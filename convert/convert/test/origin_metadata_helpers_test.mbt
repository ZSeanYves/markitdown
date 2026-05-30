///|
/// Cross-format origin/metadata regression helpers.
///
/// Why this suite exists:
/// - validates unified IR lightweight provenance contract
/// - guards metadata-sidecar image context mirrors (caption vs nearby_caption)
/// - checks asset indexing invariants shared by main_process / metadata / assets chains
/// 已做了内容删除，在测试结束后不会保留内容，但会残留测试目录
fn parent_dir(path : String) -> String {
  match path.rev_find("/") {
    None => ""
    Some(idx) => if idx == 0 { "/" } else { path[:idx].to_owned() }
  }
}

///|
fn join_path(base : String, rel : String) -> String {
  if base == "" || base == "." {
    rel
  } else if base == "/" {
    "/" + rel
  } else if base.has_suffix("/") {
    base + rel
  } else {
    base + "/" + rel
  }
}

///|
fn find_repo_root_from(dir : String) -> String? {
  if @fs.path_exists(join_path(dir, "moon.mod.json")) {
    return Some(dir)
  }
  let parent = parent_dir(dir)
  if parent == "" || parent == dir {
    None
  } else {
    find_repo_root_from(parent)
  }
}

///|
fn find_repo_root() -> String? {
  let dir = match @sys.get_env_var("PWD") {
    Some(cwd) => cwd
    None => return None
  }
  find_repo_root_from(dir)
}

///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  match find_repo_root() {
    Some(root) => {
      let rooted = join_path(root, path)
      if @fs.path_exists(rooted) {
        return rooted
      }
    }
    None => ()
  }

  fail("sample file not found: " + path)
}

///|
fn read_utf8_text(path : String) -> String raise {
  @fs.read_file_to_string(path, encoding="utf8") catch {
    e => fail("read sample failed: " + e.to_string())
  }
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn write_origin_metadata_test_pdf(
  path : String,
  pdf : @mbtpdf_core.Pdf,
) -> Unit raise {
  let (output, buffer) = @pdfio.Output::of_bytes(2048)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    preserve_objstm=true,
    generate_objstm=false,
    compress_objstm=true,
    None,
    true,
    pdf,
    output,
  )
  @fs.write_bytes_to_file(path, Bytes::from_array(output.extract_bytes(buffer)))
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
fn metadata_pdf_page_from_ops(
  ops : Array[@pdfops.Op],
  rect : @mbtpdf_core.PdfObject,
) -> @pdfpage.Page raise {
  let stream = @pdfops.Op::stream_of_ops(ops)
  let font : @mbtpdf_core.PdfObject = Dictionary([
    ("/Type", Name(@mbtpdf_core.PdfName::of_string("/Font"))),
    ("/Subtype", Name(@mbtpdf_core.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@mbtpdf_core.PdfName::of_string("/Helvetica"))),
  ])
  {
    content: [stream],
    mediabox: rect,
    cropbox: None,
    resources: Dictionary([("/Font", Dictionary([("/F0", font)]))]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
}

///|
fn write_metadata_simple_table_pdf(path : String) -> Unit raise {
  let rect : @mbtpdf_core.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(400.0),
    Real(240.0),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 180.0),
    @pdfops.Op::OpTj("Product"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(150.0, 180.0),
    @pdfops.Op::OpTj("Region"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(250.0, 180.0),
    @pdfops.Op::OpTj("Status"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 158.0),
    @pdfops.Op::OpTj("Alpha"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(150.0, 158.0),
    @pdfops.Op::OpTj("East"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(250.0, 158.0),
    @pdfops.Op::OpTj("Open"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 136.0),
    @pdfops.Op::OpTj("Beta"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(150.0, 136.0),
    @pdfops.Op::OpTj("West"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(250.0, 136.0),
    @pdfops.Op::OpTj("Closed"),
    @pdfops.Op::OpET,
  ]

  let pdf0 = @mbtpdf_core.Pdf::empty()
  let page = metadata_pdf_page_from_ops(ops, rect)
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  write_origin_metadata_test_pdf(path, pdf)
}

///|
fn write_metadata_headerless_numeric_table_pdf(path : String) -> Unit raise {
  let rect : @mbtpdf_core.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(400.0),
    Real(240.0),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 180.0),
    @pdfops.Op::OpTj("Alpha"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(180.0, 180.0),
    @pdfops.Op::OpTj("12"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(280.0, 180.0),
    @pdfops.Op::OpTj("4.5%"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 158.0),
    @pdfops.Op::OpTj("Beta"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(180.0, 158.0),
    @pdfops.Op::OpTj("9"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(280.0, 158.0),
    @pdfops.Op::OpTj("3.2%"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 136.0),
    @pdfops.Op::OpTj("Gamma"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(180.0, 136.0),
    @pdfops.Op::OpTj("7"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(280.0, 136.0),
    @pdfops.Op::OpTj("2.1%"),
    @pdfops.Op::OpET,
  ]

  let pdf0 = @mbtpdf_core.Pdf::empty()
  let page = metadata_pdf_page_from_ops(ops, rect)
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  write_origin_metadata_test_pdf(path, pdf)
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

  let props = @cor.metadata_document_properties(
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
  )
  Some(
    @cor.metadata_document_properties_with_extras(
      props,
      meta.language,
      meta.identifier,
      meta.publisher,
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
    resolve_sample_path("samples/fixtures/metadata/" + expected_name),
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
