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
    probe_registration(Txt, Exempt, required=false),
    probe_registration(Csv, Exempt, required=false),
    probe_registration(Tsv, Exempt, required=false),
    probe_registration(Jsonl, Exempt, required=false),
    probe_registration(Ndjson, Exempt, required=false),
    probe_registration(Srt, Exempt, required=false),
    probe_registration(Vtt, Exempt, required=false),
    probe_registration(Json, StructuredTextProbe),
    probe_registration(Xml, StructuredTextProbe),
    probe_registration(Yaml, StructuredTextProbe),
    probe_registration(Toml, StructuredTextProbe),
    probe_registration(Markdown, StructuredTextProbe),
    probe_registration(Html, StructuredTextProbe),
    probe_registration(Ipynb, StructuredTextProbe),
    probe_registration(Tex, StructuredTextProbe),
    probe_registration(Rst, StructuredTextProbe),
    probe_registration(Asciidoc, StructuredTextProbe),
    probe_registration(Eml, StructuredTextProbe),
    probe_registration(Docx, PackageContainerProbe),
    probe_registration(Pptx, PackageContainerProbe),
    probe_registration(Xlsx, PackageContainerProbe),
    probe_registration(Odt, PackageContainerProbe),
    probe_registration(Ods, PackageContainerProbe),
    probe_registration(Odp, PackageContainerProbe),
    probe_registration(Epub, PackageContainerProbe),
    probe_registration(Zip, PackageContainerProbe),
    probe_registration(Pdf, PagedMediaProbe),
    probe_registration(Audio(Wav), StructuredTextProbe),
    probe_registration(Audio(Mp3), StructuredTextProbe),
    probe_registration(Audio(M4a), StructuredTextProbe),
    probe_registration(Image(Png), PagedMediaProbe),
    probe_registration(Image(Jpg), PagedMediaProbe),
    probe_registration(Image(Jpeg), PagedMediaProbe),
    probe_registration(Image(Bmp), PagedMediaProbe),
    probe_registration(Image(Webp), PagedMediaProbe),
    probe_registration(Image(Tif), PagedMediaProbe),
    probe_registration(Image(Tiff), PagedMediaProbe),
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
  StructuredTextProbe
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
    Exempt => "exempt"
    StructuredTextProbe => "structured_text"
    PackageContainerProbe => "package_container"
    PagedMediaProbe => "paged_media"
  }
}

///|
pub fn probe_registry_entries() -> Array[ProbeRegistration] {
  probe_registrations()
}
