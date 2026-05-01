///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn zip_test_root() -> String raise {
  let root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
  let out = root + "/zip-tests"
  ensure_dir_tree(out)
  out
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
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  @fs.create_dir(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
fn first_image_block_by_path(
  doc : @cor.Document,
  path : String,
) -> @cor.ImageData? {
  for block in doc.blocks.val {
    match block {
      @cor.Block::ImageBlock(img) => if img.path == path { return Some(img) }
      _ => ()
    }
  }
  None
}

///|
fn assert_contains(haystack : String, needle : String) -> Unit raise {
  if !haystack.contains(needle) {
    fail("expected text to contain: " + needle + "\nactual:\n" + haystack)
  }
}

///|
fn assert_not_contains(haystack : String, needle : String) -> Unit raise {
  if haystack.contains(needle) {
    fail("expected text to exclude: " + needle + "\nactual:\n" + haystack)
  }
}

///|
fn assert_opt_string_eq(
  actual : String?,
  expected : String?,
  message : String,
) -> Unit raise {
  if actual != expected {
    fail(message)
  }
}

///|
fn assert_opt_int_eq(
  actual : Int?,
  expected : Int?,
  message : String,
) -> Unit raise {
  if actual != expected {
    fail(message)
  }
}

///|
async test "zip parse supports asset-producing docx and pptx entries" {
  let root = zip_test_root()
  let out_dir = root + "/parse_zip_assets_namespace"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let doc = @zipconv.parse_zip(
    resolve_sample_path("samples/main_process/zip/zip_assets_namespace.zip"),
    out_dir,
    6,
  )
  let md = @cor.emit_markdown(doc)

  assert_contains(md, "# docs/report.docx")
  assert_contains(
    md, "![Figure alt text](assets/archive/docs_report.docx/image01.png)",
  )
  assert_contains(md, "# slides/overview.pptx")
  assert_contains(
    md, "![Figure alt text](assets/archive/slides_overview.pptx/image01.png)",
  )

  if !@fs.path_exists(out_dir + "/assets/archive/docs_report.docx/image01.png") {
    fail("expected docx asset to be copied into archive namespace")
  }
  if !@fs.path_exists(
      out_dir + "/assets/archive/slides_overview.pptx/image01.png",
    ) {
    fail("expected pptx asset to be copied into archive namespace")
  }

  match
    doc.asset_origins.val.get("assets/archive/docs_report.docx/image01.png") {
    Some(origin) => {
      assert_opt_string_eq(
        origin.source_name,
        Some("zip_assets_namespace.zip"),
        "expected docx zip asset source_name to be rewritten to zip file",
      )
      assert_opt_string_eq(
        origin.relationship_id,
        Some("rId4"),
        "expected docx zip asset relationship_id to be preserved",
      )
      assert_opt_string_eq(
        origin.source_path,
        Some("docs/report.docx"),
        "expected docx zip asset source_path to point at archive entry path",
      )
      assert_opt_string_eq(
        origin.key_path,
        Some("docs/report.docx"),
        "expected docx zip asset key_path to point at archive entry path",
      )
      assert_opt_string_eq(
        origin.origin_id,
        Some("zip:docs/report.docx:docx-asset-1"),
        "expected docx zip asset origin_id to be namespaced with entry path",
      )
    }
    None => fail("expected docx zip asset origin")
  }
  match
    doc.asset_origins.val.get("assets/archive/slides_overview.pptx/image01.png") {
    Some(origin) => {
      assert_opt_string_eq(
        origin.source_name,
        Some("zip_assets_namespace.zip"),
        "expected pptx zip asset source_name to be rewritten to zip file",
      )
      assert_opt_string_eq(
        origin.relationship_id,
        Some("rId2"),
        "expected pptx zip asset relationship_id to be preserved",
      )
      assert_opt_string_eq(
        origin.source_path,
        Some("slides/overview.pptx"),
        "expected pptx zip asset source_path to point at archive entry path",
      )
      assert_opt_string_eq(
        origin.key_path,
        Some("slides/overview.pptx"),
        "expected pptx zip asset key_path to point at archive entry path",
      )
      assert_opt_string_eq(
        origin.origin_id,
        Some("zip:slides/overview.pptx:slide-1-image-1"),
        "expected pptx zip asset origin_id to be namespaced with entry path",
      )
    }
    None => fail("expected pptx zip asset origin")
  }

  match
    first_image_block_by_path(
      doc, "assets/archive/docs_report.docx/image01.png",
    ) {
    Some(img) =>
      match img.origin {
        Some(origin) => {
          assert_opt_string_eq(
            origin.source_name,
            Some("zip_assets_namespace.zip"),
            "expected docx zip image source_name to be rewritten to zip file",
          )
          assert_opt_string_eq(
            origin.key_path,
            Some("docs/report.docx"),
            "expected docx zip image key_path to point at entry path",
          )
          assert_opt_int_eq(
            origin.slide,
            None,
            "expected docx zip image slide origin to stay empty",
          )
        }
        None =>
          fail("expected docx image origin to be rewritten for zip context")
      }
    None => fail("expected remapped docx image block")
  }
  match
    first_image_block_by_path(
      doc, "assets/archive/slides_overview.pptx/image01.png",
    ) {
    Some(img) =>
      match img.origin {
        Some(origin) => {
          assert_opt_string_eq(
            origin.source_name,
            Some("zip_assets_namespace.zip"),
            "expected pptx zip image source_name to be rewritten to zip file",
          )
          if origin.key_path != Some("slides/overview.pptx") {
            fail("expected pptx zip image key_path to point at entry path")
          }
          if origin.slide != Some(1) {
            fail("expected pptx zip image slide origin to be preserved")
          }
        }
        None =>
          fail("expected pptx image origin to be rewritten for zip context")
      }
    None => fail("expected remapped pptx image block")
  }

  let metadata_json = @cor.emit_metadata_json(
    doc, "zip_assets_namespace.zip", "zip", "zip_assets_namespace.md",
  )
  assert_contains(
    metadata_json, "\"path\": \"assets/archive/docs_report.docx/image01.png\"",
  )
  assert_contains(metadata_json, "\"key_path\": \"docs/report.docx\"")
  assert_contains(metadata_json, "\"relationship_id\": \"rId4\"")
  assert_contains(
    metadata_json, "\"path\": \"assets/archive/slides_overview.pptx/image01.png\"",
  )
  assert_contains(metadata_json, "\"key_path\": \"slides/overview.pptx\"")
  assert_contains(metadata_json, "\"relationship_id\": \"rId2\"")
}

///|
async test "zip parse supports html local images inside zip" {
  let root = zip_test_root()
  let out_dir = root + "/parse_zip_html_assets"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let sample = resolve_sample_path("samples/test/zip/zip_html_local_image.zip")
  let doc = @zipconv.parse_zip(sample, out_dir, 6)
  let md = @cor.emit_markdown(doc)

  assert_contains(md, "# site/page.html")
  assert_contains(md, "![single](assets/archive/site_page.html/image01.png)")
  assert_not_contains(
    md, "Skipped: asset-producing HTML inside ZIP is not supported yet",
  )

  if !@fs.path_exists(out_dir + "/assets/archive/site_page.html/image01.png") {
    fail("zip html local image should materialize archive-namespaced assets")
  }
  match doc.asset_origins.val.get("assets/archive/site_page.html/image01.png") {
    Some(origin) => {
      assert_opt_string_eq(
        origin.source_name,
        Some("zip_html_local_image.zip"),
        "expected html zip asset source_name to be rewritten to zip file",
      )
      assert_opt_string_eq(
        origin.source_path,
        Some("site/page.html"),
        "expected html zip asset source_path to point at archive entry path",
      )
      assert_opt_string_eq(
        origin.key_path,
        Some("site/page.html"),
        "expected html zip asset key_path to point at archive entry path",
      )
      assert_opt_string_eq(
        origin.origin_id,
        Some("zip:site/page.html:html-asset-1"),
        "expected html zip asset origin_id to be namespaced with entry path",
      )
    }
    None => fail("expected zip html local image asset origin")
  }

  let extracted_root = extracted_root_for_sample(sample)
  if !@fs.path_exists(extracted_root + "/site/page.html") {
    fail("expected html local image entry to be materialized in extracted tree")
  }
  if !@fs.path_exists(extracted_root + "/site/img/pic.png") {
    fail("expected sibling image to be materialized in extracted tree")
  }
  if @fs.path_exists(extracted_root + "/__MACOSX/site/img/._pic.png") {
    fail("expected hidden macOS metadata entries to stay out of extracted tree")
  }
}

///|
async test "zip parse keeps unsafe parent-image refs as fallback" {
  let root = zip_test_root()
  let out_dir = root + "/parse_zip_html_parent_ref_negative"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let doc = @zipconv.parse_zip(
    resolve_sample_path(
      "samples/test/zip/zip_html_local_image_unsafe_parent.zip",
    ),
    out_dir,
    6,
  )
  let md = @cor.emit_markdown(doc)

  assert_contains(md, "# site/page.html")
  assert_contains(md, "[blocked]")
  if doc.asset_origins.val.length() != 0 {
    fail("expected unsafe parent html ref to avoid exported asset origins")
  }
  if @fs.path_exists(out_dir + "/assets") {
    fail("expected unsafe parent html ref to avoid archive assets")
  }
}

///|
async test "zip parse keeps remote html image refs as fallback" {
  let root = zip_test_root()
  let out_dir = root + "/parse_zip_html_remote_ref_negative"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let doc = @zipconv.parse_zip(
    resolve_sample_path("samples/test/zip/zip_html_local_image_remote.zip"),
    out_dir,
    6,
  )
  let md = @cor.emit_markdown(doc)

  assert_contains(md, "# page.html")
  assert_contains(md, "[remote]")
  if doc.asset_origins.val.length() != 0 {
    fail("expected remote html ref to avoid exported asset origins")
  }
  if @fs.path_exists(out_dir + "/assets") {
    fail("expected remote html ref to avoid archive assets")
  }
}

///|
async test "zip parse fails closed on normalized path collisions" {
  let root = zip_test_root()
  let out_dir = root + "/parse_zip_normalized_collision"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let result = try? @zipconv.parse_zip(
    resolve_sample_path("samples/test/zip/zip_normalized_collision.zip"),
    out_dir,
    6,
  )
  assert_true(result is Err(_))
}

///|
async test "zip parse keeps nested archive and unsupported warnings" {
  let root = zip_test_root()
  let out_dir = root + "/parse_zip_warning_regression"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let doc = @zipconv.parse_zip(
    resolve_sample_path("samples/main_process/zip/zip_basic_structured.zip"),
    out_dir,
    6,
  )
  let md = @cor.emit_markdown(doc)

  assert_contains(md, "# unsupported/archive.zip")
  assert_contains(md, "> Skipped: nested archive is not supported: zip")
  assert_contains(md, "# unsupported/blob.bin")
  assert_contains(md, "> Skipped: unsupported file type: bin")
}

///|
fn extracted_root_for_sample(sample_path : String) -> String {
  let root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
  root + "/zip/" + @cor.basename(sample_path) + "/extracted"
}
