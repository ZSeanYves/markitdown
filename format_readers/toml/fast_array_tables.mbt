///|
pub struct TomlFastArrayTable {
  base_path : String
  keys : Array[String]
  rows : Array[Array[String]]
  line_start : Int
  line_end : Int
  table_count : Int
}

///|
fn prepare_fast_array_table_suffix(
  text : String,
) -> (String, TomlFastArrayTable)? {
  if text.length() < 1_048_576 {
    return None
  }
  let prefix = StringBuilder::new()
  let mut last_header = ""
  let mut run_start = 0
  let keys : Array[String] = []
  let rows : Array[Array[String]] = []
  let mut current : Array[String] = []
  let mut table_count = 0
  let mut line_end = 0
  let mut line_no = 0
  for line_view in text.split("\n") {
    line_no += 1
    let line = line_view.to_owned()
    if table_count == 0 {
      match fast_array_header(line) {
        Some(header) => {
          last_header = header
          run_start = line_no
          table_count = 1
          line_end = line_no
          continue
        }
        None => {
          if line_no > 1 {
            prefix.write_char('\n')
          }
          prefix.write_string(line)
          continue
        }
      }
    }
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    match fast_array_header(line) {
      Some(header) => {
        if header != last_header {
          return None
        }
        if current.length() != keys.length() {
          return None
        }
        rows.push(current)
        current = []
        table_count += 1
        line_end = line_no
      }
      None => {
        if trimmed.has_prefix("#") {
          return None
        }
        let (raw_key, raw_value) = match trimmed.split_once("=") {
          Some(value) => value
          None => return None
        }
        let key = raw_key.trim().to_owned()
        if key == "" || !key.to_array().all(toml_is_bare_key_char) {
          return None
        }
        let value = match
          fast_scalar_cell(raw_value.trim().to_owned(), line_no) {
          Some(value) => value
          None => return None
        }
        let key_index = current.length()
        if table_count == 1 {
          keys.push(key)
        } else if key_index >= keys.length() || keys[key_index] != key {
          return None
        }
        current.push(value)
        line_end = line_no
      }
    }
  }
  if table_count < 1024 || current.length() != keys.length() {
    return None
  }
  rows.push(current)
  if keys.length() == 0 {
    return None
  }
  let path_parts = last_header.split(".").to_array()
  if path_parts.length() == 0 ||
    path_parts.any(part => {
      part == "" || !part.to_array().all(toml_is_bare_key_char)
    }) {
    return None
  }
  Some(
    (
      prefix.to_string(),
      {
        base_path: "/" + path_parts.join("/"),
        keys,
        rows,
        line_start: run_start,
        line_end,
        table_count,
      },
    ),
  )
}

///|
fn fast_array_header(line : String) -> String? {
  let trimmed = line.trim().to_owned()
  if trimmed.length() < 5 ||
    !trimmed.has_prefix("[[") ||
    !trimmed.has_suffix("]]") {
    return None
  }
  let body = trimmed[2:trimmed.length() - 2].trim().to_owned()
  if body == "" {
    None
  } else {
    Some(body)
  }
}

///|
fn fast_scalar_cell(token : String, line : Int) -> String? {
  if token.length() >= 2 && token.has_prefix("\"") && token.has_suffix("\"") {
    let body = token[1:token.length() - 1].to_owned()
    if body.contains("\\") {
      None
    } else {
      Some(body)
    }
  } else if token.length() >= 2 &&
    token.has_prefix("'") &&
    token.has_suffix("'") {
    Some(token[1:token.length() - 1].to_owned())
  } else {
    let parsed = try toml_scalar_value_from_token(token, line) |> Some catch {
      _ => None
    }
    match parsed {
      Some(TomlValue::Integer(value)) => Some(value)
      Some(TomlValue::Float(value)) => Some(value)
      Some(TomlValue::Bool(value)) => Some(if value { "true" } else { "false" })
      Some(TomlValue::Datetime(value)) => Some(value)
      _ => None
    }
  }
}
