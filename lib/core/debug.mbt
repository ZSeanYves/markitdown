///|
pub fn json_string(s : String) -> String {
  "\"" + escape_json_string(s) + "\""
}

///|
pub fn json_string_opt(s : String?) -> String {
  match s {
    Some(v) => json_string(v)
    None => "null"
  }
}

///|
pub fn string_array_json(values : Array[String]) -> String {
  let items : Array[String] = []
  for value in values {
    items.push(json_string(value))
  }
  array_json(items)
}

///|
pub fn string_array_json_opt(values : Array[String]) -> String {
  string_array_json(values)
}

///|
pub fn object_json(fields : Array[String]) -> String {
  "{" + fields.join(", ") + "}"
}

///|
pub fn array_json(items : Array[String]) -> String {
  "[" + items.join(", ") + "]"
}

///|
fn escape_json_string(s : String) -> String {
  let out : Array[Char] = []
  for ch in s {
    match ch {
      '"' => {
        out.push('\\')
        out.push('"')
      }
      '\\' => {
        out.push('\\')
        out.push('\\')
      }
      '\n' => {
        out.push('\\')
        out.push('n')
      }
      '\r' => {
        out.push('\\')
        out.push('r')
      }
      '\t' => {
        out.push('\\')
        out.push('t')
      }
      _ => out.push(ch)
    }
  }
  String::from_array(out)
}
