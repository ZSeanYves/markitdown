///|
pub(all) enum PdfV2TableKind {
  PipeSeparated
  WhitespaceAligned
  CoordinateGrid
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2TableCellCandidate {
  text : String
  row_index : Int
  column_index : Int
  source_refs : Array[PdfV2SourceRef]
  confidence : Double
}

///|
pub(all) struct PdfV2TableCandidate {
  page_index : Int?
  block_indices : Array[Int]
  line_indices : Array[Int]
  rows : Array[Array[String]]
  columns : Int
  cells : Array[PdfV2TableCellCandidate]
  source_refs : Array[PdfV2SourceRef]
  confidence : Double
  reason_tags : Array[String]
  table_kind : PdfV2TableKind
  has_header : Bool
  header_row_index : Int?
}

///|
priv struct PdfV2TablePositionedText {
  page_index : Int?
  text : String
  x : Double
  y : Double
  source_ref : PdfV2SourceRef
  source_order : Int
}

///|
fn pdf_v2_table_abs(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
fn pdf_v2_table_ordered_lines(
  lines : Array[PdfV2LineCandidate],
) -> Array[PdfV2LineCandidate] {
  let ordered : Array[PdfV2LineCandidate] = []
  ordered.append(lines)
  ordered.sort_by(fn(a, b) { a.line_index - b.line_index })
  ordered
}

///|
fn pdf_v2_table_line_refs(
  lines : Array[PdfV2LineCandidate],
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for line in lines {
    refs.append(line.source_refs)
  }
  refs
}

///|
fn pdf_v2_table_line_indices(lines : Array[PdfV2LineCandidate]) -> Array[Int] {
  let out : Array[Int] = []
  for line in lines {
    out.push(line.line_index)
  }
  out
}

///|
fn pdf_v2_table_block_indices(block : PdfV2BlockCandidate) -> Array[Int] {
  [block.block_index]
}

///|
fn pdf_v2_table_cells_from_rows(
  rows : Array[Array[String]],
  source_refs : Array[PdfV2SourceRef],
  confidence : Double,
) -> Array[PdfV2TableCellCandidate] {
  let cells : Array[PdfV2TableCellCandidate] = []
  for row_index in 0..<rows.length() {
    let row = rows[row_index]
    for column_index in 0..<row.length() {
      cells.push({
        text: row[column_index],
        row_index,
        column_index,
        source_refs,
        confidence,
      })
    }
  }
  cells
}

///|
fn pdf_v2_table_candidate(
  page_index : Int?,
  block_indices : Array[Int],
  line_indices : Array[Int],
  rows : Array[Array[String]],
  source_refs : Array[PdfV2SourceRef],
  confidence : Double,
  reason_tags : Array[String],
  table_kind : PdfV2TableKind,
  header_rows : Int,
) -> PdfV2TableCandidate {
  let columns = if rows.length() == 0 { 0 } else { rows[0].length() }
  let has_header = header_rows > 0
  {
    page_index,
    block_indices,
    line_indices,
    rows,
    columns,
    cells: pdf_v2_table_cells_from_rows(rows, source_refs, confidence),
    source_refs,
    confidence,
    reason_tags,
    table_kind,
    has_header,
    header_row_index: if has_header {
      Some(0)
    } else {
      None
    },
  }
}

///|
fn pdf_v2_table_lines_from_block(
  block : PdfV2BlockCandidate,
) -> Array[PdfV2LineCandidate] {
  if block.lines.length() > 0 {
    pdf_v2_table_ordered_lines(block.lines)
  } else {
    []
  }
}

///|
fn pdf_v2_table_text_lines(text : String) -> Array[String] {
  let out : Array[String] = []
  for
    raw in text
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
    .split("\n") {
    let line = raw.to_owned().trim().to_owned()
    if line != "" {
      out.push(line)
    }
  }
  out
}

///|
fn pdf_v2_table_trim_edge_pipes(text : String) -> String {
  let mut out = text.trim().to_owned()
  if out.has_prefix("|") {
    out = out[1:].to_owned()
  }
  if out.has_suffix("|") && out.length() > 0 {
    out = out[:out.length() - 1].to_owned()
  }
  out.trim().to_owned()
}

///|
fn pdf_v2_table_parse_pipe_row(line : String) -> Array[String] {
  let row : Array[String] = []
  let inner = pdf_v2_table_trim_edge_pipes(line)
  for cell in inner.split("|") {
    row.push(cell.to_owned().trim().to_owned())
  }
  row
}

///|
fn pdf_v2_table_is_pipe_separator_cell(cell : String) -> Bool {
  let t = cell.trim().to_owned()
  if t.length() < 3 {
    return false
  }
  let chars = t.to_array()
  let mut dash_count = 0
  for i in 0..<chars.length() {
    let ch = chars[i]
    if ch == '-' {
      dash_count = dash_count + 1
    } else if (ch == ':' && (i == 0 || i + 1 == chars.length())) || ch == ' ' {
      ()
    } else {
      return false
    }
  }
  dash_count >= 3
}

///|
fn pdf_v2_table_is_pipe_separator_line(line : String) -> Bool {
  let row = pdf_v2_table_parse_pipe_row(line)
  if row.length() < 2 {
    return false
  }
  for cell in row {
    if !pdf_v2_table_is_pipe_separator_cell(cell) {
      return false
    }
  }
  true
}

///|
fn pdf_v2_table_parse_aligned_row(line : String) -> Array[String] {
  let row : Array[String] = []
  let chars = line.to_array()
  let mut cell = ""
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == ' ' || ch == '\t' {
      let mut j = i
      while j < chars.length() && (chars[j] == ' ' || chars[j] == '\t') {
        j = j + 1
      }
      if j - i >= 2 {
        let value = cell.trim().to_owned()
        if value == "" {
          return []
        }
        row.push(value)
        cell = ""
      } else {
        cell = cell + " "
      }
      i = j
    } else {
      cell = cell + ch.to_string()
      i = i + 1
    }
  }
  let value = cell.trim().to_owned()
  if value != "" {
    row.push(value)
  }
  row
}

///|
fn pdf_v2_table_starts_with_numbered_list_marker(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 4 {
    return false
  }
  let mut i = 0
  let mut saw_digit = false
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      saw_digit = true
      i = i + 1
      continue
    }
    break
  }
  if !saw_digit || i + 1 >= chars.length() {
    return false
  }
  (chars[i] == '.' || chars[i] == ')' || chars[i] == '\u{3001}') &&
  (chars[i + 1] == ' ' || chars[i + 1] == '\t')
}

///|
fn pdf_v2_table_sentence_like_cell(cell : String) -> Bool {
  let t = cell.trim().to_owned()
  if t.length() < 24 {
    return false
  }
  let words = t.split(" ").length()
  (t.has_suffix(".") || t.has_suffix("!") || t.has_suffix("?")) && words >= 5
}

///|
fn pdf_v2_table_numeric_like(cell : String) -> Bool {
  let t = cell
    .trim()
    .to_owned()
    .replace_all(old=",", new="")
    .replace_all(old="%", new="")
  if t == "" {
    return false
  }
  let chars = t.to_array()
  let mut digit_count = 0
  for i in 0..<chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      digit_count = digit_count + 1
    } else if ch == '.' || (i == 0 && (ch == '-' || ch == '+')) || ch == '$' {
      ()
    } else {
      return false
    }
  }
  digit_count > 0
}

///|
fn pdf_v2_table_short_label(cell : String) -> Bool {
  let t = cell.trim().to_owned()
  t != "" &&
  t.length() <= 32 &&
  !pdf_v2_table_numeric_like(t) &&
  !pdf_v2_table_sentence_like_cell(t)
}

///|
fn pdf_v2_table_row_reject(row : Array[String]) -> Bool {
  for cell in row {
    let t = cell.trim().to_owned()
    if t == "" {
      return true
    }
    let lower = t.to_lower()
    if lower.has_prefix("figure ") ||
      lower.has_prefix("fig. ") ||
      lower.has_prefix("table ") ||
      t.has_prefix("图") ||
      t.has_prefix("表 ") ||
      t.has_prefix("- ") ||
      t.has_prefix("* ") ||
      t.has_prefix("\u{2022} ") ||
      pdf_v2_table_starts_with_numbered_list_marker(t) ||
      pdf_v2_table_sentence_like_cell(t) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_table_rows_reliable(rows : Array[Array[String]]) -> Bool {
  if rows.length() < 2 {
    return false
  }
  let width = rows[0].length()
  if width < 2 {
    return false
  }
  let mut numeric_count = 0
  let mut short_label_count = 0
  let mut cell_count = 0
  for row in rows {
    if row.length() != width || pdf_v2_table_row_reject(row) {
      return false
    }
    for cell in row {
      cell_count = cell_count + 1
      if pdf_v2_table_numeric_like(cell) {
        numeric_count = numeric_count + 1
      }
      if pdf_v2_table_short_label(cell) {
        short_label_count = short_label_count + 1
      }
    }
  }
  numeric_count > 0 || short_label_count * 2 >= cell_count
}

///|
fn pdf_v2_table_numeric_cell_count(row : Array[String]) -> Int {
  let mut out = 0
  for cell in row {
    if pdf_v2_table_numeric_like(cell) {
      out = out + 1
    }
  }
  out
}

///|
fn pdf_v2_table_infer_header_rows(rows : Array[Array[String]]) -> Int {
  if rows.length() < 2 {
    return 0
  }
  let first_numeric = pdf_v2_table_numeric_cell_count(rows[0])
  let second_numeric = pdf_v2_table_numeric_cell_count(rows[1])
  if first_numeric == 0 && second_numeric > 0 {
    return 1
  }
  let mut short_labels = 0
  for cell in rows[0] {
    if pdf_v2_table_short_label(cell) {
      short_labels = short_labels + 1
    }
  }
  if short_labels * 2 >= rows[0].length() {
    1
  } else {
    0
  }
}

///|
fn pdf_v2_table_from_pipe_lines(
  lines : Array[String],
) -> (Array[Array[String]], Int, Double)? {
  if lines.length() < 2 {
    return None
  }
  let rows : Array[Array[String]] = []
  let mut separator_seen = false
  let mut width = 0
  for i in 0..<lines.length() {
    let line = lines[i]
    if !line.contains("|") {
      return None
    }
    if pdf_v2_table_is_pipe_separator_line(line) {
      if i != 1 || separator_seen || rows.length() != 1 {
        return None
      }
      separator_seen = true
      continue
    }
    let row = pdf_v2_table_parse_pipe_row(line)
    if row.length() < 2 {
      return None
    }
    if width == 0 {
      width = row.length()
    } else if row.length() != width {
      return None
    }
    rows.push(row)
  }
  if rows.length() < 2 {
    return None
  }
  if separator_seen {
    Some((rows, 1, 0.96))
  } else if pdf_v2_table_rows_reliable(rows) {
    Some((rows, pdf_v2_table_infer_header_rows(rows), 0.86))
  } else {
    None
  }
}

///|
fn pdf_v2_table_from_aligned_lines(
  lines : Array[String],
) -> (Array[Array[String]], Int, Double)? {
  if lines.length() < 2 {
    return None
  }
  let rows : Array[Array[String]] = []
  let mut width = 0
  for line in lines {
    if line.contains("|") {
      return None
    }
    let row = pdf_v2_table_parse_aligned_row(line)
    if row.length() < 2 || pdf_v2_table_row_reject(row) {
      return None
    }
    if width == 0 {
      width = row.length()
    } else if row.length() != width {
      return None
    }
    rows.push(row)
  }
  if rows.length() < 2 || !pdf_v2_table_rows_reliable(rows) {
    return None
  }
  Some((rows, pdf_v2_table_infer_header_rows(rows), 0.82))
}

///|
fn pdf_v2_table_candidate_from_line_group(
  block : PdfV2BlockCandidate,
  lines : Array[PdfV2LineCandidate],
  kind : PdfV2TableKind,
) -> PdfV2TableCandidate? {
  let text_lines : Array[String] = []
  for line in lines {
    let text = line.text.trim().to_owned()
    if text != "" {
      text_lines.push(text)
    }
  }
  let parsed = match kind {
    PdfV2TableKind::PipeSeparated => pdf_v2_table_from_pipe_lines(text_lines)
    PdfV2TableKind::WhitespaceAligned =>
      pdf_v2_table_from_aligned_lines(text_lines)
    _ => None
  }
  match parsed {
    Some((rows, header_rows, confidence)) =>
      Some(
        pdf_v2_table_candidate(
          block.page_index,
          pdf_v2_table_block_indices(block),
          pdf_v2_table_line_indices(lines),
          rows,
          pdf_v2_table_line_refs(lines),
          confidence,
          ["table_candidate", "parser_side_fact", "text_line_table_candidate"],
          kind,
          header_rows,
        ),
      )
    None => None
  }
}

///|
fn pdf_v2_table_block_text_candidate(
  block : PdfV2BlockCandidate,
) -> PdfV2TableCandidate? {
  let text_lines = pdf_v2_table_text_lines(block.text)
  if text_lines.length() < 2 {
    return None
  }
  match pdf_v2_table_from_pipe_lines(text_lines) {
    Some((rows, header_rows, confidence)) =>
      Some(
        pdf_v2_table_candidate(
          block.page_index,
          pdf_v2_table_block_indices(block),
          [],
          rows,
          block.source_refs,
          confidence,
          ["table_candidate", "parser_side_fact", "block_text_table_candidate"],
          PdfV2TableKind::PipeSeparated,
          header_rows,
        ),
      )
    None =>
      match pdf_v2_table_from_aligned_lines(text_lines) {
        Some((rows, header_rows, confidence)) =>
          Some(
            pdf_v2_table_candidate(
              block.page_index,
              pdf_v2_table_block_indices(block),
              [],
              rows,
              block.source_refs,
              confidence,
              [
                "table_candidate", "parser_side_fact", "block_text_table_candidate",
              ],
              PdfV2TableKind::WhitespaceAligned,
              header_rows,
            ),
          )
        None => None
      }
  }
}

///|
fn pdf_v2_table_candidates_from_block_lines(
  block : PdfV2BlockCandidate,
) -> Array[PdfV2TableCandidate] {
  let lines = pdf_v2_table_lines_from_block(block)
  let out : Array[PdfV2TableCandidate] = []
  if lines.length() < 2 {
    return out
  }
  let mut i = 0
  while i < lines.length() {
    if lines[i].text.contains("|") {
      let group : Array[PdfV2LineCandidate] = []
      let mut j = i
      while j < lines.length() && lines[j].text.contains("|") {
        group.push(lines[j])
        j = j + 1
      }
      match
        pdf_v2_table_candidate_from_line_group(
          block,
          group,
          PdfV2TableKind::PipeSeparated,
        ) {
        Some(candidate) => {
          out.push(candidate)
          i = j
          continue
        }
        None => ()
      }
    }
    if pdf_v2_table_parse_aligned_row(lines[i].text).length() >= 2 {
      let group : Array[PdfV2LineCandidate] = []
      let mut j = i
      while j < lines.length() &&
            !lines[j].text.contains("|") &&
            pdf_v2_table_parse_aligned_row(lines[j].text).length() >= 2 {
        group.push(lines[j])
        j = j + 1
      }
      match
        pdf_v2_table_candidate_from_line_group(
          block,
          group,
          PdfV2TableKind::WhitespaceAligned,
        ) {
        Some(candidate) => {
          out.push(candidate)
          i = j
          continue
        }
        None => ()
      }
    }
    i = i + 1
  }
  out
}

///|
fn pdf_v2_table_candidates_from_blocks(
  blocks : Array[PdfV2BlockCandidate],
) -> Array[PdfV2TableCandidate] {
  let out : Array[PdfV2TableCandidate] = []
  for block in blocks {
    match pdf_v2_table_block_text_candidate(block) {
      Some(candidate) => out.push(candidate)
      None => {
        let candidates = pdf_v2_table_candidates_from_block_lines(block)
        out.append(candidates)
      }
    }
  }
  out
}

///|
fn pdf_v2_table_positioned_texts(
  events : Array[PdfV2SourceEvent],
) -> Array[PdfV2TablePositionedText] {
  let out : Array[PdfV2TablePositionedText] = []
  for event in events {
    match event.text_show {
      Some(show) =>
        match (show.decoded_text, show.text_matrix_snapshot) {
          (Some(text), Some(matrix)) => {
            let trimmed = text.trim().to_owned()
            if trimmed == "" {
              continue
            }
            match show.decode_confidence {
              High | Medium =>
                out.push({
                  page_index: show.source_ref.page_index,
                  text: trimmed,
                  x: matrix.e,
                  y: matrix.f,
                  source_ref: show.source_ref,
                  source_order: show.source_ref.content_order_index.unwrap_or(0),
                })
              _ => ()
            }
          }
          _ => ()
        }
      None => ()
    }
  }
  out
}

///|
fn pdf_v2_table_positioned_order(
  items : Array[PdfV2TablePositionedText],
) -> Array[PdfV2TablePositionedText] {
  let ordered : Array[PdfV2TablePositionedText] = []
  ordered.append(items)
  ordered.sort_by(fn(a, b) {
    if a.y > b.y {
      -1
    } else if a.y < b.y {
      1
    } else if a.x < b.x {
      -1
    } else if a.x > b.x {
      1
    } else {
      a.source_order - b.source_order
    }
  })
  ordered
}

///|
fn pdf_v2_table_x_order(
  row : Array[PdfV2TablePositionedText],
) -> Array[PdfV2TablePositionedText] {
  let ordered : Array[PdfV2TablePositionedText] = []
  ordered.append(row)
  ordered.sort_by(fn(a, b) {
    if a.x < b.x {
      -1
    } else if a.x > b.x {
      1
    } else {
      a.source_order - b.source_order
    }
  })
  ordered
}

///|
fn pdf_v2_table_group_rows_by_y(
  items : Array[PdfV2TablePositionedText],
) -> Array[Array[PdfV2TablePositionedText]] {
  let ordered = pdf_v2_table_positioned_order(items)
  let row_ys : Array[Double] = []
  let rows : Array[Array[PdfV2TablePositionedText]] = []
  let tolerance = 3.0
  for item in ordered {
    let mut found = -1
    for i in 0..<row_ys.length() {
      if pdf_v2_table_abs(row_ys[i] - item.y) <= tolerance {
        found = i
        break
      }
    }
    if found < 0 {
      row_ys.push(item.y)
      rows.push([item])
    } else {
      rows[found].push(item)
    }
  }
  let out : Array[Array[PdfV2TablePositionedText]] = []
  for row in rows {
    out.push(pdf_v2_table_x_order(row))
  }
  out
}

///|
fn pdf_v2_table_rows_x_aligned(
  first : Array[PdfV2TablePositionedText],
  row : Array[PdfV2TablePositionedText],
) -> Bool {
  if first.length() != row.length() || first.length() < 2 {
    return false
  }
  for i in 0..<first.length() {
    if pdf_v2_table_abs(first[i].x - row[i].x) > 8.0 {
      return false
    }
  }
  true
}

///|
fn pdf_v2_table_row_x_spread_ok(row : Array[PdfV2TablePositionedText]) -> Bool {
  if row.length() < 2 {
    return false
  }
  for i in 1..<row.length() {
    if row[i].x - row[i - 1].x < 18.0 {
      return false
    }
  }
  true
}

///|
fn pdf_v2_table_grid_rows_reliable(
  rows : Array[Array[PdfV2TablePositionedText]],
) -> Bool {
  if rows.length() < 3 || rows[0].length() < 2 {
    return false
  }
  let width = rows[0].length()
  for row in rows {
    if row.length() != width || !pdf_v2_table_row_x_spread_ok(row) {
      return false
    }
    let text_row : Array[String] = []
    for cell in row {
      text_row.push(cell.text)
    }
    if pdf_v2_table_row_reject(text_row) {
      return false
    }
  }
  let string_rows : Array[Array[String]] = []
  for row in rows {
    let string_row : Array[String] = []
    for cell in row {
      string_row.push(cell.text)
    }
    string_rows.push(string_row)
  }
  pdf_v2_table_rows_reliable(string_rows)
}

///|
fn pdf_v2_table_source_refs_from_grid(
  rows : Array[Array[PdfV2TablePositionedText]],
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for row in rows {
    for cell in row {
      refs.push(cell.source_ref)
    }
  }
  refs
}

///|
fn pdf_v2_table_string_rows_from_grid(
  rows : Array[Array[PdfV2TablePositionedText]],
) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for row in rows {
    let text_row : Array[String] = []
    for cell in row {
      text_row.push(cell.text)
    }
    out.push(text_row)
  }
  out
}

///|
fn pdf_v2_table_event_line_indices(
  rows : Array[Array[PdfV2TablePositionedText]],
) -> Array[Int] {
  let out : Array[Int] = []
  let mut index = 0
  for row in rows {
    for _cell in row {
      out.push(index)
      index = index + 1
    }
  }
  out
}

///|
fn pdf_v2_table_flat_text(rows : Array[Array[String]]) -> String {
  let parts : Array[String] = []
  for row in rows {
    for cell in row {
      let text = cell.trim().to_owned()
      if text != "" {
        parts.push(text)
      }
    }
  }
  parts.join(" ")
}

///|
fn pdf_v2_table_normalize_flat_text(text : String) -> String {
  let out = StringBuilder::new()
  let mut prev_space = false
  for ch in text {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if !prev_space {
        out.write_char(' ')
        prev_space = true
      }
    } else {
      out.write_char(ch)
      prev_space = false
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn pdf_v2_table_matching_block_indices(
  blocks : Array[PdfV2BlockCandidate],
  page_index : Int?,
  rows : Array[Array[String]],
  source_refs : Array[PdfV2SourceRef],
) -> Array[Int] {
  let target = pdf_v2_table_flat_text(rows)
  let out : Array[Int] = []
  if target == "" {
    return out
  }
  for block in blocks {
    if block.page_index != page_index {
      continue
    }
    let text = pdf_v2_table_normalize_flat_text(block.text)
    if pdf_v2_table_source_refs_overlap(block.source_refs, source_refs) ||
      text.contains(target) {
      out.push(block.block_index)
    }
  }
  if out.length() > 0 {
    return out
  }
  pdf_v2_table_matching_contiguous_block_indices(blocks, page_index, target)
}

///|
fn pdf_v2_table_ordered_blocks(
  blocks : Array[PdfV2BlockCandidate],
) -> Array[PdfV2BlockCandidate] {
  let ordered : Array[PdfV2BlockCandidate] = []
  ordered.append(blocks)
  ordered.sort_by(fn(a, b) { a.block_index - b.block_index })
  ordered
}

///|
fn pdf_v2_table_matching_contiguous_block_indices(
  blocks : Array[PdfV2BlockCandidate],
  page_index : Int?,
  target : String,
) -> Array[Int] {
  let ordered = pdf_v2_table_ordered_blocks(blocks)
  for start in 0..<ordered.length() {
    let indices : Array[Int] = []
    let parts : Array[String] = []
    let mut j = start
    while j < ordered.length() {
      let block = ordered[j]
      if block.page_index != page_index {
        break
      }
      let text = pdf_v2_table_normalize_flat_text(block.text)
      if text == "" {
        break
      }
      parts.push(text)
      indices.push(block.block_index)
      let candidate = pdf_v2_table_normalize_flat_text(parts.join(" "))
      if candidate == target {
        return indices
      }
      if !target.has_prefix(candidate) {
        break
      }
      j = j + 1
    }
  }
  []
}

///|
fn pdf_v2_table_grid_candidate(
  rows : Array[Array[PdfV2TablePositionedText]],
  blocks : Array[PdfV2BlockCandidate],
) -> PdfV2TableCandidate? {
  if !pdf_v2_table_grid_rows_reliable(rows) {
    return None
  }
  let string_rows = pdf_v2_table_string_rows_from_grid(rows)
  let source_refs = pdf_v2_table_source_refs_from_grid(rows)
  let page_index = if rows.length() > 0 && rows[0].length() > 0 {
    rows[0][0].page_index
  } else {
    None
  }
  Some(
    pdf_v2_table_candidate(
      page_index,
      pdf_v2_table_matching_block_indices(
        blocks, page_index, string_rows, source_refs,
      ),
      pdf_v2_table_event_line_indices(rows),
      string_rows,
      source_refs,
      0.90,
      [
        "table_candidate", "parser_side_fact", "coordinate_grid_table_candidate",
        "line_indices_from_text_show_order",
      ],
      PdfV2TableKind::CoordinateGrid,
      pdf_v2_table_infer_header_rows(string_rows),
    ),
  )
}

///|
fn pdf_v2_table_candidates_from_positioned_page(
  items : Array[PdfV2TablePositionedText],
  blocks : Array[PdfV2BlockCandidate],
) -> Array[PdfV2TableCandidate] {
  let row_groups = pdf_v2_table_group_rows_by_y(items)
  let out : Array[PdfV2TableCandidate] = []
  let mut i = 0
  while i < row_groups.length() {
    if row_groups[i].length() < 2 {
      i = i + 1
      continue
    }
    let first = row_groups[i]
    let group : Array[Array[PdfV2TablePositionedText]] = [first]
    let mut j = i + 1
    while j < row_groups.length() &&
          pdf_v2_table_rows_x_aligned(first, row_groups[j]) {
      group.push(row_groups[j])
      j = j + 1
    }
    match pdf_v2_table_grid_candidate(group, blocks) {
      Some(candidate) => {
        out.push(candidate)
        i = j
      }
      None => i = i + 1
    }
  }
  out
}

///|
fn pdf_v2_table_candidates_from_text_shows(
  events : Array[PdfV2SourceEvent],
  blocks : Array[PdfV2BlockCandidate],
) -> Array[PdfV2TableCandidate] {
  let items = pdf_v2_table_positioned_texts(events)
  let page_indices : Array[Int?] = []
  for item in items {
    if !page_indices.contains(item.page_index) {
      page_indices.push(item.page_index)
    }
  }
  let out : Array[PdfV2TableCandidate] = []
  for page_index in page_indices {
    let page_items : Array[PdfV2TablePositionedText] = []
    for item in items {
      if item.page_index == page_index {
        page_items.push(item)
      }
    }
    out.append(pdf_v2_table_candidates_from_positioned_page(page_items, blocks))
  }
  out
}

///|
fn pdf_v2_table_source_refs_overlap(
  left : Array[PdfV2SourceRef],
  right : Array[PdfV2SourceRef],
) -> Bool {
  for a in left {
    for b in right {
      if a.page_index == b.page_index &&
        a.object_id == b.object_id &&
        a.stream_index == b.stream_index &&
        a.op_index == b.op_index &&
        a.content_order_index == b.content_order_index &&
        a.kind == b.kind {
        return true
      }
    }
  }
  false
}

///|
fn pdf_v2_table_duplicate_candidate(
  candidate : PdfV2TableCandidate,
  existing : Array[PdfV2TableCandidate],
) -> Bool {
  for item in existing {
    if candidate.page_index == item.page_index &&
      pdf_v2_table_source_refs_overlap(candidate.source_refs, item.source_refs) {
      return true
    }
    if candidate.page_index == item.page_index &&
      pdf_v2_table_flat_text(candidate.rows) ==
      pdf_v2_table_flat_text(item.rows) {
      return true
    }
  }
  false
}

///|
pub fn pdf_v2_build_table_candidates(
  source_events : Array[PdfV2SourceEvent],
  blocks : Array[PdfV2BlockCandidate],
) -> Array[PdfV2TableCandidate] {
  let out = pdf_v2_table_candidates_from_blocks(blocks)
  let grid = pdf_v2_table_candidates_from_text_shows(source_events, blocks)
  for candidate in grid {
    if !pdf_v2_table_duplicate_candidate(candidate, out) {
      out.push(candidate)
    }
  }
  out
}
