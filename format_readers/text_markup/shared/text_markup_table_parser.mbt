///|
pub fn parse_text_markup_table(
  block : TextMarkupBlock,
  format : TextMarkupFormat,
) -> TextMarkupTable? {
  if block.meta.contains("synthetic_table") {
    return parse_pipe_table_literal(block.text)
  }
  match format {
    TextMarkupFormat::Rst => parse_rst_table_block(block.text)
    TextMarkupFormat::Asciidoc => parse_asciidoc_table_block(block.text)
    TextMarkupFormat::Tex => parse_tex_table_block(block.text)
  }
}

///|
fn parse_pipe_table_literal(text : String) -> TextMarkupTable? {
  let content_lines = text
    .split("\n")
    .to_array()
    .map(line => line.trim().to_owned())
    .filter(line => line.has_prefix("|"))
  if content_lines.length() < 2 {
    return None
  }
  let rows = content_lines.map(parse_pipe_row)
  if rows.length() < 2 || rows[0].length() == 0 {
    return None
  }
  let body_rows : Array[Array[String]] = []
  for i in 1..<rows.length() {
    body_rows.push(rows[i])
  }
  Some({ header: rows[0], rows: body_rows })
}

///|
fn parse_rst_table_block(text : String) -> TextMarkupTable? {
  parse_pipe_table_literal(text)
}

///|
fn parse_asciidoc_table_block(text : String) -> TextMarkupTable? {
  let raw_lines = text
    .split("\n")
    .to_array()
    .map(line => line.trim().to_owned())
    .filter(line => line != "")
  let parsed_rows : Array[Array[String]] = []
  for line in raw_lines {
    if !line.has_prefix("|") {
      continue
    }
    let cells = parse_pipe_row(line)
    if cells.length() > 0 {
      parsed_rows.push(cells)
    }
  }
  if parsed_rows.length() < 2 {
    return None
  }
  let header = parsed_rows[0]
  if header.length() == 0 {
    return None
  }
  let rows : Array[Array[String]] = []
  let pending : Array[String] = []
  for i in 1..<parsed_rows.length() {
    let cells = parsed_rows[i]
    if cells.length() >= header.length() {
      if pending.length() > 0 {
        rows.push(pending.copy())
        pending.clear()
      }
      rows.push(cells)
      continue
    }
    for cell in cells {
      pending.push(cell)
      if pending.length() == header.length() {
        rows.push(pending.copy())
        pending.clear()
      }
    }
  }
  if pending.length() > 0 {
    rows.push(pending.copy())
  }
  if rows.length() == 0 {
    return None
  }
  Some({ header, rows })
}

///|
fn parse_tex_table_block(text : String) -> TextMarkupTable? {
  let raw_lines = text
    .split("\n")
    .to_array()
    .map(line => line.trim().to_owned())
    .filter(line => line != "" && line != "\\hline")
  let rows : Array[Array[String]] = []
  for line in raw_lines {
    let normalized = if line.has_suffix("\\\\") {
      line[:line.length() - 2].trim().to_owned()
    } else {
      line
    }
    if !normalized.contains("&") {
      continue
    }
    let cells = normalized
      .split("&")
      .to_array()
      .map(cell => cell.trim().to_owned())
      .filter(cell => cell != "")
    if cells.length() > 0 {
      rows.push(cells)
    }
  }
  if rows.length() < 2 {
    return None
  }
  let body_rows : Array[Array[String]] = []
  for i in 1..<rows.length() {
    body_rows.push(rows[i])
  }
  Some({ header: rows[0], rows: body_rows })
}

///|
fn parse_pipe_row(line : String) -> Array[String] {
  let trimmed = line.trim().to_owned()
  if !trimmed.has_prefix("|") {
    return []
  }
  trimmed
  .split("|")
  .to_array()
  .map(cell => cell.trim().to_owned())
  .filter(cell => cell != "")
}
