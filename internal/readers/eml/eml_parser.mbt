///|
const DEFAULT_CONTENT_TYPE : String = "text/plain; charset=utf-8"

///|
pub fn parse_eml_message(text : String) -> EmlMessage raise {
  let normalized = eml_normalize_newlines(text)
  let root = eml_parse_entity(normalized, 0, "/")
  let text_plain : Array[EmlPart] = []
  let text_html : Array[EmlPart] = []
  let attachments : Array[EmlAttachment] = []
  let inline_images : Array[EmlAttachment] = []
  let children = if root.children.length() > 0 { root.children } else { [root] }
  for part in children {
    eml_collect_message_views(
      part, text_plain, text_html, attachments, inline_images,
    )
  }
  {
    headers: root.headers,
    header_map: root.header_map,
    summary: root.summary,
    text_plain,
    text_html,
    attachments,
    inline_images,
    children,
    raw_source: normalized,
  }
}

///|
fn eml_parse_entity(
  raw : String,
  depth : Int,
  pointer : String,
) -> EmlPart raise {
  if depth > 8 {
    raise ParseError("maximum eml nesting depth exceeded")
  }
  let (header_text, body_text) = eml_split_headers_and_body(raw)
  let headers = eml_parse_headers(header_text)
  let header_map = eml_header_map(headers)
  let content_type = header_map.content_type.unwrap_or(DEFAULT_CONTENT_TYPE)
  let mime_type = eml_mime_type(content_type)
  let media_type = eml_media_type(mime_type)
  let charset = eml_content_type_param(content_type, "charset")
  let boundary = eml_content_type_param(content_type, "boundary")
  let disposition = eml_parse_disposition(
    eml_header_value(headers, "Content-Disposition"),
  )
  let transfer_encoding = eml_transfer_encoding(
    header_map.content_transfer_encoding,
  )
  let content_id = eml_clean_angle_token(
    eml_header_value(headers, "Content-ID"),
  )
  let location = eml_header_value(headers, "Content-Location")
  let name = eml_content_type_param(content_type, "name")
  let part = {
    index: 0,
    headers,
    header_map,
    summary: {
      content_type,
      mime_type,
      media_type,
      charset,
      boundary,
      name,
      disposition: eml_disposition_kind_opt(disposition),
      disposition_filename: eml_disposition_filename_opt(disposition),
      transfer_encoding,
      content_id,
      location,
      json_pointer: pointer,
    },
    body_text: None,
    attachments: [],
    child_message: None,
    children: [],
    raw_body: body_text,
  }
  eml_lower_entity_body(part, body_text, depth, pointer)
}

///|
pub fn decode_eml_source_text(bytes : Bytes) -> String {
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => {
      let chars : Array[Char] = []
      for byte in bytes.to_array() {
        chars.push(Int::unsafe_to_char(byte.to_int()))
      }
      String::from_array(chars)
    }
  }
}

///|
fn eml_lower_entity_body(
  part : EmlPart,
  body_text : String,
  depth : Int,
  pointer : String,
) -> EmlPart raise {
  if part.summary.media_type == "multipart" {
    let boundary = match part.summary.boundary {
      Some(value) if value.trim() != "" => value.trim().to_owned()
      _ => raise ParseError("multipart part missing boundary")
    }
    let children = eml_split_multipart_parts(body_text, boundary)
    if children.length() > 1_024 {
      raise ParseError("maximum eml multipart child count exceeded")
    }
    let lowered : Array[EmlPart] = []
    for i in 0..<children.length() {
      let child_pointer = pointer + "/parts/" + i.to_string()
      let child = eml_parse_entity(children[i], depth + 1, child_pointer) catch {
        err => {
          let message = err.to_string()
          if message.contains("maximum eml nesting depth") ||
            message.contains("maximum eml multipart child count") {
            raise ParseError(message)
          }
          eml_recovered_raw_part(children[i], child_pointer)
        }
      }
      lowered.push({ ..child, index: i })
    }
    { ..part, children: lowered }
  } else if part.summary.mime_type == "message/rfc822" {
    let decoded = eml_decode_body_text(
      body_text,
      part.summary.transfer_encoding,
      part.summary.charset,
    )
    let normalized_child = eml_normalize_newlines(decoded.0)
    let child = eml_parse_entity(
      normalized_child,
      depth + 1,
      pointer + "/message",
    )
    let child_message = {
      headers: child.headers,
      header_map: child.header_map,
      summary: child.summary,
      text_plain: [],
      text_html: [],
      attachments: [],
      inline_images: [],
      children: if child.children.length() > 0 {
        child.children
      } else {
        [child]
      },
      raw_source: normalized_child,
    }
    let text_plain : Array[EmlPart] = []
    let text_html : Array[EmlPart] = []
    let attachments : Array[EmlAttachment] = []
    let inline_images : Array[EmlAttachment] = []
    for nested in child_message.children {
      eml_collect_message_views(
        nested, text_plain, text_html, attachments, inline_images,
      )
    }
    {
      ..part,
      child_message: Some({
        ..child_message,
        text_plain,
        text_html,
        attachments,
        inline_images,
      }),
    }
  } else {
    let attachment = eml_maybe_attachment(part, body_text)
    match attachment {
      Some(value) => { ..part, attachments: [value] }
      None => {
        let decoded = eml_decode_body_text(
          body_text,
          part.summary.transfer_encoding,
          part.summary.charset,
        )
        let body = {
          text: decoded.0,
          decoded: decoded.1,
          charset: part.summary.charset,
        }
        { ..part, body_text: Some(body) }
      }
    }
  }
}

///|
fn eml_recovered_raw_part(raw : String, pointer : String) -> EmlPart {
  let summary : EmlPartSummary = {
    content_type: "application/x-markitdown-recovered-mime-part",
    mime_type: "application/x-markitdown-recovered-mime-part",
    media_type: "application",
    charset: None,
    boundary: None,
    name: None,
    disposition: None,
    disposition_filename: None,
    transfer_encoding: SevenBit,
    content_id: None,
    location: None,
    json_pointer: pointer,
  }
  {
    index: 0,
    headers: [],
    header_map: {
      subject: None,
      from: None,
      to: None,
      cc: None,
      date: None,
      message_id: None,
      in_reply_to: None,
      references: None,
      mime_version: None,
      content_type: Some(summary.content_type),
      content_transfer_encoding: None,
    },
    summary,
    body_text: Some({ text: raw, decoded: false, charset: None }),
    attachments: [],
    child_message: None,
    children: [],
    raw_body: raw,
  }
}

///|
fn eml_maybe_attachment(part : EmlPart, body_text : String) -> EmlAttachment? {
  let is_inline = part.summary.disposition == Some(Inline)
  let explicit_attachment = part.summary.disposition == Some(Attachment)
  let is_image = eml_mime_is_image(part.summary.mime_type)
  let has_name = part.summary.name is Some(_) ||
    part.summary.disposition_filename is Some(_)
  if !explicit_attachment &&
    !(is_inline && is_image) &&
    !(has_name && !eml_is_textual_mime(part.summary.mime_type)) {
    return None
  }
  Some({
    file_name: eml_attachment_name(part.summary),
    mime_type: part.summary.mime_type,
    disposition: part.summary.disposition,
    content_id: part.summary.content_id,
    location: part.summary.location,
    transfer_encoding: part.summary.transfer_encoding,
    payload_decoded: false,
    bytes: None,
    decoded_text: None,
    raw_text: body_text,
    summary: part.summary,
  })
}

///|
pub fn materialize_attachment_payload(
  attachment : EmlAttachment,
  want_text : Bool,
  want_bytes : Bool,
) -> EmlAttachment {
  if !want_text && !want_bytes {
    return attachment
  }
  if attachment.payload_decoded &&
    (!want_text || attachment.decoded_text is Some(_)) &&
    (!want_bytes || attachment.bytes is Some(_)) {
    return attachment
  }
  let decoded = eml_decode_body_text(
    attachment.raw_text,
    attachment.transfer_encoding,
    attachment.summary.charset,
  )
  {
    file_name: attachment.file_name,
    mime_type: attachment.mime_type,
    disposition: attachment.disposition,
    content_id: attachment.content_id,
    location: attachment.location,
    transfer_encoding: attachment.transfer_encoding,
    payload_decoded: decoded.1,
    bytes: if want_bytes {
      decoded.2
    } else {
      attachment.bytes
    },
    decoded_text: if want_text {
      Some(decoded.0)
    } else {
      attachment.decoded_text
    },
    raw_text: attachment.raw_text,
    summary: attachment.summary,
  }
}

///|
fn eml_collect_message_views(
  part : EmlPart,
  text_plain : Array[EmlPart],
  text_html : Array[EmlPart],
  attachments : Array[EmlAttachment],
  inline_images : Array[EmlAttachment],
) -> Unit {
  if part.summary.mime_type == "text/plain" && part.body_text is Some(_) {
    text_plain.push(part)
  }
  if part.summary.mime_type == "text/html" && part.body_text is Some(_) {
    text_html.push(part)
  }
  for attachment in part.attachments {
    attachments.push(attachment)
    if eml_attachment_is_inline_image_local(attachment) {
      inline_images.push(attachment)
    }
  }
  match part.child_message {
    Some(child) =>
      for nested in child.children {
        eml_collect_message_views(
          nested, text_plain, text_html, attachments, inline_images,
        )
      }
    None => ()
  }
  for child in part.children {
    eml_collect_message_views(
      child, text_plain, text_html, attachments, inline_images,
    )
  }
}

///|
fn eml_attachment_is_inline_image_local(attachment : EmlAttachment) -> Bool {
  attachment.disposition == Some(Inline) &&
  eml_mime_is_image(attachment.mime_type)
}

///|
fn eml_attachment_name(summary : EmlPartSummary) -> String? {
  match summary.disposition_filename {
    Some(value) => Some(value)
    None => summary.name
  }
}

///|
fn eml_disposition_kind_opt(
  value : (EmlDispositionKind, String?)?,
) -> EmlDispositionKind? {
  match value {
    Some(pair) => Some(pair.0)
    None => None
  }
}

///|
fn eml_disposition_filename_opt(
  value : (EmlDispositionKind, String?)?,
) -> String? {
  match value {
    Some(pair) => pair.1
    None => None
  }
}

///|
fn eml_split_headers_and_body(raw : String) -> (String, String) {
  match raw.split_once("\n\n") {
    Some((headers, body)) => (headers.to_owned(), body.to_owned())
    None => (raw, "")
  }
}

///|
fn eml_parse_headers(header_text : String) -> Array[EmlHeader] raise {
  let out : Array[EmlHeader] = []
  if header_text.trim() == "" {
    return out
  }
  let lines = header_text.split("\n").to_array().map(line => line.to_owned())
  let mut current_name = ""
  let current_value : Array[String] = []
  fn flush(
    out : Array[EmlHeader],
    current_name : String,
    current_value : Array[String],
  ) -> Unit {
    if current_name.trim() == "" {
      current_value.clear()
      return
    }
    let joined = current_value.join(" ").trim().to_owned()
    out.push({ name: current_name, value: joined })
    current_value.clear()
  }
  for line in lines {
    if line.has_prefix(" ") || line.has_prefix("\t") {
      if current_name.trim() == "" {
        raise ParseError("header continuation without a leading field name")
      }
      current_value.push(line.trim().to_owned())
      continue
    }
    if out.length() == 0 &&
      current_name.trim() == "" &&
      line.has_prefix("From ") {
      continue
    }
    flush(out, current_name, current_value)
    match line.split_once(":") {
      Some((name, value)) => {
        current_name = name.trim().to_owned()
        current_value.push(value.trim().to_owned())
      }
      None =>
        raise ParseError("malformed header line: " + line.trim().to_owned())
    }
  }
  flush(out, current_name, current_value)
  out
}

///|
fn eml_header_map(headers : Array[EmlHeader]) -> EmlHeaderMap {
  {
    subject: eml_decoded_header_value(headers, "Subject"),
    from: eml_decoded_header_value(headers, "From"),
    to: eml_decoded_header_value(headers, "To"),
    cc: eml_decoded_header_value(headers, "Cc"),
    date: eml_header_value(headers, "Date"),
    message_id: eml_header_value(headers, "Message-ID"),
    in_reply_to: eml_header_value(headers, "In-Reply-To"),
    references: eml_header_value(headers, "References"),
    mime_version: eml_header_value(headers, "MIME-Version"),
    content_type: eml_header_value(headers, "Content-Type"),
    content_transfer_encoding: eml_header_value(
      headers, "Content-Transfer-Encoding",
    ),
  }
}

///|
fn eml_decoded_header_value(
  headers : Array[EmlHeader],
  name : String,
) -> String? {
  eml_header_value(headers, name).map(eml_decode_encoded_words)
}

///|
fn eml_header_value(headers : Array[EmlHeader], name : String) -> String? {
  let target = name.trim().to_lower()
  for header in headers {
    if header.name.trim().to_lower() == target {
      return Some(header.value)
    }
  }
  None
}

///|
fn eml_transfer_encoding(raw : String?) -> EmlTransferEncoding {
  let lowered = match raw {
    Some(value) => value.trim().to_lower().to_owned()
    None => ""
  }
  match lowered {
    "7bit" => SevenBit
    "8bit" => EightBit
    "binary" => Binary
    "base64" => Base64
    "quoted-printable" => QuotedPrintable
    "" => SevenBit
    value => Other(value)
  }
}

///|
fn eml_parse_disposition(raw : String?) -> (EmlDispositionKind, String?)? {
  let value = match raw {
    Some(v) if v.trim() != "" => v.trim().to_owned()
    _ => return None
  }
  let kind_text = value.split(";").to_array()[0].trim().to_lower()
  let kind = match kind_text {
    "inline" => EmlDispositionKind::Inline
    "attachment" => Attachment
    _ => Other(kind_text.to_owned())
  }
  let filename = eml_header_param(value, "filename")
  Some((kind, filename))
}

///|
fn eml_mime_type(content_type : String) -> String {
  content_type.split(";").to_array()[0].trim().to_lower().to_owned()
}

///|
fn eml_media_type(mime_type : String) -> String {
  let parts = mime_type.split("/").to_array()
  if parts.length() == 0 {
    ""
  } else {
    parts[0].to_owned()
  }
}

///|
fn eml_content_type_param(content_type : String, key : String) -> String? {
  eml_header_param(content_type, key)
}

///|
fn eml_header_param(value : String, key : String) -> String? {
  let target = key.trim().to_lower().to_owned()
  let parts = value.split(";").to_array()
  let continuation : Array[String] = []
  for i in 1..<parts.length() {
    match parts[i].split_once("=") {
      Some((name, raw_value)) => {
        let normalized_name = name.trim().to_lower().to_owned()
        if normalized_name == target {
          return Some(eml_strip_quotes(raw_value.trim().to_owned()))
        }
        if normalized_name == target + "*" {
          return Some(eml_decode_rfc2231_value(raw_value.trim().to_owned()))
        }
        for segment in 0..<32 {
          let plain = target + "*" + segment.to_string()
          let encoded = plain + "*"
          if normalized_name == plain || normalized_name == encoded {
            while continuation.length() <= segment {
              continuation.push("")
            }
            continuation[segment] = eml_strip_quotes(
              raw_value.trim().to_owned(),
            )
          }
        }
      }
      None => ()
    }
  }
  if continuation.length() > 0 && continuation.all(part => part != "") {
    return Some(eml_decode_rfc2231_value(continuation.join("")))
  }
  None
}

///|
fn eml_strip_quotes(value : String) -> String {
  let trimmed = value.trim()
  if trimmed.length() >= 2 &&
    trimmed.has_prefix("\"") &&
    trimmed.has_suffix("\"") {
    trimmed[1:trimmed.length() - 1].to_owned()
  } else {
    trimmed.to_owned()
  }
}

///|
fn eml_clean_angle_token(value : String?) -> String? {
  match value {
    Some(raw) => {
      let trimmed = raw.trim().to_owned()
      if trimmed.length() >= 2 &&
        trimmed.has_prefix("<") &&
        trimmed.has_suffix(">") {
        Some(trimmed[1:trimmed.length() - 1].to_owned())
      } else if trimmed != "" {
        Some(trimmed)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn eml_normalize_newlines(text : String) -> String {
  text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
}

///|
fn eml_split_multipart_parts(body : String, boundary : String) -> Array[String] {
  let lines = body.split("\n").to_array().map(line => line.to_owned())
  let marker = "--" + boundary
  let end_marker = marker + "--"
  let current : Array[String] = []
  let parts : Array[String] = []
  let mut active = false
  for line in lines {
    if line == marker || line.trim() == marker {
      if active && current.length() > 0 {
        parts.push(current.join("\n").trim().to_owned())
        current.clear()
      }
      active = true
      continue
    }
    if line == end_marker || line.trim() == end_marker {
      if active && current.length() > 0 {
        parts.push(current.join("\n").trim().to_owned())
      }
      current.clear()
      break
    }
    if active {
      current.push(line)
    }
  }
  if active && current.length() > 0 {
    parts.push(current.join("\n").trim().to_owned())
  }
  parts.filter(part => part.trim() != "")
}

///|
fn eml_decode_body_text(
  raw : String,
  encoding : EmlTransferEncoding,
  charset : String?,
) -> (String, Bool, Bytes?) {
  match encoding {
    Base64 => {
      let compact = raw
        .replace_all(old="\n", new="")
        .replace_all(old=" ", new="")
      let decoded = try @base64.decode(compact, url_safe=false) |> Some catch {
        _ => None
      }
      match decoded {
        Some(bytes) => {
          let decoded_text = eml_decode_text_bytes_with_charset(bytes, charset)
          (decoded_text.0, decoded_text.1, Some(bytes))
        }
        None => (raw, false, None)
      }
    }
    QuotedPrintable => {
      let bytes = eml_decode_quoted_printable(raw)
      let decoded_text = eml_decode_text_bytes_with_charset(bytes, charset)
      (decoded_text.0, decoded_text.1, Some(bytes))
    }
    _ => {
      let bytes = @utf8.encode(raw)
      (raw, true, Some(bytes))
    }
  }
}

///|
fn eml_decode_text_bytes_with_charset(
  bytes : Bytes,
  charset : String?,
) -> (String, Bool) {
  let normalized = charset
    .map(value => {
      value.trim().to_lower().replace_all(old="_", new="-").to_owned()
    })
    .unwrap_or("utf-8")
  match normalized {
    "utf-8" | "utf8" =>
      match
        (try @utf8.decode(bytes, ignore_bom=false) |> Some catch {
          _ => None
        }) {
        Some(text) => (text, true)
        None => (eml_decode_text_bytes(bytes), false)
      }
    "us-ascii" | "ascii" =>
      match
        (try @ascii.decode(bytes) |> Some catch {
          _ => None
        }) {
        Some(text) => (text, true)
        None => (eml_decode_single_byte_text(bytes, false), false)
      }
    "iso-8859-1" | "iso8859-1" | "latin1" | "latin-1" =>
      (eml_decode_single_byte_text(bytes, false), true)
    "windows-1252" | "cp1252" =>
      (eml_decode_single_byte_text(bytes, true), true)
    "utf-16" | "utf-16le" => (eml_decode_utf16_text(bytes, false), true)
    "utf-16be" => (eml_decode_utf16_text(bytes, true), true)
    _ => (eml_decode_text_bytes(bytes), false)
  }
}

///|
fn eml_decode_single_byte_text(bytes : Bytes, windows_1252 : Bool) -> String {
  let chars : Array[Char] = []
  for byte in bytes.to_array() {
    let value = byte.to_int()
    let codepoint = if windows_1252 && value >= 0x80 && value <= 0x9F {
      eml_windows_1252_codepoint(value)
    } else {
      value
    }
    chars.push(Int::unsafe_to_char(codepoint))
  }
  String::from_array(chars)
}

///|
fn eml_windows_1252_codepoint(value : Int) -> Int {
  let table = [
    0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030,
    0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F, 0x0090, 0x2018, 0x2019, 0x201C,
    0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D,
    0x017E, 0x0178,
  ]
  table[value - 0x80]
}

///|
fn eml_decode_utf16_text(bytes : Bytes, big_endian : Bool) -> String {
  let values = bytes.to_array()
  let chars : Array[Char] = []
  let mut i = 0
  let mut use_big_endian = big_endian
  if values.length() >= 2 {
    if values[0].to_int() == 0xFE && values[1].to_int() == 0xFF {
      use_big_endian = true
      i = 2
    } else if values[0].to_int() == 0xFF && values[1].to_int() == 0xFE {
      use_big_endian = false
      i = 2
    }
  }
  while i + 1 < values.length() {
    let first = values[i].to_int()
    let second = values[i + 1].to_int()
    let unit = if use_big_endian {
      first * 256 + second
    } else {
      second * 256 + first
    }
    i += 2
    if unit >= 0xD800 && unit <= 0xDBFF && i + 1 < values.length() {
      let next_first = values[i].to_int()
      let next_second = values[i + 1].to_int()
      let low = if use_big_endian {
        next_first * 256 + next_second
      } else {
        next_second * 256 + next_first
      }
      if low >= 0xDC00 && low <= 0xDFFF {
        chars.push(
          Int::unsafe_to_char(0x10000 + (unit - 0xD800) * 1024 + low - 0xDC00),
        )
        i += 2
        continue
      }
    }
    if unit >= 0xD800 && unit <= 0xDFFF {
      chars.push('\u{FFFD}')
    } else {
      chars.push(Int::unsafe_to_char(unit))
    }
  }
  if i < values.length() {
    chars.push('\u{FFFD}')
  }
  String::from_array(chars)
}

///|
fn eml_decode_text_bytes(bytes : Bytes) -> String {
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ =>
      @ascii.decode(bytes) catch {
        _ => {
          let chars : Array[Char] = []
          for byte in bytes.to_array() {
            chars.push(Int::unsafe_to_char(byte.to_int()))
          }
          String::from_array(chars)
        }
      }
  }
}

///|
fn eml_decode_encoded_words(value : String) -> String {
  let pieces : Array[String] = []
  let mut rest = value
  while true {
    match rest.find("=?") {
      Some(start) => {
        pieces.push(rest[:start].to_owned())
        let candidate = rest[start + 2:]
        let charset_end = match candidate.find("?") {
          Some(index) => index
          None => {
            pieces.push(rest[start:].to_owned())
            break
          }
        }
        let charset = candidate[:charset_end].to_owned()
        let after_charset = candidate[charset_end + 1:]
        let encoding_end = match after_charset.find("?") {
          Some(index) => index
          None => {
            pieces.push(rest[start:].to_owned())
            break
          }
        }
        let encoding = after_charset[:encoding_end].trim().to_lower().to_owned()
        let payload_and_tail = after_charset[encoding_end + 1:]
        let payload_end = match payload_and_tail.find("?=") {
          Some(index) => index
          None => {
            pieces.push(rest[start:].to_owned())
            break
          }
        }
        let payload = payload_and_tail[:payload_end].to_owned()
        let bytes = if encoding == "b" {
          try @base64.decode(payload, url_safe=false) |> Some catch {
            _ => None
          }
        } else if encoding == "q" {
          Some(
            eml_decode_quoted_printable(payload.replace_all(old="_", new=" ")),
          )
        } else {
          None
        }
        match bytes {
          Some(decoded) =>
            pieces.push(
              eml_decode_text_bytes_with_charset(decoded, Some(charset)).0,
            )
          None =>
            pieces.push(
              rest[start:start +
              2 +
              charset_end +
              1 +
              encoding_end +
              1 +
              payload_end +
              2].to_owned(),
            )
        }
        rest = payload_and_tail[payload_end + 2:].to_owned()
      }
      None => {
        pieces.push(rest)
        break
      }
    }
  }
  pieces.join("").trim().to_owned()
}

///|
fn eml_decode_rfc2231_value(value : String) -> String {
  let stripped = eml_strip_quotes(value)
  let (charset, encoded) = match stripped.split_once("''") {
    Some((left, right)) => (Some(left.to_owned()), right.to_owned())
    None => (None, stripped)
  }
  let bytes = eml_percent_decode(encoded)
  eml_decode_text_bytes_with_charset(bytes, charset).0
}

///|
fn eml_percent_decode(value : String) -> Bytes {
  let chars = value.to_array()
  let bytes : Array[Byte] = []
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '%' && i + 2 < chars.length() {
      match (eml_hex_value(chars[i + 1]), eml_hex_value(chars[i + 2])) {
        (Some(high), Some(low)) => {
          bytes.push((high * 16 + low).to_byte())
          i += 3
          continue
        }
        _ => ()
      }
    }
    for byte in @utf8.encode(chars[i].to_string()).to_array() {
      bytes.push(byte)
    }
    i += 1
  }
  Bytes::from_array(bytes)
}

///|
fn eml_decode_quoted_printable(raw : String) -> Bytes {
  let chars = raw.to_array()
  let out : Array[Byte] = []
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '=' {
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 2
        continue
      }
      if i + 2 < chars.length() && chars[i + 1] == '\r' && chars[i + 2] == '\n' {
        i += 3
        continue
      }
      if i + 2 < chars.length() {
        let hi = eml_hex_value(chars[i + 1])
        let lo = eml_hex_value(chars[i + 2])
        match (hi, lo) {
          (Some(h), Some(l)) => {
            out.push((h * 16 + l).to_byte())
            i += 3
            continue
          }
          _ => ()
        }
      }
    }
    if ch == '\n' {
      out.push((10).to_byte())
    } else {
      out.push(ch.to_int().to_byte())
    }
    i += 1
  }
  Bytes::from_array(out)
}

///|
fn eml_hex_value(ch : Char) -> Int? {
  let code = ch.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    Some(code - '0'.to_int())
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    Some(code - 'A'.to_int() + 10)
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    Some(code - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn eml_is_textual_mime(mime_type : String) -> Bool {
  mime_type.has_prefix("text/") ||
  mime_type == "application/json" ||
  mime_type.contains("+json") ||
  mime_type == "application/xml" ||
  mime_type.contains("+xml") ||
  mime_type == "application/x-ipynb+json"
}

///|
fn eml_mime_is_image(mime_type : String) -> Bool {
  mime_type == "image/png" ||
  mime_type == "image/jpeg" ||
  mime_type == "image/gif" ||
  mime_type == "image/svg+xml"
}
