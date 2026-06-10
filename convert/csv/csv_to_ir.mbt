///|
priv enum DelimitedFormat {
  Csv
  Tsv
}

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

  let read_started = match profile {
    Some(_) => @env.now()
    None => 0
  }
  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("csv: read failed: " + e.to_string())
  }
  csv_profile_add_stage(
    profile,
    "csv_file_read",
    match profile {
      Some(_) => @env.now() - read_started
      None => 0
    },
    match profile {
      Some(_) => Some("bytes=" + bytes.length().to_string())
      None => None
    },
  )

  let decode_started = match profile {
    Some(_) => @env.now()
    None => 0
  }
  let text = decode_delimited_text(bytes, format) catch {
    e => raise @cor.AppError("csv: text decode failed: " + e.to_string())
  }
  csv_profile_add_stage(
    profile,
    "csv_bytes_to_string",
    match profile {
      Some(_) => @env.now() - decode_started
      None => 0
    },
    match profile {
      Some(_) =>
        Some(
          "format=" +
          format_label(format) +
          " chars=" +
          text.length().to_string(),
        )
      None => None
    },
  )

  let parse_started = match profile {
    Some(_) => @env.now()
    None => 0
  }
  let parsed = match format {
    DelimitedFormat::Csv => @dpcsv.parse_csv_document(text)
    DelimitedFormat::Tsv => @dptsv.parse_tsv_document(text)
  }
  csv_profile_add_stage(
    profile,
    "csv_parse_records",
    match profile {
      Some(_) => @env.now() - parse_started
      None => 0
    },
    match profile {
      Some(_) =>
        Some(
          "format=" +
          format_label(format) +
          " rows=" +
          parsed.rows.length().to_string(),
        )
      None => None
    },
  )
  let rows : Array[Array[String]] = []
  for row in parsed.rows {
    rows.push(row.fields)
  }
  let physical_line_count = parsed.line_count
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  if rows.length() == 0 {
    csv_profile_add_stage(
      profile,
      "csv_to_rich_table",
      0,
      match profile {
        Some(_) => Some("format=" + format_label(format) + " blocks=0")
        None => None
      },
    )
    return (doc, profile)
  }

  let table_started = match profile {
    Some(_) => @env.now()
    None => 0
  }
  @cor.push_with_origin(
    doc,
    @cor.Block::RichTable({ rows, header_rows: 1, hints: None }),
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
    match profile {
      Some(_) => @env.now() - table_started
      None => 0
    },
    match profile {
      Some(_) =>
        Some(
          "format=" +
          format_label(format) +
          " blocks=" +
          doc.blocks.val.length().to_string(),
        )
      None => None
    },
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
fn decode_delimited_text(
  bytes : Bytes,
  format : DelimitedFormat,
) -> String raise {
  let utf8_result = try decode_delimited_utf8_text(bytes) |> Ok catch {
    e => Err(e)
  }
  match utf8_result {
    Ok(text) => text
    Err(_) =>
      match decode_delimited_cp932_text(bytes) {
        Some(text) =>
          if looks_like_delimited_text(text, format) {
            normalize_delimited_text_non_bmp(text)
          } else {
            raise @cor.AppError("csv: unsupported text encoding")
          }
        None => raise @cor.AppError("csv: unsupported text encoding")
      }
  }
}

///|
fn decode_delimited_utf8_text(bytes : Bytes) -> String raise {
  let decoded = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise @cor.Utf8DecodeError("csv: invalid utf8")
  }
  normalize_delimited_text_non_bmp(decoded)
}

///|
fn looks_like_delimited_text(text : String, format : DelimitedFormat) -> Bool {
  if has_disallowed_delimited_control_char(text) {
    return false
  }
  text.contains(delimiter_for_format(format)) ||
  text.contains("\n") ||
  text.contains("\r")
}

///|
fn delimiter_for_format(format : DelimitedFormat) -> String {
  match format {
    DelimitedFormat::Csv => ","
    DelimitedFormat::Tsv => "\t"
  }
}

///|
fn has_disallowed_delimited_control_char(text : String) -> Bool {
  for ch in text.to_array() {
    let cp = ch.to_int()
    if cp < 0x20 && ch != '\n' && ch != '\r' && ch != '\t' {
      return true
    }
  }
  false
}

///|
fn normalize_delimited_text_non_bmp(decoded : String) -> String {
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
