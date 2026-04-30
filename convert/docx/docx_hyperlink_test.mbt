///|
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
fn has_link(xs : Array[@cor.Inline], text : String, href : String) -> Bool {
  for x in xs {
    match x {
      @cor.Inline::Link(t, h) => if t == text && h == href { return true }
      _ => ()
    }
  }
  false
}

///|
fn has_any_link(xs : Array[@cor.Inline]) -> Bool {
  for x in xs {
    match x {
      @cor.Inline::Link(_, _) => return true
      _ => ()
    }
  }
  false
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
fn test_tmp_root() -> String {
  ".tmp"
}

///|
fn docx_test_out_dir(name : String) -> String raise {
  ensure_dir_tree(test_tmp_root())
  let root = test_tmp_root() + "/docx"
  ensure_dir(root)
  let dir = root + "/" + name
  recreate_clean_dir(dir)
  dir
}

///|
test "docx hyperlink basic and paragraph preservation" {
  let basic_out = docx_test_out_dir("link_basic")
  let basic_doc = parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_link_basic.docx"),
    basic_out,
    6,
  )
  let basic_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/docx/docx_link_basic.md"),
  )
  assert_eq(@cor.emit_markdown(basic_doc), basic_expected)
  match basic_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "OpenAI", "https://openai.com"))
    _ => fail("docx_link_basic should emit RichParagraph")
  }

  let para_out = docx_test_out_dir("link_in_paragraph")
  let para_doc = parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_link_in_paragraph.docx"),
    para_out,
    6,
  )
  let para_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_link_in_paragraph.md",
    ),
  )
  assert_eq(@cor.emit_markdown(para_doc), para_expected)
  match para_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "OpenAI", "https://openai.com"))
    _ => fail("docx_link_in_paragraph should emit RichParagraph")
  }
}

///|
test "docx hyperlink merges multiple runs and missing rel degrades to text" {
  let multi_out = docx_test_out_dir("link_multiple_runs")
  let multi_doc = parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/docx_link_multiple_runs.docx",
    ),
    multi_out,
    6,
  )
  let multi_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_link_multiple_runs.md",
    ),
  )
  assert_eq(@cor.emit_markdown(multi_doc), multi_expected)
  match multi_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "OpenAI Docs", "https://openai.com/docs"))
    _ => fail("docx_link_multiple_runs should emit RichParagraph")
  }

  let negative_out = docx_test_out_dir("link_missing_rel_negative")
  let negative_doc = parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/docx_link_missing_rel_negative.docx",
    ),
    negative_out,
    6,
  )
  let negative_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_link_missing_rel_negative.md",
    ),
  )
  assert_eq(@cor.emit_markdown(negative_doc), negative_expected)
  match negative_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) => assert_true(!has_any_link(inlines))
    _ => fail("docx_link_missing_rel_negative should emit RichParagraph")
  }
}
