///|
test "metadata sidecar old entrypoint emits null document" {
  let doc = new_document()
  push(doc, Block::Paragraph("hello"))

  let json = emit_metadata_json(doc, "sample.html", "html", "sample.md")
  if !json.contains("\"document\": null") {
    fail("old metadata entrypoint should emit null document")
  }
}

///|
test "metadata sidecar serializes document properties" {
  let doc = new_document()
  push(doc, Block::Paragraph("hello"))
  let props = metadata_document_properties(
    Some("Title"),
    Some("Subject"),
    Some("Creator"),
    Some("Description"),
    Some("keyword"),
    Some("2026-01-01T00:00:00Z"),
    Some("2026-01-02T00:00:00Z"),
    Some("App"),
    Some("1"),
    Some("2"),
    Some("3"),
    Some("4"),
  )

  let json = emit_metadata_json_with_document_properties(
    doc,
    "sample.docx",
    "docx",
    "sample.md",
    Some(props),
  )

  if !json.contains("\"document\": {") {
    fail("metadata should contain document object")
  }
  if !json.contains("\"title\": \"Title\"") {
    fail("metadata should contain document title")
  }
  if !json.contains("\"summary\"") {
    fail("metadata should still contain summary")
  }
}
