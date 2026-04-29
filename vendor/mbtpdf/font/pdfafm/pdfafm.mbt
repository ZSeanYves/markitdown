///|
/// Parse Adobe Font Metrics (AFM) files.

///|
pub struct PdfAfm {
  unit : Unit
}

///|
pub fn PdfAfm::new() -> PdfAfm {
  { unit: () }
}

///|
fn split_whitespace(line : String) -> Array[String] {
  let out = Array::new()
  let mut current = StringBuilder::new()
  for ch in line {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if !current.is_empty() {
        out.push(current.to_string())
        current = StringBuilder::new()
      }
    } else {
      current.write_char(ch)
    }
  }
  if !current.is_empty() {
    out.push(current.to_string())
  }
  out
}

///|
fn parse_int(token : String) -> Int raise {
  @strconv.parse_int(token, base=10)
}

///|
fn read_char_metrics_line(line : String) -> (String, (Int, Int)) raise {
  let parts = split_whitespace(line)
  let mut name = ""
  let mut charnum : Int? = None
  let mut width : Int? = None
  fn is_field_label(parts : Array[String], idx : Int) -> Bool {
    idx == 0 || parts[idx - 1] == ";"
  }

  let mut i = 0
  while i < parts.length() {
    if is_field_label(parts, i) {
      match parts[i] {
        "C" =>
          if i + 1 < parts.length() {
            charnum = Some(parse_int(parts[i + 1]))
          }
        "WX" =>
          if i + 1 < parts.length() {
            width = Some(parse_int(parts[i + 1]))
          }
        "N" => if i + 1 < parts.length() { name = parts[i + 1] }
        _ => ()
      }
    }
    i = i + 1
  }
  match (charnum, width) {
    (Some(c), Some(w)) => (name, (c, w))
    _ => fail("badline in read_char_metrics_line")
  }
}

///|
fn read_kern_line(line : String) -> (String, String, Int) raise {
  let parts = split_whitespace(line)
  if parts.length() >= 4 && parts[0] == "KPX" {
    let kern = parse_int(parts[3])
    (parts[1], parts[2], kern)
  } else {
    fail("badline in read_kern_line")
  }
}

///|
fn extract_section(
  lines : Array[String],
  start_prefix : String,
  end_prefix : String,
) -> Array[String] {
  let out = Array::new()
  let mut collecting = false
  for line in lines {
    if line.has_prefix(start_prefix) {
      collecting = true
      continue
    }
    if line.has_prefix(end_prefix) {
      collecting = false
      continue
    }
    if collecting {
      out.push(line)
    }
  }
  out
}

///|
fn split_header(line : String) -> (String, String) raise {
  match line.find(" ") {
    None => (line, "")
    Some(pos) =>
      (line[0:pos].to_string(), line[pos + 1:].to_string().trim().to_string())
  }
}

///|
fn lookup_charnum(table : Map[String, (Int, Int)], name : String) -> Int {
  match table.get(name) {
    Some(pair) => pair.0
    None => -1
  }
}

///|
fn get_tables(
  lines : Array[String],
) -> (
  Array[(String, String)],
  Array[(Int, Int)],
  Array[(Int, Int, Int)],
  Array[(String, Int)],
) raise {
  let char_metrics_lines = extract_section(
    lines, "StartCharMetrics", "EndCharMetrics",
  )
  let kern_lines = extract_section(lines, "StartKernPairs", "EndKernPairs")
  let header_lines = Array::new(capacity=lines.length())
  for line in lines {
    if line.has_prefix("C ") {
      break
    }
    if line.length() > 0 {
      header_lines.push(line)
    }
  }
  let headers = Array::new(capacity=header_lines.length())
  for line in header_lines {
    headers.push(split_header(line))
  }
  let charmetrics = char_metrics_lines.filter_map(line => if line
    .trim()
    .length() <
    5 {
    None
  } else {
    Some(read_char_metrics_line(line))
  })
  let charmetrics_hash : Map[String, (Int, Int)] = Map::new(
    capacity=charmetrics.length(),
  )
  for entry in charmetrics {
    charmetrics_hash.set(entry.0, entry.1)
  }
  let kerns = kern_lines.filter_map(line => if line.trim().length() < 5 {
    None
  } else {
    Some(read_kern_line(line))
  })
  let ws = Array::new(capacity=charmetrics.length())
  for entry in charmetrics {
    let (c, w) = entry.1
    if c > -1 {
      ws.push((c, w))
    }
  }
  let ks = Array::new(capacity=kerns.length())
  for entry in kerns {
    let (n, n2, kern) = entry
    let p = lookup_charnum(charmetrics_hash, n)
    let p2 = lookup_charnum(charmetrics_hash, n2)
    if p > -1 && p2 > -1 {
      ks.push((p, p2, kern))
    }
  }
  let ws_prime = charmetrics.map(entry => (entry.0, entry.1.1))
  (headers, ws, ks, ws_prime)
}

///|
pub fn PdfAfm::read(
  _self : PdfAfm,
  input : @pdfio.Input,
) -> (
  Array[(String, String)],
  Array[(Int, Int)],
  Array[(Int, Int, Int)],
  Array[(String, Int)],
) raise {
  let lines = input.read_lines()
  get_tables(lines)
}
