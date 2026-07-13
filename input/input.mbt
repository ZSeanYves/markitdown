///|
/// Payload source categories accepted by the product path.
pub(all) enum InputKind {
  Path
  Text
  Bytes
  Reader
} derive(Eq)

///|
/// Caller-owned synchronous random-access reader.
///
/// `read_at` returns at most `length` bytes starting at `offset`. Returning an
/// empty payload marks end-of-input. Callers remain responsible for the
/// lifetime of resources captured by the callback.
pub struct InputReader {
  size : Int64?
  read_at : (Int64, Int) -> Result[Bytes, String]
}

///|
/// Construct a caller-owned random-access reader contract.
pub fn make_input_reader(
  read_at : (Int64, Int) -> Result[Bytes, String],
  size? : Int64,
) -> InputReader {
  { size, read_at }
}

///|
/// The single payload carried by an input source.
pub(all) enum InputPayload {
  Path(String)
  Text(String)
  Bytes(Bytes)
  Reader(InputReader)
}

///|
/// Direct image subtypes currently routed through the image OCR entry.
pub(all) enum ImageFormat {
  Png
  Jpg
  Jpeg
  Bmp
  Webp
  Tif
  Tiff
} derive(Eq)

///|
/// Audio subtypes currently routed through the audio transcription entry.
pub(all) enum AudioFormat {
  Wav
  Mp3
  M4a
} derive(Eq)

///|
/// Canonical detected format enum used across CLI, routing, diagnostics, and
/// provenance.
pub(all) enum DetectedFormat {
  Txt
  Markdown
  Csv
  Tsv
  Srt
  Vtt
  Json
  Jsonl
  Ndjson
  Ipynb
  Xml
  Yaml
  Toml
  Html
  Tex
  Rst
  Asciidoc
  Eml
  Zip
  Epub
  Odt
  Ods
  Odp
  Pdf
  Docx
  Pptx
  Xlsx
  Audio(AudioFormat)
  Image(ImageFormat)
  Unknown
} derive(Eq)

///|
/// Caller-supplied input handle for the product path.
///
/// `payload` is the only content-bearing field. `origin_path` is metadata kept
/// when a path source is materialized so provenance and relative asset lookup
/// remain stable.
pub struct InputSource {
  source_name : String
  payload : InputPayload
  origin_path : String?
  mime_type : String?
  explicit_format : DetectedFormat?
}

///|
/// Stable explanation of how format detection resolved for one input.
///
/// The `used_*` flags indicate which detection signals were authoritative, and
/// `notes` records the ordered hints that supported the final decision.
pub struct FormatDetectionResult {
  format : DetectedFormat
  used_explicit_format : Bool
  used_extension : Bool
  text_like : Bool
  binary_like : Bool
  notes : Array[String]
}

///|
/// Thin wrapper around the canonical format-detection function.
pub struct FormatDetector {
  detect : (InputSource) -> FormatDetectionResult
}

///|
/// Construct a path-backed input without forcing a detected format.
pub fn input_from_path(path : String) -> InputSource {
  input_from_path_with_format(path, None)
}

///|
/// Construct a path-backed input with an optional explicit format override.
pub fn input_from_path_with_format(
  path : String,
  explicit_format : DetectedFormat?,
) -> InputSource {
  {
    source_name: input_source_name_from_path(path),
    payload: InputPayload::Path(path),
    origin_path: Some(path),
    mime_type: None,
    explicit_format,
  }
}

///|
/// Construct an in-memory text input with the default `<memory>` source name.
pub fn input_from_text(
  text : String,
  source_name? : String = "<memory>",
) -> InputSource {
  input_from_text_with_format(text, source_name, None)
}

///|
/// Construct an in-memory text input with an optional explicit format hint.
pub fn input_from_text_with_format(
  text : String,
  source_name : String,
  explicit_format : DetectedFormat?,
) -> InputSource {
  {
    source_name,
    payload: InputPayload::Text(text),
    origin_path: None,
    mime_type: None,
    explicit_format,
  }
}

///|
/// Construct an in-memory byte input with the default `<bytes>` source name.
pub fn input_from_bytes(
  bytes : Bytes,
  source_name? : String = "<bytes>",
) -> InputSource {
  input_from_bytes_with_format(bytes, source_name, None)
}

///|
/// Construct an in-memory byte input with an optional explicit format hint.
pub fn input_from_bytes_with_format(
  bytes : Bytes,
  source_name : String,
  explicit_format : DetectedFormat?,
) -> InputSource {
  {
    source_name,
    payload: InputPayload::Bytes(bytes),
    origin_path: None,
    mime_type: None,
    explicit_format,
  }
}

///|
/// Construct a random-access reader input with the default `<reader>` name.
pub fn input_from_reader(
  reader : InputReader,
  source_name? : String = "<reader>",
) -> InputSource {
  input_from_reader_with_format(reader, source_name, None)
}

///|
/// Construct a random-access reader input with an explicit format hint.
pub fn input_from_reader_with_format(
  reader : InputReader,
  source_name : String,
  explicit_format : DetectedFormat?,
) -> InputSource {
  {
    source_name,
    payload: InputPayload::Reader(reader),
    origin_path: None,
    mime_type: None,
    explicit_format,
  }
}

///|
/// Return the source category while preserving path origin after materializing
/// a payload.
pub fn input_kind(source : InputSource) -> InputKind {
  match source.origin_path {
    Some(_) => InputKind::Path
    None =>
      match source.payload {
        InputPayload::Path(_) => InputKind::Path
        InputPayload::Text(_) => InputKind::Text
        InputPayload::Bytes(_) => InputKind::Bytes
        InputPayload::Reader(_) => InputKind::Reader
      }
  }
}

///|
/// Return the original source path when one is available.
pub fn input_path(source : InputSource) -> String? {
  match source.origin_path {
    Some(path) => Some(path)
    None =>
      match source.payload {
        InputPayload::Path(path) => Some(path)
        _ => None
      }
  }
}

///|
/// Return an attached text payload without materializing another payload kind.
pub fn input_text(source : InputSource) -> String? {
  match source.payload {
    InputPayload::Text(text) => Some(text)
    _ => None
  }
}

///|
/// Return an attached byte payload without materializing another payload kind.
pub fn input_bytes(source : InputSource) -> Bytes? {
  match source.payload {
    InputPayload::Bytes(bytes) => Some(bytes)
    _ => None
  }
}

///|
/// Return the known payload size without reading an unknown-size source.
pub fn input_size(source : InputSource) -> Int64? {
  match source.payload {
    InputPayload::Path(_) => None
    InputPayload::Text(text) => Some(@utf8.encode(text).length().to_int64())
    InputPayload::Bytes(bytes) => Some(bytes.length().to_int64())
    InputPayload::Reader(reader) => reader.size
  }
}

///|
/// Return a copy of `source` with a new explicit-format override.
pub fn with_explicit_format(
  source : InputSource,
  explicit_format : DetectedFormat?,
) -> InputSource {
  { ..source, explicit_format, }
}

///|
/// Return a copy of `source` with a new mime-type hint.
pub fn with_mime_type(source : InputSource, mime_type : String?) -> InputSource {
  { ..source, mime_type, }
}

///|
/// Return a copy of `source` with an in-memory text payload attached.
pub fn with_text_payload(source : InputSource, text : String) -> InputSource {
  { ..source, payload: InputPayload::Text(text) }
}

///|
/// Return a copy of `source` with an in-memory byte payload attached.
pub fn with_bytes_payload(source : InputSource, bytes : Bytes) -> InputSource {
  { ..source, payload: InputPayload::Bytes(bytes) }
}

///|
/// Return the default product format detector.
pub fn default_format_detector() -> FormatDetector {
  {
    detect: fn(source : InputSource) -> FormatDetectionResult {
      detect_format(source)
    },
  }
}

///|
/// Detect the product format using explicit override, mime type, extension,
/// magic bytes, and finally conservative text heuristics.
///
/// This function is intentionally format-identification only; it does not make
/// routing, fidelity, or parser-mode decisions.
pub fn detect_format(source : InputSource) -> FormatDetectionResult {
  match source.explicit_format {
    Some(format) =>
      return {
        format,
        used_explicit_format: true,
        used_extension: false,
        text_like: !detected_format_is_binary_like(format),
        binary_like: detected_format_is_binary_like(format),
        notes: detected_format_detection_notes(format, false),
      }
    None => ()
  }

  match detect_format_from_mime(source.mime_type) {
    Some((format, notes)) =>
      return {
        format,
        used_explicit_format: false,
        used_extension: false,
        text_like: !detected_format_is_binary_like(format),
        binary_like: detected_format_is_binary_like(format),
        notes,
      }
    None => ()
  }

  let extension_format = match input_path(source) {
    Some(path) => format_from_extension(path)
    None => format_from_extension(source.source_name)
  }
  if extension_format != DetectedFormat::Unknown {
    return {
      format: extension_format,
      used_explicit_format: false,
      used_extension: true,
      text_like: !detected_format_is_binary_like(extension_format),
      binary_like: detected_format_is_binary_like(extension_format),
      notes: detected_format_detection_notes(extension_format, true),
    }
  }

  let lower_name = source.source_name.trim().to_lower()
  if lower_name.has_suffix(".jsonl") {
    return {
      format: DetectedFormat::Jsonl,
      used_explicit_format: false,
      used_extension: true,
      text_like: true,
      binary_like: false,
      notes: ["extension"],
    }
  }
  if lower_name.has_suffix(".ndjson") {
    return {
      format: DetectedFormat::Ndjson,
      used_explicit_format: false,
      used_extension: true,
      text_like: true,
      binary_like: false,
      notes: ["extension"],
    }
  }

  let prefix = match read_input_prefix(source, 64 * 1024) {
    Ok(payload) => payload
    Err(_) => Bytes::from_array([])
  }
  let magic_result = if bytes_have_zip_signature(prefix) {
    match detect_container_format_from_source(source) {
      Some(value) => Some(value)
      None => Some((DetectedFormat::Zip, ["magic_bytes", "zip_signature"]))
    }
  } else {
    detect_format_from_magic_or_container(prefix)
  }
  match magic_result {
    Some((format, notes)) =>
      return {
        format,
        used_explicit_format: false,
        used_extension: false,
        text_like: !detected_format_is_binary_like(format),
        binary_like: detected_format_is_binary_like(format),
        notes,
      }
    None => ()
  }
  let text_like = bytes_look_text_like(prefix)
  let binary_like = !text_like && prefix.length() > 0
  if text_like {
    match detect_ipynb_from_text_bytes(prefix) {
      Some(notes) =>
        return {
          format: DetectedFormat::Ipynb,
          used_explicit_format: false,
          used_extension: false,
          text_like: true,
          binary_like: false,
          notes,
        }
      None => ()
    }
  }
  let heuristic_format = if text_like {
    DetectedFormat::Txt
  } else {
    DetectedFormat::Unknown
  }
  let notes : Array[String] = []
  if text_like {
    notes.push("text_heuristic")
  }
  if binary_like {
    notes.push("binary_heuristic")
  }
  {
    format: heuristic_format,
    used_explicit_format: false,
    used_extension: false,
    text_like,
    binary_like,
    notes,
  }
}

///|
/// Stable lower-case format label used in the CLI, registry, diagnostics, and
/// provenance output.
pub fn detected_format_name(format : DetectedFormat) -> String {
  match format {
    DetectedFormat::Txt => "txt"
    DetectedFormat::Markdown => "markdown"
    DetectedFormat::Csv => "csv"
    DetectedFormat::Tsv => "tsv"
    DetectedFormat::Srt => "srt"
    DetectedFormat::Vtt => "vtt"
    DetectedFormat::Json => "json"
    DetectedFormat::Jsonl => "jsonl"
    DetectedFormat::Ndjson => "ndjson"
    DetectedFormat::Ipynb => "ipynb"
    DetectedFormat::Xml => "xml"
    DetectedFormat::Yaml => "yaml"
    DetectedFormat::Toml => "toml"
    DetectedFormat::Html => "html"
    DetectedFormat::Tex => "tex"
    DetectedFormat::Rst => "rst"
    DetectedFormat::Asciidoc => "asciidoc"
    DetectedFormat::Eml => "eml"
    DetectedFormat::Zip => "zip"
    DetectedFormat::Epub => "epub"
    DetectedFormat::Odt => "odt"
    DetectedFormat::Ods => "ods"
    DetectedFormat::Odp => "odp"
    DetectedFormat::Pdf => "pdf"
    DetectedFormat::Docx => "docx"
    DetectedFormat::Pptx => "pptx"
    DetectedFormat::Xlsx => "xlsx"
    DetectedFormat::Audio(kind) => audio_format_name(kind)
    DetectedFormat::Image(kind) => image_format_name(kind)
    DetectedFormat::Unknown => "unknown"
  }
}

///|
/// Parse a user-facing format label into the internal `DetectedFormat` enum.
pub fn parse_detected_format(name : String) -> DetectedFormat {
  match name.trim().to_lower() {
    "txt" => DetectedFormat::Txt
    "md" => DetectedFormat::Markdown
    "markdown" => DetectedFormat::Markdown
    "csv" => DetectedFormat::Csv
    "tsv" => DetectedFormat::Tsv
    "srt" => DetectedFormat::Srt
    "vtt" => DetectedFormat::Vtt
    "json" => DetectedFormat::Json
    "jsonl" => DetectedFormat::Jsonl
    "ndjson" => DetectedFormat::Ndjson
    "ipynb" => DetectedFormat::Ipynb
    "xml" => DetectedFormat::Xml
    "yaml" => DetectedFormat::Yaml
    "yml" => DetectedFormat::Yaml
    "toml" => DetectedFormat::Toml
    "html" => DetectedFormat::Html
    "htm" => DetectedFormat::Html
    "tex" => DetectedFormat::Tex
    "latex" => DetectedFormat::Tex
    "rst" => DetectedFormat::Rst
    "adoc" => DetectedFormat::Asciidoc
    "asciidoc" => DetectedFormat::Asciidoc
    "eml" => DetectedFormat::Eml
    "msg" => DetectedFormat::Eml
    "zip" => DetectedFormat::Zip
    "epub" => DetectedFormat::Epub
    "odt" => DetectedFormat::Odt
    "ods" => DetectedFormat::Ods
    "odp" => DetectedFormat::Odp
    "pdf" => DetectedFormat::Pdf
    "docx" => DetectedFormat::Docx
    "pptx" => DetectedFormat::Pptx
    "xlsx" => DetectedFormat::Xlsx
    "wav" => DetectedFormat::Audio(AudioFormat::Wav)
    "mp3" => DetectedFormat::Audio(AudioFormat::Mp3)
    "m4a" => DetectedFormat::Audio(AudioFormat::M4a)
    "png" => DetectedFormat::Image(ImageFormat::Png)
    "jpg" => DetectedFormat::Image(ImageFormat::Jpg)
    "jpeg" => DetectedFormat::Image(ImageFormat::Jpeg)
    "bmp" => DetectedFormat::Image(ImageFormat::Bmp)
    "webp" => DetectedFormat::Image(ImageFormat::Webp)
    "tif" => DetectedFormat::Image(ImageFormat::Tif)
    "tiff" => DetectedFormat::Image(ImageFormat::Tiff)
    _ => DetectedFormat::Unknown
  }
}

///|
/// Return the stable label for an audio subtype.
pub fn audio_format_name(format : AudioFormat) -> String {
  match format {
    AudioFormat::Wav => "wav"
    AudioFormat::Mp3 => "mp3"
    AudioFormat::M4a => "m4a"
  }
}

///|
/// Return the stable label for an image subtype.
pub fn image_format_name(format : ImageFormat) -> String {
  match format {
    ImageFormat::Png => "png"
    ImageFormat::Jpg => "jpg"
    ImageFormat::Jpeg => "jpeg"
    ImageFormat::Bmp => "bmp"
    ImageFormat::Webp => "webp"
    ImageFormat::Tif => "tif"
    ImageFormat::Tiff => "tiff"
  }
}

///|
/// Return whether the detected format should enter the image OCR routing path.
pub fn detected_format_is_image_candidate(format : DetectedFormat) -> Bool {
  match format {
    DetectedFormat::Image(_) => true
    _ => false
  }
}

///|
/// Read text from any supported input source, decoding UTF-8 bytes when
/// needed.
///
/// The function prefers already attached in-memory payloads before falling
/// back to filesystem reads.
pub fn read_input_text(source : InputSource) -> Result[String, String] {
  match source.payload {
    InputPayload::Text(text) => Ok(text)
    InputPayload::Bytes(bytes) => decode_input_utf8(bytes)
    InputPayload::Path(path) =>
      try @fs.read_file_to_string(path, encoding="utf8") |> Ok catch {
        e => Err("read text failed: " + e.to_string())
      }
    InputPayload::Reader(reader) =>
      read_reader_bytes(reader) |> Result::bind(decode_input_utf8)
  }
}

///|
/// Read raw bytes from any supported input source, encoding in-memory text
/// when needed.
///
/// The function mirrors `read_input_text` so downstream code can consume a
/// uniform API regardless of where the input came from.
pub fn read_input_bytes(source : InputSource) -> Result[Bytes, String] {
  match source.payload {
    InputPayload::Bytes(bytes) => Ok(bytes)
    InputPayload::Text(text) => Ok(@utf8.encode(text))
    InputPayload::Path(path) =>
      try @fs.read_file_to_bytes(path) |> Ok catch {
        e => Err("read bytes failed: " + e.to_string())
      }
    InputPayload::Reader(reader) => read_reader_bytes(reader)
  }
}

///|
/// Read at most `limit` bytes for format detection.
pub fn read_input_prefix(
  source : InputSource,
  limit : Int,
) -> Result[Bytes, String] {
  if limit <= 0 {
    return Ok(Bytes::new(0))
  }
  match open_source_cursor(source) {
    Ok(cursor) => source_cursor_read_at(cursor, 0L, length=limit)
    Err(message) => Err(message)
  }
}

///|
fn decode_input_utf8(bytes : Bytes) -> Result[String, String] {
  try @utf8.decode(bytes, ignore_bom=false) |> Ok catch {
    _ => Err("utf8 decode failed")
  }
}

///|
fn read_reader_bytes(reader : InputReader) -> Result[Bytes, String] {
  let chunk_size = 64 * 1024
  let out : Array[Byte] = []
  let mut offset = 0L
  while true {
    match reader.size {
      Some(size) if offset >= size => break
      _ => ()
    }
    let chunk = match (reader.read_at)(offset, chunk_size) {
      Ok(chunk) => chunk
      Err(message) => return Err("reader read failed: " + message)
    }
    if chunk.length() > chunk_size {
      return Err("reader returned more bytes than requested")
    }
    if chunk.length() == 0 {
      match reader.size {
        Some(size) if offset < size =>
          return Err("reader ended before declared size")
        _ => break
      }
    }
    for byte in chunk {
      out.push(byte)
    }
    offset = offset + chunk.length().to_int64()
    match reader.size {
      Some(size) if offset > size =>
        return Err("reader returned bytes beyond declared size")
      _ => ()
    }
  }
  Ok(Bytes::from_array(out))
}

///|
fn input_source_name_from_path(path : String) -> String {
  let parts = path.split("/").to_array()
  parts.last().unwrap_or(path).to_owned()
}

///|
fn format_from_extension(path : String) -> DetectedFormat {
  let trimmed = path.trim().to_lower()
  let chars = trimmed.to_array()
  let mut last_dot : Int? = None
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = Some(i)
    }
  }
  match last_dot {
    Some(index) => parse_detected_format(trimmed[index + 1:].to_owned())
    None => DetectedFormat::Unknown
  }
}

///|
fn detected_format_is_binary_like(format : DetectedFormat) -> Bool {
  match format {
    DetectedFormat::Pdf
    | DetectedFormat::Eml
    | DetectedFormat::Zip
    | DetectedFormat::Epub
    | DetectedFormat::Odt
    | DetectedFormat::Ods
    | DetectedFormat::Odp
    | DetectedFormat::Docx
    | DetectedFormat::Pptx
    | DetectedFormat::Xlsx
    | DetectedFormat::Audio(_)
    | DetectedFormat::Image(_) => true
    _ => false
  }
}

///|
fn detected_format_detection_notes(
  format : DetectedFormat,
  from_extension : Bool,
) -> Array[String] {
  let notes : Array[String] = []
  if from_extension {
    notes.push("extension")
  } else {
    notes.push("explicit_format")
  }
  if detected_format_is_image_candidate(format) {
    notes.push("image_ocr_candidate")
  }
  notes
}

///|
fn bytes_look_text_like(bytes : Bytes) -> Bool {
  if bytes.length() == 0 {
    return true
  }
  let arr = bytes.to_array()
  let mut suspicious = 0
  for b in arr {
    let code = b.to_int()
    if code == 0 {
      return false
    }
    if code < 0x09 || (code > 0x0D && code < 0x20) {
      suspicious += 1
    }
  }
  suspicious * 8 < arr.length()
}

///|
fn bytes_have_zip_signature(bytes : Bytes) -> Bool {
  bytes.length() >= 4 &&
  byte_to_int(bytes[0]) == 0x50 &&
  byte_to_int(bytes[1]) == 0x4B &&
  byte_to_int(bytes[2]) == 0x03 &&
  byte_to_int(bytes[3]) == 0x04
}

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
