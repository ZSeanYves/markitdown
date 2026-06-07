///|
/// Cross-format dispatcher options.
/// This struct intentionally carries only orchestration toggles shared by CLI.
pub(all) struct ConvertOptions {
  out_dir : String?
  max_heading : Int?
  pdf_enhance_mode : String?
  pdf_extract_debug : Bool
  pdf_dump_selected_raw : Bool
  pdf_pipeline_debug : Bool
}

///|
pub(all) enum ConverterCapability {
  NativeDocument
  Archive
  ImageOcr
  ExplicitProviderFuture
} derive(Eq)

///|
pub(all) struct ConverterRegistryEntry {
  format : String
  extensions : Array[String]
  capability : ConverterCapability
  default_enabled : Bool
  notes : String
}

///|
let converter_registry_entries : Array[ConverterRegistryEntry] = [
  {
    format: "docx",
    extensions: ["docx"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "OOXML document conversion via native MoonBit package parsing",
  },
  {
    format: "pdf",
    extensions: ["pdf"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "native text-PDF conversion; OCR/provider routes stay explicit and separate",
  },
  {
    format: "xlsx",
    extensions: ["xlsx"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "OOXML workbook conversion with conservative formula/table policy",
  },
  {
    format: "pptx",
    extensions: ["pptx"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "OOXML presentation conversion with reading-order and notes policy",
  },
  {
    format: "html",
    extensions: ["html", "htm"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "offline tolerant HTML lowering; no browser layout or remote fetch",
  },
  {
    format: "csv",
    extensions: ["csv"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "delimited text table conversion",
  },
  {
    format: "tsv",
    extensions: ["tsv"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "tab-delimited table conversion",
  },
  {
    format: "txt",
    extensions: ["txt"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "plain text paragraph conversion",
  },
  {
    format: "xml",
    extensions: ["xml"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "offline XML source-preserving conversion",
  },
  {
    format: "json",
    extensions: ["json"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "JSON structured-text conversion",
  },
  {
    format: "yaml",
    extensions: ["yaml", "yml"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "YAML structured-text conversion with conservative unsupported-feature policy",
  },
  {
    format: "markdown",
    extensions: ["md", "markdown"],
    capability: ConverterCapability::NativeDocument,
    default_enabled: true,
    notes: "Markdown passthrough/structured note conversion",
  },
  {
    format: "zip",
    extensions: ["zip"],
    capability: ConverterCapability::Archive,
    default_enabled: true,
    notes: "archive traversal with supported-entry dispatch; no recursive archive explosion",
  },
  {
    format: "epub",
    extensions: ["epub"],
    capability: ConverterCapability::Archive,
    default_enabled: true,
    notes: "EPUB package/spine/nav conversion through ZIP/XML foundations",
  },
  {
    format: "image-ocr",
    extensions: ["png", "jpg", "jpeg", "bmp", "webp", "tif", "tiff"],
    capability: ConverterCapability::ImageOcr,
    default_enabled: false,
    notes: "main-CLI explicit image OCR path; not routed through this native dispatcher",
  },
  {
    format: "future-provider",
    extensions: [
      "odt", "ods", "odp", "rtf", "eml", "msg", "srt", "vtt", "webvtt", "tex", "typ",
      "adoc", "asciidoc", "mp3", "wav", "mp4", "mov", "mkv",
    ],
    capability: ConverterCapability::ExplicitProviderFuture,
    default_enabled: false,
    notes: "future explicit provider/external-tool work; default dispatcher fails closed",
  },
]

///|
pub fn list_converter_registry_entries() -> Array[ConverterRegistryEntry] {
  converter_registry_entries
}

///|
pub fn lookup_converter_registry_entry(ext : String) -> ConverterRegistryEntry? {
  let normalized = ext.trim().to_owned().to_lower()
  for entry in converter_registry_entries {
    for candidate in entry.extensions {
      if candidate == normalized {
        return Some(entry)
      }
    }
  }
  None
}

///|
pub fn supported_native_extensions() -> Array[String] {
  let out : Array[String] = []
  for entry in converter_registry_entries {
    if entry.default_enabled &&
      (
        entry.capability == ConverterCapability::NativeDocument ||
        entry.capability == ConverterCapability::Archive
      ) {
      out.append(entry.extensions)
    }
  }
  out
}

///|
/// Dispatch by registry-normalized file extension to format-specific parser.
///
/// Why dispatcher is isolated:
/// - keeps extension routing independent from format recovery heuristics
/// - makes new format onboarding explicit (single entry to register)
/// - improves explainability in acceptance reviews: "where does parsing start?"
///
/// Non-goal:
/// - no format fallback / repair strategy here; those belong inside each converter.
/// - no OCR/provider/remote route is selected here; those stay explicit in CLI/provider layers.
pub async fn parse_to_ir(
  input_path : String,
  opts : ConvertOptions,
) -> Result[@cor.Document, @cor.AppError] {
  let ext = @cor.file_ext_lower(input_path)
  let registry_entry = match lookup_converter_registry_entry(ext) {
    Some(entry) => entry
    None => return Err(@cor.AppError("Unsupported file type: " + ext))
  }
  if !registry_entry.default_enabled {
    return Err(@cor.AppError("Unsupported file type: " + ext))
  }

  let out_dir_str = match opts.out_dir {
    None => ""
    Some(dir) => dir
  }
  let max_h = opts.max_heading.unwrap_or(6)

  match registry_entry.format {
    "docx" => Ok(@doc.parse_docx(input_path, out_dir_str, max_h))
    "pdf" =>
      Ok(
        @pdf.parse_pdf(
          input_path,
          out_dir_str,
          max_h,
          opts.pdf_enhance_mode,
          opts.pdf_extract_debug,
          opts.pdf_dump_selected_raw,
          opts.pdf_pipeline_debug,
        ),
      )
    "xlsx" => Ok(@xlsx.parse_xlsx(input_path, out_dir_str, max_h))
    "pptx" => Ok(@pptx_v2.parse_pptx(input_path, out_dir_str, max_h))
    "html" => Ok(@html.parse_html(input_path, out_dir_str, max_h))
    "csv" => Ok(@csv.parse_csv(input_path, out_dir_str, max_h))
    "tsv" => Ok(@csv.parse_tsv(input_path, out_dir_str, max_h))
    "txt" => Ok(@txt.parse_txt(input_path, out_dir_str, max_h))
    "xml" => Ok(@xml.parse_xml(input_path, out_dir_str, max_h))
    "json" => Ok(@json.parse_json(input_path, out_dir_str, max_h))
    "yaml" => Ok(@yaml.parse_yaml(input_path, out_dir_str, max_h))
    "markdown" => Ok(@md.parse_markdown(input_path, out_dir_str, max_h))
    "zip" => Ok(@zipconv.parse_zip(input_path, out_dir_str, max_h))
    "epub" => Ok(@epub.parse_epub(input_path, out_dir_str, max_h))
    _ => Err(@cor.AppError("Unsupported file type: " + ext))
  }
}
