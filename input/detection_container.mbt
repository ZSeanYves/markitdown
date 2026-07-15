///|
fn detect_container_format_from_source(
  source : InputSource,
) -> (DetectedFormat, Array[String])? {
  let cursor = match open_source_cursor(source) {
    Ok(value) => value
    Err(_) => return None
  }
  let size = match cursor.size {
    Some(value) => value
    None => return None
  }
  let tail_length = if size > 65557L { 65557 } else { size.to_int() }
  let tail_offset = size - tail_length.to_int64()
  let tail = match
    source_cursor_read_at(cursor, tail_offset, length=tail_length) {
    Ok(value) => value
    Err(_) => return None
  }
  let eocd = find_zip_eocd(tail)
  let eocd = match eocd {
    Some(value) => value
    None => return None
  }
  let directory_size = zip_u32(tail, eocd + 12)
  let directory_offset = zip_u32(tail, eocd + 16)
  if directory_size < 0 ||
    directory_size > 16 * 1024 * 1024 ||
    directory_offset < 0 ||
    directory_offset.to_int64() + directory_size.to_int64() > size {
    return None
  }
  let directory = match
    source_cursor_read_at(
      cursor,
      directory_offset.to_int64(),
      length=directory_size,
    ) {
    Ok(value) => value
    Err(_) => return None
  }
  let mut has_docx = false
  let mut has_pptx = false
  let mut has_xlsx = false
  let mut has_epub_container = false
  let mut mimetype_offset : Int? = None
  let mut position = 0
  while position + 46 <= directory.length() {
    if zip_u32(directory, position) != 0x02014B50 {
      break
    }
    let name_length = zip_u16(directory, position + 28)
    let extra_length = zip_u16(directory, position + 30)
    let comment_length = zip_u16(directory, position + 32)
    let entry_end = position + 46 + name_length + extra_length + comment_length
    if name_length < 0 || entry_end > directory.length() {
      break
    }
    let name_bytes = directory
      .view(start=position + 46, end=position + 46 + name_length)
      .to_owned()
    let name = @utf8.decode(name_bytes, ignore_bom=true) catch { _ => "" }
    match name {
      "word/document.xml" => has_docx = true
      "ppt/presentation.xml" => has_pptx = true
      "xl/workbook.xml" => has_xlsx = true
      "META-INF/container.xml" => has_epub_container = true
      "mimetype" => mimetype_offset = Some(zip_u32(directory, position + 42))
      _ => ()
    }
    position = entry_end
  }
  if has_docx {
    return Some(
      (
        DetectedFormat::Docx,
        ["magic_bytes", "zip_signature", "container_inspection", "ooxml_docx"],
      ),
    )
  }
  if has_pptx {
    return Some(
      (
        DetectedFormat::Pptx,
        ["magic_bytes", "zip_signature", "container_inspection", "ooxml_pptx"],
      ),
    )
  }
  if has_xlsx {
    return Some(
      (
        DetectedFormat::Xlsx,
        ["magic_bytes", "zip_signature", "container_inspection", "ooxml_xlsx"],
      ),
    )
  }
  let mimetype = match mimetype_offset {
    Some(offset) => read_zip_stored_mimetype(cursor, offset)
    None => None
  }
  match mimetype {
    Some("application/epub+zip") if has_epub_container =>
      Some(
        (
          DetectedFormat::Epub,
          [
            "magic_bytes", "zip_signature", "container_inspection", "epub_container",
          ],
        ),
      )
    Some("application/vnd.oasis.opendocument.text") =>
      Some(
        (
          DetectedFormat::Odt,
          ["magic_bytes", "zip_signature", "container_inspection", "odf_odt"],
        ),
      )
    Some("application/vnd.oasis.opendocument.spreadsheet") =>
      Some(
        (
          DetectedFormat::Ods,
          ["magic_bytes", "zip_signature", "container_inspection", "odf_ods"],
        ),
      )
    Some("application/vnd.oasis.opendocument.presentation") =>
      Some(
        (
          DetectedFormat::Odp,
          ["magic_bytes", "zip_signature", "container_inspection", "odf_odp"],
        ),
      )
    _ => None
  }
}

///|
fn find_zip_eocd(tail : Bytes) -> Int? {
  let mut index = tail.length() - 22
  while index >= 0 {
    if zip_u32(tail, index) == 0x06054B50 {
      return Some(index)
    }
    index -= 1
  }
  None
}

///|
fn read_zip_stored_mimetype(cursor : SourceCursor, offset : Int) -> String? {
  if offset < 0 {
    return None
  }
  let header = match
    source_cursor_read_at(cursor, offset.to_int64(), length=30) {
    Ok(value) => value
    Err(_) => return None
  }
  if header.length() < 30 || zip_u32(header, 0) != 0x04034B50 {
    return None
  }
  let compression = zip_u16(header, 8)
  let payload_size = zip_u32(header, 18)
  let name_length = zip_u16(header, 26)
  let extra_length = zip_u16(header, 28)
  if compression != 0 || payload_size < 0 || payload_size > 256 {
    return None
  }
  let data_offset = offset + 30 + name_length + extra_length
  let payload = match
    source_cursor_read_at(cursor, data_offset.to_int64(), length=payload_size) {
    Ok(value) => value
    Err(_) => return None
  }
  try @utf8.decode(payload, ignore_bom=true).trim().to_owned() |> Some catch {
    _ => None
  }
}

///|
fn zip_u16(bytes : Bytes, offset : Int) -> Int {
  if offset < 0 || offset + 2 > bytes.length() {
    return -1
  }
  byte_to_int(bytes[offset]) | (byte_to_int(bytes[offset + 1]) << 8)
}

///|
fn zip_u32(bytes : Bytes, offset : Int) -> Int {
  if offset < 0 || offset + 4 > bytes.length() {
    return -1
  }
  byte_to_int(bytes[offset]) |
  (byte_to_int(bytes[offset + 1]) << 8) |
  (byte_to_int(bytes[offset + 2]) << 16) |
  (byte_to_int(bytes[offset + 3]) << 24)
}

///|
fn detect_format_from_mime(
  mime_type : String?,
) -> (DetectedFormat, Array[String])? {
  let lowered = match mime_type {
    Some(value) => value.trim().to_lower()
    None => return None
  }
  if lowered == "" {
    return None
  }
  let notes = ["mime_type"]
  match lowered {
    "text/plain" => Some((DetectedFormat::Txt, notes))
    "text/markdown" | "text/x-markdown" =>
      Some((DetectedFormat::Markdown, notes))
    "text/csv" => Some((DetectedFormat::Csv, notes))
    "text/tab-separated-values" => Some((DetectedFormat::Tsv, notes))
    "application/x-subrip" | "text/srt" => Some((DetectedFormat::Srt, notes))
    "text/vtt" => Some((DetectedFormat::Vtt, notes))
    "application/json" | "text/json" => Some((DetectedFormat::Json, notes))
    "application/x-ipynb+json"
    | "application/x-jupyter-notebook+json"
    | "application/vnd.jupyter"
    | "application/vnd.jupyter.cells" => Some((DetectedFormat::Ipynb, notes))
    "application/xml" | "text/xml" => Some((DetectedFormat::Xml, notes))
    "application/yaml" | "application/x-yaml" | "text/yaml" | "text/x-yaml" =>
      Some((DetectedFormat::Yaml, notes))
    "application/toml" | "text/toml" | "text/x-toml" =>
      Some((DetectedFormat::Toml, notes))
    "text/html" | "application/html" => Some((DetectedFormat::Html, notes))
    "application/x-tex" | "text/x-tex" => Some((DetectedFormat::Tex, notes))
    "text/x-rst" | "text/prs.fallenstein.rst" =>
      Some((DetectedFormat::Rst, notes))
    "text/asciidoc" | "text/x-asciidoc" =>
      Some((DetectedFormat::Asciidoc, notes))
    "message/rfc822" | "text/rfc822-headers" =>
      Some((DetectedFormat::Eml, notes))
    "application/zip" => Some((DetectedFormat::Zip, notes))
    "application/epub+zip" => Some((DetectedFormat::Epub, notes))
    "application/vnd.oasis.opendocument.text" =>
      Some((DetectedFormat::Odt, notes))
    "application/vnd.oasis.opendocument.spreadsheet" =>
      Some((DetectedFormat::Ods, notes))
    "application/vnd.oasis.opendocument.presentation" =>
      Some((DetectedFormat::Odp, notes))
    "application/pdf" => Some((DetectedFormat::Pdf, notes))
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" =>
      Some((DetectedFormat::Docx, notes))
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" =>
      Some((DetectedFormat::Pptx, notes))
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" =>
      Some((DetectedFormat::Xlsx, notes))
    "audio/wav" | "audio/wave" | "audio/x-wav" =>
      Some((DetectedFormat::Audio(AudioFormat::Wav), notes))
    "audio/mpeg" | "audio/mp3" =>
      Some((DetectedFormat::Audio(AudioFormat::Mp3), notes))
    "audio/mp4" | "audio/m4a" | "audio/x-m4a" =>
      Some((DetectedFormat::Audio(AudioFormat::M4a), notes))
    "image/png" =>
      Some((DetectedFormat::Image(ImageFormat::Png), notes_with_image(notes)))
    "image/jpeg" =>
      Some((DetectedFormat::Image(ImageFormat::Jpeg), notes_with_image(notes)))
    "image/bmp" =>
      Some((DetectedFormat::Image(ImageFormat::Bmp), notes_with_image(notes)))
    "image/webp" =>
      Some((DetectedFormat::Image(ImageFormat::Webp), notes_with_image(notes)))
    "image/tiff" =>
      Some((DetectedFormat::Image(ImageFormat::Tiff), notes_with_image(notes)))
    _ => None
  }
}

///|
fn detect_format_from_magic_or_container(
  bytes : Bytes,
) -> (DetectedFormat, Array[String])? {
  let arr = bytes.to_array()
  if arr.length() >= 4 &&
    byte_to_int(arr[0]) == 0x50 &&
    byte_to_int(arr[1]) == 0x4B &&
    byte_to_int(arr[2]) == 0x03 &&
    byte_to_int(arr[3]) == 0x04 {
    return detect_container_format_from_zip(bytes)
  }
  if arr.length() >= 4 &&
    byte_to_int(arr[0]) == 0x25 &&
    byte_to_int(arr[1]) == 0x50 &&
    byte_to_int(arr[2]) == 0x44 &&
    byte_to_int(arr[3]) == 0x46 {
    return Some((DetectedFormat::Pdf, ["magic_bytes", "pdf_signature"]))
  }
  if arr.length() >= 12 &&
    byte_to_int(arr[0]) == 0x52 &&
    byte_to_int(arr[1]) == 0x49 &&
    byte_to_int(arr[2]) == 0x46 &&
    byte_to_int(arr[3]) == 0x46 &&
    bytes_prefix_ascii(arr, 8, 4) == "WAVE" {
    return Some(
      (
        DetectedFormat::Audio(AudioFormat::Wav),
        ["magic_bytes", "riff_signature", "wave_signature"],
      ),
    )
  }
  if arr.length() >= 3 &&
    byte_to_int(arr[0]) == 0x49 &&
    byte_to_int(arr[1]) == 0x44 &&
    byte_to_int(arr[2]) == 0x33 {
    return Some(
      (
        DetectedFormat::Audio(AudioFormat::Mp3),
        ["magic_bytes", "id3_signature"],
      ),
    )
  }
  if arr.length() >= 2 &&
    byte_to_int(arr[0]) == 0xFF &&
    (byte_to_int(arr[1]) & 0xE0) == 0xE0 {
    return Some(
      (
        DetectedFormat::Audio(AudioFormat::Mp3),
        ["magic_bytes", "mpeg_frame_sync"],
      ),
    )
  }
  if arr.length() >= 4 &&
    byte_to_int(arr[0]) == 0x89 &&
    byte_to_int(arr[1]) == 0x50 &&
    byte_to_int(arr[2]) == 0x4E &&
    byte_to_int(arr[3]) == 0x47 {
    return Some(
      (
        DetectedFormat::Image(ImageFormat::Png),
        ["magic_bytes", "png_signature", "image_ocr_candidate"],
      ),
    )
  }
  if arr.length() >= 3 &&
    byte_to_int(arr[0]) == 0xFF &&
    byte_to_int(arr[1]) == 0xD8 &&
    byte_to_int(arr[2]) == 0xFF {
    return Some(
      (
        DetectedFormat::Image(ImageFormat::Jpeg),
        ["magic_bytes", "jpeg_signature", "image_ocr_candidate"],
      ),
    )
  }
  if arr.length() >= 4 &&
    byte_to_int(arr[0]) == 0x42 &&
    byte_to_int(arr[1]) == 0x4D {
    return Some(
      (
        DetectedFormat::Image(ImageFormat::Bmp),
        ["magic_bytes", "bmp_signature", "image_ocr_candidate"],
      ),
    )
  }
  if arr.length() >= 4 &&
    byte_to_int(arr[0]) == 0x52 &&
    byte_to_int(arr[1]) == 0x49 &&
    byte_to_int(arr[2]) == 0x46 &&
    byte_to_int(arr[3]) == 0x46 &&
    arr.length() >= 12 &&
    bytes_prefix_ascii(arr, 8, 4) == "WEBP" {
    return Some(
      (
        DetectedFormat::Image(ImageFormat::Webp),
        ["magic_bytes", "webp_signature", "image_ocr_candidate"],
      ),
    )
  }
  if arr.length() >= 4 &&
    (
      (
        byte_to_int(arr[0]) == 0x49 &&
        byte_to_int(arr[1]) == 0x49 &&
        byte_to_int(arr[2]) == 0x2A &&
        byte_to_int(arr[3]) == 0x00
      ) ||
      (
        byte_to_int(arr[0]) == 0x4D &&
        byte_to_int(arr[1]) == 0x4D &&
        byte_to_int(arr[2]) == 0x00 &&
        byte_to_int(arr[3]) == 0x2A
      )
    ) {
    return Some(
      (
        DetectedFormat::Image(ImageFormat::Tiff),
        ["magic_bytes", "tiff_signature", "image_ocr_candidate"],
      ),
    )
  }
  match detect_format_from_text_magic(bytes) {
    Some(result) => return Some(result)
    None => ()
  }
  None
}

///|
fn detect_format_from_text_magic(
  bytes : Bytes,
) -> (DetectedFormat, Array[String])? {
  let text = decode_utf8_trimmed(bytes)
  let text = match text {
    Some(value) => value
    None => return None
  }
  if text == "" {
    return None
  }
  if text.has_prefix("WEBVTT") {
    return Some((DetectedFormat::Vtt, ["magic_text", "webvtt_signature"]))
  }
  if detect_eml_text_signature(text) {
    return Some((DetectedFormat::Eml, ["magic_text", "rfc822_headers"]))
  }
  if detect_rst_text_signature(text) {
    return Some((DetectedFormat::Rst, ["magic_text", "rst_signature"]))
  }
  if detect_asciidoc_text_signature(text) {
    return Some(
      (DetectedFormat::Asciidoc, ["magic_text", "asciidoc_signature"]),
    )
  }
  if detect_tex_text_signature(text) {
    return Some((DetectedFormat::Tex, ["magic_text", "tex_signature"]))
  }
  if detect_srt_text_signature(text) {
    return Some((DetectedFormat::Srt, ["magic_text", "subrip_signature"]))
  }
  None
}

///|
fn detect_container_format_from_zip(
  bytes : Bytes,
) -> (DetectedFormat, Array[String])? {
  let archive = try @zip.open_zip(bytes) |> Ok catch {
    _ => Err(())
  }
  let archive = match archive {
    Ok(value) => value
    Err(_) =>
      return Some((DetectedFormat::Zip, ["magic_bytes", "zip_signature"]))
  }
  if @zip.has_entry(archive, "[Content_Types].xml") {
    if @zip.has_entry(archive, "word/document.xml") {
      return Some(
        (
          DetectedFormat::Docx,
          ["magic_bytes", "zip_signature", "container_inspection", "ooxml_docx"],
        ),
      )
    }
    if @zip.has_entry(archive, "ppt/presentation.xml") {
      return Some(
        (
          DetectedFormat::Pptx,
          ["magic_bytes", "zip_signature", "container_inspection", "ooxml_pptx"],
        ),
      )
    }
    if @zip.has_entry(archive, "xl/workbook.xml") {
      return Some(
        (
          DetectedFormat::Xlsx,
          ["magic_bytes", "zip_signature", "container_inspection", "ooxml_xlsx"],
        ),
      )
    }
  }
  if @zip.has_entry(archive, "META-INF/container.xml") {
    let mimetype = try @zip.read_entry(archive, "mimetype") |> Ok catch {
      _ => Err(())
    }
    match mimetype {
      Ok(payload) =>
        match decode_utf8_trimmed(payload) {
          Some(value) if value == "application/epub+zip" =>
            return Some(
              (
                DetectedFormat::Epub,
                [
                  "magic_bytes", "zip_signature", "container_inspection", "epub_container",
                ],
              ),
            )
          _ => ()
        }
      Err(_) => ()
    }
  }
  if @zip.has_entry(archive, "META-INF/manifest.xml") &&
    @zip.has_entry(archive, "content.xml") {
    let mimetype = try @zip.read_entry(archive, "mimetype") |> Ok catch {
      _ => Err(())
    }
    match mimetype {
      Ok(payload) =>
        match decode_utf8_trimmed(payload) {
          Some("application/vnd.oasis.opendocument.text") =>
            return Some(
              (
                DetectedFormat::Odt,
                [
                  "magic_bytes", "zip_signature", "container_inspection", "odf_odt",
                ],
              ),
            )
          Some("application/vnd.oasis.opendocument.spreadsheet") =>
            return Some(
              (
                DetectedFormat::Ods,
                [
                  "magic_bytes", "zip_signature", "container_inspection", "odf_ods",
                ],
              ),
            )
          Some("application/vnd.oasis.opendocument.presentation") =>
            return Some(
              (
                DetectedFormat::Odp,
                [
                  "magic_bytes", "zip_signature", "container_inspection", "odf_odp",
                ],
              ),
            )
          _ => ()
        }
      Err(_) => ()
    }
  }
  Some((DetectedFormat::Zip, ["magic_bytes", "zip_signature"]))
}

///|
fn notes_with_image(notes : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for note in notes {
    out.push(note)
  }
  out.push("image_ocr_candidate")
  out
}

///|
fn decode_utf8_trimmed(bytes : Bytes) -> String? {
  try @utf8.decode(bytes, ignore_bom=false).trim().to_owned() |> Some catch {
    _ => None
  }
}

///|
fn bytes_prefix_ascii(arr : Array[Byte], start : Int, length : Int) -> String {
  let chars : Array[Char] = []
  let end_index = start + length
  if arr.length() < end_index {
    return ""
  }
  for i in start..<end_index {
    chars.push(Int::unsafe_to_char(byte_to_int(arr[i])))
  }
  String::from_array(chars)
}

///|
fn byte_to_int(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 0 {
    v
  } else {
    v + 256
  }
}

///|
fn detect_ipynb_from_text_bytes(bytes : Bytes) -> Array[String]? {
  let text = try @utf8.decode(bytes, ignore_bom=false) |> Ok catch {
    _ => Err(())
  }
  let text = match text {
    Ok(value) => value
    Err(_) => return None
  }
  if !text.contains("\"nbformat\"") || !text.contains("\"cells\"") {
    return None
  }
  let lowered = text.to_lower()
  if lowered.contains("\"cells\"") &&
    lowered.contains("\"cell_type\"") &&
    lowered.contains("\"nbformat\"") {
    return Some(["content_notebook_json"])
  }
  None
}

///|
fn detect_eml_text_signature(text : String) -> Bool {
  let lowered = text.to_lower()
  (lowered.contains("\nfrom:") || lowered.has_prefix("from:")) &&
  (
    lowered.contains("\nsubject:") ||
    lowered.has_prefix("subject:") ||
    lowered.contains("\nmime-version:") ||
    lowered.contains("\ncontent-type:")
  ) &&
  lowered.contains("\n\n")
}

///|
fn detect_rst_text_signature(text : String) -> Bool {
  let lines = text.split("\n").to_array()
  if lines.length() < 2 {
    return false
  }
  let next = lines[1].trim().to_owned()
  if next.length() < 3 {
    return false
  }
  let chars = next.to_array()
  let marker = chars[0]
  if marker != '=' &&
    marker != '-' &&
    marker != '~' &&
    marker != '^' &&
    marker != '"' {
    return false
  }
  for ch in chars {
    if ch != marker {
      return false
    }
  }
  true
}

///|
fn detect_asciidoc_text_signature(text : String) -> Bool {
  let trimmed = text.trim_start()
  trimmed.has_prefix("= ") ||
  trimmed.has_prefix("[source") ||
  trimmed.has_prefix(":toc:") ||
  trimmed.contains("\n== ")
}

///|
fn detect_tex_text_signature(text : String) -> Bool {
  let trimmed = text.trim_start()
  trimmed.has_prefix("\\documentclass") ||
  trimmed.has_prefix("\\begin{document}") ||
  trimmed.contains("\\section{") ||
  trimmed.contains("\\subsection{")
}

///|
fn detect_srt_text_signature(text : String) -> Bool {
  let lines = text.split("\n").to_array()
  if lines.length() < 2 {
    return false
  }
  let first = lines[0].trim().to_owned()
  let second = lines[1].trim().to_owned()
  (first == "" || ascii_digits_only(first)) &&
  second.contains(" --> ") &&
  second.contains(":")
}

///|
fn ascii_digits_only(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  for ch in trimmed {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}
