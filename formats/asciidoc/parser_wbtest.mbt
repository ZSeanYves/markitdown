///|
test "AsciiDoc parser lowers headings lists blocks tables admonitions and includes" {
  let text = [
    "= Title", "", "Paragraph with *bold* and https://example.test[link].", "", "* First",
    "* Second", "", "NOTE: Important body", "", "include::chapter.adoc[]", "", "[source,python]",
    "----", "print(1)", "----", "", "|===", "|Name |Value", "|A |1", "|===", "",
    "[quote]", "____", "Quoted body", "____",
  ].join("\n")
  let result = (asciidoc_parser().parse)(
    @input.input_from_text_with_format(text, "complex.adoc", Some(Asciidoc)),
    @parser.new_parse_context(Asciidoc),
  ).unwrap()
  assert_true(result.document.unwrap().blocks.length() >= 4)
  assert_true(result.diagnostics.metrics.get("heading_count") != Some("0"))
  assert_true(result.diagnostics.metrics.get("block_count") != Some("0"))
  assert_true(result.diagnostics.pass_trace.contains("parse:asciidoc_parser"))
}

///|
test "AsciiDoc edge syntax retains attributes xrefs footnotes and local includes" {
  let text = [
    ":project: MarkItDown", "", "See <<target,{project}>> and footnote:[A note].",
    "", "[[target]]", "== Target", "", "WARNING: Retained warning", "", "include::local-only.adoc[]",
    "", "image::diagram.png[Architecture]",
  ].join("\n")
  let result = (asciidoc_parser().parse)(
    @input.input_from_text_with_format(text, "edge.adoc", Some(Asciidoc)),
    @parser.new_parse_context(Asciidoc),
  ).unwrap()
  let blocks = result.document.unwrap().blocks
  assert_true(blocks.any(block => block.text.contains("Retained warning")))
  assert_true(blocks.any(block => block.text.contains("local-only.adoc")))
  assert_true(blocks.any(block => block.text.contains("A note")))
  let images = blocks.filter(block => block.kind == Image)
  assert_eq(images.length(), 1)
  assert_true(images[0].attrs.get("src") == Some("diagram.png"))
  assert_true(images[0].attrs.get("alt") == Some("Architecture"))
  assert_true(images[0].attrs.get("reference_only") == Some("true"))
}

///|
test "AsciiDoc malformed unclosed source block degrades under control" {
  let parsed = @dmark.parse_asciidoc_document("[source]\n----\nvisible code")
  assert_true(parsed.blocks.length() > 0)
  assert_true(parsed.blocks.any(block => block.text.contains("visible code")))
}

///|
test "AsciiDoc nested ordered and bullet lists retain items" {
  let parsed = @dmark.parse_asciidoc_document(
    ". one\n.. two\n* bullet\n** nested",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("one"))
  assert_true(joined.contains("two"))
  assert_true(joined.contains("nested"))
}

///|
test "AsciiDoc attributes expand in visible text" {
  let parsed = @dmark.parse_asciidoc_document(":name: MoonBit\n\nHello {name}")
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("MoonBit"))
}

///|
test "AsciiDoc xref and footnote preserve targets and bodies" {
  let parsed = @dmark.parse_asciidoc_document(
    "See <<target,Target>> footnote:[Footnote body].\n\n[[target]]\n== Target",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("Target"))
  assert_true(joined.contains("Footnote body"))
}

///|
test "AsciiDoc table retains headers and cells" {
  let parsed = @dmark.parse_asciidoc_document("|===\n|Name |Value\n|A |1\n|===")
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("Name"))
  assert_true(joined.contains("Value"))
  assert_true(joined.contains("A"))
}

///|
test "AsciiDoc image remains a local reference" {
  let result = (asciidoc_parser().parse)(
    @input.input_from_text_with_format(
      "image::local.png[Local image]",
      "image.adoc",
      Some(Asciidoc),
    ),
    @parser.new_parse_context(Asciidoc),
  ).unwrap()
  let images = result.document.unwrap().blocks.filter(block => {
    block.kind == Image
  })
  assert_eq(images.length(), 1)
  assert_true(images[0].attrs.get("src") == Some("local.png"))
  assert_true(images[0].attrs.get("path") == Some("assets/asciidoc-local.png"))
  assert_true(images[0].attrs.get("source_path") == Some("local.png"))
  assert_true(images[0].attrs.get("asset_id") == Some("asciidoc-image-1"))
  assert_true(images[0].attrs.get("alt") == Some("Local image"))
  assert_true(images[0].attrs.get("reference_only") == Some("true"))
}

///|
test "AsciiDoc include traversal remains reference-only" {
  let parsed = @dmark.parse_asciidoc_document("include::../../secret.adoc[]")
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("../../secret.adoc"))
}

///|
test "AsciiDoc admonitions retain labels and visible body" {
  let parsed = @dmark.parse_asciidoc_document(
    "WARNING: Visible warning\n\n[NOTE]\n====\nVisible note\n====",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("Visible warning"))
  assert_true(joined.contains("Visible note"))
}
