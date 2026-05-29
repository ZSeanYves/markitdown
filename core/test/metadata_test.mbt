///|
test "metadata sidecar old entrypoint emits null document" {
  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Paragraph("hello"))

  let json = @cor.emit_metadata_json(doc, "sample.html", "html", "sample.md")
  if !json.contains("\"document\": null") {
    fail("old metadata entrypoint should emit null document")
  }
}

///|
test "metadata sidecar serializes document properties" {
  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Paragraph("hello"))
  let props = @cor.metadata_document_properties(
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

  let json = @cor.emit_metadata_json_with_document_properties(
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

///|
test "metadata sidecar serializes rich table structure" {
  let doc = @cor.new_document()
  @cor.push(
    doc,
    @cor.Block::RichTable({
      rows: [["Name", "Role"], ["Alice", "Engineer"]],
      header_rows: 1,
      hints: None,
    }),
  )

  let json = @cor.emit_metadata_json(doc, "sample.json", "json", "sample.md")
  if !json.contains("\"block_type\": \"table\"") {
    fail("rich table metadata should keep table block type")
  }
  if !json.contains("\"text\": \"Name | Role\\nAlice | Engineer\"") {
    fail("rich table metadata should keep flat table text")
  }
  if !json.contains("\"table\": {") {
    fail("rich table metadata should contain table object")
  }
  if !json.contains("\"rows\": [") {
    fail("rich table metadata should contain table rows")
  }
  if !json.contains("[\"Name\", \"Role\"]") {
    fail("rich table metadata should serialize header row")
  }
  if !json.contains("\"header_rows\": 1") {
    fail("rich table metadata should serialize header_rows")
  }
  if !json.contains("\"version\": \"1\"") {
    fail("rich table metadata should keep version 1")
  }
}

///|
test "metadata sidecar omits legacy table structure" {
  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Table([["Name", "Role"], ["Alice", "Engineer"]]))

  let json = @cor.emit_metadata_json(doc, "sample.csv", "csv", "sample.md")
  if !json.contains("\"block_type\": \"table\"") {
    fail("legacy table metadata should keep table block type")
  }
  if !json.contains("\"text\": \"Name | Role\\nAlice | Engineer\"") {
    fail("legacy table metadata should keep flat table text")
  }
  if json.contains("\"table\":") {
    fail("legacy table metadata should not synthesize table object")
  }
}

///|
test "metadata sidecar serializes note definitions when present" {
  let doc = @cor.new_document()
  @cor.push(
    doc,
    @cor.Block::RichParagraph([
      @cor.Inline::Text("Body"),
      @cor.Inline::NoteRef({
        note_id: "1",
        marker: "1",
        kind: @cor.NoteKind::Footnote,
        source_kind: @cor.NoteSourceKind::DocxFootnoteRef,
        confidence: @cor.NoteConfidence::High,
        body_status: @cor.NoteBodyStatus::Resolved,
      }),
    ]),
  )
  @cor.push_note_definition(doc, {
    note_id: "1",
    marker: "1",
    kind: @cor.NoteKind::Footnote,
    blocks: [@cor.Block::Paragraph("Footnote body.")],
    placement: @cor.NotePlacement::DocumentEnd,
    source_kind: @cor.NoteSourceKind::DocxFootnoteBody,
    body_status: @cor.NoteBodyStatus::Resolved,
    origin: None,
  })

  let json = @cor.emit_metadata_json(doc, "sample.docx", "docx", "sample.md")
  if !json.contains("\"note_definition_count\": 1") {
    fail("metadata summary should count note definitions")
  }
  if !json.contains("\"note_definitions\": [") {
    fail("metadata should include note_definitions when present")
  }
  if !json.contains("\"source_kind\": \"docx_footnote_body\"") {
    fail("metadata should serialize note source kind")
  }
  if !json.contains("\"text_preview\": \"Footnote body.\"") {
    fail("metadata should serialize note body preview")
  }
}

///|
test "metadata sidecar omits empty note definitions section" {
  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Paragraph("plain"))

  let json = @cor.emit_metadata_json(doc, "sample.txt", "txt", "sample.md")
  if json.contains("\"note_definitions\":") {
    fail("metadata should not add empty note_definitions churn")
  }
  if json.contains("\"note_definition_count\":") {
    fail("metadata should not add zero note_definition_count churn")
  }
}
