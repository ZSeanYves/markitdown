///|
test "rich table with explicit header row emits markdown header" {
  let doc = @cor.new_document()
  @cor.push(
    doc,
    @cor.Block::RichTable({
      rows: [["Name", "Role"], ["Ada", "Engineer"], ["Grace", "Admiral"]],
      header_rows: 1,
      hints: None,
    }),
  )

  let expected = "| Name | Role |\n| --- | --- |\n| Ada | Engineer |\n| Grace | Admiral |\n"
  assert_eq(@cor.emit_markdown(doc), expected)
}

///|
test "rich table without header emits synthetic markdown headers" {
  let doc = @cor.new_document()
  @cor.push(
    doc,
    @cor.Block::RichTable({
      rows: [["Ada", "Engineer"], ["Grace", "Admiral"]],
      header_rows: 0,
      hints: None,
    }),
  )

  let expected = "| Column 1 | Column 2 |\n| --- | --- |\n| Ada | Engineer |\n| Grace | Admiral |\n"
  assert_eq(@cor.emit_markdown(doc), expected)
}

///|
test "markdown emitter note ref without definition uses marker-only fallback" {
  let doc = @cor.new_document()
  @cor.push(
    doc,
    @cor.Block::RichParagraph([
      @cor.Inline::Text("approaches,"),
      @cor.Inline::NoteRef({
        note_id: "",
        marker: "3",
        kind: @cor.NoteKind::Footnote,
        source_kind: @cor.NoteSourceKind::PdfSuperscript,
        confidence: @cor.NoteConfidence::Medium,
        body_status: @cor.NoteBodyStatus::Missing,
      }),
      @cor.Inline::Text(" we present AutoGen."),
    ]),
  )

  let expected = "approaches,^3 we present AutoGen.\n"
  assert_eq(@cor.emit_markdown(doc), expected)
}

///|
test "markdown emitter note ref with definition emits footnote syntax" {
  let doc = @cor.new_document()
  @cor.push(
    doc,
    @cor.Block::RichParagraph([
      @cor.Inline::Text("approaches,"),
      @cor.Inline::NoteRef({
        note_id: "3",
        marker: "3",
        kind: @cor.NoteKind::Footnote,
        source_kind: @cor.NoteSourceKind::DocxFootnoteRef,
        confidence: @cor.NoteConfidence::High,
        body_status: @cor.NoteBodyStatus::Resolved,
      }),
      @cor.Inline::Text(" we present AutoGen."),
    ]),
  )
  @cor.push_note_definition(doc, {
    note_id: "3",
    marker: "3",
    kind: @cor.NoteKind::Footnote,
    blocks: [@cor.Block::Paragraph("We refer to Appendix A.")],
    placement: @cor.NotePlacement::DocumentEnd,
    source_kind: @cor.NoteSourceKind::DocxFootnoteRef,
    body_status: @cor.NoteBodyStatus::Resolved,
    origin: None,
  })

  let expected = "approaches,[^3] we present AutoGen.\n\n[^3]: We refer to Appendix A.\n"
  assert_eq(@cor.emit_markdown(doc), expected)
}
