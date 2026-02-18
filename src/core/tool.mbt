///|
pub fn trim_string(s : String) -> String {
  let normalized = s.replace(old="\u3000", new=" ")
  normalized.trim().to_string()
}

///|
pub fn escape_pipes(s : String) -> String {
  s.replace(old="|", new="\\|")
}

///|
pub fn normalize_cell(s : String) -> String {
  trim_string(escape_pipes(s))
}

///|
pub fn is_blank(s : String) -> Bool {
  trim_string(s) == ""
}
