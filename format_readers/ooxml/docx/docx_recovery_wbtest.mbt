///|
test "DOCX body recovery preserves mixed structures and diagnoses unknown nodes" {
  let warnings : Array[DocxSourceWarning] = []
  let xml = "<w:document><w:body>" +
    "<w:bookmarkStart w:id=\"1\" w:name=\"start\"/>" +
    "<w:p><w:pPr><w:pStyle w:val=\"Heading2\"/><w:jc w:val=\"center\"/>" +
    "<w:numPr><w:ilvl w:val=\"1\"/><w:numId w:val=\"7\"/></w:numPr></w:pPr>" +
    "<w:r><w:t>Hello</w:t><w:br w:type=\"page\"/><w:sym w:font=\"Wingdings\" w:char=\"F0A7\"/></w:r>" +
    "<w:hyperlink w:anchor=\"target\"><w:r><w:t>jump</w:t></w:r></w:hyperlink>" +
    "<m:oMath><m:r><m:t>x+1</m:t></m:r></m:oMath></w:p>" +
    "<w:sdt><w:sdtPr><w:alias w:val=\"profile\"/></w:sdtPr><w:sdtContent>" +
    "<w:p><w:r><w:t>controlled text</w:t></w:r></w:p></w:sdtContent></w:sdt>" +
    "<w:custom><w:t>unknown but bounded</w:t></w:custom>" +
    "<w:sectPr></w:sectPr></w:body></w:document>"
  let blocks = parse_docx_body_blocks(
    "word/document.xml",
    xml,
    [],
    None,
    warnings,
  )
  assert_true(blocks.length() >= 5)
  assert_true(blocks.any(block => block.text.contains("Hello")))
  assert_true(blocks.any(block => block.text.contains("controlled text")))
  assert_true(blocks.any(block => block.kind == Unknown))
  assert_true(blocks.any(block => block.kind == Structural))
  assert_true(warnings.any(warning => warning.kind == UnknownBodyNode))
  assert_true(warnings.any(warning => warning.kind == UnsupportedMath))
}

///|
test "DOCX nested table recovery retains cells spans headers and depth" {
  let warnings : Array[DocxSourceWarning] = []
  let xml = "<w:document><w:body><w:tbl><w:tr><w:trPr><w:tblHeader/></w:trPr>" +
    "<w:tc><w:tcPr><w:gridSpan w:val=\"2\"/><w:vMerge w:val=\"restart\"/></w:tcPr>" +
    "<w:p><w:r><w:t>outer</w:t></w:r></w:p>" +
    "<w:bookmarkEnd w:id=\"1\"/>" +
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>inner</w:t></w:r></w:p></w:tc></w:tr></w:tbl>" +
    "<w:sdt><w:sdtContent><w:p><w:r><w:t>cell control</w:t></w:r></w:p></w:sdtContent></w:sdt>" +
    "<w:unexpected/></w:tc></w:tr></w:tbl></w:body></w:document>"
  let blocks = parse_docx_body_blocks(
    "word/document.xml",
    xml,
    [],
    None,
    warnings,
  )
  assert_eq(blocks.length(), 1)
  let table = blocks[0].table.unwrap()
  assert_eq(table.rows.length(), 1)
  assert_true(table.rows[0].is_header)
  let cell = table.rows[0].cells[0]
  assert_true(cell.grid_span == Some("2"))
  assert_true(cell.has_nested_table)
  assert_true(cell.max_nested_depth >= 1)
  assert_true(cell.text.contains("outer"))
  assert_true(cell.text.contains("inner"))
  assert_true(cell.text.contains("cell control"))
  assert_true(warnings.any(warning => warning.kind == UnknownBodyNode))
}

///|
test "DOCX inline relationship recovery preserves labels and source diagnostics" {
  let key = docx_source_key("word/document.xml", 0, "inline")
  let warnings : Array[DocxSourceWarning] = []

  let anchored_xml = "<w:hyperlink w:anchor=\"section-1\"><w:r><w:t>Section</w:t></w:r></w:hyperlink>"
  let anchored = parse_docx_hyperlink(
    anchored_xml,
    0,
    anchored_xml.length(),
    key,
    [],
    None,
    warnings,
  )
  assert_eq(anchored.text, "Section")
  assert_true(anchored.target == Some("#section-1"))
  assert_true(anchored.target_mode == Some(Internal))

  let missing_xml = "<w:hyperlink r:id=\"rMissing\"><w:r><w:t>Still readable</w:t></w:r></w:hyperlink>"
  let missing = parse_docx_hyperlink(
    missing_xml,
    0,
    missing_xml.length(),
    key,
    [],
    None,
    warnings,
  )
  assert_eq(missing.text, "Still readable")
  assert_true(missing.target is None)

  let no_target_xml = "<w:hyperlink><w:r><w:t>Label</w:t></w:r></w:hyperlink>"
  ignore(
    parse_docx_hyperlink(
      no_target_xml,
      0,
      no_target_xml.length(),
      key,
      [],
      None,
      warnings,
    ),
  )
  assert_true(warnings.length() >= 2)
  assert_true(warnings.all(warning => warning.kind == MissingHyperlinkTarget))
}

///|
test "DOCX drawing and VML metadata survive unresolved media relationships" {
  let key = docx_source_key("word/document.xml", 1, "media")
  let warnings : Array[DocxSourceWarning] = []
  let drawing_xml = "<w:drawing><wp:inline><wp:docPr id=\"3\" name=\"Diagram\"/>" +
    "<pic:pic><pic:nvPicPr><pic:cNvPr id=\"4\" name=\"Picture\" descr=\"fallback alt\" title=\"fallback title\"/></pic:nvPicPr>" +
    "<pic:blipFill><a:blip r:embed=\"rMissing\"><a:extLst><a:ext><asvg:svgBlip r:embed=\"rSvg\"/></a:ext></a:extLst></a:blip></pic:blipFill>" +
    "</pic:pic></wp:inline></w:drawing>"
  let drawing = parse_docx_drawing_anchor(
    drawing_xml,
    0,
    drawing_xml.length(),
    key,
    [],
    None,
    warnings,
  )
  assert_true(drawing.doc_pr_id == Some("3"))
  assert_true(drawing.descr == Some("fallback alt"))
  assert_true(drawing.title == Some("fallback title"))
  assert_true(drawing.media is Some(_))
  assert_eq(drawing.alternate_media.length(), 1)

  let pict_xml = "<w:pict><v:shape id=\"shape1\" type=\"#rect\" style=\"width:1in\" alt=\"vml alt\" title=\"vml title\">" +
    "<v:imagedata r:link=\"rExternal\"/></v:shape></w:pict>"
  let shape = parse_docx_shape_anchor(
    pict_xml,
    0,
    pict_xml.length(),
    key,
    [],
    None,
    warnings,
  )
  assert_true(shape.shape_id == Some("shape1"))
  assert_true(shape.alt_text == Some("vml alt"))
  assert_true(shape.title == Some("vml title"))
  assert_true(shape.media is Some(_))
  assert_true(warnings.length() >= 3)

  assert_true(
    read_docx_blip_relationship_ref("<a:blip r:link=\"r1\"/>").relationship_kind ==
    Link,
  )
  assert_true(
    read_docx_blip_relationship_ref("<a:blip r:id=\"r2\"/>").relationship_kind ==
    Unknown,
  )
  assert_true(
    read_docx_vml_image_relationship_ref("<v:imagedata r:embed=\"r3\"/>").relationship_id ==
    Some("r3"),
  )
  assert_true(
    read_docx_vml_image_relationship_ref("<v:imagedata r:link=\"r4\"/>").relationship_kind ==
    Link,
  )
}

///|
test "DOCX run scanner preserves the supported inline vocabulary in source order" {
  let key = docx_source_key("word/document.xml", 2, "run")
  let warnings : Array[DocxSourceWarning] = []
  let xml = "<w:rPr><w:b/></w:rPr><w:t>A &amp; B</w:t><w:tab/>" +
    "<w:br/><w:br w:type=\"column\"/><w:br w:type=\"textWrapping\"/><w:br w:type=\"other\"/><w:cr/>" +
    "<mc:AlternateContent><mc:Choice Requires=\"w14\"><w:t>choice</w:t></mc:Choice>" +
    "<mc:Fallback><w:t>fallback</w:t></mc:Fallback></mc:AlternateContent>" +
    "<w:drawing><wp:inline><wp:docPr id=\"8\" name=\"inline\" descr=\"diagram\"/>" +
    "<a:blip r:embed=\"missingDrawing\"/></wp:inline></w:drawing>" +
    "<w:pict><v:shape id=\"v1\" alt=\"legacy diagram\"><v:imagedata r:id=\"missingVml\"/></v:shape></w:pict>" +
    "<w:txbxContent><w:p><w:r><w:t>textbox</w:t></w:r></w:p></w:txbxContent>" +
    "<w:hyperlink w:anchor=\"inside\"><w:r><w:t>inside link</w:t></w:r></w:hyperlink>" +
    "<w:fldChar w:fldCharType=\"begin\"/><w:instrText> PAGE </w:instrText>" +
    "<w:fldSimple w:instr=\"DATE\"><w:r><w:t>2026-07-11</w:t></w:r></w:fldSimple>" +
    "<m:oMath><m:r><m:t>y=2</m:t></m:r></m:oMath>" +
    "<w:bookmarkStart w:id=\"2\" w:name=\"inside\"/><w:bookmarkEnd w:id=\"2\"/>" +
    "<w:proofErr w:type=\"spellStart\"/><w:annotationRef/>" +
    "<w:footnoteReference w:id=\"4\"/><w:endnoteReference w:id=\"5\"/><w:commentReference w:id=\"6\"/>" +
    "<w:sym w:font=\"Symbol\" w:char=\"03B1\"/><w:softHyphen/><w:noBreakHyphen/>" +
    "<w:ins w:id=\"7\" w:author=\"Editor\"><w:r><w:t>inserted</w:t></w:r></w:ins>" +
    "<w:unsupported><w:t>bounded</w:t></w:unsupported>"
  let inlines = parse_docx_run_inlines(xml, key, [], None, warnings)
  assert_true(inlines.length() >= 20)
  let text = docx_source_inline_text(inlines)
  assert_true(text.contains("A & B"))
  assert_true(text.contains("choice"))
  assert_true(text.contains("inside link"))
  assert_true(text.contains("2026-07-11"))
  assert_true(text.contains("inserted"))
  assert_true(warnings.any(warning => warning.kind == UnsupportedInline))
  assert_true(warnings.any(warning => warning.kind == UnsupportedMath))
  assert_true(warnings.any(warning => warning.kind == MissingMediaTarget))

  inlines.push(Unsupported("legacy-inline"))
  let model_warnings : Array[DocxWarning] = []
  let normalized = docx_model_inlines(inlines, model_warnings, key, [])
  assert_eq(normalized.length(), inlines.length())
  assert_true(model_warnings.any(warning => warning.kind == UnsupportedInline))
  assert_true(model_warnings.any(warning => warning.kind == UnsupportedMath))
  assert_true(model_warnings.any(warning => warning.kind == TrackedChange))
  docx_add_unresolved_inline_ref_warnings(
    normalized,
    key,
    [],
    [],
    [],
    model_warnings,
  )
  assert_true(
    model_warnings.any(warning => warning.kind == UnresolvedFootnoteRef),
  )
  assert_true(
    model_warnings.any(warning => warning.kind == UnresolvedEndnoteRef),
  )
  assert_true(
    model_warnings.any(warning => warning.kind == UnresolvedCommentRef),
  )
}

///|
test "DOCX paragraph scanner retains fields smart tags controls and tracked changes" {
  let key = docx_source_key("word/document.xml", 3, "paragraph")
  let warnings : Array[DocxSourceWarning] = []
  let xml = "<w:pPr><w:pStyle w:val=\"BodyText\"/></w:pPr>" +
    "<w:r><w:rPr><w:rStyle w:val=\"Strong\"/><w:b/></w:rPr><w:t>lead</w:t></w:r>" +
    "<w:hyperlink w:anchor=\"bookmark\"><w:r><w:t>bookmark link</w:t></w:r></w:hyperlink>" +
    "<w:fldSimple w:instr=\"REF bookmark\"><w:r><w:t>field result</w:t></w:r></w:fldSimple>" +
    "<w:sdt><w:sdtContent><w:r><w:t>controlled inline</w:t></w:r></w:sdtContent></w:sdt>" +
    "<w:smartTag><w:r><w:t>tagged text</w:t></w:r></w:smartTag>" +
    "<w:del w:id=\"8\" w:author=\"Editor\"><w:r><w:delText>removed</w:delText></w:r></w:del>" +
    "<w:bookmarkStart w:id=\"9\" w:name=\"bookmark\"/><w:bookmarkEnd w:id=\"9\"/>" +
    "<w:permStart w:id=\"10\"/><w:unknownInline/>"
  let runs = parse_docx_paragraph_runs(xml, key, [], None, warnings)
  assert_true(runs.length() >= 8)
  let text = docx_source_inline_text(docx_source_run_inlines(runs))
  assert_true(text.contains("lead"))
  assert_true(text.contains("bookmark link"))
  assert_true(text.contains("field result"))
  assert_true(text.contains("controlled inline"))
  assert_true(text.contains("tagged text"))
  assert_true(warnings.any(warning => warning.kind == UnsupportedInline))
}

///|
test "DOCX model resolves textbox identities conservatively and diagnoses linked media" {
  let key = docx_source_key("word/document.xml", 12, "textbox")
  let other_key = docx_source_key("word/header1.xml", 12, "textbox")
  let box_a : DocxTextBox = {
    anchor_id: "anchor-a",
    owner_part: "word/document.xml",
    relationship_id: None,
    part_name: "word/document.xml#textbox-a",
    blocks: [],
    source_key: key,
    shape_id: Some("shape-a"),
    doc_pr_id: Some("21"),
    doc_pr_name: Some("shape-a"),
    descr: Some("accessible diagram"),
    title: None,
  }
  let box_b : DocxTextBox = {
    ..box_a,
    anchor_id: "anchor-b",
    part_name: "word/document.xml#textbox-b",
    source_key: docx_source_key("word/document.xml", 13, "textbox"),
    shape_id: Some("shape-b"),
    doc_pr_id: Some("22"),
  }
  let other : DocxTextBox = {
    ..box_a,
    anchor_id: "header-anchor",
    owner_part: "word/header1.xml",
    source_key: other_key,
  }
  let boxes = [box_a, box_b, other]
  assert_true(!docx_textboxes_are_equivalent(box_a, other))
  assert_true(
    docx_textboxes_are_equivalent(box_a, { ..box_a, anchor_id: "same-doc-pr" }),
  )
  assert_true(
    docx_textboxes_are_equivalent(box_b, {
      ..box_b,
      doc_pr_id: None,
      anchor_id: "same-shape",
    }),
  )
  assert_true(docx_textbox_doc_pr_name_matches_shape_id(box_a, box_a))
  let merged = docx_merge_textboxes(
    { ..box_a, relationship_id: None, title: Some("") },
    { ..box_a, relationship_id: Some("rTextbox"), title: Some("Title") },
  )
  assert_true(merged.relationship_id == Some("rTextbox"))
  assert_true(merged.title == Some("Title"))
  assert_true(
    docx_resolve_textbox_ref(
      {
        anchor_id: Some("explicit"),
        doc_pr_id: None,
        shape_id: None,
        owner_part: "word/document.xml",
        source_key: key,
      },
      boxes,
    ) ==
    Some("explicit"),
  )
  assert_true(
    docx_resolve_textbox_ref(
      {
        anchor_id: None,
        doc_pr_id: Some("21"),
        shape_id: None,
        owner_part: "word/document.xml",
        source_key: key,
      },
      boxes,
    ) ==
    Some("anchor-a"),
  )
  assert_true(
    docx_resolve_textbox_ref(
      {
        anchor_id: None,
        doc_pr_id: Some("missing"),
        shape_id: Some("shape-b"),
        owner_part: "word/document.xml",
        source_key: key,
      },
      boxes,
    ) ==
    Some("anchor-b"),
  )
  assert_true(
    docx_resolve_textbox_ref(
      {
        anchor_id: None,
        doc_pr_id: None,
        shape_id: None,
        owner_part: "word/document.xml",
        source_key: key,
      },
      boxes,
    ) ==
    Some("anchor-a"),
  )

  let warnings : Array[DocxWarning] = []
  let external : DocxSourceMediaRef = {
    relationship_id: Some("rLink"),
    relationship_kind: Link,
    container_kind: Drawing,
    target: Some("https://example.test/image.png"),
    resolved_target: Some("https://example.test/image.png"),
    target_mode: Some(External),
    target_part: None,
    target_exists: None,
    content_type: Some("image/png"),
    alt_text: Some("remote diagram"),
    title: None,
    source_key: key,
  }
  let missing : DocxSourceMediaRef = {
    ..external,
    relationship_id: None,
    relationship_kind: Unknown,
    target: None,
    resolved_target: None,
    target_mode: None,
  }
  let normalized_media = docx_model_media_refs([external, missing], warnings)
  assert_eq(normalized_media.length(), 2)
  assert_true(warnings.any(warning => warning.kind == UnsupportedMedia))
  assert_true(warnings.any(warning => warning.kind == MissingMediaTarget))
}

///|
test "DOCX model preserves placeholder structural and unknown blocks with warnings" {
  let key = docx_source_key("word/document.xml", 20, "block")
  let table_placeholder : DocxSourceBlock = {
    kind: Table,
    source_key: key,
    paragraph_style_id: None,
    paragraph_alignment: None,
    numbering_ref: None,
    runs: [],
    table: None,
    content_control: None,
    text: "",
    inlines: [],
    structural_kind: None,
    raw_tag: Some("w:tbl"),
  }
  let control_placeholder : DocxSourceBlock = {
    ..table_placeholder,
    kind: ContentControl,
    raw_tag: Some("w:sdt"),
  }
  let structural : DocxSourceBlock = {
    ..table_placeholder,
    kind: Structural,
    raw_tag: Some("w:proofErr"),
  }
  let unknown : DocxSourceBlock = {
    ..table_placeholder,
    kind: Unknown,
    raw_tag: Some("w:futureNode"),
  }
  let warnings : Array[DocxWarning] = []
  let blocks = docx_model_blocks(
    [table_placeholder, control_placeholder, structural, unknown, unknown],
    warnings,
    [],
  )
  assert_eq(blocks.length(), 5)
  assert_true(warnings.any(warning => warning.kind == UnsupportedTable))
  assert_true(warnings.any(warning => warning.kind == UnknownBodyNode))
  assert_eq(
    warnings.filter(warning => warning.kind == UnknownBodyNode).length(),
    1,
  )
}

///|
test "DOCX source diagnostics map one-to-one into product diagnostics" {
  let source_kinds = [
    DocxSourceWarningKind::MissingMainDocument,
    MalformedDocumentXml,
    MissingHyperlinkTarget,
    MissingMediaTarget,
    MissingMediaPart,
    UnsupportedMedia,
    UnsupportedMath,
    MissingStylesPart,
    MissingNumberingPart,
    MissingContainerPart,
    NestedTable,
    UnsupportedTextbox,
    UnknownBodyNode,
    UnsupportedTable,
    UnsupportedField,
    UnsupportedBookmark,
    TrackedChange,
    UnsupportedInline,
    UnresolvedFootnoteRef,
    UnresolvedEndnoteRef,
    UnresolvedCommentRef,
  ]
  let product_kinds = [
    DocxWarningKind::MissingMainDocument,
    MalformedDocumentXml,
    MissingHyperlinkTarget,
    MissingMediaTarget,
    MissingMediaPart,
    UnsupportedMedia,
    UnsupportedMath,
    MissingStylesPart,
    MissingNumberingPart,
    MissingContainerPart,
    NestedTable,
    UnsupportedTextbox,
    UnknownBodyNode,
    UnsupportedTable,
    UnsupportedField,
    UnsupportedBookmark,
    TrackedChange,
    UnsupportedInline,
    UnresolvedFootnoteRef,
    UnresolvedEndnoteRef,
    UnresolvedCommentRef,
  ]
  for index in 0..<source_kinds.length() {
    let mapped = docx_warning_from_source({
      kind: source_kinds[index],
      message: "diagnostic " + index.to_string(),
      source_key: None,
    })
    assert_true(mapped.kind == product_kinds[index])
    assert_eq(mapped.message, "diagnostic " + index.to_string())
    assert_true(mapped.severity == Warning)
  }
}
