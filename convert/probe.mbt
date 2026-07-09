///|
fn structured_text_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> ProbeOutcome {
  match format {
    @input.DetectedFormat::Markdown => markdown_preflight_probe(source, options)
    @input.DetectedFormat::Json => json_preflight_probe(source, options)
    @input.DetectedFormat::Ipynb => ipynb_preflight_probe(source, options)
    @input.DetectedFormat::Yaml => yaml_preflight_probe(source, options)
    @input.DetectedFormat::Toml => toml_preflight_probe(source, options)
    @input.DetectedFormat::Tex => text_markup_preflight_probe(source, format)
    @input.DetectedFormat::Rst => text_markup_preflight_probe(source, format)
    @input.DetectedFormat::Asciidoc =>
      text_markup_preflight_probe(source, format)
    @input.DetectedFormat::Xml => xml_preflight_probe(source, options)
    @input.DetectedFormat::Html => html_preflight_probe(source, options)
    @input.DetectedFormat::Audio(_) => audio_preflight_probe(source, format)
    _ => generic_preflight_probe(source, format)
  }
}

///|
fn package_container_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> ProbeOutcome {
  match format {
    @input.DetectedFormat::Zip => zip_preflight_probe(source, options)
    @input.DetectedFormat::Epub => epub_preflight_probe(source, options)
    @input.DetectedFormat::Docx => docx_preflight_probe(source, options)
    @input.DetectedFormat::Pptx => pptx_preflight_probe(source, options)
    @input.DetectedFormat::Xlsx => xlsx_preflight_probe(source, options)
    @input.DetectedFormat::Odt => odt_preflight_probe(source, options)
    @input.DetectedFormat::Ods => ods_preflight_probe(source, options)
    @input.DetectedFormat::Odp => odp_preflight_probe(source, options)
    _ => generic_preflight_probe(source, format)
  }
}

///|
fn paged_media_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> ProbeOutcome {
  match format {
    @input.DetectedFormat::Pdf => pdf_preflight_probe(source, options)
    _ => generic_preflight_probe(source, format)
  }
}

///|
fn preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> ProbeOutcome {
  match @fmeta.probe_template_for_format(format) {
    @fmeta.ProbeTemplate::Exempt => generic_preflight_probe(source, format)
    @fmeta.ProbeTemplate::StructuredTextProbe =>
      structured_text_preflight_probe(source, format, options)
    @fmeta.ProbeTemplate::PackageContainerProbe =>
      package_container_preflight_probe(source, format, options)
    @fmeta.ProbeTemplate::PagedMediaProbe =>
      paged_media_preflight_probe(source, format, options)
  }
}
