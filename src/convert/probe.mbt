///|
fn structured_text_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> ProbeOutcome {
  match format {
    Markdown => markdown_preflight_probe(source, options)
    Json => json_preflight_probe(source, options)
    Ipynb => ipynb_preflight_probe(source, options)
    Yaml => yaml_preflight_probe(source, options)
    Toml => toml_preflight_probe(source, options)
    Tex => text_markup_preflight_probe(source, format)
    Rst => text_markup_preflight_probe(source, format)
    Asciidoc => text_markup_preflight_probe(source, format)
    Xml => xml_preflight_probe(source, options)
    Html => html_preflight_probe(source, options)
    Audio(_) => audio_preflight_probe(source, format)
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
    Zip => zip_preflight_probe(source, options)
    Epub => epub_preflight_probe(source, options)
    Docx => docx_preflight_probe(source, options)
    Pptx => pptx_preflight_probe(source, options)
    Xlsx => xlsx_preflight_probe(source, options)
    Odt => odt_preflight_probe(source, options)
    Ods => ods_preflight_probe(source, options)
    Odp => odp_preflight_probe(source, options)
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
    Pdf => pdf_preflight_probe(source, options)
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
    Exempt => generic_preflight_probe(source, format)
    StructuredTextProbe =>
      structured_text_preflight_probe(source, format, options)
    PackageContainerProbe =>
      package_container_preflight_probe(source, format, options)
    PagedMediaProbe => paged_media_preflight_probe(source, format, options)
  }
}
