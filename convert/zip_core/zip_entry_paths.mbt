///|
pub fn normalize_zip_entry_path(raw_path : String) -> String? {
  let p = raw_path.replace(old="\\", new="/")
  if p.trim() == "" || p.has_prefix("/") {
    return None
  }
  if p.length() >= 2 && p[1] == ':' {
    return None
  }
  let parts = p.split("/")
  let clean : Array[String] = []
  for part in parts {
    let segment = part.trim().to_owned()
    if segment == "" || segment == "." || segment == ".." {
      return None
    }
    clean.push(segment)
  }
  if clean.length() == 0 {
    None
  } else {
    Some(clean.join("/"))
  }
}

///|
fn display_path(raw_path : String) -> String {
  let p = raw_path.replace(old="\\", new="/")
  if p.trim() == "" {
    "(empty path)"
  } else {
    p
  }
}

///|
pub fn is_hidden_or_macos_metadata(path : String) -> Bool {
  if path == "__MACOSX" || path.has_prefix("__MACOSX/") {
    return true
  }
  let base = @cor.basename(path)
  base == ".DS_Store" || base.has_prefix("._")
}

///|
pub fn is_supported_entry_ext(ext : String) -> Bool {
  match ext {
    "docx"
    | "pdf"
    | "xlsx"
    | "pptx"
    | "md"
    | "markdown"
    | "csv"
    | "tsv"
    | "txt"
    | "xml"
    | "json"
    | "yaml"
    | "yml"
    | "html"
    | "htm" => true
    _ => false
  }
}

///|
pub fn is_html_entry_ext(ext : String) -> Bool {
  match ext {
    "html" | "htm" => true
    _ => false
  }
}

///|
pub fn is_nested_archive_ext(ext : String) -> Bool {
  match ext {
    "zip" | "jar" | "epub" => true
    _ => false
  }
}

///|
fn unique_entry_id(path : String, used : Map[String, Int]) -> String {
  let base = safe_entry_id(path)
  let count = used.get(base).unwrap_or(0) + 1
  used.set(base, count)
  if count == 1 {
    base
  } else {
    base + "_" + count.to_string()
  }
}

///|
fn safe_entry_id(path : String) -> String {
  let out : Array[Char] = []
  for ch in path.to_array() {
    if is_safe_id_char(ch) {
      out.push(ch)
    } else {
      out.push('_')
    }
  }
  let value = String::from_array(out).trim().to_owned()
  if value == "" {
    "entry"
  } else {
    value
  }
}

///|
fn is_safe_id_char(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '.' ||
  ch == '_' ||
  ch == '-'
}

///|
fn compare_zip_path(a : String, b : String) -> Int {
  a[:].lexical_compare(b[:])
}
