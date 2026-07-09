///|
pub(all) enum ProbeTemplate {
  Exempt
  StructuredTextProbe
  PackageContainerProbe
  PagedMediaProbe
} derive(Eq)

///|
pub struct ProbeRegistration {
  format : @input.DetectedFormat
  template : ProbeTemplate
  required : Bool
}

///|
fn probe_registration(
  format : @input.DetectedFormat,
  template : ProbeTemplate,
  required? : Bool = true,
) -> ProbeRegistration {
  { format, template, required }
}

///|
fn probe_registrations() -> Array[ProbeRegistration] {
  [
    probe_registration(
      @input.DetectedFormat::Txt,
      ProbeTemplate::Exempt,
      required=false,
    ),
    probe_registration(
      @input.DetectedFormat::Csv,
      ProbeTemplate::Exempt,
      required=false,
    ),
    probe_registration(
      @input.DetectedFormat::Tsv,
      ProbeTemplate::Exempt,
      required=false,
    ),
    probe_registration(
      @input.DetectedFormat::Jsonl,
      ProbeTemplate::Exempt,
      required=false,
    ),
    probe_registration(
      @input.DetectedFormat::Ndjson,
      ProbeTemplate::Exempt,
      required=false,
    ),
    probe_registration(
      @input.DetectedFormat::Srt,
      ProbeTemplate::Exempt,
      required=false,
    ),
    probe_registration(
      @input.DetectedFormat::Vtt,
      ProbeTemplate::Exempt,
      required=false,
    ),
    probe_registration(
      @input.DetectedFormat::Json,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Xml,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Yaml,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Toml,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Markdown,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Html,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Ipynb,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Tex,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Rst,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Asciidoc,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Eml,
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Docx,
      ProbeTemplate::PackageContainerProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Pptx,
      ProbeTemplate::PackageContainerProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Xlsx,
      ProbeTemplate::PackageContainerProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Odt,
      ProbeTemplate::PackageContainerProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Ods,
      ProbeTemplate::PackageContainerProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Odp,
      ProbeTemplate::PackageContainerProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Epub,
      ProbeTemplate::PackageContainerProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Zip,
      ProbeTemplate::PackageContainerProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Pdf,
      ProbeTemplate::PagedMediaProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Audio(@input.AudioFormat::Mp3),
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Audio(@input.AudioFormat::M4a),
      ProbeTemplate::StructuredTextProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Image(@input.ImageFormat::Png),
      ProbeTemplate::PagedMediaProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Image(@input.ImageFormat::Jpg),
      ProbeTemplate::PagedMediaProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Image(@input.ImageFormat::Jpeg),
      ProbeTemplate::PagedMediaProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Image(@input.ImageFormat::Bmp),
      ProbeTemplate::PagedMediaProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Image(@input.ImageFormat::Webp),
      ProbeTemplate::PagedMediaProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Image(@input.ImageFormat::Tif),
      ProbeTemplate::PagedMediaProbe,
    ),
    probe_registration(
      @input.DetectedFormat::Image(@input.ImageFormat::Tiff),
      ProbeTemplate::PagedMediaProbe,
    ),
  ]
}

///|
pub fn probe_template_for_format(
  format : @input.DetectedFormat,
) -> ProbeTemplate {
  for registration in probe_registrations() {
    if registration.format == format {
      return registration.template
    }
  }
  ProbeTemplate::StructuredTextProbe
}

///|
pub fn probe_required_for_format(format : @input.DetectedFormat) -> Bool {
  for registration in probe_registrations() {
    if registration.format == format {
      return registration.required
    }
  }
  true
}

///|
pub fn probe_template_name(template : ProbeTemplate) -> String {
  match template {
    ProbeTemplate::Exempt => "exempt"
    ProbeTemplate::StructuredTextProbe => "structured_text"
    ProbeTemplate::PackageContainerProbe => "package_container"
    ProbeTemplate::PagedMediaProbe => "paged_media"
  }
}

///|
pub fn probe_registry_entries() -> Array[ProbeRegistration] {
  probe_registrations()
}
