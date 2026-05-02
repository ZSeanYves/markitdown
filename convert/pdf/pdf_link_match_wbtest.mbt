///|
fn rect(x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn make_test_line(
  page_index : Int,
  line_index : Int,
  text : String,
  bbox : @model.PdfRect,
) -> PdfConvertLine {
  {
    _page_index: page_index,
    line_index,
    text,
    _source_block_index: 0,
    source_block_line_count: 1,
    source_block_kind: @model.PdfTextBlockKind::Text,
    source_block_bbox: bbox,
    source_block_dominant_font_size: Some(12.0),
    source_block_dominant_font_name: Some("Test"),
    is_heading_candidate: false,
    is_page_number_candidate: false,
    is_header_footer_candidate: false,
    is_artifact_candidate: false,
    is_caption_candidate: false,
    is_table_cell_candidate: false,
    dominant_language: None,
    writing_direction: @model.PdfWritingDirection::LeftToRight,
    _bbox: bbox,
    font_size: Some(12.0),
    font_name: Some("Test"),
    indent_left: None,
    indent_right: None,
    alignment_hint: None,
    line_gap_before: None,
    _line_gap_after: None,
    line_height: Some(12.0),
    baseline_y: None,
    is_wrapped_candidate: false,
    is_same_paragraph_with_prev_candidate: false,
  }
}

///|
fn make_test_annotation(
  page_index : Int,
  annotation_index : Int,
  subtype : String,
  bbox : @model.PdfRect,
  uri : String?,
  dest : String?,
) -> PdfConvertAnnotation {
  {
    _page_index: page_index,
    _annotation_index: annotation_index,
    subtype,
    _bbox: bbox,
    uri,
    dest,
    object_ref: Some("12 0 R"),
    contents: None,
    subject: None,
    color: None,
  }
}

///|
fn make_test_page(
  lines : Array[PdfConvertLine],
  annotations : Array[PdfConvertAnnotation],
  media_box : @model.PdfRect?,
) -> PdfConvertPage {
  {
    _page_index: 0,
    media_box,
    crop_box: None,
    lines,
    blocks: [],
    images: [],
    annotations,
    objects: [],
  }
}

///|
test "pdf uri link filter accepts safe schemes and rejects unsupported ones" {
  let accepted = filter_uri_link_annotation(
    make_test_annotation(
      0,
      0,
      "/Link",
      rect(10.0, 10.0, 40.0, 20.0),
      Some("https://example.com"),
      None,
    ),
  )
  match accepted {
    PdfUriLinkFilterStatus::Accepted => ()
    _ => fail("expected accepted URI link")
  }

  let unsupported = filter_uri_link_annotation(
    make_test_annotation(
      0,
      1,
      "/Link",
      rect(10.0, 10.0, 40.0, 20.0),
      Some("javascript:alert(1)"),
      None,
    ),
  )
  match unsupported {
    PdfUriLinkFilterStatus::RejectedUnsupportedScheme => ()
    _ => fail("expected unsupported scheme rejection")
  }

  let dest_only = filter_uri_link_annotation(
    make_test_annotation(
      0,
      2,
      "/Link",
      rect(10.0, 10.0, 40.0, 20.0),
      None,
      Some("[12 0 R /XYZ 0 100 1]"),
    ),
  )
  match dest_only {
    PdfUriLinkFilterStatus::RejectedDestOnly => ()
    _ => fail("expected dest-only rejection")
  }
}

///|
test "pdf uri link matcher matches one high-confidence line" {
  let page = make_test_page(
    [make_test_line(0, 0, "Example link", rect(10.0, 10.0, 90.0, 20.0))],
    [
      make_test_annotation(
        0,
        0,
        "/Link",
        rect(12.0, 10.0, 88.0, 20.0),
        Some("https://example.com"),
        None,
      ),
    ],
    Some(rect(0.0, 0.0, 200.0, 200.0)),
  )
  let results = match_page_uri_links(page)
  assert_eq(results.length(), 1)
  match results[0].status {
    PdfUriLinkMatchStatus::Matched => ()
    _ => fail("expected matched URI link")
  }
  match results[0].matched_text {
    Some("Example link") => ()
    _ => fail("expected matched link text")
  }
  match results[0].matched_line_index {
    Some(0) => ()
    _ => fail("expected matched line index 0")
  }
}

///|
test "pdf uri link matcher rejects no-visible-text and too-large boxes" {
  let no_visible_page = make_test_page(
    [make_test_line(0, 0, "Body", rect(10.0, 10.0, 40.0, 20.0))],
    [
      make_test_annotation(
        0,
        0,
        "/Link",
        rect(100.0, 100.0, 140.0, 120.0),
        Some("https://example.com"),
        None,
      ),
    ],
    Some(rect(0.0, 0.0, 200.0, 200.0)),
  )
  let no_visible = match_page_uri_links(no_visible_page)
  match no_visible[0].status {
    PdfUriLinkMatchStatus::NoVisibleText => ()
    _ => fail("expected no-visible-text result")
  }

  let too_large_page = make_test_page(
    [make_test_line(0, 0, "Body", rect(10.0, 10.0, 40.0, 20.0))],
    [
      make_test_annotation(
        0,
        0,
        "/Link",
        rect(0.0, 0.0, 198.0, 120.0),
        Some("https://example.com"),
        None,
      ),
    ],
    Some(rect(0.0, 0.0, 200.0, 200.0)),
  )
  let too_large = match_page_uri_links(too_large_page)
  match too_large[0].status {
    PdfUriLinkMatchStatus::TooLarge => ()
    _ => fail("expected too-large result")
  }
}

///|
test "pdf uri link matcher marks ambiguous and overlapping cases" {
  let ambiguous_page = make_test_page(
    [
      make_test_line(0, 0, "Line A", rect(10.0, 30.0, 90.0, 40.0)),
      make_test_line(0, 1, "Line B", rect(10.0, 18.0, 90.0, 28.0)),
    ],
    [
      make_test_annotation(
        0,
        0,
        "/Link",
        rect(12.0, 18.0, 88.0, 40.0),
        Some("https://example.com/a"),
        None,
      ),
    ],
    Some(rect(0.0, 0.0, 200.0, 200.0)),
  )
  let ambiguous = match_page_uri_links(ambiguous_page)
  match ambiguous[0].status {
    PdfUriLinkMatchStatus::Ambiguous => ()
    _ => fail("expected ambiguous result")
  }

  let overlapping_page = make_test_page(
    [make_test_line(0, 0, "Shared", rect(10.0, 10.0, 90.0, 20.0))],
    [
      make_test_annotation(
        0,
        0,
        "/Link",
        rect(12.0, 10.0, 50.0, 20.0),
        Some("https://example.com/a"),
        None,
      ),
      make_test_annotation(
        0,
        1,
        "/Link",
        rect(20.0, 10.0, 88.0, 20.0),
        Some("https://example.com/b"),
        None,
      ),
    ],
    Some(rect(0.0, 0.0, 200.0, 200.0)),
  )
  let overlapping = match_page_uri_links(overlapping_page)
  match overlapping[0].status {
    PdfUriLinkMatchStatus::OverlappingAnnotations => ()
    _ => fail("expected overlapping-annotations result for first link")
  }
  match overlapping[1].status {
    PdfUriLinkMatchStatus::OverlappingAnnotations => ()
    _ => fail("expected overlapping-annotations result for second link")
  }
}
