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
fn write_profile_report(
  path : String,
  counters : DocxProfilingCounters,
  total_elapsed_ms : UInt64,
  styles_elapsed_ms : UInt64,
  numbering_elapsed_ms : UInt64,
  scan_elapsed_ms : UInt64,
) -> Unit raise {
  let report = "total_elapsed_ms=" +
    total_elapsed_ms.to_string() +
    "\n" +
    "styles_elapsed_ms=" +
    styles_elapsed_ms.to_string() +
    "\n" +
    "numbering_elapsed_ms=" +
    numbering_elapsed_ms.to_string() +
    "\n" +
    "scan_elapsed_ms=" +
    scan_elapsed_ms.to_string() +
    "\n" +
    "paragraphs_seen=" +
    counters.paragraphs_seen.val.to_string() +
    "\n" +
    "hyperlink_nodes_seen=" +
    counters.hyperlink_nodes_seen.val.to_string() +
    "\n" +
    "collect_wt_inlines_calls=" +
    counters.collect_wt_inlines_calls.val.to_string() +
    "\n" +
    "collect_wt_text_calls=" +
    counters.collect_wt_text_calls.val.to_string() +
    "\n" +
    "collect_wt_text_total_input_len=" +
    counters.collect_wt_text_total_input_len.val.to_string() +
    "\n" +
    "hyperlink_target_lookup_calls=" +
    counters.hyperlink_target_lookup_calls.val.to_string() +
    "\n" +
    "relationship_context_read_count=" +
    counters.relationship_context_read_count.val.to_string() +
    "\n" +
    "xml_attr_lookup_calls=" +
    counters.xml_attr_lookup_calls.val.to_string() +
    "\n" +
    "xml_tag_scan_calls=" +
    counters.xml_tag_scan_calls.val.to_string() +
    "\n" +
    "xml_tag_scan_total_search_len=" +
    counters.xml_tag_scan_total_search_len.val.to_string() +
    "\n" +
    "slice_to_string_calls=" +
    counters.slice_to_string_calls.val.to_string() +
    "\n" +
    "styles_read_count=" +
    counters.styles_read_count.val.to_string() +
    "\n" +
    "styles_parse_calls=" +
    counters.styles_parse_calls.val.to_string() +
    "\n" +
    "styles_xml_len=" +
    counters.styles_xml_len.val.to_string() +
    "\n" +
    "style_nodes_seen=" +
    counters.style_nodes_seen.val.to_string() +
    "\n" +
    "style_lookup_calls=" +
    counters.style_lookup_calls.val.to_string() +
    "\n" +
    "style_lookup_misses=" +
    counters.style_lookup_misses.val.to_string() +
    "\n" +
    "styles_tag_scan_calls=" +
    counters.styles_tag_scan_calls.val.to_string() +
    "\n" +
    "styles_tag_scan_total_search_len=" +
    counters.styles_tag_scan_total_search_len.val.to_string() +
    "\n" +
    "styles_elapsed_ms_counter=" +
    counters.styles_elapsed_ms.val.to_string() +
    "\n" +
    "document_has_pstyle=" +
    counters.document_has_pstyle.val.to_string() +
    "\n" +
    "document_has_numpr=" +
    counters.document_has_numpr.val.to_string() +
    "\n"
  @fs.write_string_to_file(path, report, encoding="utf8") catch {
    e => fail("write profile report failed: " + e.to_string())
  }
}

///|
fn inline_text_for_docx_test(inlines : Array[@cor.Inline]) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline {
      @cor.Inline::Text(text) => out.write_string(text)
      @cor.Inline::Break => out.write_string("\n")
      @cor.Inline::Link(text, _href) => out.write_string(text)
    }
  }
  out.to_string()
}

///|
test "docx hyperlink profiling captures hot path counters" {
  let out_dir = docx_test_out_dir("link_many_performance_guard")
  let counter : Ref[Int] = { val: 0 }
  let profile : DocxProfilingCounters = {
    paragraphs_seen: { val: 0 },
    hyperlink_nodes_seen: { val: 0 },
    collect_wt_inlines_calls: { val: 0 },
    collect_wt_text_calls: { val: 0 },
    collect_wt_text_total_input_len: { val: 0 },
    hyperlink_target_lookup_calls: { val: 0 },
    relationship_context_read_count: { val: 0 },
    xml_attr_lookup_calls: { val: 0 },
    xml_tag_scan_calls: { val: 0 },
    xml_tag_scan_total_search_len: { val: 0 },
    slice_to_string_calls: { val: 0 },
    styles_read_count: { val: 0 },
    styles_parse_calls: { val: 0 },
    styles_xml_len: { val: 0 },
    style_nodes_seen: { val: 0 },
    style_lookup_calls: { val: 0 },
    style_lookup_misses: { val: 0 },
    styles_tag_scan_calls: { val: 0 },
    styles_tag_scan_total_search_len: { val: 0 },
    styles_elapsed_ms: { val: 0 },
    document_has_pstyle: { val: false },
    document_has_numpr: { val: false },
  }
  let prev_profile = current_docx_profile.val
  let prev_enabled = docx_profile_enabled.val
  current_docx_profile.val = profile
  docx_profile_enabled.val = true
  defer {
    current_docx_profile.val = prev_profile
    docx_profile_enabled.val = prev_enabled
  }
  let started = @env.now()
  let path = resolve_sample_path(
    "samples/main_process/docx/docx_link_many_performance_guard.docx",
  )
  let pkg = open_docx(path)
  let doc_xml = pkg.read_text_required("word/document.xml")
  let document_features = scan_docx_document_features(doc_xml)
  let rel_ctx = pkg.read_document_relationship_context(Some(counter))
  let asset_by_target = build_docx_asset_path_map(rel_ctx, out_dir)
  let styles_started = @env.now()
  let styles = pkg.load_styles_for_document(document_features)
  let styles_elapsed_ms = @env.now() - styles_started
  let numbering_started = @env.now()
  let numbering = pkg.load_numbering()
  let numbering_elapsed_ms = @env.now() - numbering_started
  pkg.extract_media_by_relationships(
    rel_ctx,
    asset_by_target,
    out_dir + "/assets",
  )
  reset_docx_scan_profile_counters()
  let scan_started = @env.now()
  let doc = scan_document(
    doc_xml,
    rel_ctx,
    asset_by_target,
    styles,
    numbering,
    empty_docx_note_bundle(),
    empty_docx_header_footer_bundle(),
    empty_docx_text_box_bundle(),
    6,
    @cor.basename(path),
  )
  let scan_elapsed_ms = @env.now() - scan_started
  let total_elapsed_ms = @env.now() - started

  assert_eq(counter.val, 1)
  assert_eq(profile.relationship_context_read_count.val, 1)
  assert_eq(profile.hyperlink_nodes_seen.val, 80)
  assert_eq(profile.hyperlink_target_lookup_calls.val, 80)
  assert_eq(profile.collect_wt_text_calls.val, 0)
  assert_false(profile.document_has_pstyle.val)
  assert_eq(profile.styles_read_count.val, 0)
  assert_eq(profile.styles_parse_calls.val, 0)
  assert_eq(profile.styles_xml_len.val, 0)
  assert_eq(profile.style_nodes_seen.val, 0)
  assert_eq(profile.styles_tag_scan_calls.val, 0)
  assert_true(styles_elapsed_ms < 100)
  assert_true(profile.xml_tag_scan_total_search_len.val < 1_200_000)
  write_profile_report(
    test_tmp_root() + "/docx/link_many_profile.txt",
    profile,
    total_elapsed_ms,
    styles_elapsed_ms,
    numbering_elapsed_ms,
    scan_elapsed_ms,
  )

  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("[Link 001](https://example.com/001)"))
  assert_true(markdown.contains("[Link 080](https://example.com/080)"))
}

///|
test "docx style-linked numbering fallback and ordered heuristic stay conservative" {
  let styles = parse_styles_xml(
    "<w:styles>" +
    "<w:style w:type=\"paragraph\" w:styleId=\"ListNumber2\">" +
    "<w:name w:val=\"List Number 2\"/>" +
    "<w:pPr><w:numPr><w:ilvl w:val=\"1\"/><w:numId w:val=\"9\"/></w:numPr></w:pPr>" +
    "</w:style>" +
    "</w:styles>",
  )
  let numbering = parse_numbering_xml(
    "<w:numbering>" +
    "<w:abstractNum w:abstractNumId=\"7\">" +
    "<w:lvl w:ilvl=\"1\"><w:numFmt w:val=\"decimal\"/></w:lvl>" +
    "</w:abstractNum>" +
    "<w:num w:numId=\"9\"><w:abstractNumId w:val=\"7\"/></w:num>" +
    "</w:numbering>",
  )

  let list_blocks = scan_paragraph(
    "<w:pPr><w:pStyle w:val=\"ListNumber2\"/></w:pPr><w:r><w:t>ordered item</w:t></w:r>",
    empty_docx_relationship_context(),
    Map::new(),
    styles,
    numbering,
    6,
    None,
  )
  match list_blocks[0] {
    @cor.Block::RichListItem(true, level, inlines) => {
      assert_eq(level, 1)
      assert_eq(inline_text_for_docx_test(inlines), "ordered item")
    }
    @cor.Block::ListItem(true, level, text) => {
      assert_eq(level, 1)
      assert_eq(text, "ordered item")
    }
    _ => fail("style-linked numbering should emit ordered list semantics")
  }

  let fallback_blocks = scan_paragraph(
    "<w:numPr/><w:r><w:t>1. ordered fallback</w:t></w:r>",
    empty_docx_relationship_context(),
    Map::new(),
    empty_styles(),
    empty_numbering(),
    6,
    None,
  )
  match fallback_blocks[0] {
    @cor.Block::RichListItem(true, 0, inlines) =>
      assert_eq(inline_text_for_docx_test(inlines), "1. ordered fallback")
    @cor.Block::ListItem(true, 0, text) =>
      assert_eq(text, "1. ordered fallback")
    _ => fail("ordered fallback should not degrade to unordered list")
  }
}

///|
test "docx notes parser and append sections stay conservative and deterministic" {
  let footnotes = parse_footnotes_xml(
    "<w:footnotes>" +
    "<w:footnote w:id=\"-1\"><w:p><w:r><w:t>separator</w:t></w:r></w:p></w:footnote>" +
    "<w:footnote w:id=\"2\"><w:p><w:r><w:t>Second footnote</w:t></w:r></w:p></w:footnote>" +
    "<w:footnote w:id=\"1\"><w:p><w:r><w:t>First footnote</w:t></w:r></w:p></w:footnote>" +
    "</w:footnotes>",
  )
  let endnotes = parse_endnotes_xml(
    "<w:endnotes>" +
    "<w:endnote w:id=\"1\"><w:p><w:r><w:t>Only endnote</w:t></w:r></w:p></w:endnote>" +
    "</w:endnotes>",
  )
  let comments = parse_comments_xml(
    "<w:comments>" +
    "<w:comment w:id=\"3\" w:author=\"Alice\" w:initials=\"A\"><w:p><w:r><w:t>Review comment</w:t></w:r></w:p></w:comment>" +
    "</w:comments>",
  )

  assert_eq(footnotes.length(), 2)
  assert_true(!footnotes.contains(-1))
  assert_eq(footnotes.get(1).unwrap().text, "First footnote")
  assert_eq(endnotes.get(1).unwrap().text, "Only endnote")
  assert_eq(comments.get(3).unwrap().author.unwrap(), "Alice")

  let ledger = new_docx_reference_ledger()
  let scan = scan_docx_inline_text(
    "<w:r><w:t>Body</w:t></w:r>" +
    "<w:r><w:footnoteReference w:id=\"2\"/></w:r>" +
    "<w:r><w:endnoteReference w:id=\"1\"/></w:r>" +
    "<w:r><w:commentReference w:id=\"3\"/></w:r>",
    empty_docx_relationship_context(),
    Some(ledger),
  )
  assert_eq(scan.text, "Body[^1][^e1] [comment 1]")
  assert_eq(ledger.footnote_order.length(), 1)
  assert_eq(ledger.footnote_order[0], 2)
  assert_eq(ledger.endnote_order[0], 1)
  assert_eq(ledger.comment_order[0], 3)

  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::RichParagraph(scan.inlines))
  append_docx_notes_sections(
    doc,
    {
      footnotes_by_id: footnotes,
      endnotes_by_id: endnotes,
      comments_by_id: comments,
    },
    ledger,
    "notes.docx",
  )

  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("Body[^1][^e1] [comment 1]"))
  assert_true(markdown.contains("## Footnotes"))
  assert_true(markdown.contains("[^1]: Second footnote"))
  assert_true(markdown.contains("## Endnotes"))
  assert_true(markdown.contains("[^e1]: Only endnote"))
  assert_true(markdown.contains("## Comments"))
  assert_true(markdown.contains("1. Alice: Review comment"))
}

///|
test "docx header footer refs and page-number filtering stay conservative" {
  let rel_ctx : DocxRelationshipContext = {
    document_relationships: [],
    targets_by_rid: { "rId10": "word/header1.xml", "rId11": "word/footer1.xml" },
    hyperlink_targets_by_rid: {},
  }
  let refs = parse_docx_header_footer_references(
    "<w:document><w:body>" +
    "<w:sectPr>" +
    "<w:headerReference w:type=\"default\" r:id=\"rId10\"/>" +
    "<w:footerReference w:type=\"even\" r:id=\"rId11\"/>" +
    "</w:sectPr>" +
    "<w:sectPr>" +
    "<w:headerReference w:type=\"default\" r:id=\"rId10\"/>" +
    "</w:sectPr>" +
    "</w:body></w:document>",
    rel_ctx,
  )
  assert_eq(refs.length(), 2)
  assert_eq(refs[0].part_name, "word/header1.xml")
  assert_eq(refs[1].part_name, "word/footer1.xml")

  let visible_header = render_docx_part_text_for_header_footer(
    "<w:hdr><w:p><w:r><w:t>Project Header</w:t></w:r></w:p></w:hdr>",
  )
  assert_eq(visible_header, "Project Header")

  let page_only = "<w:ftr>" +
    "<w:p>" +
    "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" +
    "<w:r><w:instrText> PAGE </w:instrText></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>" +
    "<w:r><w:t>1</w:t></w:r>" +
    "</w:p>" +
    "</w:ftr>"
  assert_true(docx_header_footer_is_page_number_only(page_only))

  let mixed = "<w:ftr><w:p><w:r><w:t>Confidential</w:t></w:r>" +
    "<w:r><w:instrText> PAGE </w:instrText></w:r><w:r><w:t>1</w:t></w:r></w:p></w:ftr>"
  assert_false(docx_header_footer_is_page_number_only(mixed))

  let doc = @cor.new_document()
  append_docx_header_footer_sections(
    doc,
    {
      headers: [
        {
          kind: DocxHeaderFooterKind::Header,
          ref_type: DocxHeaderFooterRefType::Default,
          relationship_id: "rId10",
          part_name: "word/header1.xml",
          text: "Project Header",
          is_page_number_only: false,
        },
      ],
      footers: [
        {
          kind: DocxHeaderFooterKind::Footer,
          ref_type: DocxHeaderFooterRefType::Default,
          relationship_id: "rId11",
          part_name: "word/footer1.xml",
          text: "1",
          is_page_number_only: true,
        },
      ],
    },
    "header_footer.docx",
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## Headers"))
  assert_true(markdown.contains("### Header 1 Default"))
  assert_true(markdown.contains("Project Header"))
  assert_true(!markdown.contains("## Footers"))
}

///|
test "docx text box extraction stays append-only and strips inline duplication" {
  let xml = "<w:p><w:r><w:t>Body before.</w:t></w:r></w:p>" +
    "<w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent>" +
    "<w:p><w:r><w:t>Text box body.</w:t></w:r></w:p>" +
    "</w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p>"
  let stripped = strip_docx_text_box_content_xml(xml)
  assert_true(!stripped.contains("Text box body."))

  let boxes = collect_docx_text_boxes_from_xml(
    xml,
    empty_docx_relationship_context(),
    {},
    empty_styles(),
    empty_numbering(),
    DocxTextBoxContext::Body,
    "word/document.xml",
    None,
  )
  assert_eq(boxes.length(), 1)
  assert_eq(boxes[0].textbox_index, 1)
  assert_eq(boxes[0].source_part, "word/document.xml")
  assert_eq(boxes[0].blocks.length(), 1)
  match boxes[0].blocks[0] {
    @cor.Block::Paragraph(text) => assert_eq(text, "Text box body.")
    @cor.Block::RichParagraph(inlines) => {
      let text = inline_text_for_docx_test(inlines)
      assert_eq(text, "Text box body.")
    }
    _ =>
      fail("text box paragraph should lower conservatively to text paragraph")
  }

  let doc = @cor.new_document()
  append_docx_text_box_sections(doc, { items: boxes }, "textbox.docx")
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## Text Boxes"))
  assert_true(markdown.contains("### Text Box 1"))
  assert_true(markdown.contains("Text box body."))
}

///|
test "docx revision stripping preserves inserted text while skipping deleted and moved-from text" {
  let xml = "<w:p>" +
    "<w:r><w:t>Keep </w:t></w:r>" +
    "<w:del><w:r><w:delText>drop</w:delText></w:r></w:del>" +
    "<w:ins><w:r><w:t>inserted</w:t></w:r></w:ins>" +
    "<w:moveFrom><w:r><w:t> old</w:t></w:r></w:moveFrom>" +
    "<w:moveTo><w:r><w:t> moved</w:t></w:r></w:moveTo>" +
    "</w:p>"
  let scan = scan_docx_inline_text(
    strip_docx_deleted_revision_xml(xml),
    empty_docx_relationship_context(),
    None,
  )
  assert_eq(scan.text, "Keep inserted moved")
  assert_true(!scan.text.contains("drop"))
  assert_true(!scan.text.contains("old"))
}

///|
test "docx nested table scan stays content-preserving for outer and inner cells" {
  let rows = scan_table_block(
    "<w:tr>" +
    "<w:tc><w:p><w:r><w:t>Outer A</w:t></w:r></w:p></w:tc>" +
    "<w:tc>" +
    "<w:p><w:r><w:t>Outer B</w:t></w:r></w:p>" +
    "<w:tbl>" +
    "<w:tr><w:tc><w:p><w:r><w:t>Inner 1</w:t></w:r></w:p></w:tc></w:tr>" +
    "</w:tbl>" +
    "</w:tc>" +
    "</w:tr>",
  )
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].length(), 2)
  assert_eq(rows[0][0], "Outer A")
  assert_true(rows[0][1].contains("Outer B"))
  assert_true(rows[0][1].contains("Inner 1"))
}

///|
test "docx merged and rich-run table text degrades conservatively without losing visible content" {
  let rows = scan_table_block(
    "<w:tr>" +
    "<w:tc><w:tcPr><w:gridSpan w:val=\"2\"/></w:tcPr><w:p><w:r><w:t>Merged Head</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:p><w:r><w:t>Right</w:t></w:r></w:p></w:tc>" +
    "</w:tr>" +
    "<w:tr>" +
    "<w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Bold</w:t></w:r><w:r><w:t> text</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:p><w:r><w:rPr><w:i/></w:rPr><w:t>Italic</w:t></w:r></w:p></w:tc>" +
    "</w:tr>",
  )
  assert_eq(rows.length(), 2)
  assert_eq(rows[0][0], "Merged Head")
  assert_eq(rows[0][1], "Right")
  assert_eq(rows[1][0], "Bold text")
  assert_eq(rows[1][1], "Italic")
}
