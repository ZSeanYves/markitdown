///|
fn resolve_html_parser_sample_path(path : String) -> String raise {
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
fn read_html_parser_utf8_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @cor.utf8_bytes_to_string(bytes) catch {
    e => fail("utf8 decode failed: " + e.to_string())
  }
}

///|
test "html strips utf8 bom and normalizes crlf" {
  let doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_bom_utf8.html",
    ),
    "",
    6,
  )
  let expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_bom_utf8.md",
    ),
  )
  assert_eq(@cor.emit_markdown(doc), expected)
}

///|
test "html keeps current conservative entity and wrapper behavior stable" {
  let entities_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_entities.html",
    ),
    "",
    6,
  )
  let entities_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_entities.md",
    ),
  )
  assert_eq(@cor.emit_markdown(entities_doc), entities_expected)

  let details_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_details_summary.html",
    ),
    "",
    6,
  )
  let details_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_details_summary.md",
    ),
  )
  assert_eq(@cor.emit_markdown(details_doc), details_expected)

  let semantic_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_semantic_sectioning.html",
    ),
    "",
    6,
  )
  let semantic_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_semantic_sectioning.md",
    ),
  )
  assert_eq(@cor.emit_markdown(semantic_doc), semantic_expected)
}

///|
test "html remote images keep current downgrade policy" {
  let inline_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_remote_image_current_behavior.html",
    ),
    "",
    6,
  )
  let inline_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_remote_image_current_behavior.md",
    ),
  )
  assert_eq(@cor.emit_markdown(inline_doc), inline_expected)

  let figure_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_remote_figure_current_behavior.html",
    ),
    "",
    6,
  )
  let figure_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_remote_figure_current_behavior.md",
    ),
  )
  assert_eq(
    trim_one_trailing_newline(@cor.emit_markdown(figure_doc)),
    trim_one_trailing_newline(figure_expected),
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
