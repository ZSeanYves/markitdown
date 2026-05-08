///|
/// Construct explicit CSV parse options.
pub fn new_csv_parse_options(
  delimiter : CsvDelimiter,
  quote_char : Char,
  double_quote_escape : Bool,
  skip_blank_rows : Bool,
  normalize_ragged_rows : Bool,
) -> CsvParseOptions {
  {
    delimiter,
    quote_char,
    double_quote_escape,
    skip_blank_rows,
    normalize_ragged_rows,
  }
}

///|
/// Return the default CSV parse options used by `parse_csv_document`.
pub fn default_csv_parse_options() -> CsvParseOptions {
  new_csv_parse_options(CsvDelimiter::Comma, '"', true, true, true)
}

///|
/// Return TSV-compatible options while reusing the shared CSV parser.
pub fn csv_parse_options_for_tsv() -> CsvParseOptions {
  new_csv_parse_options(CsvDelimiter::Tab, '"', true, true, true)
}

///|
/// Parse CSV text with the default CSV options.
pub fn parse_csv_document(text : String) -> CsvDocument raise {
  parse_csv_with_options(text, default_csv_parse_options())
}

///|
/// Parse delimited text into a source-native CSV document model.
pub fn parse_csv_with_options(
  text : String,
  options : CsvParseOptions,
) -> CsvDocument raise {
  let normalized = normalize_csv_source(text)
  parse_delimited_chars(normalized.to_array(), normalized, options)
}

///|
/// Classify a hard CSV parse failure into a stable error kind.
pub fn classify_csv_error(err : CsvError) -> CsvErrorInfo {
  let detail = err.to_string().to_lower()
  let kind = if detail.contains("unterminated quoted field") {
    CsvErrorKind::UnterminatedQuotedField
  } else {
    CsvErrorKind::Unknown
  }
  { kind, detail: err.to_string() }
}

///|
fn parse_delimited_chars(
  chars : Array[Char],
  normalized : String,
  options : CsvParseOptions,
) -> CsvDocument raise {
  if chars.length() == 0 {
    return {
      delimiter: options.delimiter,
      rows: [],
      column_count: 0,
      line_count: 0,
    }
  }

  let delimiter = delimiter_char(options.delimiter)
  let quote_char = options.quote_char
  let rows : Array[CsvRow] = []
  let mut row_fields : Array[String] = []
  let field : Array[Char] = []
  let mut in_quotes = false
  let mut field_started = false
  let mut last_was_record_break = false
  let mut i = 0
  let mut line_no = 1
  let mut row_line_start = 1
  let mut row_line_end = 1

  fn finish_field(row_fields : Array[String], field : Array[Char]) -> Unit {
    row_fields.push(String::from_array(field))
    field.clear()
  }

  fn finish_row(
    rows : Array[CsvRow],
    row_fields : Array[String],
    field : Array[Char],
    row_line_start : Int,
    row_line_end : Int,
    options : CsvParseOptions,
  ) -> Array[String] {
    finish_field(row_fields, field)
    let original_field_count = row_fields.length()
    if !(options.skip_blank_rows && row_is_blank(row_fields)) {
      rows.push({
        fields: row_fields,
        original_field_count,
        line_start: row_line_start,
        line_end: row_line_end,
      })
    }
    []
  }

  while i < chars.length() {
    let ch = chars[i]

    if in_quotes {
      if ch == quote_char {
        if options.double_quote_escape &&
          i + 1 < chars.length() &&
          chars[i + 1] == quote_char {
          field.push(quote_char)
          i += 2
          last_was_record_break = false
          continue
        } else {
          in_quotes = false
          i += 1
          last_was_record_break = false
          continue
        }
      }

      if ch == '\n' {
        row_line_end = line_no + 1
        line_no += 1
      }
      field.push(ch)
      i += 1
      last_was_record_break = false
      continue
    }

    if ch == quote_char && !field_started && field.length() == 0 {
      in_quotes = true
      field_started = true
      i += 1
      last_was_record_break = false
      continue
    }

    if ch == delimiter {
      finish_field(row_fields, field)
      field_started = false
      i += 1
      last_was_record_break = false
      continue
    }

    if ch == '\n' {
      row_line_end = line_no
      row_fields = finish_row(
        rows, row_fields, field, row_line_start, row_line_end, options,
      )
      field_started = false
      i += 1
      line_no += 1
      row_line_start = line_no
      row_line_end = line_no
      last_was_record_break = true
      continue
    }

    field.push(ch)
    field_started = true
    i += 1
    last_was_record_break = false
  }

  if in_quotes {
    raise ParseError("unterminated quoted field")
  }

  if field.length() > 0 || row_fields.length() > 0 || !last_was_record_break {
    row_line_end = line_no
    finish_field(row_fields, field)
    let original_field_count = row_fields.length()
    if !(options.skip_blank_rows && row_is_blank(row_fields)) {
      rows.push({
        fields: row_fields,
        original_field_count,
        line_start: row_line_start,
        line_end: row_line_end,
      })
    }
  }

  let column_count = widest_row_width(rows)
  if options.normalize_ragged_rows && column_count > 0 {
    for row in rows {
      while row.fields.length() < column_count {
        row.fields.push("")
      }
    }
  }

  {
    delimiter: options.delimiter,
    rows,
    column_count,
    line_count: physical_line_count(normalized),
  }
}

///|
fn delimiter_char(delimiter : CsvDelimiter) -> Char {
  match delimiter {
    CsvDelimiter::Comma => ','
    CsvDelimiter::Tab => '\t'
  }
}

///|
fn row_is_blank(row : Array[String]) -> Bool {
  for cell in row {
    if cell != "" {
      return false
    }
  }
  true
}

///|
fn widest_row_width(rows : Array[CsvRow]) -> Int {
  let mut width = 0
  for row in rows {
    if row.original_field_count > width {
      width = row.original_field_count
    }
  }
  width
}

///|
fn normalize_csv_source(text : String) -> String {
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

  let mut breaks = 0
  for ch in text.to_array() {
    if ch == '\n' {
      breaks += 1
    }
  }

  if text.has_suffix("\n") {
    breaks
  } else {
    breaks + 1
  }
}
