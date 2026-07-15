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
