///|
priv enum PdfUriLinkFilterStatus {
  Accepted
  RejectedEmptyUri
  RejectedUnsupportedScheme
  RejectedDestOnly
  RejectedNoBbox
  RejectedNonLink
}

///|
priv enum PdfUriLinkMatchStatus {
  Matched
  RejectedEmptyUri
  RejectedUnsupportedScheme
  RejectedDestOnly
  RejectedNoBbox
  RejectedNonLink
  NoVisibleText
  Ambiguous
  TooLarge
  OverlappingAnnotations
}

///|
priv struct PdfUriLinkMatchResult {
  _page_index : Int
  _annotation_index : Int
  status : PdfUriLinkMatchStatus
  uri : String?
  dest : String?
  matched_text : String?
  matched_line_index : Int?
  matched_line_count : Int
  annotation_bbox : @model.PdfRect
  line_bbox : @model.PdfRect?
  overlap_ratio : Double?
}

///|
fn filter_uri_link_annotation(
  annotation : PdfConvertAnnotation,
) -> PdfUriLinkFilterStatus {
  if annotation.subtype != "/Link" {
    PdfUriLinkFilterStatus::RejectedNonLink
  } else if !@model.is_rect_valid(annotation._bbox) {
    PdfUriLinkFilterStatus::RejectedNoBbox
  } else {
    match annotation.uri {
      Some(uri) =>
        if uri.trim() == "" {
          PdfUriLinkFilterStatus::RejectedEmptyUri
        } else if !is_safe_pdf_link_uri(uri) {
          PdfUriLinkFilterStatus::RejectedUnsupportedScheme
        } else {
          PdfUriLinkFilterStatus::Accepted
        }
      None =>
        match annotation.dest {
          Some(dest) =>
            if dest.trim() != "" {
              PdfUriLinkFilterStatus::RejectedDestOnly
            } else {
              PdfUriLinkFilterStatus::RejectedEmptyUri
            }
          None => PdfUriLinkFilterStatus::RejectedEmptyUri
        }
    }
  }
}

///|
fn match_page_uri_links(page : PdfConvertPage) -> Array[PdfUriLinkMatchResult] {
  let out : Array[PdfUriLinkMatchResult] = []

  for annotation in page.annotations {
    match filter_uri_link_annotation(annotation) {
      PdfUriLinkFilterStatus::Accepted =>
        out.push(match_single_uri_link_annotation(page, annotation))
      PdfUriLinkFilterStatus::RejectedEmptyUri =>
        out.push(make_rejected_link_match(page, annotation, RejectedEmptyUri))
      PdfUriLinkFilterStatus::RejectedUnsupportedScheme =>
        out.push(
          make_rejected_link_match(page, annotation, RejectedUnsupportedScheme),
        )
      PdfUriLinkFilterStatus::RejectedDestOnly =>
        out.push(make_rejected_link_match(page, annotation, RejectedDestOnly))
      PdfUriLinkFilterStatus::RejectedNoBbox =>
        out.push(make_rejected_link_match(page, annotation, RejectedNoBbox))
      PdfUriLinkFilterStatus::RejectedNonLink =>
        out.push(make_rejected_link_match(page, annotation, RejectedNonLink))
    }
  }

  mark_overlapping_annotation_matches(out)
  out
}

///|
fn match_single_uri_link_annotation(
  page : PdfConvertPage,
  annotation : PdfConvertAnnotation,
) -> PdfUriLinkMatchResult {
  if is_annotation_bbox_too_large(page, annotation) {
    return {
      _page_index: annotation._page_index,
      _annotation_index: annotation._annotation_index,
      status: PdfUriLinkMatchStatus::TooLarge,
      uri: annotation.uri,
      dest: annotation.dest,
      matched_text: None,
      matched_line_index: None,
      matched_line_count: 0,
      annotation_bbox: annotation._bbox,
      line_bbox: None,
      overlap_ratio: None,
    }
  }

  let matched_lines : Array[(Int, Double)] = []

  for line in page.lines {
    let ratio = annotation_line_overlap_ratio(annotation, line)
    if ratio >= 0.55 && line.text.trim() != "" {
      matched_lines.push((line.line_index, ratio))
    }
  }

  if matched_lines.length() == 0 {
    return {
      _page_index: annotation._page_index,
      _annotation_index: annotation._annotation_index,
      status: PdfUriLinkMatchStatus::NoVisibleText,
      uri: annotation.uri,
      dest: annotation.dest,
      matched_text: None,
      matched_line_index: None,
      matched_line_count: 0,
      annotation_bbox: annotation._bbox,
      line_bbox: None,
      overlap_ratio: None,
    }
  }

  if matched_lines.length() != 1 {
    return {
      _page_index: annotation._page_index,
      _annotation_index: annotation._annotation_index,
      status: PdfUriLinkMatchStatus::Ambiguous,
      uri: annotation.uri,
      dest: annotation.dest,
      matched_text: None,
      matched_line_index: None,
      matched_line_count: matched_lines.length(),
      annotation_bbox: annotation._bbox,
      line_bbox: None,
      overlap_ratio: None,
    }
  }

  let (matched_line_index, ratio) = matched_lines[0]
  let matched_line = page.lines[matched_line_index]

  {
    _page_index: annotation._page_index,
    _annotation_index: annotation._annotation_index,
    status: PdfUriLinkMatchStatus::Matched,
    uri: annotation.uri,
    dest: annotation.dest,
    matched_text: Some(matched_line.text),
    matched_line_index: Some(matched_line.line_index),
    matched_line_count: 1,
    annotation_bbox: annotation._bbox,
    line_bbox: Some(matched_line._bbox),
    overlap_ratio: Some(ratio),
  }
}

///|
fn make_rejected_link_match(
  page : PdfConvertPage,
  annotation : PdfConvertAnnotation,
  status : PdfUriLinkMatchStatus,
) -> PdfUriLinkMatchResult {
  {
    _page_index: page._page_index,
    _annotation_index: annotation._annotation_index,
    status,
    uri: annotation.uri,
    dest: annotation.dest,
    matched_text: None,
    matched_line_index: None,
    matched_line_count: 0,
    annotation_bbox: annotation._bbox,
    line_bbox: None,
    overlap_ratio: None,
  }
}

///|
fn is_safe_pdf_link_uri(uri : String) -> Bool {
  let trimmed = uri.trim().to_lower()
  if trimmed == "" {
    return false
  }
  trimmed.has_prefix("http://") ||
  trimmed.has_prefix("https://") ||
  trimmed.has_prefix("mailto:")
}

///|
fn annotation_line_overlap_ratio(
  annotation : PdfConvertAnnotation,
  line : PdfConvertLine,
) -> Double {
  let annot = annotation._bbox
  let line_box = line._bbox

  let h = overlap_1d(annot.x0, annot.x1, line_box.x0, line_box.x1)
  if h <= 0.0 {
    return 0.0
  }

  let v = overlap_1d(annot.y0, annot.y1, line_box.y0, line_box.y1)
  if v <= 0.0 {
    return 0.0
  }

  let annot_w = max_f64(@model.rect_width(annot), 1.0)
  let annot_h = max_f64(@model.rect_height(annot), 1.0)
  let line_w = max_f64(@model.rect_width(line_box), 1.0)
  let line_h = max_f64(@model.rect_height(line_box), 1.0)

  let horiz_ratio = h / min_f64(annot_w, line_w)
  let vert_ratio = v / min_f64(annot_h, line_h)
  let area_ratio = h * v / min_f64(annot_w * annot_h, line_w * line_h)

  min_f64(1.0, min_f64(horiz_ratio, min_f64(vert_ratio, area_ratio)))
}

///|
fn is_annotation_bbox_too_large(
  page : PdfConvertPage,
  annotation : PdfConvertAnnotation,
) -> Bool {
  match page.media_box {
    Some(box) => {
      let page_w = max_f64(@model.rect_width(box), 1.0)
      let page_h = max_f64(@model.rect_height(box), 1.0)
      let annot_w = max_f64(@model.rect_width(annotation._bbox), 0.0)
      let annot_h = max_f64(@model.rect_height(annotation._bbox), 0.0)
      let width_ratio = annot_w / page_w
      let height_ratio = annot_h / page_h
      let area_ratio = annot_w * annot_h / (page_w * page_h)
      width_ratio >= 0.95 || height_ratio >= 0.50 || area_ratio >= 0.30
    }
    None => false
  }
}

///|
fn mark_overlapping_annotation_matches(
  results : Array[PdfUriLinkMatchResult],
) -> Unit {
  let matched_lines : Map[Int, Int] = Map::new()

  for result in results {
    match result.status {
      PdfUriLinkMatchStatus::Matched => ()
      _ => continue
    }
    match result.matched_line_index {
      Some(line_index) =>
        matched_lines.set(
          line_index,
          matched_lines.get(line_index).unwrap_or(0) + 1,
        )
      None => ()
    }
  }

  for i = 0; i < results.length(); i = i + 1 {
    match results[i].status {
      PdfUriLinkMatchStatus::Matched => ()
      _ => continue
    }
    match results[i].matched_line_index {
      Some(line_index) =>
        if matched_lines.get(line_index).unwrap_or(0) > 1 {
          results[i] = {
            ..results[i],
            status: PdfUriLinkMatchStatus::OverlappingAnnotations,
          }
        }
      None => ()
    }
  }
}

///|
fn overlap_1d(a0 : Double, a1 : Double, b0 : Double, b1 : Double) -> Double {
  let left = max_f64(a0, b0)
  let right = min_f64(a1, b1)
  if right > left {
    right - left
  } else {
    0.0
  }
}

///|
fn render_pdf_link_match_status(status : PdfUriLinkMatchStatus) -> String {
  match status {
    PdfUriLinkMatchStatus::Matched => "matched"
    PdfUriLinkMatchStatus::RejectedEmptyUri => "rejected_empty_uri"
    PdfUriLinkMatchStatus::RejectedUnsupportedScheme =>
      "rejected_unsupported_scheme"
    PdfUriLinkMatchStatus::RejectedDestOnly => "rejected_dest_only"
    PdfUriLinkMatchStatus::RejectedNoBbox => "rejected_no_bbox"
    PdfUriLinkMatchStatus::RejectedNonLink => "rejected_non_link"
    PdfUriLinkMatchStatus::NoVisibleText => "no_visible_text"
    PdfUriLinkMatchStatus::Ambiguous => "ambiguous"
    PdfUriLinkMatchStatus::TooLarge => "too_large"
    PdfUriLinkMatchStatus::OverlappingAnnotations => "overlapping_annotations"
  }
}

///|
fn render_pdf_link_match(result : PdfUriLinkMatchResult) -> String {
  let mut out = "[pdf-link-match] page=" +
    result._page_index.to_string() +
    " annot=" +
    result._annotation_index.to_string() +
    " status=" +
    render_pdf_link_match_status(result.status)

  match result.uri {
    Some(uri) => out = out + " uri=" + uri
    None => ()
  }
  match result.dest {
    Some(dest) => out = out + " dest=" + dest
    None => ()
  }
  match result.matched_line_index {
    Some(i) => out = out + " line=" + i.to_string()
    None => ()
  }
  out = out + " matched_line_count=" + result.matched_line_count.to_string()
  match result.matched_text {
    Some(text) => out = out + " text=\"" + text + "\""
    None => ()
  }
  match result.overlap_ratio {
    Some(v) => out = out + " overlap=" + v.to_string()
    None => ()
  }
  out = out + " annot_bbox=" + rect_str(result.annotation_bbox)
  match result.line_bbox {
    Some(b) => out = out + " line_bbox=" + rect_str(b)
    None => ()
  }

  out
}

///|
fn attach_high_confidence_uri_links(
  doc : PdfConvertDocument,
) -> PdfConvertDocument {
  let pages = Array::new()

  for page in doc.pages {
    let matches = match_page_uri_links(page)
    let block_by_line : Map[Int, PdfUriLinkMatchResult] = Map::new()

    for result in matches {
      match result.status {
        PdfUriLinkMatchStatus::Matched =>
          match result.matched_line_index {
            Some(line_index) => block_by_line.set(line_index, result)
            None => ()
          }
        _ => ()
      }
    }

    let blocks : Array[PdfConvertBlock] = []
    for block in page.blocks {
      let patched = if block.line_start == block.line_end {
        match block_by_line.get(block.line_start) {
          Some(result) =>
            match (result.uri, result.matched_text) {
              (Some(uri), Some(text)) =>
                if text.trim() != "" && text == block.text {
                  {
                    ..block,
                    rich_inlines: Some([@cor.Inline::Link(text, uri)]),
                  }
                } else {
                  block
                }
              _ => block
            }
          None => block
        }
      } else {
        block
      }
      blocks.push(patched)
    }

    pages.push({
      _page_index: page._page_index,
      media_box: page.media_box,
      crop_box: page.crop_box,
      lines: page.lines,
      blocks,
      images: page.images,
      annotations: page.annotations,
      objects: build_page_objects(blocks, page.images),
    })
  }

  { pages, }
}
