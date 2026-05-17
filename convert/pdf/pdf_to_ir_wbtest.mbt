///|
fn ir_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn make_ir_block(
  block_index : Int,
  kind : PdfConvertBlockKind,
  text : String,
  rich_inlines : Array[@cor.Inline]?,
) -> PdfConvertBlock {
  let bbox = ir_rect(40.0, 720.0, 220.0, 740.0)
  {
    _page_index: 0,
    block_index,
    kind,
    text,
    rich_inlines,
    line_start: block_index,
    line_end: block_index,
    source_block_index: block_index,
    source_block_line_count: 1,
    source_block_kind: @model.PdfTextBlockKind::HeadingCandidate,
    source_block_bbox: bbox,
    source_block_dominant_font_size: Some(16.0),
    source_block_dominant_font_name: Some("Test"),
    is_heading_candidate: true,
    is_noise_candidate: false,
    is_header_footer_candidate: false,
    is_artifact_candidate: false,
    is_caption_candidate: false,
    is_table_cell_candidate: false,
    dominant_language: None,
    writing_direction: @model.PdfWritingDirection::LeftToRight,
    _bbox: bbox,
    dominant_font_size: Some(16.0),
    dominant_font_name: Some("Test"),
    top_y: 740.0,
    left_x: 40.0,
    line_count: 1,
    first_indent_left: Some(40.0),
    last_indent_left: Some(40.0),
    first_indent_right: None,
    last_indent_right: None,
    first_alignment_hint: Some("left"),
    last_alignment_hint: Some("left"),
    first_line_gap_before: Some(12.0),
    last_line_gap_after: Some(8.0),
    first_line_height: Some(16.0),
    last_line_height: Some(16.0),
    first_baseline_y: Some(732.0),
    last_baseline_y: Some(732.0),
    first_is_wrapped_candidate: false,
    last_is_wrapped_candidate: false,
    first_is_same_paragraph_with_prev_candidate: false,
    last_is_same_paragraph_with_prev_candidate: false,
  }
}

///|
fn make_ir_annotation(
  annotation_index : Int,
  subtype : String,
  subject : String?,
  contents : String?,
) -> PdfConvertAnnotation {
  {
    _page_index: 0,
    _annotation_index: annotation_index,
    subtype,
    _bbox: ir_rect(40.0, 700.0, 120.0, 720.0),
    uri: None,
    dest: None,
    target_page: None,
    object_ref: Some((annotation_index + 20).to_string() + " 0 R"),
    contents,
    subject,
    color: None,
  }
}

///|
test "pdf to ir preserves rich heading links when block already has rich inlines" {
  let block = make_ir_block(
    0,
    PdfConvertBlockKind::Heading,
    "mozilla.org",
    Some([@cor.Inline::Link("mozilla.org", "https://example.com")]),
  )
  let doc = convert_pdf_blocks_to_ir(
    {
      pages: [
        {
          _page_index: 0,
          media_box: Some(ir_rect(0.0, 0.0, 595.0, 842.0)),
          crop_box: None,
          lines: [],
          blocks: [block],
          images: [],
          annotations: [],
          objects: [PdfConvertPageObject::TextBlock(block)],
        },
      ],
    },
    6,
    "sample.pdf",
  )

  match doc.blocks.val[0] {
    @cor.Block::RichHeading(
      _,
      [@cor.Inline::Link("mozilla.org", "https://example.com")]
    ) => ()
    _ => fail("expected RichHeading with link preserved")
  }
}

///|
test "pdf to ir appends meaningful non-link annotations in appendix" {
  let block = {
    ..make_ir_block(0, PdfConvertBlockKind::Paragraph, "Body paragraph", None),
    is_heading_candidate: false,
  }
  let doc = convert_pdf_blocks_to_ir(
    {
      pages: [
        {
          _page_index: 0,
          media_box: Some(ir_rect(0.0, 0.0, 595.0, 842.0)),
          crop_box: None,
          lines: [],
          blocks: [block],
          images: [],
          annotations: [
            make_ir_annotation(
              0,
              "/Text",
              Some("Reviewer"),
              Some("Important note"),
            ),
            make_ir_annotation(
              1,
              "/Highlight",
              Some("Comment"),
              Some("Marked text"),
            ),
            make_ir_annotation(2, "/Popup", None, None),
            {
              ..make_ir_annotation(3, "/Link", None, Some("ignored")),
              uri: Some("https://example.com"),
            },
          ],
          objects: [PdfConvertPageObject::TextBlock(block)],
        },
      ],
    },
    6,
    "sample.pdf",
  )

  let actual = doc.blocks.val.map(fn(block) {
    match block {
      @cor.Block::Heading(level, text) => "H" + level.to_string() + ":" + text
      @cor.Block::RichHeading(level, _) => "RH" + level.to_string()
      @cor.Block::Paragraph(text) => "P:" + text
      _ => "OTHER"
    }
  })
  let expected = [
    "P:Body paragraph", "H2:Annotations", "P:Text (page 1): Reviewer — Important note",
    "P:Highlight (page 1): Comment — Marked text",
  ]
  if actual.length() != expected.length() {
    fail(
      "expected " +
      expected.length().to_string() +
      " blocks, got " +
      actual.length().to_string(),
    )
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail(
        "annotation appendix mismatch at " +
        i.to_string() +
        ": expected `" +
        expected[i] +
        "`, got `" +
        actual[i] +
        "`",
      )
    }
  }
}

///|
test "pdf to ir appends internal destination links conservatively in appendix" {
  let block = {
    ..make_ir_block(0, PdfConvertBlockKind::Paragraph, "Go to page 2", None),
    is_heading_candidate: false,
  }
  let doc = convert_pdf_blocks_to_ir(
    {
      pages: [
        {
          _page_index: 0,
          media_box: Some(ir_rect(0.0, 0.0, 595.0, 842.0)),
          crop_box: None,
          lines: [],
          blocks: [block],
          images: [],
          annotations: [
            {
              ..make_ir_annotation(0, "/Link", None, None),
              dest: Some("[1 0 R /FitR -264 -45 877 813]"),
              target_page: Some(2),
            },
            {
              ..make_ir_annotation(1, "/Link", None, Some("ignored uri link")),
              uri: Some("https://example.com"),
            },
          ],
          objects: [PdfConvertPageObject::TextBlock(block)],
        },
      ],
    },
    6,
    "sample.pdf",
  )

  let actual = doc.blocks.val.map(fn(block) {
    match block {
      @cor.Block::Heading(level, text) => "H" + level.to_string() + ":" + text
      @cor.Block::Paragraph(text) => "P:" + text
      _ => "OTHER"
    }
  })
  let expected = ["P:Go to page 2", "H2:Annotations", "P:Link (page 1): page 2"]
  if actual.length() != expected.length() {
    fail(
      "expected " +
      expected.length().to_string() +
      " blocks, got " +
      actual.length().to_string(),
    )
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail(
        "internal link appendix mismatch at " +
        i.to_string() +
        ": expected `" +
        expected[i] +
        "`, got `" +
        actual[i] +
        "`",
      )
    }
  }
}

///|
test "pdf to ir keeps named destination labels when internal links resolve to a page" {
  let block = {
    ..make_ir_block(
      0,
      PdfConvertBlockKind::Paragraph,
      "Named destination link",
      None,
    ),
    is_heading_candidate: false,
  }
  let doc = convert_pdf_blocks_to_ir(
    {
      pages: [
        {
          _page_index: 0,
          media_box: Some(ir_rect(0.0, 0.0, 595.0, 842.0)),
          crop_box: None,
          lines: [],
          blocks: [block],
          images: [],
          annotations: [
            {
              ..make_ir_annotation(0, "/Link", None, None),
              dest: Some("(chapter-one)"),
              target_page: Some(2),
            },
          ],
          objects: [PdfConvertPageObject::TextBlock(block)],
        },
      ],
    },
    6,
    "sample.pdf",
  )

  let actual = doc.blocks.val.map(fn(block) {
    match block {
      @cor.Block::Heading(level, text) => "H" + level.to_string() + ":" + text
      @cor.Block::Paragraph(text) => "P:" + text
      _ => "OTHER"
    }
  })
  let expected = [
    "P:Named destination link", "H2:Annotations", "P:Link (page 1): destination chapter-one -> page 2",
  ]
  if actual.length() != expected.length() {
    fail(
      "expected " +
      expected.length().to_string() +
      " blocks, got " +
      actual.length().to_string(),
    )
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail(
        "named-destination annotation appendix mismatch at " +
        i.to_string() +
        ": expected `" +
        expected[i] +
        "`, got `" +
        actual[i] +
        "`",
      )
    }
  }
}

///|
test "pdf to ir appends bookmark outline items conservatively" {
  let out = convert_pdf_blocks_to_ir({ pages: [] }, 6, "sample.pdf")
  append_pdf_outlines_to_ir(
    out,
    [
      {
        title: "Parent",
        page_index: Some(0),
        dest: None,
        children: [
          { title: "Child", page_index: Some(1), dest: None, children: [] },
          {
            title: "Named target",
            page_index: Some(2),
            dest: Some("section-2"),
            children: [],
          },
          {
            title: "Detached target",
            page_index: None,
            dest: Some("appendix-a"),
            children: [],
          },
        ],
      },
    ],
    "sample.pdf",
  )

  let actual = out.blocks.val.map(fn(block) {
    match block {
      @cor.Block::Heading(level, text) => "H" + level.to_string() + ":" + text
      @cor.Block::ListItem(_, level, text) =>
        "LI" + level.to_string() + ":" + text
      _ => "OTHER"
    }
  })
  let expected = [
    "H2:Bookmarks", "LI0:Parent -> page 1", "LI1:Child -> page 2", "LI1:Named target -> destination section-2 -> page 3",
    "LI1:Detached target -> destination appendix-a",
  ]
  if actual.length() != expected.length() {
    fail(
      "expected " +
      expected.length().to_string() +
      " blocks, got " +
      actual.length().to_string(),
    )
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail(
        "bookmark appendix mismatch at " +
        i.to_string() +
        ": expected `" +
        expected[i] +
        "`, got `" +
        actual[i] +
        "`",
      )
    }
  }
}

///|
test "pdf to ir bullet parser ignores pure separator lines" {
  match
    try_parse_bullet_list_item_for_ir("- ----------------------------------") {
    None => ()
    Some(_) => fail("separator line should not become bullet list item")
  }

  match try_parse_bullet_list_item_for_ir("* Important note") {
    Some("Important note") => ()
    _ => fail("real bullet item should still parse")
  }
}

///|
test "pdf to ir skips redundant bookmark appendix when headings already surface the same titles" {
  let out = @cor.new_document()
  @cor.push(out, @cor.Block::Heading(2, "Summary"))
  @cor.push(out, @cor.Block::Heading(2, "Details"))
  @cor.push(out, @cor.Block::Heading(2, "Conclusion"))

  append_pdf_outlines_to_ir(
    out,
    [
      { title: "Summary", page_index: Some(0), dest: None, children: [] },
      { title: "Details", page_index: Some(1), dest: None, children: [] },
      { title: "Conclusion", page_index: Some(2), dest: None, children: [] },
    ],
    "sample.pdf",
  )

  assert_eq(out.blocks.val.length(), 3)
}

///|
test "pdf to ir skips degenerate subject-only annotation shells" {
  let block = {
    ..make_ir_block(0, PdfConvertBlockKind::Paragraph, "Body paragraph", None),
    is_heading_candidate: false,
  }
  let doc = convert_pdf_blocks_to_ir(
    {
      pages: [
        {
          _page_index: 0,
          media_box: Some(ir_rect(0.0, 0.0, 595.0, 842.0)),
          crop_box: None,
          lines: [],
          blocks: [block],
          images: [],
          annotations: [
            {
              ..make_ir_annotation(0, "/FreeText", Some("Typewriter"), None),
              _bbox: ir_rect(28.8538, 765.348, 29.8538, 775.392),
            },
            {
              ..make_ir_annotation(1, "/Ink", Some("Pencil"), None),
              _bbox: ir_rect(174.391, 632.654, 285.965, 729.449),
            },
          ],
          objects: [PdfConvertPageObject::TextBlock(block)],
        },
      ],
    },
    6,
    "sample.pdf",
  )

  let actual = doc.blocks.val.map(fn(block) {
    match block {
      @cor.Block::Heading(level, text) => "H" + level.to_string() + ":" + text
      @cor.Block::RichHeading(level, _) => "RH" + level.to_string()
      @cor.Block::Paragraph(text) => "P:" + text
      _ => "OTHER"
    }
  })
  let expected = [
    "P:Body paragraph", "H2:Annotations", "P:Ink (page 1): Pencil",
  ]
  if actual.length() != expected.length() {
    fail(
      "expected " +
      expected.length().to_string() +
      " blocks, got " +
      actual.length().to_string(),
    )
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail(
        "degenerate annotation-shell mismatch at " +
        i.to_string() +
        ": expected `" +
        expected[i] +
        "`, got `" +
        actual[i] +
        "`",
      )
    }
  }
}
