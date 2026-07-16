///|
priv struct PdfNativeLinkSegment {
  start : Int
  end : Int
  href : String
  source_ref : @core.SourceRef
  link_index : Int
}

///|
fn pdf_native_lowered_paragraph(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  text_block_index : Int,
) -> PdfNativeLoweredParagraph? {
  match pdf_native_text_block_paragraph(page, text_block, text_block_index) {
    Some((text, source_ref)) => {
      let link_segments = pdf_native_link_segments_for_text_block(
        page, text_block, text_block_index, text, source_ref,
      )
      match link_segments {
        Some(segments) => {
          let rich_inlines = pdf_native_rich_inlines_from_link_segments(
            text, source_ref, segments,
          )
          if rich_inlines.length() > 0 {
            return Some({
              text,
              source_ref,
              rich_inlines: Some(rich_inlines),
              consumed_link_indexes: segments.map(segment => segment.link_index),
            })
          }
        }
        None => ()
      }
      Some({ text, source_ref, rich_inlines: None, consumed_link_indexes: [] })
    }
    None => None
  }
}

///|
fn pdf_native_link_segments_for_text_block(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  text_block_index : Int,
  text : String,
  paragraph_source_ref : @core.SourceRef,
) -> Array[PdfNativeLinkSegment]? {
  let segments : Array[PdfNativeLinkSegment] = []
  for link_index in 0..<page.link_candidates.length() {
    let link = page.link_candidates[link_index]
    if !pdf_native_link_candidate_is_productizable_uri(
        page, text_block, text_block_index, link,
      ) {
      continue
    }
    let anchor_text = match
      pdf_native_link_anchor_text_for_block(text_block, text, link) {
      Some(value) => value
      None => continue
    }
    let range = match pdf_native_unique_substring_range(text, anchor_text) {
      Some(value) => value
      None => continue
    }
    let source_ref = match link.source_ref {
      Some(value) => value
      None => paragraph_source_ref
    }
    let overlaps_existing = segments.any(segment => {
      !(range.1 <= segment.start || range.0 >= segment.end)
    })
    if overlaps_existing {
      continue
    }
    segments.push({
      start: range.0,
      end: range.1,
      href: link.href,
      source_ref,
      link_index,
    })
  }
  if segments.length() == 0 {
    return None
  }
  segments.sort_by(fn(left, right) {
    if left.start < right.start {
      -1
    } else if left.start > right.start {
      1
    } else if left.end < right.end {
      -1
    } else if left.end > right.end {
      1
    } else {
      0
    }
  })
  Some(segments)
}

///|
fn pdf_native_link_candidate_is_productizable_uri(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  text_block_index : Int,
  link : PdfNativeLinkCandidate,
) -> Bool {
  if !pdf_native_href_is_external_uri(link.href) {
    return false
  }
  if pdf_native_link_page_no(link, page.geometry.page_no) !=
    page.geometry.page_no {
    return false
  }
  if !pdf_native_pdf_bboxes_overlap(link.bbox, text_block.bbox) {
    return false
  }
  let mut match_count = 0
  for block_index in 0..<page.text_blocks.length() {
    if !pdf_native_pdf_bboxes_overlap(
        link.bbox,
        page.text_blocks[block_index].bbox,
      ) {
      continue
    }
    match_count += 1
    if block_index + 1 != text_block_index || match_count > 1 {
      return false
    }
  }
  match_count == 1
}

///|
fn pdf_native_href_is_external_uri(href : String) -> Bool {
  let trimmed = href.trim().to_owned()
  trimmed != "" &&
  !trimmed.contains(" ") &&
  (
    trimmed.has_prefix("http://") ||
    trimmed.has_prefix("https://") ||
    trimmed.has_prefix("mailto:")
  )
}

///|
fn pdf_native_link_anchor_text_for_block(
  text_block : PdfNativeTextBlock,
  paragraph_text : String,
  link : PdfNativeLinkCandidate,
) -> String? {
  match link.text {
    Some(value) => {
      let normalized = pdf_native_inline_anchor_text(value)
      if normalized != "" {
        return Some(normalized)
      }
    }
    None => ()
  }
  let matching_lines : Array[(PdfNativeTextLine, String)] = []
  for line in text_block.lines {
    let line_text = pdf_native_line_text(line)
    if line_text == "" {
      continue
    }
    if pdf_native_pdf_bboxes_overlap(link.bbox, line.bbox) {
      matching_lines.push((line, line_text))
    }
  }
  if matching_lines.length() != 1 {
    return None
  }
  let line_anchor = pdf_native_link_anchor_text_from_line(
    matching_lines[0].0,
    matching_lines[0].1,
    link,
  )
  match line_anchor {
    Some(value) => Some(value)
    None =>
      if paragraph_text == matching_lines[0].1 {
        Some(paragraph_text)
      } else {
        None
      }
  }
}

///|
fn pdf_native_link_anchor_text_from_line(
  line : PdfNativeTextLine,
  fallback_text : String,
  link : PdfNativeLinkCandidate,
) -> String? {
  let parts : Array[String] = []
  for span in line.spans {
    let trimmed = span.text.trim().to_owned()
    if trimmed == "" {
      continue
    }
    if pdf_native_pdf_bboxes_overlap(link.bbox, span.bbox) {
      parts.push(trimmed)
    }
  }
  if parts.length() > 0 {
    return Some(pdf_native_inline_anchor_text(parts.join(" ")))
  }
  if pdf_native_pdf_bboxes_overlap(link.bbox, line.bbox) {
    let normalized = pdf_native_inline_anchor_text(fallback_text)
    if normalized != "" {
      return Some(normalized)
    }
  }
  None
}

///|
fn pdf_native_inline_anchor_text(text : String) -> String {
  let parts : Array[String] = []
  for part in text.split(" ") {
    let trimmed = part.trim().to_owned()
    if trimmed != "" {
      parts.push(trimmed)
    }
  }
  parts.join(" ")
}

///|
fn pdf_native_find_substring(
  text : String,
  needle : String,
  start : Int,
) -> Int? {
  let text_len = text.length()
  let needle_len = needle.length()
  if needle_len == 0 {
    return Some(start)
  }
  if start < 0 || start >= text_len || text_len < needle_len {
    return None
  }
  let last = text_len - needle_len
  let mut index = start
  while index <= last {
    if text[index:index + needle_len] == needle {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn pdf_native_unique_substring_range(
  text : String,
  needle : String,
) -> (Int, Int)? {
  if needle == "" {
    return None
  }
  let start = match pdf_native_find_substring(text, needle, 0) {
    Some(value) => value
    None => return None
  }
  match pdf_native_find_substring(text, needle, start + needle.length()) {
    Some(_) => None
    None => Some((start, start + needle.length()))
  }
}

///|
fn pdf_native_rich_inlines_from_link_segments(
  text : String,
  source_ref : @core.SourceRef,
  segments : Array[PdfNativeLinkSegment],
) -> Array[@core.CoreInline] {
  let inlines : Array[@core.CoreInline] = []
  let mut cursor = 0
  for segment in segments {
    if segment.start > cursor {
      inlines.push(
        @core.make_inline_text(
          text[cursor:segment.start].to_owned(),
          source_ref~,
        ),
      )
    }
    inlines.push(
      @core.make_inline_link(
        text[segment.start:segment.end].to_owned(),
        segment.href,
        source_ref=segment.source_ref,
      ),
    )
    cursor = segment.end
  }
  if cursor < text.length() {
    inlines.push(@core.make_inline_text(text[cursor:].to_owned(), source_ref~))
  }
  inlines
}

///|
fn pdf_native_text_block_paragraph(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  text_block_index : Int,
) -> (String, @core.SourceRef)? {
  let parts : Array[String] = []
  let meaningful_lines : Array[PdfNativeTextLine] = []
  for line in text_block.lines {
    let text = pdf_native_line_text(line)
    if text == "" {
      continue
    }
    if parts.length() == 0 {
      parts.push(text)
    } else {
      let previous = parts[parts.length() - 1]
      parts[parts.length() - 1] = pdf_native_merge_block_line_text(
        previous, text,
      )
    }
    meaningful_lines.push(line)
  }
  if parts.length() == 0 {
    return None
  }
  let source_ref = pdf_native_text_block_source_ref(
    page, text_block, meaningful_lines, text_block_index,
  )
  Some((parts.join(" "), source_ref))
}

///|
fn pdf_native_merge_block_line_text(left : String, right : String) -> String {
  let lhs = left.trim_end().to_owned()
  let rhs = right.trim_start().to_owned()
  if lhs == "" {
    return rhs
  }
  if rhs == "" {
    return lhs
  }
  if lhs.has_suffix("-") {
    lhs[:lhs.length() - 1].to_owned() + rhs
  } else {
    lhs + " " + rhs
  }
}

///|
fn pdf_native_text_block_source_ref(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  lines : Array[PdfNativeTextLine],
  text_block_index : Int,
) -> @core.SourceRef {
  let first_line = lines[0]
  let last_line = lines[lines.length() - 1]
  let base = pdf_native_line_base_source_ref(first_line)
  let page_no = base.page.unwrap_or(page.geometry.page_no)
  let line_start = base.line_start.unwrap_or(1)
  let last_base = pdf_native_line_base_source_ref(last_line)
  let line_end = last_base.line_end.unwrap_or(
    last_base.line_start.unwrap_or(line_start),
  )
  let next = {
    ..base,
    format: Some(base.format.unwrap_or("pdf")),
    page: Some(page_no),
    bbox: pdf_native_effective_bbox(base.bbox, text_block.bbox),
    line_start: Some(line_start),
    line_end: Some(line_end),
  }
  if next.extra.get("page_no") == None {
    next.extra.set("page_no", page_no.to_string())
  }
  if next.extra.get("pdf_text_block_index") == None {
    next.extra.set("pdf_text_block_index", text_block_index.to_string())
  }
  if next.extra.get("pdf_line_index") == None {
    next.extra.set("pdf_line_index", line_start.to_string())
  }
  next.extra.set("pdf_line_end_index", line_end.to_string())
  match text_block.reading_order_index {
    Some(value) =>
      if next.extra.get("reading_order_index") == None {
        next.extra.set("reading_order_index", value.to_string())
      }
    None => ()
  }
  next
}

///|
fn pdf_native_line_base_source_ref(line : PdfNativeTextLine) -> @core.SourceRef {
  match line.source_ref {
    Some(source_ref) => source_ref
    None => {
      for span in line.spans {
        match span.source_ref {
          Some(source_ref) => return source_ref
          None => ()
        }
      }
      @core.empty_source_ref()
    }
  }
}

///|
fn pdf_native_effective_bbox(
  current : @core.BBox?,
  fallback : PdfBBox,
) -> @core.BBox? {
  match current {
    Some(value) => Some(value)
    None =>
      if pdf_bbox_is_empty(fallback) {
        None
      } else {
        Some(pdf_native_core_bbox(fallback))
      }
  }
}

///|
fn pdf_native_core_bbox(bbox : PdfBBox) -> @core.BBox {
  {
    x0: bbox.x,
    y0: bbox.y,
    x1: pdf_bbox_right(bbox),
    y1: pdf_bbox_bottom(bbox),
  }
}

///|
fn pdf_native_link_candidate_json(
  link : PdfNativeLinkCandidate,
  fallback_page_no : Int,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("href", String(link.href))
  payload.set("target", String(link.href))
  payload.set(
    "page",
    Number(pdf_native_link_page_no(link, fallback_page_no).to_string()),
  )
  payload.set("bbox", pdf_native_bbox_json(link.bbox))
  match link.text {
    Some(text) =>
      if text.trim() != "" {
        payload.set("text", String(text.trim().to_owned()))
      }
    None => ()
  }
  match link.source_ref {
    Some(source_ref) => {
      match source_ref.file_id {
        Some(file_id) => payload.set("file_id", String(file_id))
        None => ()
      }
      match source_ref.format {
        Some(format) => payload.set("format", String(format))
        None => ()
      }
      match source_ref.page {
        Some(page_no) => payload.set("source_page", Number(page_no.to_string()))
        None => ()
      }
      match source_ref.bbox {
        Some(bbox) =>
          payload.set("source_bbox", pdf_native_core_bbox_json(bbox))
        None => ()
      }
      match source_ref.extra.get("reading_order_index") {
        Some(value) => payload.set("reading_order_index", Number(value))
        None => ()
      }
    }
    None => ()
  }
  match link.annotation_index {
    Some(value) => payload.set("annotation_index", Number(value.to_string()))
    None => ()
  }
  match link.annotation_object_id {
    Some(value) =>
      payload.set("annotation_object_id", Number(value.to_string()))
    None => ()
  }
  Object(payload)
}

///|
fn pdf_native_link_page_no(
  link : PdfNativeLinkCandidate,
  fallback_page_no : Int,
) -> Int {
  match link.source_ref {
    Some(source_ref) => source_ref.page.unwrap_or(fallback_page_no)
    None => fallback_page_no
  }
}

///|
