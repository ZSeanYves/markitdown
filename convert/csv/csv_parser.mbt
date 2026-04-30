///|
priv enum DelimitedFormat {
  Csv
  Tsv
}

///|
fn delimiter_for_format(format : DelimitedFormat) -> Char {
  match format {
    DelimitedFormat::Csv => ','
    DelimitedFormat::Tsv => '\t'
  }
}

///|
fn parse_delimited_table(
  text : String,
  format : DelimitedFormat,
) -> Array[Array[String]] raise {
  let delimiter = delimiter_for_format(format)
  parse_delimited_chars(text.to_array(), delimiter)
}

///|
fn parse_delimited_chars(
  chars : Array[Char],
  delimiter : Char,
) -> Array[Array[String]] raise {
  if chars.length() == 0 {
    return []
  }

  let rows : Array[Array[String]] = []
  let mut row : Array[String] = []
  let field : Array[Char] = []
  let mut in_quotes = false
  let mut field_started = false
  let mut last_was_record_break = false
  let mut i = 0

  fn finish_field(row : Array[String], field : Array[Char]) -> Unit {
    row.push(String::from_array(field))
    field.clear()
  }

  fn finish_row(
    rows : Array[Array[String]],
    row : Array[String],
    field : Array[Char],
  ) -> Array[String] {
    finish_field(row, field)
    rows.push(row)
    []
  }

  while i < chars.length() {
    let ch = chars[i]

    if in_quotes {
      if ch == '"' {
        if i + 1 < chars.length() && chars[i + 1] == '"' {
          field.push('"')
          i = i + 2
          last_was_record_break = false
          continue
        } else {
          in_quotes = false
          i = i + 1
          last_was_record_break = false
          continue
        }
      }

      field.push(ch)
      i = i + 1
      last_was_record_break = false
      continue
    }

    if ch == '"' && !field_started && field.length() == 0 {
      in_quotes = true
      field_started = true
      i = i + 1
      last_was_record_break = false
      continue
    }

    if ch == delimiter {
      finish_field(row, field)
      field_started = false
      i = i + 1
      last_was_record_break = false
      continue
    }

    if ch == '\n' || ch == '\r' {
      row = finish_row(rows, row, field)
      field_started = false
      if ch == '\r' && i + 1 < chars.length() && chars[i + 1] == '\n' {
        i = i + 2
      } else {
        i = i + 1
      }
      last_was_record_break = true
      continue
    }

    field.push(ch)
    field_started = true
    i = i + 1
    last_was_record_break = false
  }

  if in_quotes {
    raise @cor.AppError("csv: unterminated quoted field")
  }

  if field.length() > 0 || row.length() > 0 || !last_was_record_break {
    finish_field(row, field)
    if row.length() > 0 {
      rows.push(row)
    }
  }

  normalize_ragged_rows(rows)
}

///|
fn normalize_ragged_rows(rows : Array[Array[String]]) -> Array[Array[String]] {
  let mut width = 0
  for row in rows {
    if row.length() > width {
      width = row.length()
    }
  }

  if width == 0 {
    return rows
  }

  for row in rows {
    while row.length() < width {
      row.push("")
    }
  }

  rows
}
