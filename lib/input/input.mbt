///|
/// Payload source categories accepted by the product path.
pub(all) enum InputKind {
  Path
  Text
  Bytes
  Reader
} derive(Eq)

///|
pub extend InputKind with Eq::{equal, not_equal}

///|
/// Caller-owned random-access reader.
///
/// `read_at` returns at most `length` bytes starting at `offset`. Returning an
/// empty payload marks end-of-input. Callers remain responsible for the
/// lifetime of resources captured by the callback. Every consumer uses the
/// same asynchronous protocol; synchronous callbacks are adapted at creation.
pub struct InputReader {
  size : Int64?
  read_at : async (Int64, Int32) -> Result[Bytes, String]
}

///|
/// Construct a caller-owned random-access reader contract.
pub fn make_input_reader(
  read_at : (Int64, Int32) -> Result[Bytes, String],
  size? : Int64,
) -> InputReader {
  { size, read_at: fn(offset, length) { read_at(offset, length) }, }
}

///|
/// Construct a caller-owned asynchronous random-access reader contract.
///
/// No synchronous projection or full-input bridge is created.
pub fn make_async_input_reader(
  read_at : async (Int64, Int32) -> Result[Bytes, String],
  size? : Int64,
) -> InputReader {
  { size, read_at, }
}

///|
/// Apply a conversion-level byte ceiling to caller-owned reader input.
pub fn input_source_with_reader_limit(
  source : InputSource,
  max_bytes : Int64,
) -> InputSource {
  {
    ..source,
    byte_limit: Some(source.byte_limit.unwrap_or(max_bytes).min(max_bytes)),
  }
}

///|
/// Return whether an input error violates the reader or resource contract.
pub fn input_error_is_fatal_reader_error(message : String) -> Bool {
  message.contains("input byte limit exceeded") ||
  message.contains("reader returned more bytes than requested") ||
  message.contains("reader returned bytes beyond declared size") ||
  message.contains("reader ended before declared size") ||
  message.contains("reader offset and length must be non-negative")
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
/// Direct image subtypes detected for asset/unsupported-capability handling.
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
pub extend ImageFormat with Eq::{equal, not_equal}

///|
/// Audio subtypes detected for unsupported-capability handling.
pub(all) enum AudioFormat {
  Wav
  Mp3
  M4a
} derive(Eq)

///|
pub extend AudioFormat with Eq::{equal, not_equal}

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
pub extend DetectedFormat with Eq::{equal, not_equal}

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
  priv session : InputSessionState?
  priv byte_limit : Int64?
  // Only trusted materialization/decoding helpers set this proof. Offsets in
  // the prepared payload still refer to that representation, not raw bytes.
  priv physical_bytes : Int64?
  // Trusted container factories assign the entry's independent access cap.
  // The shared session's max_bytes still describes the original root input.
  priv derived_entry_limit : Int64?
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
  detect : async (InputSource) -> FormatDetectionResult
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
    payload: Path(path),
    origin_path: Some(path),
    mime_type: None,
    explicit_format,
    session: None,
    byte_limit: None,
    physical_bytes: None,
    derived_entry_limit: None,
  }
}

///|
/// Construct an in-memory text input with the default `<memory>` source name.
pub fn input_from_text(
  text : String,
  source_name~ : String = "<memory>",
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
    payload: Text(text),
    origin_path: None,
    mime_type: None,
    explicit_format,
    session: None,
    byte_limit: None,
    physical_bytes: None,
    derived_entry_limit: None,
  }
}

///|
/// Construct an in-memory byte input with the default `<bytes>` source name.
pub fn input_from_bytes(
  bytes : Bytes,
  source_name~ : String = "<bytes>",
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
    payload: Bytes(bytes),
    origin_path: None,
    mime_type: None,
    explicit_format,
    session: None,
    byte_limit: None,
    physical_bytes: None,
    derived_entry_limit: None,
  }
}

///|
/// A container entry is a distinct byte representation with a declared local
/// access cap, while borrowing its parent's conversion account and failures.
pub fn input_from_container_entry_bytes(
  parent : InputSource,
  bytes : Bytes,
  source_name : String,
  entry_limit~ : Int64,
  explicit_format~ : DetectedFormat? = None,
) -> InputSource {
  let child = {
    ..input_from_bytes_with_format(bytes, source_name, explicit_format),
    session: parent.session,
    byte_limit: Some(entry_limit),
    derived_entry_limit: Some(entry_limit),
  }
  if parent.session is Some(state) && state.closed.val {
    record_input_failure(child, "input session is closed")
  }
  if entry_limit < 0L || bytes.length().to_int64() > entry_limit {
    record_input_failure(
      child,
      input_limit_message(bytes.length().to_int64(), entry_limit),
    )
  }
  child
}

///|
/// Only trusted container factories establish this independent local cap.
pub fn input_source_entry_limit(source : InputSource) -> Int64? {
  source.derived_entry_limit.map(fn(limit) {
    limit.min(source.byte_limit.unwrap_or(limit))
  })
}

///|
/// Construct a random-access reader input with the default `<reader>` name.
pub fn input_from_reader(
  reader : InputReader,
  source_name~ : String = "<reader>",
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
    payload: Reader(reader),
    origin_path: None,
    mime_type: None,
    explicit_format,
    session: None,
    byte_limit: None,
    physical_bytes: None,
    derived_entry_limit: None,
  }
}

///|
/// Return the source category while preserving path origin after materializing
/// a payload.
pub fn input_kind(source : InputSource) -> InputKind {
  match source.origin_path {
    Some(_) => Path
    None =>
      match source.payload {
        Path(_) => Path
        Text(_) => Text
        Bytes(_) => Bytes
        Reader(_) => Reader
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
        Path(path) => Some(path)
        _ => None
      }
  }
}

///|
/// Return an attached text payload without materializing another payload kind.
pub fn input_text(source : InputSource) -> String? {
  match source.payload {
    Text(text) => Some(text)
    _ => None
  }
}

///|
/// Return an attached byte payload without materializing another payload kind.
pub fn input_bytes(source : InputSource) -> Bytes? {
  match source.payload {
    Bytes(bytes) => Some(bytes)
    _ => None
  }
}

///|
/// Return the known payload size without reading an unknown-size source.
pub fn input_size(source : InputSource) -> Int64? {
  match source.payload {
    Path(_) => None
    Text(text) =>
      match validated_text_utf8_size(text) {
        Ok(size) => Some(source.physical_bytes.unwrap_or(size))
        Err(_) => None
      }
    Bytes(bytes) =>
      Some(source.physical_bytes.unwrap_or(bytes.length().to_int64()))
    Reader(reader) => reader.size
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
  { ..source, payload: Text(text), physical_bytes: None, }
}

///|
/// Return a copy of `source` with an in-memory byte payload attached.
pub fn with_bytes_payload(source : InputSource, bytes : Bytes) -> InputSource {
  { ..source, payload: Bytes(bytes), physical_bytes: None, }
}

///|
/// Internal trusted adapter after a complete successful read and decode.
/// Raw input extent and prepared UTF8 representation size are different units.
pub fn with_prepared_text_payload(
  source : InputSource,
  text : String,
  physical_bytes? : Int64,
) -> InputSource {
  let physical_bytes = match source.physical_bytes {
    Some(size) => Some(size)
    None =>
      match physical_bytes {
        Some(size) => Some(size)
        None =>
          match input_size(source) {
            Some(size) => Some(size)
            None =>
              match validated_text_utf8_size(text) {
                Ok(size) => Some(size)
                Err(_) => None
              }
          }
      }
  }
  { ..source, payload: Text(text), physical_bytes, }
}

///|
pub fn with_prepared_bytes_payload(
  source : InputSource,
  bytes : Bytes,
) -> InputSource {
  {
    ..source,
    payload: Bytes(bytes),
    physical_bytes: Some(
      source.physical_bytes.unwrap_or(bytes.length().to_int64()),
    ),
  }
}

///|
/// Restore the caller's session after a short-lived decoding session while
/// retaining the validated raw extent and the most restrictive byte ceiling.
pub fn rebind_prepared_source(
  source : InputSource,
  prepared : InputSource,
) -> InputSource {
  let byte_limit = match (source.byte_limit, prepared.byte_limit) {
    (Some(left), Some(right)) => Some(left.min(right))
    (Some(limit), _) | (_, Some(limit)) => Some(limit)
    _ => None
  }
  {
    ..source,
    payload: prepared.payload,
    physical_bytes: prepared.physical_bytes,
    byte_limit,
  }
}

///|
/// Return the default product format detector.
pub fn default_format_detector() -> FormatDetector {
  {
    detect: async fn(source : InputSource) -> FormatDetectionResult {
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
pub async fn detect_format(source : InputSource) -> FormatDetectionResult {
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
  if extension_format != Unknown {
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
      format: Jsonl,
      used_explicit_format: false,
      used_extension: true,
      text_like: true,
      binary_like: false,
      notes: ["extension"],
    }
  }
  if lower_name.has_suffix(".ndjson") {
    return {
      format: Ndjson,
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
      None => Some((Zip, ["magic_bytes", "zip_signature"]))
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
          format: Ipynb,
          used_explicit_format: false,
          used_extension: false,
          text_like: true,
          binary_like: false,
          notes,
        }
      None => ()
    }
  }
  let heuristic_format = if text_like { DetectedFormat::Txt } else { Unknown }
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
    Txt => "txt"
    Markdown => "markdown"
    Csv => "csv"
    Tsv => "tsv"
    Srt => "srt"
    Vtt => "vtt"
    Json => "json"
    Jsonl => "jsonl"
    Ndjson => "ndjson"
    Ipynb => "ipynb"
    Xml => "xml"
    Yaml => "yaml"
    Toml => "toml"
    Html => "html"
    Tex => "tex"
    Rst => "rst"
    Asciidoc => "asciidoc"
    Eml => "eml"
    Zip => "zip"
    Epub => "epub"
    Odt => "odt"
    Ods => "ods"
    Odp => "odp"
    Pdf => "pdf"
    Docx => "docx"
    Pptx => "pptx"
    Xlsx => "xlsx"
    Audio(kind) => audio_format_name(kind)
    Image(kind) => image_format_name(kind)
    Unknown => "unknown"
  }
}

///|
/// Parse a user-facing format label into the internal `DetectedFormat` enum.
pub fn parse_detected_format(name : String) -> DetectedFormat {
  match name.trim().to_lower() {
    "txt" => Txt
    "md" => Markdown
    "markdown" => Markdown
    "csv" => Csv
    "tsv" => Tsv
    "srt" => Srt
    "vtt" => Vtt
    "json" => Json
    "jsonl" => Jsonl
    "ndjson" => Ndjson
    "ipynb" => Ipynb
    "xml" => Xml
    "yaml" => Yaml
    "yml" => Yaml
    "toml" => Toml
    "html" => Html
    "htm" => Html
    "tex" => Tex
    "latex" => Tex
    "rst" => Rst
    "adoc" => Asciidoc
    "asciidoc" => Asciidoc
    "eml" => Eml
    "msg" => Eml
    "zip" => Zip
    "epub" => Epub
    "odt" => Odt
    "ods" => Ods
    "odp" => Odp
    "pdf" => Pdf
    "docx" => Docx
    "pptx" => Pptx
    "xlsx" => Xlsx
    "wav" => Audio(Wav)
    "mp3" => Audio(Mp3)
    "m4a" => Audio(M4a)
    "png" => Image(Png)
    "jpg" => Image(Jpg)
    "jpeg" => Image(Jpeg)
    "bmp" => Image(Bmp)
    "webp" => Image(Webp)
    "tif" => Image(Tif)
    "tiff" => Image(Tiff)
    _ => Unknown
  }
}

///|
/// Return the stable label for an audio subtype.
pub fn audio_format_name(format : AudioFormat) -> String {
  match format {
    Wav => "wav"
    Mp3 => "mp3"
    M4a => "m4a"
  }
}

///|
/// Return the stable label for an image subtype.
pub fn image_format_name(format : ImageFormat) -> String {
  match format {
    Png => "png"
    Jpg => "jpg"
    Jpeg => "jpeg"
    Bmp => "bmp"
    Webp => "webp"
    Tif => "tif"
    Tiff => "tiff"
  }
}

///|
/// Return whether the detected format is an image input.
pub fn detected_format_is_image_candidate(format : DetectedFormat) -> Bool {
  match format {
    Image(_) => true
    _ => false
  }
}

///|
/// Read text from any supported input source, decoding UTF-8 bytes when
/// needed.
///
/// The function prefers already attached in-memory payloads before falling
/// back to filesystem reads.
pub async fn read_input_text(
  source : InputSource,
) -> Result[String, String] noraise {
  if source.payload is Text(text) {
    match validate_memory_input(source) {
      Ok(_) => {
        let bytes = match validated_text_utf8_size(text) {
          Ok(bytes) => bytes
          Err(message) => return record_input_result(source, Err(message))
        }
        return charge_source_read_traffic(source, bytes).map(fn(_) { text })
      }
      Err(message) => return Err(message)
    }
  }
  read_input_bytes(source) |> Result::bind(decode_input_utf8)
}

///|
// Count original Text bytes without allocating an encoded copy. Native's UTF8
// encoder aborts on an invalid surrogate; validation must precede every encode.
pub fn validated_text_utf8_size(text : String) -> Result[Int64, String] {
  let mut index = 0
  let mut bytes = 0L
  while index < text.length() {
    let unit = text[index].to_int()
    if unit >= 0xD800 && unit <= 0xDBFF {
      if index + 1 >= text.length() {
        return Err("invalid UTF16 surrogate in Text input")
      }
      let next = text[index + 1].to_int()
      if next < 0xDC00 || next > 0xDFFF {
        return Err("invalid UTF16 surrogate in Text input")
      }
      bytes += 4L
      index += 2
    } else if unit >= 0xDC00 && unit <= 0xDFFF {
      return Err("invalid UTF16 surrogate in Text input")
    } else {
      bytes += if unit <= 0x7F { 1L } else if unit <= 0x7FF { 2L } else { 3L }
      index += 1
    }
  }
  Ok(bytes)
}

///|
fn validate_memory_input(
  source : InputSource,
  max_bytes? : Int64,
) -> Result[Unit, String] {
  if source.session is Some(state) && state.closed.val {
    return Err("input session is closed")
  }
  if input_source_error(source) is Some(message) {
    return Err(message)
  }
  let representation_size = match source.payload {
    Text(text) =>
      match validated_text_utf8_size(text) {
        Ok(value) => value
        Err(message) => return record_input_result(source, Err(message))
      }
    Bytes(bytes) => bytes.length().to_int64()
    _ => return Ok(())
  }
  let size = source.physical_bytes.unwrap_or(representation_size)
  if size < 0L {
    return record_input_result(
      source,
      Err("prepared input declared a negative physical size"),
    )
  }
  let limit = effective_input_byte_limit(source, max_bytes)
  if limit < 0L || size > limit {
    record_input_result(source, Err(input_limit_message(size, limit)))
  } else {
    Ok(())
  }
}

///|
// Defaults apply only when no request/session ceiling has been supplied.
// Root/prepared-root input inherits its physical source ceiling. A trusted
// derived entry uses its own explicit cap; every smaller request still wins.
fn effective_input_byte_limit(
  source : InputSource,
  requested : Int64?,
) -> Int64 {
  let inherited = match source.byte_limit {
    Some(limit) => limit
    None =>
      match source.session {
        Some(state) => state.max_bytes
        None => 512L * 1024L * 1024L
      }
  }
  let limit = requested.unwrap_or(inherited)
  let limit = match source.byte_limit {
    Some(bound) => limit.min(bound)
    None => limit
  }
  match source.derived_entry_limit {
    Some(entry_limit) => limit.min(entry_limit)
    None =>
      match source.session {
        Some(state) => limit.min(state.max_bytes)
        None => limit
      }
  }
}

///|
/// Read raw bytes from any supported input source, encoding in-memory text
/// when needed.
///
/// The function mirrors `read_input_text` so downstream code can consume a
/// uniform API regardless of where the input came from.
pub async fn read_input_bytes(
  source : InputSource,
) -> Result[Bytes, String] noraise {
  // Even an in-memory payload must pass through the same effective ceiling.
  let cursor = match open_source_cursor(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  defer close_cursor_if_unowned(source, cursor)
  match source.payload {
    Bytes(bytes) =>
      charge_source_read_traffic(source, bytes.length().to_int64()).map(fn(_) {
        bytes
      })
    Text(text) => {
      let bytes = match validated_text_utf8_size(text) {
        Ok(bytes) => bytes
        Err(message) => return record_input_result(source, Err(message))
      }
      charge_source_read_traffic(source, bytes).map(fn(_) { @utf8.encode(text) })
    }
    _ => read_cursor_bytes(cursor)
  }
}

///|
/// Read at most `limit` bytes for format detection.
pub async fn read_input_prefix(
  source : InputSource,
  limit : Int32,
) -> Result[Bytes, String] noraise {
  if limit <= 0 {
    return Ok(Bytes::new(0))
  }
  match open_source_cursor(source) {
    Ok(cursor) => {
      defer close_cursor_if_unowned(source, cursor)
      let out = @buffer.Buffer(size_hint=limit.min(64 * 1024))
      let mut offset = 0
      while offset < limit {
        let bytes = match
          source_cursor_read_at(
            cursor,
            offset.to_int64(),
            length=(limit - offset).min(64 * 1024),
          ) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        if bytes.is_empty() {
          break
        }
        out.write_bytes(bytes[:])
        offset += bytes.length()
      }
      Ok(out.to_bytes())
    }
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
async fn read_cursor_bytes(
  cursor : SourceCursor,
) -> Result[Bytes, String] noraise {
  let out = @buffer.Buffer(size_hint=64 * 1024)
  let mut offset = 0L
  while true {
    let chunk = match source_cursor_read_at(cursor, offset) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if chunk.is_empty() {
      break
    }
    out.write_bytes(chunk[:])
    offset += chunk.length().to_int64()
  }
  Ok(out.to_bytes())
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
  let mut last_dot : Int32? = None
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = Some(i)
    }
  }
  match last_dot {
    Some(index) => parse_detected_format(trimmed[index + 1:].to_owned())
    None => Unknown
  }
}

///|
fn detected_format_is_binary_like(format : DetectedFormat) -> Bool {
  match format {
    Pdf
    | Eml
    | Zip
    | Epub
    | Odt
    | Ods
    | Odp
    | Docx
    | Pptx
    | Xlsx
    | Audio(_)
    | Image(_) => true
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
    notes.push("image_input")
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
