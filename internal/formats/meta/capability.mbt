///|
pub(all) enum CapabilityGroup {
  Core
  Office
  Containers
  Media
  PdfOcr
} derive(Eq)

///|
pub struct CapabilityEntry {
  format : @input.DetectedFormat
  group : CapabilityGroup
  cli_supported : Bool
}

///|
fn capability_entry(
  format : @input.DetectedFormat,
  group : CapabilityGroup,
  cli_supported? : Bool = true,
) -> CapabilityEntry {
  { format, group, cli_supported }
}

///|
fn capability_entries() -> Array[CapabilityEntry] {
  [
    capability_entry(@input.DetectedFormat::Txt, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Csv, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Tsv, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Srt, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Vtt, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Json, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Jsonl, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Ndjson, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Ipynb, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Xml, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Yaml, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Toml, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Html, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Markdown, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Tex, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Rst, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Asciidoc, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Eml, CapabilityGroup::Core),
    capability_entry(@input.DetectedFormat::Docx, CapabilityGroup::Office),
    capability_entry(@input.DetectedFormat::Pptx, CapabilityGroup::Office),
    capability_entry(@input.DetectedFormat::Xlsx, CapabilityGroup::Office),
    capability_entry(@input.DetectedFormat::Odt, CapabilityGroup::Office),
    capability_entry(@input.DetectedFormat::Ods, CapabilityGroup::Office),
    capability_entry(@input.DetectedFormat::Odp, CapabilityGroup::Office),
    capability_entry(@input.DetectedFormat::Zip, CapabilityGroup::Containers),
    capability_entry(@input.DetectedFormat::Epub, CapabilityGroup::Containers),
    capability_entry(
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
      CapabilityGroup::Media,
    ),
    capability_entry(
      @input.DetectedFormat::Audio(@input.AudioFormat::Mp3),
      CapabilityGroup::Media,
    ),
    capability_entry(
      @input.DetectedFormat::Audio(@input.AudioFormat::M4a),
      CapabilityGroup::Media,
    ),
    capability_entry(@input.DetectedFormat::Pdf, CapabilityGroup::PdfOcr),
    capability_entry(
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
      CapabilityGroup::PdfOcr,
    ),
    capability_entry(
      @input.DetectedFormat::Image(@input.ImageFormat::Jpg),
      CapabilityGroup::PdfOcr,
    ),
    capability_entry(
      @input.DetectedFormat::Image(@input.ImageFormat::Jpeg),
      CapabilityGroup::PdfOcr,
    ),
    capability_entry(
      @input.DetectedFormat::Image(@input.ImageFormat::Bmp),
      CapabilityGroup::PdfOcr,
    ),
    capability_entry(
      @input.DetectedFormat::Image(@input.ImageFormat::Webp),
      CapabilityGroup::PdfOcr,
    ),
    capability_entry(
      @input.DetectedFormat::Image(@input.ImageFormat::Tif),
      CapabilityGroup::PdfOcr,
    ),
    capability_entry(
      @input.DetectedFormat::Image(@input.ImageFormat::Tiff),
      CapabilityGroup::PdfOcr,
    ),
  ]
}

///|
pub fn capability_group_for_format(
  format : @input.DetectedFormat,
) -> CapabilityGroup? {
  for entry in capability_entries() {
    if entry.format == format {
      return Some(entry.group)
    }
  }
  None
}

///|
pub fn cli_supported_for_capability_format(
  format : @input.DetectedFormat,
) -> Bool {
  for entry in capability_entries() {
    if entry.format == format {
      return entry.cli_supported
    }
  }
  false
}

///|
pub fn capability_group_name(group : CapabilityGroup) -> String {
  match group {
    CapabilityGroup::Core => "core"
    CapabilityGroup::Office => "office"
    CapabilityGroup::Containers => "containers"
    CapabilityGroup::Media => "media"
    CapabilityGroup::PdfOcr => "pdf_ocr"
  }
}

///|
pub fn capability_registry_entries() -> Array[CapabilityEntry] {
  capability_entries()
}
