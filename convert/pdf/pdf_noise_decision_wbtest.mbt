///|
fn noise_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn make_noise_block(
  page_index : Int,
  block_index : Int,
  kind : PdfConvertBlockKind,
  text : String,
  bbox : @model.PdfRect,
) -> PdfConvertBlock {
  {
    _page_index: page_index,
    block_index,
    kind,
    text,
    rich_inlines: None,
    line_start: block_index,
    line_end: block_index,
    source_block_index: block_index,
    source_block_line_count: 1,
    source_block_kind: @model.PdfTextBlockKind::Text,
    source_block_bbox: bbox,
    source_block_dominant_font_size: Some(12.0),
    source_block_dominant_font_name: Some("Test"),
    is_heading_candidate: false,
    is_noise_candidate: false,
    is_header_footer_candidate: false,
    is_artifact_candidate: false,
    is_caption_candidate: false,
    is_table_cell_candidate: false,
    dominant_language: None,
    writing_direction: @model.PdfWritingDirection::LeftToRight,
    _bbox: bbox,
    dominant_font_size: Some(12.0),
    dominant_font_name: Some("Test"),
    top_y: bbox.y1,
    left_x: bbox.x0,
    line_count: 1,
    first_indent_left: Some(bbox.x0),
    last_indent_left: Some(bbox.x0),
    first_indent_right: None,
    last_indent_right: None,
    first_alignment_hint: Some("left"),
    last_alignment_hint: Some("left"),
    first_line_gap_before: Some(4.0),
    last_line_gap_after: Some(4.0),
    first_line_height: Some(12.0),
    last_line_height: Some(12.0),
    first_baseline_y: None,
    last_baseline_y: None,
    first_is_wrapped_candidate: false,
    last_is_wrapped_candidate: false,
    first_is_same_paragraph_with_prev_candidate: false,
    last_is_same_paragraph_with_prev_candidate: false,
  }
}

///|
fn make_noise_page(
  page_index : Int,
  blocks : Array[PdfConvertBlock],
  annotations : Array[PdfConvertAnnotation],
) -> PdfConvertPage {
  {
    _page_index: page_index,
    media_box: Some(noise_rect(0.0, 0.0, 400.0, 800.0)),
    crop_box: None,
    lines: [],
    blocks,
    images: [],
    annotations,
    objects: [],
  }
}

///|
fn make_noise_doc(pages : Array[PdfConvertPage]) -> PdfConvertDocument {
  { pages, }
}

///|
fn make_annotation_for_noise(
  page_index : Int,
  annotation_index : Int,
  bbox : @model.PdfRect,
) -> PdfConvertAnnotation {
  {
    _page_index: page_index,
    _annotation_index: annotation_index,
    subtype: "Link",
    _bbox: bbox,
    uri: Some("https://example.com"),
    dest: None,
    object_ref: None,
    contents: None,
    subject: None,
    color: None,
  }
}

///|
test "pdf noise evidence marks repeated top edge short text" {
  let block0 = make_noise_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "CONFIDENTIAL",
    noise_rect(40.0, 760.0, 170.0, 780.0),
  )
  let block1 = make_noise_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "CONFIDENTIAL",
    noise_rect(42.0, 758.0, 172.0, 778.0),
  )
  let repeated = build_repeated_edge_noise_index(
    make_noise_doc([
      make_noise_page(0, [block0], []),
      make_noise_page(1, [block1], []),
    ]),
  )
  let evidence = collect_edge_noise_evidence(
    make_noise_page(0, [block0], []),
    0,
    block0,
    repeated,
  )
  let tags = edge_reason_tags(evidence)
  if !tags.contains("top_edge") {
    fail("expected top_edge evidence")
  }
  if !tags.contains("repeated_across_pages") {
    fail("expected repeated_across_pages evidence")
  }
}

///|
test "pdf noise decision drops strong repeated top edge text" {
  let block0 = make_noise_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "CONFIDENTIAL",
    noise_rect(40.0, 760.0, 170.0, 780.0),
  )
  let block1 = make_noise_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "CONFIDENTIAL",
    noise_rect(42.0, 758.0, 172.0, 778.0),
  )
  let doc = make_noise_doc([
    make_noise_page(0, [block0], []),
    make_noise_page(1, [block1], []),
  ])
  let repeated = build_repeated_edge_noise_index(doc)
  let decision = decide_noise_block(
    make_noise_page(0, [block0], []),
    0,
    block0,
    repeated,
  )

  match decision.status {
    PdfNoiseDecisionStatus::Drop => ()
    _ => fail("expected drop decision")
  }
  if !decision.reason_tags.contains("top_edge") {
    fail("expected top_edge reason")
  }
  if !decision.reason_tags.contains("same_text_same_edge") {
    fail("expected same_text_same_edge reason")
  }
}

///|
test "pdf noise evidence marks bottom page number signals" {
  let block = make_noise_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "12",
    noise_rect(180.0, 12.0, 220.0, 28.0),
  )
  let repeated = build_repeated_edge_noise_index(
    make_noise_doc([make_noise_page(0, [block], [])]),
  )
  let evidence = collect_edge_noise_evidence(
    make_noise_page(0, [block], []),
    0,
    block,
    repeated,
  )
  let tags = edge_reason_tags(evidence)
  if !tags.contains("page_number_numeric") {
    fail("expected page_number_numeric evidence")
  }
  if !tags.contains("page_number_edge") {
    fail("expected page_number_edge evidence")
  }
}

///|
test "pdf noise decision drops bottom numeric page number" {
  let block = make_noise_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "12",
    noise_rect(180.0, 12.0, 220.0, 28.0),
  )
  let repeated = build_repeated_edge_noise_index(
    make_noise_doc([make_noise_page(0, [block], [])]),
  )
  let decision = decide_noise_block(
    make_noise_page(0, [block], []),
    0,
    block,
    repeated,
  )

  match decision.status {
    PdfNoiseDecisionStatus::Drop => ()
    _ => fail("expected drop decision")
  }
  if !decision.reason_tags.contains("page_number_numeric") {
    fail("expected page_number_numeric reason")
  }
  if !decision.reason_tags.contains("page_number_edge") {
    fail("expected page_number_edge reason")
  }
}

///|
test "pdf noise decision drops top edge numeric page number candidate" {
  let block = {
    ..make_noise_block(
      0,
      0,
      PdfConvertBlockKind::Paragraph,
      "3",
      noise_rect(320.0, 784.0, 344.0, 798.0),
    ),
    is_noise_candidate: true,
    is_header_footer_candidate: true,
  }
  let repeated = build_repeated_edge_noise_index(
    make_noise_doc([make_noise_page(0, [block], [])]),
  )
  let decision = decide_noise_block(
    make_noise_page(0, [block], []),
    0,
    block,
    repeated,
  )

  match decision.status {
    PdfNoiseDecisionStatus::Drop => ()
    _ => fail("expected top-edge numeric page number to drop")
  }
  if !decision.reason_tags.contains("page_number_numeric") {
    fail("expected page_number_numeric reason")
  }
  if !decision.reason_tags.contains("core_header_footer_candidate") {
    fail("expected core_header_footer_candidate reason")
  }
}

///|
test "pdf noise decision drops top edge dash page label candidate" {
  let block = {
    ..make_noise_block(
      0,
      0,
      PdfConvertBlockKind::Paragraph,
      "2 -",
      noise_rect(180.0, 784.0, 214.0, 798.0),
    ),
    is_noise_candidate: true,
    is_header_footer_candidate: true,
  }
  let repeated = build_repeated_edge_noise_index(
    make_noise_doc([make_noise_page(0, [block], [])]),
  )
  let decision = decide_noise_block(
    make_noise_page(0, [block], []),
    0,
    block,
    repeated,
  )

  match decision.status {
    PdfNoiseDecisionStatus::Drop => ()
    _ => fail("expected top-edge dash page label to drop")
  }
  if !decision.reason_tags.contains("page_count_pattern") {
    fail("expected page_count_pattern reason")
  }
  if !decision.reason_tags.contains("core_header_footer_candidate") {
    fail("expected core_header_footer_candidate reason")
  }
}

///|
test "pdf noise decision drops trailing numeric page number candidate" {
  let body = make_noise_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "Body paragraph",
    noise_rect(40.0, 360.0, 180.0, 378.0),
  )
  let trailing = {
    ..make_noise_block(
      0,
      1,
      PdfConvertBlockKind::Paragraph,
      "3",
      noise_rect(40.0, 120.0, 52.0, 134.0),
    ),
    is_noise_candidate: true,
    is_header_footer_candidate: true,
    first_line_gap_before: Some(24.0),
  }
  let page = make_noise_page(0, [body, trailing], [])
  let repeated = build_repeated_edge_noise_index(make_noise_doc([page]))
  let decision = decide_noise_block(page, 1, trailing, repeated)

  match decision.status {
    PdfNoiseDecisionStatus::Drop => ()
    _ => fail("expected trailing numeric page number to drop")
  }
  if !decision.reason_tags.contains("last_nonempty_block") {
    fail("expected last_nonempty_block reason")
  }
  if !decision.reason_tags.contains("large_gap_before") {
    fail("expected large_gap_before reason")
  }
}

///|
test "pdf noise keeps numeric text outside edge region" {
  let block = make_noise_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "12",
    noise_rect(180.0, 380.0, 220.0, 396.0),
  )
  let repeated = build_repeated_edge_noise_index(
    make_noise_doc([
      {
        ..make_noise_page(0, [block], []),
        blocks: [
          make_noise_block(
            0,
            0,
            PdfConvertBlockKind::Paragraph,
            "Body opening paragraph",
            noise_rect(40.0, 760.0, 220.0, 778.0),
          ),
          block,
          make_noise_block(
            0,
            2,
            PdfConvertBlockKind::Paragraph,
            "Body closing paragraph",
            noise_rect(40.0, 120.0, 220.0, 138.0),
          ),
        ],
      },
    ]),
  )
  let page = {
    ..make_noise_page(0, [block], []),
    blocks: [
      make_noise_block(
        0,
        0,
        PdfConvertBlockKind::Paragraph,
        "Body opening paragraph",
        noise_rect(40.0, 760.0, 220.0, 778.0),
      ),
      block,
      make_noise_block(
        0,
        2,
        PdfConvertBlockKind::Paragraph,
        "Body closing paragraph",
        noise_rect(40.0, 120.0, 220.0, 138.0),
      ),
    ],
  }
  let block = { ..block, is_noise_candidate: true }
  let page = { ..page, blocks: [page.blocks[0], block, page.blocks[2]] }
  let decision = decide_noise_block(page, 1, block, repeated)

  match decision.status {
    PdfNoiseDecisionStatus::Keep => ()
    _ => fail("expected keep decision")
  }
  if decision.reason_tags.contains("page_number_edge") ||
    decision.reason_tags.contains("top_edge") ||
    decision.reason_tags.contains("bottom_edge") {
    fail("mid-page numeric text should not carry edge-noise reasons")
  }
  if decision.reason_tags.contains("last_nonempty_block") {
    fail("mid-page numeric text should not look like trailing page number")
  }
}

///|
test "pdf noise keep reason protects body-like repeated text" {
  let block0 = make_noise_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "This repeated phrase appears in the paragraph body.",
    noise_rect(40.0, 420.0, 320.0, 438.0),
  )
  let block1 = make_noise_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "This repeated phrase appears in the paragraph body.",
    noise_rect(42.0, 418.0, 322.0, 436.0),
  )
  let doc = make_noise_doc([
    {
      ..make_noise_page(0, [block0], []),
      blocks: [
        block0,
        make_noise_block(
          0,
          1,
          PdfConvertBlockKind::Paragraph,
          "Tail paragraph",
          noise_rect(40.0, 120.0, 220.0, 138.0),
        ),
      ],
    },
    {
      ..make_noise_page(1, [block1], []),
      blocks: [
        block1,
        make_noise_block(
          1,
          1,
          PdfConvertBlockKind::Paragraph,
          "Tail paragraph",
          noise_rect(40.0, 120.0, 220.0, 138.0),
        ),
      ],
    },
  ])
  let repeated = build_repeated_edge_noise_index(doc)
  let page = {
    ..make_noise_page(0, [block0], []),
    blocks: [
      block0,
      make_noise_block(
        0,
        1,
        PdfConvertBlockKind::Paragraph,
        "Tail paragraph",
        noise_rect(40.0, 120.0, 220.0, 138.0),
      ),
    ],
  }
  let decision = decide_noise_block(page, 0, block0, repeated)
  match decision.status {
    PdfNoiseDecisionStatus::Keep => ()
    _ => fail("expected keep decision for body-like text")
  }
  if !decision.reason_tags.contains("body_like_guard") {
    fail("expected body_like_guard reason")
  }
  if !decision.reason_tags.contains("long_sentence_guard") {
    fail("expected long_sentence_guard for body-like repeated text")
  }
}

///|
test "pdf noise evidence marks heading-like repeated edge" {
  let block0 = {
    ..make_noise_block(
      0,
      0,
      PdfConvertBlockKind::Heading,
      "Weekly Report",
      noise_rect(40.0, 760.0, 180.0, 780.0),
    ),
    is_heading_candidate: true,
  }
  let block1 = {
    ..make_noise_block(
      1,
      0,
      PdfConvertBlockKind::Heading,
      "Weekly Report",
      noise_rect(40.0, 760.0, 180.0, 780.0),
    ),
    is_heading_candidate: true,
  }
  let repeated = build_repeated_edge_noise_index(
    make_noise_doc([
      make_noise_page(0, [block0], []),
      make_noise_page(1, [block1], []),
    ]),
  )
  let evidence = collect_edge_noise_evidence(
    make_noise_page(0, [block0], []),
    0,
    block0,
    repeated,
  )
  let tags = edge_reason_tags(evidence)
  if !tags.contains("heading_like_but_repeated_edge") {
    fail("expected heading_like_but_repeated_edge evidence")
  }
}

///|
test "pdf noise drops heading-like repeated edge only with repeated evidence" {
  let block0 = {
    ..make_noise_block(
      0,
      0,
      PdfConvertBlockKind::Heading,
      "Weekly Report",
      noise_rect(40.0, 760.0, 180.0, 780.0),
    ),
    is_heading_candidate: true,
  }
  let block1 = {
    ..make_noise_block(
      1,
      0,
      PdfConvertBlockKind::Heading,
      "Weekly Report",
      noise_rect(40.0, 760.0, 180.0, 780.0),
    ),
    is_heading_candidate: true,
  }
  let repeated = build_repeated_edge_noise_index(
    make_noise_doc([
      make_noise_page(0, [block0], []),
      make_noise_page(1, [block1], []),
    ]),
  )
  let decision = decide_noise_block(
    make_noise_page(0, [block0], []),
    0,
    block0,
    repeated,
  )

  match decision.status {
    PdfNoiseDecisionStatus::Drop => ()
    _ => fail("expected drop decision")
  }
  if !decision.reason_tags.contains("heading_like_but_repeated_edge") {
    fail("expected heading_like_but_repeated_edge reason")
  }
}

///|
test "pdf noise keep reason preserves two-column edge blocks" {
  let block = make_noise_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "LEFT-1 narrow note",
    noise_rect(24.0, 760.0, 118.0, 780.0),
  )
  let repeated = build_repeated_edge_noise_index(
    make_noise_doc([make_noise_page(0, [block], [])]),
  )
  let decision = decide_noise_block(
    make_noise_page(0, [block], []),
    0,
    block,
    repeated,
  )
  match decision.status {
    PdfNoiseDecisionStatus::Keep => ()
    _ => fail("expected keep decision for two-column edge block")
  }
  if !decision.reason_tags.contains("two_column_guard") &&
    !edge_reason_tags(
      collect_edge_noise_evidence(
        make_noise_page(0, [block], []),
        0,
        block,
        repeated,
      ),
    ).contains("two_column_guard") {
    fail("expected two_column_guard evidence")
  }
}

///|
test "pdf noise keeps repeated edge caption near image" {
  let block0 = {
    ..make_noise_block(
      0,
      0,
      PdfConvertBlockKind::Paragraph,
      "Figure 1. Overview",
      noise_rect(40.0, 760.0, 190.0, 778.0),
    ),
    is_caption_candidate: true,
  }
  let block1 = {
    ..make_noise_block(
      1,
      0,
      PdfConvertBlockKind::Paragraph,
      "Figure 1. Overview",
      noise_rect(40.0, 760.0, 190.0, 778.0),
    ),
    is_caption_candidate: true,
  }
  let doc = make_noise_doc([
    make_noise_page(0, [block0], []),
    make_noise_page(1, [block1], []),
  ])
  let repeated = build_repeated_edge_noise_index(doc)
  let decision = decide_noise_block(
    make_noise_page(0, [block0], []),
    0,
    block0,
    repeated,
  )

  match decision.status {
    PdfNoiseDecisionStatus::Keep => ()
    _ => fail("expected keep decision")
  }
  if !decision.reason_tags.contains("image_caption_guard") {
    fail("expected image_caption_guard reason")
  }
}

///|
test "pdf noise keeps repeated edge block near annotation" {
  let block0 = make_noise_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "Shared edge note",
    noise_rect(40.0, 760.0, 180.0, 778.0),
  )
  let block1 = make_noise_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "Shared edge note",
    noise_rect(40.0, 760.0, 180.0, 778.0),
  )
  let annot = make_annotation_for_noise(
    0,
    0,
    noise_rect(36.0, 756.0, 184.0, 782.0),
  )
  let doc = make_noise_doc([
    make_noise_page(0, [block0], [annot]),
    make_noise_page(1, [block1], []),
  ])
  let repeated = build_repeated_edge_noise_index(doc)
  let decision = decide_noise_block(
    make_noise_page(0, [block0], [annot]),
    0,
    block0,
    repeated,
  )

  match decision.status {
    PdfNoiseDecisionStatus::Keep => ()
    _ => fail("expected keep decision")
  }
  if !decision.reason_tags.contains("link_or_annotation_nearby") {
    fail("expected link_or_annotation_nearby reason")
  }
}
