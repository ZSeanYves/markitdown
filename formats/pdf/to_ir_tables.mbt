///|
priv struct PdfNativeHeaderFooterCandidateSummary {
  strategy : String
  header_count : Int
  footer_count : Int
  candidates : Array[@core.JsonValue]
  skipped_reason : String?
}

///|
priv struct PdfNativeHeaderFooterLineCandidate {
  kind : String
  normalized_text : String
  text : String
  pages : Array[Int]
  page_count : Int
  representative_bbox : PdfBBox
  representative_source_ref : @core.SourceRef?
  confidence : String
  reason : String
}

///|
priv struct PdfNativeHeaderFooterBucket {
  kind : String
  normalized_text : String
  text : String
  pages : Array[Int]
  representative_bbox : PdfBBox
  representative_source_ref : @core.SourceRef?
  match_count : Int
  min_x : Double
  max_x : Double
}

///|
priv struct PdfNativeTableCandidateSummary {
  strategy : String
  row_count : Int
  candidates : Array[@core.JsonValue]
  skipped_reason : String?
}

///|
priv struct PdfNativeTableRowCandidate {
  page_no : Int
  text : String
  bbox : PdfBBox
  source_ref : @core.SourceRef?
  reading_order_index : Int?
  line_start : Int?
  line_end : Int?
  aligned_xs : Array[Double]
}

///|
priv struct PdfNativeTableRegionCandidate {
  page_no : Int
  bbox : PdfBBox
  row_count : Int
  column_alignment_count : Int
  alignment_xs : Array[Double]
  source_refs : Array[@core.SourceRef]
  reading_order_indices : Array[Int]
  line_start : Int?
  line_end : Int?
  confidence : String
  reason : String
}

///|
fn pdf_native_header_footer_candidates(
  doc : PdfNativeDocument,
) -> PdfNativeHeaderFooterCandidateSummary {
  let strategy = "conservative_v1"
  if doc.pages.length() < 2 {
    return {
      strategy,
      header_count: 0,
      footer_count: 0,
      candidates: [],
      skipped_reason: None,
    }
  }
  let geometry_missing = doc.pages.any(page => {
    page.geometry.width <= 0.0 || page.geometry.height <= 0.0
  })
  if geometry_missing {
    return {
      strategy,
      header_count: 0,
      footer_count: 0,
      candidates: [],
      skipped_reason: Some("no_page_geometry"),
    }
  }
  let buckets : Map[String, PdfNativeHeaderFooterBucket] = Map([])
  for page in doc.pages {
    for line in pdf_native_page_header_footer_line_candidates(page) {
      let text = pdf_native_line_text(line)
      let normalized_text = pdf_native_header_footer_normalized_text(text)
      if normalized_text == "" {
        continue
      }
      let kind = match pdf_native_line_band_kind(page.geometry, line.bbox) {
        Some(value) => value
        None => continue
      }
      let key = kind + "\n" + normalized_text
      match buckets.get(key) {
        Some(bucket) => {
          if bucket.pages.contains(page.geometry.page_no) {
            continue
          }
          let next_bucket = {
            ..bucket,
            pages: bucket.pages + [page.geometry.page_no],
            match_count: bucket.match_count + 1,
            min_x: pdf_native_double_min(bucket.min_x, line.bbox.x),
            max_x: pdf_native_double_max(bucket.max_x, line.bbox.x),
          }
          buckets.set(key, next_bucket)
        }
        None =>
          buckets.set(key, {
            kind,
            normalized_text,
            text,
            pages: [page.geometry.page_no],
            representative_bbox: line.bbox,
            representative_source_ref: pdf_native_line_preferred_source_ref(
              line,
            ),
            match_count: 1,
            min_x: line.bbox.x,
            max_x: line.bbox.x,
          })
      }
    }
  }
  let candidate_structs : Array[PdfNativeHeaderFooterLineCandidate] = []
  for entry in buckets.to_array() {
    let bucket = entry.1
    if !pdf_native_header_footer_bucket_is_candidate(bucket, doc.pages.length()) {
      continue
    }
    let sorted_pages : Array[Int] = []
    sorted_pages.append(bucket.pages[:])
    sorted_pages.sort()
    candidate_structs.push({
      kind: bucket.kind,
      normalized_text: bucket.normalized_text,
      text: bucket.text,
      pages: sorted_pages,
      page_count: sorted_pages.length(),
      representative_bbox: bucket.representative_bbox,
      representative_source_ref: bucket.representative_source_ref,
      confidence: pdf_native_header_footer_candidate_confidence(
        sorted_pages.length(),
        doc.pages.length(),
      ),
      reason: if bucket.kind == "header" {
        "repeated_top_band"
      } else {
        "repeated_bottom_band"
      },
    })
  }
  candidate_structs.sort_by(fn(left, right) {
    if left.kind < right.kind {
      -1
    } else if left.kind > right.kind {
      1
    } else if left.normalized_text < right.normalized_text {
      -1
    } else if left.normalized_text > right.normalized_text {
      1
    } else {
      0
    }
  })
  let candidate_json = candidate_structs.map(candidate => {
    pdf_native_header_footer_candidate_json(candidate)
  })
  let header_count = candidate_structs
    .filter(fn(candidate) { candidate.kind == "header" })
    .length()
  let footer_count = candidate_structs.length() - header_count
  {
    strategy,
    header_count,
    footer_count,
    candidates: candidate_json,
    skipped_reason: None,
  }
}

///|
fn pdf_native_table_candidates(
  doc : PdfNativeDocument,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
) -> PdfNativeTableCandidateSummary {
  let strategy = "conservative_v1"
  let table_row_candidates : Array[PdfNativeTableRowCandidate] = []
  for page in doc.pages {
    table_row_candidates.append(
      pdf_native_page_table_row_candidates(page, header_footer_candidates)[:],
    )
  }
  if table_row_candidates.length() == 0 {
    return { strategy, row_count: 0, candidates: [], skipped_reason: None }
  }
  let region_candidates : Array[PdfNativeTableRegionCandidate] = []
  let page_nos : Array[Int] = []
  for row in table_row_candidates {
    if !page_nos.contains(row.page_no) {
      page_nos.push(row.page_no)
    }
  }
  page_nos.sort()
  for page_no in page_nos {
    let page_rows : Array[PdfNativeTableRowCandidate] = []
    for row in table_row_candidates {
      if row.page_no == page_no {
        page_rows.push(row)
      }
    }
    page_rows.sort_by(fn(left, right) {
      if left.reading_order_index.unwrap_or(1_000_000) <
        right.reading_order_index.unwrap_or(1_000_000) {
        -1
      } else if left.reading_order_index.unwrap_or(1_000_000) >
        right.reading_order_index.unwrap_or(1_000_000) {
        1
      } else if left.bbox.y > right.bbox.y {
        -1
      } else if left.bbox.y < right.bbox.y {
        1
      } else {
        0
      }
    })
    let current_rows : Array[PdfNativeTableRowCandidate] = []
    for row in page_rows {
      if current_rows.length() == 0 {
        current_rows.push(row)
        continue
      }
      if pdf_native_table_row_should_join_region(current_rows, row) {
        current_rows.push(row)
      } else {
        match pdf_native_table_region_candidate(current_rows) {
          Some(region) => region_candidates.push(region)
          None => ()
        }
        current_rows.clear()
        current_rows.push(row)
      }
    }
    if current_rows.length() > 0 {
      match pdf_native_table_region_candidate(current_rows) {
        Some(region) => region_candidates.push(region)
        None => ()
      }
    }
  }
  region_candidates.sort_by(fn(left, right) {
    if left.page_no < right.page_no {
      -1
    } else if left.page_no > right.page_no {
      1
    } else if left.line_start.unwrap_or(1_000_000) <
      right.line_start.unwrap_or(1_000_000) {
      -1
    } else if left.line_start.unwrap_or(1_000_000) >
      right.line_start.unwrap_or(1_000_000) {
      1
    } else {
      0
    }
  })
  {
    strategy,
    row_count: table_row_candidates.length(),
    candidates: region_candidates.map(region => {
      pdf_native_table_region_candidate_json(region)
    }),
    skipped_reason: None,
  }
}

///|
fn pdf_native_page_header_footer_line_candidates(
  page : PdfNativePage,
) -> Array[PdfNativeTextLine] {
  let lines : Array[PdfNativeTextLine] = []
  for text_block in page.text_blocks {
    for line in text_block.lines {
      let text = pdf_native_line_text(line)
      if text == "" {
        continue
      }
      if pdf_bbox_is_empty(line.bbox) {
        continue
      }
      if pdf_native_line_band_kind(page.geometry, line.bbox) == None {
        continue
      }
      if !pdf_native_header_footer_text_is_eligible(text) {
        continue
      }
      lines.push(line)
    }
  }
  lines
}

///|
fn pdf_native_line_band_kind(
  geometry : PdfPageGeometry,
  bbox : PdfBBox,
) -> String? {
  if geometry.height <= 0.0 {
    return None
  }
  let top_threshold = geometry.height * 0.85
  let bottom_threshold = geometry.height * 0.15
  let y0 = bbox.y
  let y1 = pdf_bbox_bottom(bbox)
  if y1 >= top_threshold {
    Some("header")
  } else if y0 <= bottom_threshold {
    Some("footer")
  } else {
    None
  }
}

///|
fn pdf_native_header_footer_text_is_eligible(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if trimmed.length() > 120 {
    return false
  }
  if pdf_native_line_looks_like_list_boundary_text(trimmed) {
    return false
  }
  if pdf_native_line_looks_table_like(trimmed) {
    return false
  }
  true
}

///|
fn pdf_native_header_footer_normalized_text(text : String) -> String {
  let chars : Array[Char] = []
  let mut previous_space = false
  for ch in text.trim().to_owned().to_array() {
    let lowered = pdf_native_ascii_lower_char(ch)
    let is_space = lowered == ' ' ||
      lowered == '\n' ||
      lowered == '\r' ||
      lowered == '\t'
    if is_space {
      if !previous_space {
        chars.push(' ')
      }
      previous_space = true
    } else {
      chars.push(lowered)
      previous_space = false
    }
  }
  String::from_array(chars).trim().to_owned()
}

///|
fn pdf_native_ascii_lower_char(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    Int::unsafe_to_char(ch.to_int() + 32)
  } else {
    ch
  }
}

///|
fn pdf_native_header_footer_bucket_is_candidate(
  bucket : PdfNativeHeaderFooterBucket,
  total_pages : Int,
) -> Bool {
  if bucket.pages.length() < 2 {
    return false
  }
  if bucket.max_x - bucket.min_x > 24.0 {
    return false
  }
  if total_pages >= 4 {
    bucket.pages.length() * 2 >= total_pages
  } else {
    true
  }
}

///|
fn pdf_native_header_footer_candidate_confidence(
  page_count : Int,
  total_pages : Int,
) -> String {
  if total_pages > 0 && page_count == total_pages {
    "high"
  } else if total_pages > 0 && page_count * 2 >= total_pages {
    "medium"
  } else {
    "low"
  }
}

///|
fn pdf_native_header_footer_candidate_json(
  candidate : PdfNativeHeaderFooterLineCandidate,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("kind", @core.JsonValue::String(candidate.kind))
  payload.set(
    "normalized_text",
    @core.JsonValue::String(candidate.normalized_text),
  )
  payload.set("text", @core.JsonValue::String(candidate.text))
  payload.set(
    "page_count",
    @core.JsonValue::Number(candidate.page_count.to_string()),
  )
  payload.set("pages", pdf_native_int_array_json(candidate.pages))
  payload.set("bbox", pdf_native_bbox_json(candidate.representative_bbox))
  payload.set("confidence", @core.JsonValue::String(candidate.confidence))
  payload.set("reason", @core.JsonValue::String(candidate.reason))
  match candidate.representative_source_ref {
    Some(source_ref) =>
      payload.set("source_ref", pdf_native_source_ref_json(source_ref))
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_line_preferred_source_ref(
  line : PdfNativeTextLine,
) -> @core.SourceRef? {
  match line.source_ref {
    Some(source_ref) => Some(source_ref)
    None => {
      for span in line.spans {
        match span.source_ref {
          Some(source_ref) => return Some(source_ref)
          None => ()
        }
      }
      None
    }
  }
}

///|
fn pdf_native_line_candidate_source_ref(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  text_block_index : Int,
  line : PdfNativeTextLine,
  line_index : Int,
  merge_group : String,
) -> @core.SourceRef {
  let base = match pdf_native_line_preferred_source_ref(line) {
    Some(source_ref) => source_ref
    None => pdf_native_line_base_source_ref(line)
  }
  let line_no = base.line_start.unwrap_or(line_index + 1)
  let next = {
    ..base,
    format: Some(base.format.unwrap_or("pdf")),
    page: Some(base.page.unwrap_or(page.geometry.page_no)),
    bbox: pdf_native_effective_bbox(base.bbox, line.bbox),
    line_start: Some(line_no),
    line_end: Some(base.line_end.unwrap_or(line_no)),
  }
  if next.extra.get("page_no") == None {
    next.extra.set("page_no", page.geometry.page_no.to_string())
  }
  next.extra.set("pdf_text_block_index", text_block_index.to_string())
  next.extra.set("pdf_merge_group", merge_group)
  next.extra.set("pdf_line_index", line_no.to_string())
  next.extra.set(
    "pdf_line_end_index",
    next.line_end.unwrap_or(line_no).to_string(),
  )
  match text_block.reading_order_index {
    Some(value) => next.extra.set("reading_order_index", value.to_string())
    None =>
      match line.reading_order_index {
        Some(value) => next.extra.set("reading_order_index", value.to_string())
        None => ()
      }
  }
  next
}

///|
fn pdf_native_source_ref_json(source_ref : @core.SourceRef) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  match source_ref.file_id {
    Some(file_id) => payload.set("file_id", @core.JsonValue::String(file_id))
    None => ()
  }
  match source_ref.format {
    Some(format) => payload.set("format", @core.JsonValue::String(format))
    None => ()
  }
  match source_ref.page {
    Some(page_no) =>
      payload.set("page", @core.JsonValue::Number(page_no.to_string()))
    None => ()
  }
  match source_ref.line_start {
    Some(line_start) =>
      payload.set("line_start", @core.JsonValue::Number(line_start.to_string()))
    None => ()
  }
  match source_ref.line_end {
    Some(line_end) =>
      payload.set("line_end", @core.JsonValue::Number(line_end.to_string()))
    None => ()
  }
  match source_ref.bbox {
    Some(bbox) => payload.set("bbox", pdf_native_core_bbox_json(bbox))
    None => ()
  }
  let extra_entries : Map[String, @core.JsonValue] = Map([])
  for entry in source_ref.extra.to_array() {
    extra_entries.set(entry.0, @core.JsonValue::String(entry.1))
  }
  if extra_entries.length() > 0 {
    payload.set("extra", @core.JsonValue::Object(extra_entries))
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_int_array_json(values : Array[Int]) -> @core.JsonValue {
  @core.JsonValue::Array(
    values.map(value => @core.JsonValue::Number(value.to_string())),
  )
}

///|
fn pdf_native_line_looks_like_list_boundary_text(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let chars = trimmed.to_array()
  let first = chars[0]
  if first == '-' || first == '*' || first == '\u{2022}' {
    return true
  }
  let mut index = 0
  while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
    index += 1
  }
  index > 0 &&
  index < chars.length() &&
  (chars[index] == '.' || chars[index] == ')')
}

///|
fn pdf_native_line_looks_table_like(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.contains(" | ") || trimmed.contains("\t")
}

///|
fn pdf_native_double_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn pdf_native_double_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn pdf_native_page_table_row_candidates(
  page : PdfNativePage,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
) -> Array[PdfNativeTableRowCandidate] {
  let rows : Array[PdfNativeTableRowCandidate] = []
  for text_block in page.text_blocks {
    for line in text_block.lines {
      match
        pdf_native_table_row_candidate_from_line(
          page, line, header_footer_candidates,
        ) {
        Some(row) => rows.push(row)
        None => ()
      }
    }
  }
  rows
}

///|
fn pdf_native_table_row_candidate_from_line(
  page : PdfNativePage,
  line : PdfNativeTextLine,
  header_footer_candidates : PdfNativeHeaderFooterCandidateSummary,
) -> PdfNativeTableRowCandidate? {
  if pdf_bbox_is_empty(line.bbox) {
    return None
  }
  let text = pdf_native_line_text(line)
  if !pdf_native_table_row_text_is_eligible(text) {
    return None
  }
  if pdf_native_line_band_kind(page.geometry, line.bbox) is Some(_) {
    return None
  }
  let source_ref = pdf_native_line_preferred_source_ref(line)
  if pdf_native_line_matches_header_footer_candidate(
      line, text, source_ref, header_footer_candidates,
    ) {
    return None
  }
  let aligned_xs = pdf_native_table_row_alignment_positions(line, text)
  if aligned_xs.length() < 2 {
    return None
  }
  let base = pdf_native_line_base_source_ref(line)
  Some({
    page_no: base.page.unwrap_or(page.geometry.page_no),
    text,
    bbox: line.bbox,
    source_ref,
    reading_order_index: line.reading_order_index,
    line_start: base.line_start,
    line_end: Some(base.line_end.unwrap_or(base.line_start.unwrap_or(1))),
    aligned_xs,
  })
}

///|
fn pdf_native_table_row_text_is_eligible(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if trimmed.length() > 160 {
    return false
  }
  if pdf_native_line_looks_like_list_boundary_text(trimmed) {
    return false
  }
  if pdf_native_line_looks_table_like(trimmed) {
    return true
  }
  let tokens = pdf_native_table_text_tokens(trimmed)
  if tokens.length() < 3 {
    return false
  }
  let mut alpha_count = 0
  for token in tokens {
    if pdf_native_table_token_has_letter(token) {
      alpha_count += 1
    }
  }
  alpha_count >= 2
}

///|
fn pdf_native_line_matches_header_footer_candidate(
  line : PdfNativeTextLine,
  text : String,
  source_ref : @core.SourceRef?,
  summary : PdfNativeHeaderFooterCandidateSummary,
) -> Bool {
  let normalized_text = pdf_native_header_footer_normalized_text(text)
  for candidate in summary.candidates {
    match candidate {
      @core.JsonValue::Object(payload) => {
        let same_text = payload.get("normalized_text") ==
          Some(@core.JsonValue::String(normalized_text))
        let same_bbox = payload.get("bbox") ==
          Some(pdf_native_bbox_json(line.bbox))
        let same_line = match (payload.get("source_ref"), source_ref) {
          (Some(@core.JsonValue::Object(candidate_ref)), Some(current_ref)) =>
            candidate_ref.get("page") ==
            current_ref.page.map(page => {
              @core.JsonValue::Number(page.to_string())
            }) &&
            candidate_ref.get("line_start") ==
            current_ref.line_start.map(line_start => {
              @core.JsonValue::Number(line_start.to_string())
            })
          _ => false
        }
        if same_text && (same_bbox || same_line) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn pdf_native_table_row_alignment_positions(
  line : PdfNativeTextLine,
  text : String,
) -> Array[Double] {
  let xs : Array[Double] = []
  for span in line.spans {
    let trimmed = span.text.trim().to_owned()
    if trimmed == "" {
      continue
    }
    xs.push(span.bbox.x)
  }
  if xs.length() >= 2 {
    return pdf_native_distinct_sorted_xs(xs)
  }
  if !text.contains("  ") {
    return []
  }
  let tokens = pdf_native_table_text_tokens(text)
  if tokens.length() < 3 {
    return []
  }
  let fallback_xs : Array[Double] = []
  let mut index = 0
  for _token in tokens {
    fallback_xs.push(line.bbox.x + index.to_double() * 24.0)
    index += 1
  }
  pdf_native_distinct_sorted_xs(fallback_xs)
}

///|
fn pdf_native_distinct_sorted_xs(values : Array[Double]) -> Array[Double] {
  let xs : Array[Double] = []
  xs.append(values[:])
  xs.sort_by(fn(left, right) {
    if left < right {
      -1
    } else if left > right {
      1
    } else {
      0
    }
  })
  let distinct : Array[Double] = []
  for value in xs {
    if distinct.length() == 0 ||
      pdf_abs_double(value - distinct[distinct.length() - 1]) > 6.0 {
      distinct.push(value)
    }
  }
  distinct
}

///|
fn pdf_native_table_text_tokens(text : String) -> Array[String] {
  let tokens : Array[String] = []
  for token in text.split(" ") {
    let trimmed = token.trim().to_owned()
    if trimmed != "" {
      tokens.push(trimmed)
    }
  }
  tokens
}

///|
fn pdf_native_table_token_has_letter(token : String) -> Bool {
  for ch in token.to_array() {
    if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
      return true
    }
  }
  false
}

///|
fn pdf_native_table_row_should_join_region(
  current_rows : Array[PdfNativeTableRowCandidate],
  next_row : PdfNativeTableRowCandidate,
) -> Bool {
  let previous = current_rows[current_rows.length() - 1]
  let previous_index = previous.reading_order_index.unwrap_or(-1)
  let next_index = next_row.reading_order_index.unwrap_or(-1)
  if previous_index >= 0 && next_index >= 0 && next_index - previous_index > 2 {
    return false
  }
  let gap = previous.bbox.y - pdf_bbox_bottom(next_row.bbox)
  if gap < -4.0 || gap > 32.0 {
    return false
  }
  let current_alignment = pdf_native_table_region_alignment_positions(
    current_rows,
  )
  let overlap = pdf_native_table_alignment_overlap_count(
    current_alignment,
    next_row.aligned_xs,
  )
  overlap >= 2
}

///|
fn pdf_native_table_region_candidate(
  rows : Array[PdfNativeTableRowCandidate],
) -> PdfNativeTableRegionCandidate? {
  if rows.length() < 2 {
    return None
  }
  let alignment_positions = pdf_native_table_region_alignment_positions(rows)
  if alignment_positions.length() < 2 {
    return None
  }
  let mut bbox = make_pdf_bbox(0.0, 0.0, 0.0, 0.0)
  let source_refs : Array[@core.SourceRef] = []
  let reading_order_indices : Array[Int] = []
  for row in rows {
    bbox = if pdf_bbox_is_empty(bbox) {
      row.bbox
    } else {
      pdf_union_bbox(bbox, row.bbox)
    }
    match row.source_ref {
      Some(source_ref) => source_refs.push(source_ref)
      None => ()
    }
    match row.reading_order_index {
      Some(index) => reading_order_indices.push(index)
      None => ()
    }
  }
  Some({
    page_no: rows[0].page_no,
    bbox,
    row_count: rows.length(),
    column_alignment_count: alignment_positions.length(),
    alignment_xs: alignment_positions,
    source_refs,
    reading_order_indices,
    line_start: rows[0].line_start,
    line_end: rows[rows.length() - 1].line_end,
    confidence: pdf_native_table_candidate_confidence(
      rows.length(),
      alignment_positions.length(),
    ),
    reason: if rows.any(fn(row) { pdf_native_line_looks_table_like(row.text) }) {
      "table_like_rows"
    } else {
      "repeated_column_alignment"
    },
  })
}

///|
fn pdf_native_table_region_alignment_positions(
  rows : Array[PdfNativeTableRowCandidate],
) -> Array[Double] {
  let positions : Array[Double] = []
  let counts : Array[Int] = []
  for row in rows {
    for x in row.aligned_xs {
      let mut matched = false
      let mut index = 0
      while index < positions.length() {
        if pdf_abs_double(positions[index] - x) <= 8.0 {
          positions[index] = (positions[index] + x) / 2.0
          counts[index] = counts[index] + 1
          matched = true
          break
        }
        index += 1
      }
      if !matched {
        positions.push(x)
        counts.push(1)
      }
    }
  }
  let repeated : Array[Double] = []
  let threshold = if rows.length() >= 3 { 2 } else { rows.length() }
  let mut index = 0
  while index < positions.length() {
    if counts[index] >= threshold {
      repeated.push(positions[index])
    }
    index += 1
  }
  pdf_native_distinct_sorted_xs(repeated)
}

///|
fn pdf_native_table_alignment_overlap_count(
  left : Array[Double],
  right : Array[Double],
) -> Int {
  let mut count = 0
  for lhs in left {
    if right.any(fn(rhs) { pdf_abs_double(lhs - rhs) <= 8.0 }) {
      count += 1
    }
  }
  count
}

///|
fn pdf_native_table_candidate_confidence(
  row_count : Int,
  column_alignment_count : Int,
) -> String {
  if row_count >= 3 && column_alignment_count >= 3 {
    "high"
  } else if row_count >= 2 && column_alignment_count >= 2 {
    "medium"
  } else {
    "low"
  }
}

///|
fn pdf_native_table_region_candidate_json(
  candidate : PdfNativeTableRegionCandidate,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("page", @core.JsonValue::Number(candidate.page_no.to_string()))
  payload.set("bbox", pdf_native_bbox_json(candidate.bbox))
  payload.set(
    "row_count",
    @core.JsonValue::Number(candidate.row_count.to_string()),
  )
  payload.set(
    "column_alignment_count",
    @core.JsonValue::Number(candidate.column_alignment_count.to_string()),
  )
  if candidate.alignment_xs.length() > 0 {
    payload.set(
      "alignment_xs",
      @core.JsonValue::Array(
        candidate.alignment_xs.map(value => {
          @core.JsonValue::Number(value.to_string())
        }),
      ),
    )
  }
  payload.set("confidence", @core.JsonValue::String(candidate.confidence))
  payload.set("reason", @core.JsonValue::String(candidate.reason))
  match candidate.line_start {
    Some(line_start) =>
      payload.set("line_start", @core.JsonValue::Number(line_start.to_string()))
    None => ()
  }
  match candidate.line_end {
    Some(line_end) =>
      payload.set("line_end", @core.JsonValue::Number(line_end.to_string()))
    None => ()
  }
  if candidate.reading_order_indices.length() > 0 {
    payload.set(
      "reading_order_indices",
      pdf_native_int_array_json(candidate.reading_order_indices),
    )
  }
  if candidate.source_refs.length() > 0 {
    payload.set(
      "source_refs",
      @core.JsonValue::Array(
        candidate.source_refs.map(source_ref => {
          pdf_native_source_ref_json(source_ref)
        }),
      ),
    )
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_table_region_candidates_from_summary(
  summary : PdfNativeTableCandidateSummary,
  policy : @parser.PdfTableReconstructionPolicy,
) -> Array[PdfNativeTableRegionCandidate] {
  if policy != @parser.PdfTableReconstructionPolicy::InternalSimpleRowsOnly {
    return []
  }
  let regions : Array[PdfNativeTableRegionCandidate] = []
  for item in summary.candidates {
    match item {
      @core.JsonValue::Object(payload) => {
        let page_no = match payload.get("page") {
          Some(@core.JsonValue::Number(value)) =>
            @string.parse_int(value) catch {
              _ => -1
            }
          _ => -1
        }
        if page_no <= 0 {
          continue
        }
        let bbox = match payload.get("bbox") {
          Some(@core.JsonValue::Object(bbox_payload)) =>
            pdf_native_bbox_from_json_object(bbox_payload)
          _ => None
        }
        let row_count = match payload.get("row_count") {
          Some(@core.JsonValue::Number(value)) =>
            @string.parse_int(value) catch {
              _ => 0
            }
          _ => 0
        }
        let column_alignment_count = match
          payload.get("column_alignment_count") {
          Some(@core.JsonValue::Number(value)) =>
            @string.parse_int(value) catch {
              _ => 0
            }
          _ => 0
        }
        let confidence = match payload.get("confidence") {
          Some(@core.JsonValue::String(value)) => value
          _ => "low"
        }
        let alignment_xs = match payload.get("alignment_xs") {
          Some(@core.JsonValue::Array(values)) =>
            values
            .map(item => {
              match item {
                @core.JsonValue::Number(value) =>
                  @string.parse_double(value) catch {
                    _ => -1.0
                  }
                _ => -1.0
              }
            })
            .filter(value => value >= 0.0)
          _ => []
        }
        let reason = match payload.get("reason") {
          Some(@core.JsonValue::String(value)) => value
          _ => "unknown"
        }
        let line_start = match payload.get("line_start") {
          Some(@core.JsonValue::Number(value)) =>
            Some(@string.parse_int(value) catch { _ => 0 })
          _ => None
        }
        let line_end = match payload.get("line_end") {
          Some(@core.JsonValue::Number(value)) =>
            Some(@string.parse_int(value) catch { _ => 0 })
          _ => None
        }
        let source_refs = match payload.get("source_refs") {
          Some(@core.JsonValue::Array(values)) =>
            values
            .map(item => {
              match item {
                @core.JsonValue::Object(source_ref_payload) =>
                  pdf_native_source_ref_from_json_object(source_ref_payload)
                _ => None
              }
            })
            .filter_map(fn(value) { value })
          _ => []
        }
        let reading_order_indices = match payload.get("reading_order_indices") {
          Some(@core.JsonValue::Array(values)) =>
            values
            .map(item => {
              match item {
                @core.JsonValue::Number(value) =>
                  @string.parse_int(value) catch {
                    _ => -1
                  }
                _ => -1
              }
            })
            .filter(index => index >= 0)
          _ => []
        }
        match bbox {
          Some(value) =>
            regions.push({
              page_no,
              bbox: value,
              row_count,
              column_alignment_count,
              alignment_xs,
              source_refs,
              reading_order_indices,
              line_start,
              line_end,
              confidence,
              reason,
            })
          None => ()
        }
      }
      _ => ()
    }
  }
  regions
}
