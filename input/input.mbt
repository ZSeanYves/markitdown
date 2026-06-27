///|
pub(all) enum InputKind {
  Path
  Text
  Bytes
} derive(Eq)

///|
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
pub(all) enum DetectedFormat {
  Txt
  Markdown
  Csv
  Tsv
  Json
  Jsonl
  Ndjson
  Xml
  Yaml
  Html
  Zip
  Epub
  Pdf
  Docx
  Pptx
  Xlsx
  Image(ImageFormat)
  Unknown
} derive(Eq)

///|
pub struct InputSource {
  kind : InputKind
  source_name : String
  path : String?
  text : String?
  bytes : Bytes?
  explicit_format : DetectedFormat?
}

///|
pub struct FormatDetectionResult {
  format : DetectedFormat
  used_explicit_format : Bool
  used_extension : Bool
  text_like : Bool
  binary_like : Bool
  notes : Array[String]
}

///|
pub struct FormatDetector {
  detect : (InputSource) -> FormatDetectionResult
}

///|
pub fn input_from_path(path : String) -> InputSource {
  input_from_path_with_format(path, None)
}

///|
pub fn input_from_path_with_format(
  path : String,
  explicit_format : DetectedFormat?,
) -> InputSource {
  {
    kind: InputKind::Path,
    source_name: input_source_name_from_path(path),
    path: Some(path),
    text: None,
    bytes: None,
    explicit_format,
  }
}

///|
pub fn input_from_text(
  text : String,
  source_name? : String = "<memory>",
) -> InputSource {
  input_from_text_with_format(text, source_name, None)
}

///|
pub fn input_from_text_with_format(
  text : String,
  source_name : String,
  explicit_format : DetectedFormat?,
) -> InputSource {
  {
    kind: InputKind::Text,
    source_name,
    path: None,
    text: Some(text),
    bytes: None,
    explicit_format,
  }
}

///|
pub fn input_from_bytes(
  bytes : Bytes,
  source_name? : String = "<bytes>",
) -> InputSource {
  input_from_bytes_with_format(bytes, source_name, None)
}

///|
pub fn input_from_bytes_with_format(
  bytes : Bytes,
  source_name : String,
  explicit_format : DetectedFormat?,
) -> InputSource {
  {
    kind: InputKind::Bytes,
    source_name,
    path: None,
    text: None,
    bytes: Some(bytes),
    explicit_format,
  }
}

///|
pub fn with_explicit_format(
  source : InputSource,
  explicit_format : DetectedFormat?,
) -> InputSource {
  { ..source, explicit_format, }
}

///|
pub fn with_text_payload(source : InputSource, text : String) -> InputSource {
  { ..source, text: Some(text) }
}

///|
pub fn with_bytes_payload(source : InputSource, bytes : Bytes) -> InputSource {
  { ..source, bytes: Some(bytes) }
}

///|
pub fn default_format_detector() -> FormatDetector {
  {
    detect: fn(source : InputSource) -> FormatDetectionResult {
      detect_format(source)
    },
  }
}

///|
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

  let extension_format = match source.path {
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

  let bytes = match read_input_bytes(source) {
    Ok(payload) => payload
    Err(_) => Bytes::from_array([])
  }
  let text_like = bytes_look_text_like(bytes)
  let binary_like = !text_like && bytes.length() > 0
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
  if looks_like_magic_bytes_todo(bytes) {
    notes.push("todo_magic_bytes")
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
pub fn detected_format_name(format : DetectedFormat) -> String {
  match format {
    DetectedFormat::Txt => "txt"
    DetectedFormat::Markdown => "markdown"
    DetectedFormat::Csv => "csv"
    DetectedFormat::Tsv => "tsv"
    DetectedFormat::Json => "json"
    DetectedFormat::Jsonl => "jsonl"
    DetectedFormat::Ndjson => "ndjson"
    DetectedFormat::Xml => "xml"
    DetectedFormat::Yaml => "yaml"
    DetectedFormat::Html => "html"
    DetectedFormat::Zip => "zip"
    DetectedFormat::Epub => "epub"
    DetectedFormat::Pdf => "pdf"
    DetectedFormat::Docx => "docx"
    DetectedFormat::Pptx => "pptx"
    DetectedFormat::Xlsx => "xlsx"
    DetectedFormat::Image(kind) => image_format_name(kind)
    DetectedFormat::Unknown => "unknown"
  }
}

///|
pub fn parse_detected_format(name : String) -> DetectedFormat {
  match name.trim().to_lower() {
    "txt" => DetectedFormat::Txt
    "md" => DetectedFormat::Markdown
    "markdown" => DetectedFormat::Markdown
    "csv" => DetectedFormat::Csv
    "tsv" => DetectedFormat::Tsv
    "json" => DetectedFormat::Json
    "jsonl" => DetectedFormat::Jsonl
    "ndjson" => DetectedFormat::Ndjson
    "xml" => DetectedFormat::Xml
    "yaml" => DetectedFormat::Yaml
    "yml" => DetectedFormat::Yaml
    "html" => DetectedFormat::Html
    "htm" => DetectedFormat::Html
    "zip" => DetectedFormat::Zip
    "epub" => DetectedFormat::Epub
    "pdf" => DetectedFormat::Pdf
    "docx" => DetectedFormat::Docx
    "pptx" => DetectedFormat::Pptx
    "xlsx" => DetectedFormat::Xlsx
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
pub fn detected_format_is_image_candidate(format : DetectedFormat) -> Bool {
  match format {
    DetectedFormat::Image(_) => true
    _ => false
  }
}

///|
pub fn read_input_text(source : InputSource) -> Result[String, String] {
  match source.text {
    Some(text) => Ok(text)
    None =>
      match source.bytes {
        Some(bytes) =>
          try @utf8.decode(bytes, ignore_bom=false) |> Ok catch {
            _ => Err("utf8 decode failed")
          }
        None =>
          match source.path {
            Some(path) =>
              try @fs.read_file_to_string(path, encoding="utf8") |> Ok catch {
                e => Err("read text failed: " + e.to_string())
              }
            None => Err("input source has no text payload")
          }
      }
  }
}

///|
pub fn read_input_bytes(source : InputSource) -> Result[Bytes, String] {
  match source.bytes {
    Some(bytes) => Ok(bytes)
    None =>
      match source.text {
        Some(text) => Ok(@utf8.encode(text))
        None =>
          match source.path {
            Some(path) =>
              try @fs.read_file_to_bytes(path) |> Ok catch {
                e => Err("read bytes failed: " + e.to_string())
              }
            None => Err("input source has no byte payload")
          }
      }
  }
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
    | DetectedFormat::Docx
    | DetectedFormat::Pptx
    | DetectedFormat::Xlsx
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
fn looks_like_magic_bytes_todo(bytes : Bytes) -> Bool {
  let arr = bytes.to_array()
  if arr.length() >= 4 &&
    arr[0].to_int() == 0x50 &&
    arr[1].to_int() == 0x4B &&
    arr[2].to_int() == 0x03 &&
    arr[3].to_int() == 0x04 {
    return true
  }
  if arr.length() >= 4 &&
    arr[0].to_int() == 0x25 &&
    arr[1].to_int() == 0x50 &&
    arr[2].to_int() == 0x44 &&
    arr[3].to_int() == 0x46 {
    return true
  }
  false
}
