///|
test "markdown escape helpers cover punctuation minimal mode and unicode" {
  assert_eq(
    escape_markdown_inline_text("\\`*_{}[]()#+<>|"),
    "\\\\\\`\\*\\_\\{\\}\\[\\]\\(\\)\\#\\+\\<\\>\\|",
  )
  assert_eq(
    escape_markdown_inline_text_for_format("*a* `b`", Some("minimal")),
    "*a* \\`b\\`",
  )
  assert_eq(escape_markdown_inline_text("😀"), "&#128512;")
  let out = StringBuilder::new()
  write_escaped_markdown_inline_text_for_format_to(out, "a\\b", Some("minimal"))
  assert_eq(out.to_string(), "a\\\\b")
  assert_true(markdown_punctuation_needs_escape('|'))
  assert_true(!markdown_punctuation_needs_escape('a'))
  assert_true(markdown_literal_tail_needs_escape('*'))
}

///|
test "markdown fence helpers exceed embedded backtick runs" {
  assert_eq(safe_code_fence("plain"), "```")
  assert_eq(safe_code_fence("```inside``"), "````")
  assert_eq(safe_inline_code_fence("plain"), "`")
  assert_eq(safe_inline_code_fence("a``b"), "```")
  assert_eq(repeat_char_string('#', 0), "")
  assert_eq(repeat_char_string('#', 3), "###")
}

///|
test "markdown literal line escaping blocks accidental structures" {
  let lines = render_literal_markdown_lines(
    "# heading\n> quote\n- item\n+ plus\n* star\n1. ordered\n2) ordered\n---\n___\nplain\n",
  )
  assert_true(lines[0].has_prefix("\\#"))
  assert_true(lines[1].has_prefix("\\>"))
  assert_true(lines[2].has_prefix("\\-"))
  assert_true(lines[3].has_prefix("\\+"))
  assert_true(lines[4].has_prefix("\\*"))
  assert_eq(lines[5], "1\\. ordered")
  assert_eq(lines[6], "2\\) ordered")
  assert_eq(lines[7], "\\---")
  assert_eq(lines[8], "\\_\\_\\_")
  assert_eq(lines[9], "plain")
  assert_eq(lines[10], "")
  assert_true(ordered_list_marker_parts("12. item") == Some((2, 3)))
  assert_true(ordered_list_marker_parts("item") is None)
  assert_true(thematic_break_marker("***") == Some("*"))
  assert_true(thematic_break_marker("**x") is None)
  assert_true(thematic_break_marker("--") is None)
  assert_true(is_ascii_digit('9'))
  assert_true(!is_ascii_digit('x'))
  assert_eq(clamp_heading_level("0"), 1)
  assert_eq(clamp_heading_level("9"), 6)
  assert_eq(clamp_heading_level("3"), 3)
  assert_eq(clamp_heading_level("bad"), 1)
}
