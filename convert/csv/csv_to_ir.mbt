///|
pub fn parse_csv(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  parse_csv_with_profile(input_path, _out_dir, _max_heading).0
}

///|
pub fn parse_tsv(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  parse_tsv_with_profile(input_path, _out_dir, _max_heading).0
}

///|
pub fn parse_csv_with_profile(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> (@cor.Document, CsvProfileReport?) raise {
  parse_delimited_file_with_profile_impl(input_path, DelimitedFormat::Csv)
}

///|
pub fn parse_tsv_with_profile(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> (@cor.Document, CsvProfileReport?) raise {
  parse_delimited_file_with_profile_impl(input_path, DelimitedFormat::Tsv)
}

///|
fn parse_delimited_file_with_profile_impl(
  input_path : String,
  format : DelimitedFormat,
) -> (@cor.Document, CsvProfileReport?) raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("csv: file not found: " + input_path)
  }

  let profile = if csv_profile_enabled() {
    Some(new_csv_profile_report(input_path, format_label(format)))
  } else {
    None
  }

  let read_started = @env.now()
  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("csv: read failed: " + e.to_string())
  }
  csv_profile_add_stage(
    profile,
    "csv_file_read",
    @env.now() - read_started,
    Some("bytes=" + bytes.length().to_string()),
  )

  let decode_started = @env.now()
  let text = decode_delimited_utf8_text(bytes) catch {
    e => raise @cor.AppError("csv: utf8 decode failed: " + e.to_string())
  }
  csv_profile_add_stage(
    profile,
    "csv_bytes_to_string",
    @env.now() - decode_started,
    Some(
      "format=" + format_label(format) + " chars=" + text.length().to_string(),
    ),
  )

  let normalize_started = @env.now()
  let normalized = normalize_delimited_source(text)
  csv_profile_add_stage(
    profile,
    "csv_normalize_newlines",
    @env.now() - normalize_started,
    Some("chars=" + normalized.length().to_string()),
  )

  let parse_started = @env.now()
  let rows = parse_delimited_table(normalized, format)
  csv_profile_add_stage(
    profile,
    "csv_parse_records",
    @env.now() - parse_started,
    Some(
      "format=" + format_label(format) + " rows=" + rows.length().to_string(),
    ),
  )
  let physical_line_count = physical_line_count(normalized)
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  if rows.length() == 0 {
    csv_profile_add_stage(
      profile,
      "csv_to_rich_table",
      0,
      Some("format=" + format_label(format) + " blocks=0"),
    )
    return (doc, profile)
  }

  let table_started = @env.now()
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
  csv_profile_add_stage(
    profile,
    "csv_to_rich_table",
    @env.now() - table_started,
    Some(
      "format=" +
      format_label(format) +
      " blocks=" +
      doc.blocks.val.length().to_string(),
    ),
  )

  (doc, profile)
}

///|
fn format_label(format : DelimitedFormat) -> String {
  match format {
    DelimitedFormat::Csv => "csv"
    DelimitedFormat::Tsv => "tsv"
  }
}

///|
fn decode_delimited_utf8_text(bytes : Bytes) -> String raise {
  let decoded = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise @cor.Utf8DecodeError("csv: invalid utf8")
  }

  if !contains_non_bmp_char(decoded) {
    return decoded
  }

  let out = StringBuilder::new()
  for ch in decoded.to_array() {
    let cp = ch.to_int()
    if cp > 0xFFFF {
      out.write_string("&#" + cp.to_string() + ";")
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn contains_non_bmp_char(text : String) -> Bool {
  for ch in text.to_array() {
    if ch.to_int() > 0xFFFF {
      return true
    }
  }
  false
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
