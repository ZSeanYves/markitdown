///|
pub fn parse_xml(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("xml: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("xml: read failed: " + e.to_string())
  }

  let raw = decode_xml_source_text(bytes)

  let text = normalize_xml_text(raw)
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  if text.trim() != "" {
    @cor.set_passthrough_markdown(doc, xml_fenced_markdown(text))
    @cor.push_with_origin(
      doc,
      @cor.Block::CodeBlock(text),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: Some(1),
        line_end: Some(physical_line_count(text)),
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      }),
    )
  }

  doc
}

///|
fn decode_xml_source_text(bytes : Bytes) -> String raise {
  match sniff_xml_utf16_endianness(bytes) {
    Some(endianness) =>
      return @utf16.decode(bytes, ignore_bom=false, endianness~) catch {
        _ => raise @cor.AppError("xml: utf16 decode failed")
      }
    None => ()
  }

  match sniff_xml_declared_encoding(bytes) {
    Some(raw_label) => {
      let label = raw_label.trim().to_owned().to_lower()
      if label == "utf-8" || label == "utf8" || label == "us-ascii" {
        return @utf8.decode(bytes, ignore_bom=false) catch {
          _ => raise @cor.AppError("xml: utf8 decode failed")
        }
      }
      if label == "utf-16" || label == "utf-16le" || label == "utf16le" {
        return @utf16.decode(
          bytes,
          ignore_bom=false,
          endianness=@utf16.Endian::Little,
        ) catch {
          _ => raise @cor.AppError("xml: utf16 decode failed")
        }
      }
      if label == "utf-16be" || label == "utf16be" {
        return @utf16.decode(
          bytes,
          ignore_bom=false,
          endianness=@utf16.Endian::Big,
        ) catch {
          _ => raise @cor.AppError("xml: utf16 decode failed")
        }
      }
      if label == "iso-8859-1" ||
        label == "iso8859-1" ||
        label == "latin1" ||
        label == "latin-1" ||
        label == "latin_1" {
        return decode_xml_latin1(bytes)
      }
      raise @cor.AppError("xml: unsupported encoding: " + raw_label)
    }
    None => ()
  }

  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise @cor.AppError("xml: utf8 decode failed")
  }
}

///|
fn sniff_xml_utf16_endianness(bytes : Bytes) -> @utf16.Endian? {
  if bytes.length() >= 2 {
    let b0 = bytes[0].to_int()
    let b1 = bytes[1].to_int()
    if b0 == 0xFF && b1 == 0xFE {
      return Some(@utf16.Endian::Little)
    }
    if b0 == 0xFE && b1 == 0xFF {
      return Some(@utf16.Endian::Big)
    }
  }

  if bytes.length() >= 4 {
    let b0 = bytes[0].to_int()
    let b1 = bytes[1].to_int()
    let b2 = bytes[2].to_int()
    let b3 = bytes[3].to_int()
    if b0 == 0x3C && b1 == 0x00 && b2 == 0x3F && b3 == 0x00 {
      return Some(@utf16.Endian::Little)
    }
    if b0 == 0x00 && b1 == 0x3C && b2 == 0x00 && b3 == 0x3F {
      return Some(@utf16.Endian::Big)
    }
  }

  None
}

///|
fn sniff_xml_declared_encoding(bytes : Bytes) -> String? {
  let probe = xml_ascii_probe(bytes, 256)
  let lower = probe.to_lower()
  if !lower.has_prefix("<?xml") {
    return None
  }

  let decl_end = lower.find("?>").unwrap_or(lower.length())
  let decl = lower[:decl_end]
  let encoding_index = decl.find("encoding")
  guard encoding_index is Some(start0) else { return None }

  let chars = probe.to_array()
  let mut i = start0 + "encoding".length()
  while i < decl_end && is_xml_ascii_space(chars[i]) {
    i = i + 1
  }
  if i >= decl_end || chars[i] != '=' {
    return None
  }
  i = i + 1
  while i < decl_end && is_xml_ascii_space(chars[i]) {
    i = i + 1
  }
  if i >= decl_end {
    return None
  }

  let quote = chars[i]
  if quote != '"' && quote != '\'' {
    return None
  }
  let start = i + 1
  i = start
  while i < decl_end && chars[i] != quote {
    i = i + 1
  }
  if i <= start || i >= decl_end {
    return None
  }

  Some(probe[start:i].to_owned())
}

///|
fn xml_ascii_probe(bytes : Bytes, limit : Int) -> String {
  let out : Array[Char] = []
  let end = if bytes.length() < limit { bytes.length() } else { limit }
  for i in 0..<end {
    let b = bytes[i].to_int()
    if (b >= 0x20 && b <= 0x7E) || b == 0x09 || b == 0x0A || b == 0x0D {
      out.push(bytes[i].to_char())
    } else {
      out.push(' ')
    }
  }
  String::from_array(out)
}

///|
fn is_xml_ascii_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn decode_xml_latin1(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  for b in bytes {
    out.write_char(b.to_char())
  }
  out.to_string()
}

///|
fn normalize_xml_text(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0

  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    i = 1
  }

  while i < chars.length() {
    let ch = chars[i]
    if ch == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i = i + 2
      } else {
        i = i + 1
      }
    } else {
      out.push(ch)
      i = i + 1
    }
  }

  String::from_array(out)
}

///|
fn xml_fenced_markdown(text : String) -> String {
  let fence = "`".repeat(required_fence_width(text))
  if text.has_suffix("\n") {
    fence + "xml\n" + text + fence + "\n"
  } else {
    fence + "xml\n" + text + "\n" + fence + "\n"
  }
}

///|
fn required_fence_width(text : String) -> Int {
  let chars = text.to_array()
  let mut longest = 0
  let mut current = 0

  for ch in chars {
    if ch == '`' {
      current = current + 1
      if current > longest {
        longest = current
      }
    } else {
      current = 0
    }
  }

  if longest + 1 < 3 {
    3
  } else {
    longest + 1
  }
}

///|
fn physical_line_count(text : String) -> Int {
  if text == "" {
    return 0
  }

  let mut count = 1
  let chars = text.to_array()
  for i in 0..<chars.length() {
    if chars[i] == '\n' && i + 1 < chars.length() {
      count = count + 1
    }
  }
  count
}
