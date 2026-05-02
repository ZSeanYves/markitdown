///|
fn merge_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn make_merge_block(
  page_index : Int,
  block_index : Int,
  kind : PdfConvertBlockKind,
  text : String,
  bbox : @model.PdfRect,
  first_indent_left : Double?,
  first_gap_before : Double?,
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
    first_indent_left,
    last_indent_left: first_indent_left,
    first_indent_right: None,
    last_indent_right: None,
    first_alignment_hint: Some("left"),
    last_alignment_hint: Some("left"),
    first_line_gap_before: first_gap_before,
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
fn make_merge_page(
  page_index : Int,
  blocks : Array[PdfConvertBlock],
  images : Array[PdfConvertImage],
) -> PdfConvertPage {
  {
    _page_index: page_index,
    media_box: Some(merge_rect(0.0, 0.0, 400.0, 800.0)),
    crop_box: None,
    lines: [],
    blocks,
    images,
    annotations: [],
    objects: [],
  }
}

///|
fn make_merge_image(
  page_index : Int,
  image_index : Int,
  bbox : @model.PdfRect,
) -> PdfConvertImage {
  {
    _page_index: page_index,
    _image_index: image_index,
    path: "assets/image.png",
    alt_text: None,
    _caption: None,
    _bbox: bbox,
    top_y: bbox.y1,
    left_x: bbox.x0,
    _width_px: 100,
    _height_px: 80,
    colorspace: None,
    bits_per_component: None,
    image_filter: None,
    object_ref: None,
    inline_image: false,
    source_refs_count: 0,
    source_image_id: "img-1",
  }
}

///|
test "pdf merge evidence marks continuation-friendly boundary" {
  let left = {
    ..make_merge_block(
      0,
      0,
      PdfConvertBlockKind::Paragraph,
      "This paragraph continues",
      merge_rect(40.0, 80.0, 320.0, 100.0),
      Some(40.0),
      Some(4.0),
    ),
    last_is_wrapped_candidate: true,
  }
  let right = make_merge_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "on the next page.",
    merge_rect(42.0, 720.0, 322.0, 740.0),
    Some(42.0),
    Some(4.0),
  )
  let decision = decide_page_boundary_merge(
    make_merge_page(0, [left], []),
    make_merge_page(1, [right], []),
  )

  match decision.status {
    PdfMergeDecisionStatus::Merge => ()
    _ => fail("expected merge decision")
  }
  if !decision.reason_tags.contains("previous_no_sentence_end") {
    fail("expected previous_no_sentence_end reason")
  }
  if !decision.reason_tags.contains("similar_indent") {
    fail("expected similar_indent reason")
  }
  if !decision.reason_tags.contains("body_to_body") {
    fail("expected body_to_body reason")
  }
}

///|
test "pdf merge evidence keeps split on sentence end and heading-like next" {
  let left = make_merge_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "This paragraph ends cleanly.",
    merge_rect(40.0, 80.0, 320.0, 100.0),
    Some(40.0),
    Some(4.0),
  )
  let right = make_merge_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "Chapter 2",
    merge_rect(42.0, 720.0, 140.0, 740.0),
    Some(42.0),
    Some(14.0),
  )
  let decision = decide_page_boundary_merge(
    make_merge_page(0, [left], []),
    make_merge_page(1, [right], []),
  )

  match decision.status {
    PdfMergeDecisionStatus::KeepSplit => ()
    _ => fail("expected keep_split decision")
  }
  if !decision.reason_tags.contains("previous_sentence_end") {
    fail("expected previous_sentence_end reason")
  }
  if !decision.reason_tags.contains("next_starts_heading_like") {
    fail("expected next_starts_heading_like reason")
  }
}

///|
test "pdf merge evidence keeps split on list table and image guards" {
  let left = {
    ..make_merge_block(
      0,
      0,
      PdfConvertBlockKind::Paragraph,
      "Figure caption",
      merge_rect(40.0, 80.0, 180.0, 100.0),
      Some(40.0),
      Some(4.0),
    ),
    is_caption_candidate: true,
  }
  let right = {
    ..make_merge_block(
      1,
      0,
      PdfConvertBlockKind::Paragraph,
      "- item one",
      merge_rect(42.0, 720.0, 160.0, 740.0),
      Some(42.0),
      Some(4.0),
    ),
    is_table_cell_candidate: true,
  }
  let image = make_merge_image(1, 0, merge_rect(30.0, 700.0, 170.0, 760.0))
  let decision = decide_page_boundary_merge(
    make_merge_page(0, [left], []),
    make_merge_page(1, [right], [image]),
  )

  match decision.status {
    PdfMergeDecisionStatus::KeepSplit => ()
    _ => fail("expected keep_split decision")
  }
  if !decision.reason_tags.contains("list_guard") {
    fail("expected list_guard reason")
  }
  if !decision.reason_tags.contains("table_guard") {
    fail("expected table_guard reason")
  }
}

///|
test "pdf merge evidence keeps split on large indent shift" {
  let left = make_merge_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "continues",
    merge_rect(40.0, 80.0, 320.0, 100.0),
    Some(40.0),
    Some(4.0),
  )
  let right = make_merge_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "on next page",
    merge_rect(120.0, 720.0, 340.0, 740.0),
    Some(120.0),
    Some(4.0),
  )
  let evidence = collect_page_boundary_merge_evidence(
    make_merge_page(0, [left], []),
    make_merge_page(1, [right], []),
  )
  if !evidence.large_indent_shift {
    fail("expected large_indent_shift evidence")
  }
}

///|
test "pdf merge evidence keeps split on two-column guard" {
  let left = make_merge_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "LEFT narrow",
    merge_rect(40.0, 80.0, 150.0, 100.0),
    Some(40.0),
    Some(4.0),
  )
  let right = make_merge_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "right narrow",
    merge_rect(250.0, 720.0, 360.0, 740.0),
    Some(250.0),
    Some(4.0),
  )
  let decision = decide_page_boundary_merge(
    make_merge_page(0, [left], []),
    make_merge_page(1, [right], []),
  )
  match decision.status {
    PdfMergeDecisionStatus::KeepSplit => ()
    _ => fail("expected keep_split decision")
  }
  if !decision.reason_tags.contains("column_shift_guard") &&
    !decision.reason_tags.contains("two_column_guard") {
    fail("expected column/two-column guard reason")
  }
}

///|
test "pdf merge evidence merges wrapped continuation with similar indent" {
  let left = {
    ..make_merge_block(
      0,
      0,
      PdfConvertBlockKind::Paragraph,
      "This paragraph keeps flowing",
      merge_rect(40.0, 80.0, 320.0, 100.0),
      Some(40.0),
      Some(4.0),
    ),
    last_is_wrapped_candidate: true,
  }
  let right = {
    ..make_merge_block(
      1,
      0,
      PdfConvertBlockKind::Paragraph,
      "across the next page boundary",
      merge_rect(42.0, 720.0, 322.0, 740.0),
      Some(42.0),
      Some(4.0),
    ),
    first_is_wrapped_candidate: true,
  }
  let decision = decide_page_boundary_merge(
    make_merge_page(0, [left], []),
    make_merge_page(1, [right], []),
  )

  match decision.status {
    PdfMergeDecisionStatus::Merge => ()
    _ => fail("expected merge decision")
  }
  if !decision.reason_tags.contains("wrapped_line_continuation") {
    fail("expected wrapped_line_continuation reason")
  }
  if !decision.reason_tags.contains("similar_indent") {
    fail("expected similar_indent reason")
  }
}

///|
test "pdf merge evidence keeps split when only previous_no_sentence_end exists" {
  let left = make_merge_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "continues",
    merge_rect(40.0, 80.0, 120.0, 100.0),
    Some(40.0),
    Some(4.0),
  )
  let right = make_merge_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "Next",
    merge_rect(220.0, 720.0, 320.0, 740.0),
    Some(220.0),
    Some(14.0),
  )
  let decision = decide_page_boundary_merge(
    make_merge_page(0, [left], []),
    make_merge_page(1, [right], []),
  )

  match decision.status {
    PdfMergeDecisionStatus::KeepSplit => ()
    _ => fail("expected keep_split decision")
  }
}

///|
test "pdf merge evidence keeps split when only lowercase next line exists" {
  let left = make_merge_block(
    0,
    0,
    PdfConvertBlockKind::Paragraph,
    "This paragraph ends here.",
    merge_rect(40.0, 80.0, 320.0, 100.0),
    Some(40.0),
    Some(4.0),
  )
  let right = make_merge_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "continues maybe",
    merge_rect(42.0, 720.0, 322.0, 740.0),
    Some(42.0),
    Some(4.0),
  )
  let decision = decide_page_boundary_merge(
    make_merge_page(0, [left], []),
    make_merge_page(1, [right], []),
  )

  match decision.status {
    PdfMergeDecisionStatus::KeepSplit => ()
    _ => fail("expected keep_split decision")
  }
  if !decision.reason_tags.contains("previous_sentence_end") {
    fail("expected previous_sentence_end reason")
  }
}

///|
test "pdf merge evidence keeps split on noise guard" {
  let left = {
    ..make_merge_block(
      0,
      0,
      PdfConvertBlockKind::Noise,
      "CONFIDENTIAL",
      merge_rect(40.0, 80.0, 180.0, 100.0),
      Some(40.0),
      Some(4.0),
    ),
    is_noise_candidate: true,
  }
  let right = make_merge_block(
    1,
    0,
    PdfConvertBlockKind::Paragraph,
    "next page body",
    merge_rect(42.0, 720.0, 240.0, 740.0),
    Some(42.0),
    Some(4.0),
  )
  let decision = decide_page_boundary_merge(
    make_merge_page(0, [left], []),
    make_merge_page(1, [right], []),
  )

  match decision.status {
    PdfMergeDecisionStatus::KeepSplit => ()
    _ => fail("expected keep_split decision")
  }
  if !decision.reason_tags.contains("kind_mismatch") {
    fail("expected kind_mismatch reason")
  }
  if !decision.reason_tags.contains("noise_guard") {
    fail("expected noise_guard reason")
  }
}
