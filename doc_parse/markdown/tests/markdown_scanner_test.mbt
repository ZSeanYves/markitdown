///|
test "markdown scanner tracks paragraphs blanks headings lists quotes thematic breaks and table-like rows" {
  let doc = @md.scan_markdown_document(
    "# Title\n" +
    "Body line 1\n" +
    "Body line 2\n" +
    "\n" +
    "> quote\n" +
    "- item\n" +
    "1) ordered\n" +
    "---\n" +
    "| a | b |\n",
  )
  let report = @md.inspect_markdown_document(doc)

  assert_eq(doc.blocks.length(), 8)
  assert_eq(report.heading_count, 1)
  assert_eq(report.blank_line_count, 1)
  assert_eq(report.blockquote_count, 1)
  assert_eq(report.list_item_count, 2)
  assert_eq(report.thematic_break_count, 1)
  assert_eq(report.table_like_row_count, 1)
  assert_eq(report.issue_count, 0)

  assert_true(doc.blocks[1].kind == @md.MarkdownBlockKind::ParagraphLike)
  assert_eq(doc.blocks[1].raw_text, "Body line 1\nBody line 2")
}

///|
test "markdown scanner detects yaml and toml frontmatter conservatively" {
  let yaml_doc = @md.scan_markdown_document(
    "---\n" + "title: Demo\n" + "---\n" + "\n" + "# Heading\n",
  )
  let yaml_report = @md.inspect_markdown_document(yaml_doc)
  match yaml_doc.frontmatter {
    Some(frontmatter) => {
      assert_true(frontmatter.kind == @md.MarkdownFrontmatterKind::Yaml)
      assert_true(frontmatter.closed)
      assert_eq(frontmatter.line_start, 1)
      assert_eq(frontmatter.line_end, 3)
      assert_eq(frontmatter.content, "title: Demo")
    }
    None => fail("expected yaml frontmatter")
  }
  assert_true(yaml_report.has_frontmatter)
  assert_eq(yaml_report.frontmatter_count, 1)
  assert_eq(yaml_report.heading_count, 1)

  let toml_doc = @md.scan_markdown_document(
    "+++\n" + "title = \"Demo\"\n" + "+++\n",
  )
  match toml_doc.frontmatter {
    Some(frontmatter) =>
      assert_true(frontmatter.kind == @md.MarkdownFrontmatterKind::Toml)
    None => fail("expected toml frontmatter")
  }
}

///|
test "markdown scanner detects fenced code info strings and tilde fences" {
  let doc = @md.scan_markdown_document(
    "```moonbit\n" +
    "let x = 1\n" +
    "```\n" +
    "\n" +
    "~~~json\n" +
    "{}\n" +
    "~~~\n",
  )
  let report = @md.inspect_markdown_document(doc)

  assert_eq(report.fenced_code_count, 2)
  assert_eq(report.unclosed_fence_count, 0)

  match doc.blocks[0].fenced_code {
    Some(info) => {
      assert_true(info.fence_char == '`')
      assert_eq(info.fence_length, 3)
      assert_true(info.info_string == Some("moonbit"))
      assert_true(info.closed)
    }
    None => fail("expected fenced code info")
  }

  match doc.blocks[2].fenced_code {
    Some(info) => {
      assert_true(info.fence_char == '~')
      assert_true(info.info_string == Some("json"))
    }
    None => fail("expected tilde fence info")
  }
}

///|
test "markdown scanner reports unclosed frontmatter and unclosed fence" {
  let frontmatter_doc = @md.scan_markdown_document("---\n" + "title: Demo\n")
  let frontmatter_validation = @md.validate_markdown_document(frontmatter_doc)
  assert_eq(frontmatter_validation.issue_count, 1)
  assert_true(
    frontmatter_validation.issues[0].kind ==
    @md.MarkdownValidationIssueKind::UnclosedFrontmatter,
  )

  let fence_doc = @md.scan_markdown_document("```ts\n" + "const x = 1\n")
  let fence_report = @md.inspect_markdown_document(fence_doc)
  let fence_validation = @md.validate_markdown_document(fence_doc)
  assert_eq(fence_report.fenced_code_count, 1)
  assert_eq(fence_report.unclosed_fence_count, 1)
  assert_eq(fence_validation.issue_count, 1)
  assert_true(
    fence_validation.issues[0].kind ==
    @md.MarkdownValidationIssueKind::UnclosedFence,
  )
}

///|
test "markdown scanner preserves raw html candidates and inline markdown literally" {
  let doc = @md.scan_markdown_document(
    "<div class=\"x\">\n" + "[A](b) and *em*\n",
  )
  let report = @md.inspect_markdown_document(doc)

  assert_eq(report.html_block_candidate_count, 1)
  assert_eq(doc.blocks.length(), 2)
  assert_true(doc.blocks[0].kind == @md.MarkdownBlockKind::HtmlBlockCandidate)
  assert_true(doc.blocks[1].kind == @md.MarkdownBlockKind::ParagraphLike)
  assert_eq(doc.blocks[1].raw_text, "[A](b) and *em*")
}

///|
test "markdown scanner handles setext headings bom and line-ending normalization" {
  let doc = @md.scan_markdown_document("\u{FEFF}Title\r\n---\r\n\r\nBody\r")
  let report = @md.inspect_markdown_document(doc)

  assert_eq(doc.line_count, 4)
  assert_eq(report.heading_count, 1)
  assert_eq(report.blank_line_count, 1)
  assert_true(doc.blocks[0].kind == @md.MarkdownBlockKind::HeadingSetext)
  assert_eq(doc.blocks[0].raw_text, "Title\n---")
}
