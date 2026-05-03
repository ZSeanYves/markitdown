///|
pub fn parse_csv(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  parse_delimited_file(input_path, DelimitedFormat::Csv)
}

///|
pub fn parse_tsv(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  parse_delimited_file(input_path, DelimitedFormat::Tsv)
}

///|
fn parse_delimited_file(
  input_path : String,
  format : DelimitedFormat,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("csv: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("csv: read failed: " + e.to_string())
  }

  let text = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("csv: utf8 decode failed: " + e.to_string())
  }
  let normalized = normalize_delimited_source(text)

  let rows = parse_delimited_table(normalized, format)
  let physical_line_count = physical_line_count(normalized)
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  if rows.length() == 0 {
    return doc
  }

  @cor.push_with_origin(
    doc,
    @cor.Block::RichTable({ rows, header_rows: 1 }),
    Some({
      source_name: Some(src),
      page: None,
      slide: None,
      sheet: None,
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: Some(1),
      line_end: Some(physical_line_count),
      row_index: Some(1),
      column_index: Some(1),
      object_ref: None,
      relationship_id: None,
      key_path: None,
    }),
  )

  doc
}

///|
fn normalize_delimited_source(text : String) -> String {
  let without_bom = if text.length() > 0 && text[0] == '\u{FEFF}' {
    text[1:].to_owned()
  } else {
    text
  }
  let out : Array[Char] = []
  let chars = without_bom.to_array()
  let mut i = 0

  while i < chars.length() {
    if chars[i] == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 2
      } else {
        i += 1
      }
    } else {
      out.push(chars[i])
      i += 1
    }
  }

  String::from_array(out)
}

///|
fn physical_line_count(text : String) -> Int {
  if text == "" {
    return 0
  }

  let normalized = text
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
  let mut breaks = 0
  for ch in normalized.to_array() {
    if ch == '\n' {
      breaks += 1
    }
  }

  if normalized.has_suffix("\n") {
    breaks
  } else {
    breaks + 1
  }
}
