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
fn assert_inspect_action_eq(
  actual : @zipconv.ZipInspectAction,
  expected : @zipconv.ZipInspectAction,
  message : String,
) -> Unit raise {
  if actual != expected {
    fail(message)
  }
}

///|
fn assert_inspect_kind_eq(
  actual : @zipconv.ZipInspectEntryKind,
  expected : @zipconv.ZipInspectEntryKind,
  message : String,
) -> Unit raise {
  if actual != expected {
    fail(message)
  }
}

///|
fn inspect_entry_by_raw_name(
  report : @zipconv.ZipInspectReport,
  raw_name : String,
) -> @zipconv.ZipInspectEntry raise {
  for entry in report.entries {
    if entry.raw_name == raw_name {
      return entry
    }
  }
  fail("inspect entry not found: " + raw_name)
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
test "zip inspect reports supported, nested, and unsafe entry policies" {
  let report = @zipconv.inspect_zip(
    resolve_sample_path("samples/main_process/zip/zip_basic_structured.zip"),
  ) catch {
    e => fail("inspect_zip failed: " + e.to_string())
  }

  let json_entry = inspect_entry_by_raw_name(report, "data/person.json")
  assert_inspect_kind_eq(
    json_entry.entry_kind,
    @zipconv.ZipInspectEntryKind::Supported,
    "expected json entry to be supported",
  )
  assert_inspect_action_eq(
    json_entry.action,
    @zipconv.ZipInspectAction::Convert,
    "expected json entry action to be convert",
  )
  assert_opt_string_eq(
    json_entry.dispatch_format,
    Some("json"),
    "expected json dispatch format",
  )
  assert_opt_string_eq(
    json_entry.normalized_path,
    Some("data/person.json"),
    "expected normalized json path",
  )
}

///|
test "zip inspect reports unsafe path failure clearly" {
  let inspected = try? @zipconv.inspect_zip(
    resolve_sample_path("samples/test/zip/zip_unsafe_traversal.zip"),
  )
  match inspected {
    Ok(report) => {
      let entry = inspect_entry_by_raw_name(report, "../evil.txt")
      assert_inspect_kind_eq(
        entry.entry_kind,
        @zipconv.ZipInspectEntryKind::UnsafePath,
        "expected traversal entry to be unsafe",
      )
      assert_inspect_action_eq(
        entry.action,
        @zipconv.ZipInspectAction::Fail,
        "expected traversal entry action to fail",
      )
    }
    Err(_e) =>
      fail("inspect_zip should succeed and classify unsafe traversal entry")
  }
}

///|
test "zip inspect reports normalized path collision clearly" {
  let report = @zipconv.inspect_zip(
    resolve_sample_path("samples/test/zip/zip_normalized_collision.zip"),
  ) catch {
    e => fail("inspect_zip failed: " + e.to_string())
  }

  let first = inspect_entry_by_raw_name(report, "a\\b.png")
  let second = inspect_entry_by_raw_name(report, "a/b.png")
  assert_inspect_action_eq(
    first.action,
    @zipconv.ZipInspectAction::Fail,
    "expected first colliding entry to fail",
  )
  assert_inspect_action_eq(
    second.action,
    @zipconv.ZipInspectAction::Fail,
    "expected second colliding entry to fail",
  )
  assert_inspect_kind_eq(
    first.entry_kind,
    @zipconv.ZipInspectEntryKind::UnsafePath,
    "expected first colliding entry to be marked unsafe",
  )
  assert_inspect_kind_eq(
    second.entry_kind,
    @zipconv.ZipInspectEntryKind::UnsafePath,
    "expected second colliding entry to be marked unsafe",
  )
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
async test "zip parse fails closed on unsafe archive paths" {
  let root = zip_test_root()
  let out_dir = root + "/parse_zip_unsafe_paths"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let traversal = try? @zipconv.parse_zip(
    resolve_sample_path("samples/test/zip/zip_unsafe_traversal.zip"),
    out_dir,
    6,
  )
  assert_true(traversal is Err(_))

  let absolute = try? @zipconv.parse_zip(
    resolve_sample_path("samples/test/zip/zip_unsafe_absolute.zip"),
    out_dir,
    6,
  )
  assert_true(absolute is Err(_))

  let windows_drive = try? @zipconv.parse_zip(
    resolve_sample_path("samples/test/zip/zip_unsafe_windows_drive.zip"),
    out_dir,
    6,
  )
  assert_true(windows_drive is Err(_))

  let duplicate_entries = try? @zipconv.parse_zip(
    resolve_sample_path("samples/test/zip/zip_duplicate_entries.zip"),
    out_dir,
    6,
  )
  assert_true(duplicate_entries is Err(_))
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
async test "zip parse html-asset sample stays stable across repeated conversions" {
  let root = zip_test_root()
  let first_out = root + "/parse_zip_html_assets_repeat_1"
  let second_out = root + "/parse_zip_html_assets_repeat_2"
  recreate_clean_dir(first_out)
  recreate_clean_dir(second_out)
  defer cleanup_temp_dir(first_out)
  defer cleanup_temp_dir(second_out)

  let sample = resolve_sample_path("samples/test/zip/zip_html_local_image.zip")
  let first = @zipconv.parse_zip(sample, first_out, 6)
  let second = @zipconv.parse_zip(sample, second_out, 6)

  let first_md = @cor.emit_markdown(first)
  let second_md = @cor.emit_markdown(second)
  assert_eq(first_md, second_md)
  assert_contains(
    first_md, "![single](assets/archive/site_page.html/image01.png)",
  )
  if !@fs.path_exists(first_out + "/assets/archive/site_page.html/image01.png") {
    fail("expected first repeated zip run to emit remapped asset")
  }
  if !@fs.path_exists(second_out + "/assets/archive/site_page.html/image01.png") {
    fail("expected second repeated zip run to emit remapped asset")
  }
}
