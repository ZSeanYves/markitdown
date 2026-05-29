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
pub enum PdfUriLinkMatchStatus {
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
pub struct PdfUriLinkMatchResult {
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
fn matched_block_text_for_lines(
  page : PdfConvertPage,
  matched_lines : Array[(Int, Double)],
) -> (Int, Int, String, Double)? {
  if matched_lines.is_empty() {
    return None
  }

  let first_line_index = matched_lines[0].0
  let first_line = page.lines[first_line_index]
  let source_block_index = first_line._source_block_index
  let mut last_line_index = first_line_index
  let mut min_ratio = matched_lines[0].1

  for i = 0; i < matched_lines.length(); i = i + 1 {
    let (line_index, ratio) = matched_lines[i]
    let line = page.lines[line_index]
    if line._source_block_index != source_block_index {
      return None
    }
    if i > 0 && line_index != last_line_index + 1 {
      return None
    }
    if ratio < min_ratio {
      min_ratio = ratio
    }
    last_line_index = line_index
  }

  for block in page.blocks {
    if block.source_block_index == source_block_index &&
      block.line_start == first_line_index &&
      block.line_end == last_line_index {
      let text = block.text.trim().to_owned()
      if text != "" {
        return Some((first_line_index, matched_lines.length(), text, min_ratio))
      }
    }
  }

  None
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
pub fn match_page_uri_links(
  page : PdfConvertPage,
) -> Array[PdfUriLinkMatchResult] {
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

  if matched_lines.length() > 1 {
    match matched_block_text_for_lines(page, matched_lines) {
      Some((matched_line_index, matched_line_count, matched_text, ratio)) =>
        return {
          _page_index: annotation._page_index,
          _annotation_index: annotation._annotation_index,
          status: PdfUriLinkMatchStatus::Matched,
          uri: annotation.uri,
          dest: annotation.dest,
          matched_text: Some(matched_text),
          matched_line_index: Some(matched_line_index),
          matched_line_count,
          annotation_bbox: annotation._bbox,
          line_bbox: None,
          overlap_ratio: Some(ratio),
        }
      None =>
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
  let matched_lines : Map[Int, Int] = Map([])

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
pub fn attach_high_confidence_uri_links(
  doc : PdfConvertDocument,
) -> PdfConvertDocument {
  let pages = Array::new()

  for page in doc.pages {
    let matches = match_page_uri_links(page)

    let blocks : Array[PdfConvertBlock] = []
    for block in page.blocks {
      let mut patched = block
      for result in matches {
        if uri_link_match_is_inside_block(result, patched) {
          patched = attach_uri_link_to_block(patched, result)
        }
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
      forms: page.forms,
      objects: build_page_objects(blocks, page.images),
    })
  }

  { pages, }
}

///|
fn uri_link_match_is_inside_block(
  result : PdfUriLinkMatchResult,
  block : PdfConvertBlock,
) -> Bool {
  match result.status {
    PdfUriLinkMatchStatus::Matched => ()
    _ => return false
  }

  match result.matched_line_index {
    Some(line_index) => {
      let line_end = line_index + result.matched_line_count - 1
      line_index >= block.line_start && line_end <= block.line_end
    }
    None => false
  }
}

///|
fn attach_uri_link_to_block(
  block : PdfConvertBlock,
  result : PdfUriLinkMatchResult,
) -> PdfConvertBlock {
  match (result.uri, result.matched_text) {
    (Some(uri), Some(text)) => {
      let label = text.trim().to_owned()
      if label == "" {
        return block
      }
      if label == block.text {
        match block.rich_inlines {
          Some(inlines) =>
            if !pdf_link_text_only_inlines(inlines) {
              return block
            }
          None => ()
        }
        return { ..block, rich_inlines: Some([@cor.Inline::Link(label, uri)]) }
      }

      match block.rich_inlines {
        Some(inlines) =>
          match unique_inline_link_for_text_inlines(inlines, label, uri) {
            Some(patched) => { ..block, rich_inlines: Some(patched) }
            None => block
          }
        None =>
          match unique_inline_link_for_block_text(block.text, label, uri) {
            Some(inlines) => { ..block, rich_inlines: Some(inlines) }
            None => block
          }
      }
    }
    _ => block
  }
}

///|
fn unique_inline_link_for_text_inlines(
  inlines : Array[@cor.Inline],
  label : String,
  uri : String,
) -> Array[@cor.Inline]? {
  if !pdf_link_text_only_inlines(inlines) {
    return None
  }

  unique_inline_link_for_block_text(
    pdf_link_text_from_inlines(inlines), label, uri,
  )
}

///|
fn pdf_link_text_only_inlines(inlines : Array[@cor.Inline]) -> Bool {
  for inline in inlines {
    match inline {
      @cor.Inline::Text(_) => ()
      _ => return false
    }
  }
  true
}

///|
fn pdf_link_text_from_inlines(inlines : Array[@cor.Inline]) -> String {
  let mut out = ""
  for inline in inlines {
    match inline {
      @cor.Inline::Text(text) => out = out + text
      _ => ()
    }
  }
  out
}

///|
fn unique_inline_link_for_block_text(
  block_text : String,
  label : String,
  uri : String,
) -> Array[@cor.Inline]? {
  match unique_substring_range(block_text, label) {
    Some((start, end)) => {
      let inlines : Array[@cor.Inline] = []
      let prefix = block_text[:start].to_owned()
      let matched = block_text[start:end].to_owned()
      let suffix = block_text[end:].to_owned()

      if prefix != "" {
        inlines.push(@cor.Inline::Text(prefix))
      }
      inlines.push(@cor.Inline::Link(matched, uri))
      if suffix != "" {
        inlines.push(@cor.Inline::Text(suffix))
      }
      Some(inlines)
    }
    None => None
  }
}

///|
fn unique_substring_range(text : String, needle : String) -> (Int, Int)? {
  if needle == "" {
    return None
  }

  match text.find(needle) {
    Some(start) => {
      let end = start + needle.length()
      match text[end:].find(needle) {
        Some(_) => None
        None => Some((start, end))
      }
    }
    None => None
  }
}
