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
fn read_utf8_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read expected failed: " + e.to_string())
  }
  @cor.utf8_bytes_to_string(bytes) catch {
    e => fail("utf8 decode failed: " + e.to_string())
  }
}

///|
fn test_tmp_root() -> String {
  match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
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
  ensure_dir_tree(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
fn assert_contains(text : String, expected : String) -> Unit raise {
  if !text.contains(expected) {
    fail("expected markdown to contain: " + expected)
  }
}

///|
test "epub convert main_process basic spine sample" {
  let out_dir = test_tmp_root() + "/epub-convert-basic"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let input = resolve_sample_path(
    "samples/main_process/epub/epub_basic_spine.epub",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/epub/epub_basic_spine.md",
    ),
  )
  let doc = @epub.parse_epub(input, out_dir, 6)
  let actual = @cor.emit_markdown(doc)
  assert_eq(actual, expected)

  let asset_path = out_dir +
    "/assets/archive/OEBPS_chapter-01.xhtml/image01.png"
  if !@fs.path_exists(asset_path) {
    fail("expected remapped EPUB asset file: " + asset_path)
  }
  if !doc.asset_origins.val.contains(
      "assets/archive/OEBPS_chapter-01.xhtml/image01.png",
    ) {
    fail("expected remapped EPUB asset origin")
  }
}

///|
test "epub convert remote image falls back without asset export" {
  let out_dir = test_tmp_root() + "/epub-convert-remote"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let input = resolve_sample_path("samples/test/epub/epub_remote_image.epub")
  let doc = @epub.parse_epub(input, out_dir, 6)
  let markdown = @cor.emit_markdown(doc)
  assert_contains(markdown, "# OPS/chapter.xhtml")
  if markdown.contains("assets/") {
    fail("remote EPUB image should not export asset paths")
  }
  if doc.asset_origins.val.length() != 0 {
    fail("remote EPUB image should not create asset origins")
  }
}

///|
test "epub convert unsupported spine media emits warning block" {
  let out_dir = test_tmp_root() + "/epub-convert-unsupported-spine"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let input = resolve_sample_path(
    "samples/test/epub/epub_unsupported_spine_media.epub",
  )
  let doc = @epub.parse_epub(input, out_dir, 6)
  let markdown = @cor.emit_markdown(doc)
  assert_contains(markdown, "# OPS/diagram.svg")
  assert_contains(
    markdown, "> Skipped: unsupported spine media type: image/svg+xml",
  )
}

///|
test "epub convert multi chapter spine order sample" {
  let out_dir = test_tmp_root() + "/epub-convert-spine-order"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let input = resolve_sample_path(
    "samples/main_process/epub/epub_multi_chapter_spine_order.epub",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/epub/epub_multi_chapter_spine_order.md",
    ),
  )
  let doc = @epub.parse_epub(input, out_dir, 6)
  assert_eq(@cor.emit_markdown(doc), expected)
}

///|
test "epub convert local image sample remaps assets" {
  let out_dir = test_tmp_root() + "/epub-convert-local-image"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let input = resolve_sample_path(
    "samples/main_process/epub/epub_local_image_basic.epub",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/epub/epub_local_image_basic.md",
    ),
  )
  let doc = @epub.parse_epub(input, out_dir, 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  if !doc.asset_origins.val.contains(
      "assets/archive/OPS_chapter.xhtml/image01.png",
    ) {
    fail("expected remapped EPUB asset origin")
  }
}

///|
test "epub convert linear no spine item is skipped" {
  let out_dir = test_tmp_root() + "/epub-convert-linear-no"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let input = resolve_sample_path(
    "samples/main_process/epub/epub_linear_no_current_behavior.epub",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/epub/epub_linear_no_current_behavior.md",
    ),
  )
  let doc = @epub.parse_epub(input, out_dir, 6)
  assert_eq(@cor.emit_markdown(doc), expected)
}

///|
test "epub convert unsupported spine warning sample" {
  let out_dir = test_tmp_root() + "/epub-convert-unsupported-warning"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let input = resolve_sample_path(
    "samples/main_process/epub/epub_unsupported_spine_warning.epub",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/epub/epub_unsupported_spine_warning.md",
    ),
  )
  let doc = @epub.parse_epub(input, out_dir, 6)
  assert_eq(@cor.emit_markdown(doc), expected)
}
