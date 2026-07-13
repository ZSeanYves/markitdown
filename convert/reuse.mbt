///|
fn parse_with_route_probe_artifact(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
  artifacts : Array[RouteProbeArtifact],
) -> Result[@parser.ParseResult, String]? {
  for artifact in artifacts {
    let matched = match artifact {
      RouteProbeArtifact::MarkdownPrepared(prepared) =>
        if format == @input.DetectedFormat::Markdown {
          Some(
            Ok(
              @fmarkdown.markdown_parse_with_prepared_document(
                prepared.prepared_source,
                context,
                prepared,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::MarkdownLargeLiteral(
        prepared_source,
        text,
        line_count
      ) =>
        if format == @input.DetectedFormat::Markdown {
          Some(
            Ok(
              @fmarkdown.markdown_parse_large_literal(
                prepared_source, context, text, line_count,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::HtmlPrepared(prepared) =>
        if format == @input.DetectedFormat::Html {
          match prepared.events {
            Some(_) =>
              Some(
                Ok(
                  @fhtml.html_parse_with_prepared_document(
                    prepared.prepared_source,
                    context,
                    prepared,
                  ),
                ),
              )
            None =>
              match prepared.event_summary {
                Some(_) =>
                  Some(
                    Ok(
                      @fhtml.html_parse_with_prepared_document(
                        prepared.prepared_source,
                        context,
                        prepared,
                      ),
                    ),
                  )
                None => None
              }
          }
        } else {
          None
        }
      RouteProbeArtifact::IpynbPrepared(prepared) =>
        if format == @input.DetectedFormat::Ipynb {
          Some(
            Ok(
              @fipynb.ipynb_parse_with_prepared_notebook(
                prepared.prepared_source,
                context,
                prepared,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::JsonPrepared(prepared) =>
        if format == @input.DetectedFormat::Json &&
          context.requested_mode == Some(@parser.ParserMode::StreamingEvent) {
          match prepared.stream {
            Some(_) =>
              Some(
                Ok(
                  @fjson.json_parse_with_prepared_document(
                    prepared.prepared_source,
                    context,
                    prepared,
                  ),
                ),
              )
            None => None
          }
        } else {
          None
        }
      RouteProbeArtifact::TextMarkupPrepared(prepared) =>
        match format {
          @input.DetectedFormat::Tex =>
            Some(
              Ok(
                @fshared.parse_text_markup_result_with_prepared_document(
                  prepared,
                  context,
                  @ftex.tex_text_markup_hooks(),
                ),
              ),
            )
          @input.DetectedFormat::Rst =>
            Some(
              Ok(
                @fshared.parse_text_markup_result_with_prepared_document(
                  prepared,
                  context,
                  @frst.rst_text_markup_hooks(),
                ),
              ),
            )
          @input.DetectedFormat::Asciidoc =>
            Some(
              Ok(
                @fshared.parse_text_markup_result_with_prepared_document(
                  prepared,
                  context,
                  @fasciidoc.asciidoc_text_markup_hooks(),
                ),
              ),
            )
          _ => None
        }
      RouteProbeArtifact::TomlPrepared(prepared) =>
        if format == @input.DetectedFormat::Toml {
          match prepared.document {
            Some(_) =>
              Some(
                Ok(
                  @ftoml.toml_parse_with_prepared_document(
                    prepared.prepared_source,
                    context,
                    prepared,
                  ),
                ),
              )
            None => None
          }
        } else {
          None
        }
      RouteProbeArtifact::XmlPrepared(prepared) =>
        if format == @input.DetectedFormat::Xml &&
          context.requested_mode == Some(@parser.ParserMode::StreamingEvent) {
          match prepared.tokens {
            Some(_) =>
              Some(
                Ok(
                  @fxml.xml_parse_with_prepared_text(
                    prepared.prepared_source,
                    context,
                    prepared,
                  ),
                ),
              )
            None => None
          }
        } else {
          None
        }
      RouteProbeArtifact::DocxPrepared(prepared, _artifact) =>
        if format == @input.DetectedFormat::Docx {
          Some(
            Ok(
              @fdocx.docx_parse_with_prepared_document(
                prepared.prepared_source,
                context,
                prepared,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::PptxPrepared(prepared, _artifact) =>
        if format == @input.DetectedFormat::Pptx {
          Some(
            Ok(
              @fpptx.pptx_parse_with_prepared_document(
                prepared.prepared_source,
                context,
                prepared,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::OdtPrepared(prepared) =>
        if format == @input.DetectedFormat::Odt {
          Some(
            Ok(
              @fodt.odt_parse_with_prepared_document(
                prepared.prepared_source,
                context,
                prepared,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::OdsPrepared(prepared) =>
        if format == @input.DetectedFormat::Ods {
          Some(
            Ok(
              @fods.ods_parse_with_prepared_document(
                prepared.prepared_source,
                context,
                prepared,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::OdpPrepared(prepared) =>
        if format == @input.DetectedFormat::Odp {
          Some(
            Ok(
              @fodp.odp_parse_with_prepared_document(
                prepared.prepared_source,
                context,
                prepared,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::XlsxPrepared(prepared) =>
        if format == @input.DetectedFormat::Xlsx {
          Some(
            Ok(
              @dxlsx.xlsx_parse_with_prepared_package(
                prepared.prepared_source,
                context,
                prepared,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::PdfNativeDocument(document) =>
        if format == @input.DetectedFormat::Pdf {
          Some(
            Ok(
              @fpdfinternal.pdf_parse_with_native_document(
                source,
                context,
                document,
                probe_artifact_reused=true,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::ZipPrepared(prepared) =>
        if format == @input.DetectedFormat::Zip {
          Some(
            Ok(
              @fzipinternal.zip_parse_with_prepared_archive(
                prepared.prepared_source,
                context,
                registry,
                prepared,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::EpubPrepared(prepared) =>
        if format == @input.DetectedFormat::Epub {
          Some(
            Ok(
              @fepubinternal.epub_parse_with_package_artifact(
                prepared.prepared_source,
                context,
                registry,
                prepared.opened_package,
                prepared.inspect,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::YamlPrepared(prepared) =>
        if format == @input.DetectedFormat::Yaml &&
          context.requested_mode == Some(@parser.ParserMode::StreamingEvent) {
          match (prepared.events, prepared.compact_sequence) {
            (Some(_), _) | (_, Some(_)) =>
              Some(
                Ok(
                  @fyaml.yaml_parse_with_prepared_document(
                    prepared.prepared_source,
                    context,
                    prepared,
                  ),
                ),
              )
            _ => None
          }
        } else {
          None
        }
    }
    if matched is Some(_) {
      return matched
    }
  }
  None
}

///|
fn parse_prepared_request(
  request : PreparedParseRequest,
  context : @parser.ParseContext,
  registry : @parser.ParserRegistry,
) -> Result[@parser.ParseResult, String]? {
  let artifacts = match request.probe_artifact {
    Some(artifact) => [artifact]
    None => request.probe_outcome.probe_artifacts
  }
  parse_with_route_probe_artifact(
    request.source,
    request.detected_format,
    context,
    registry,
    artifacts,
  )
}

///|
fn heavy_probe_artifact_required(format : @input.DetectedFormat) -> Bool {
  match format {
    @input.DetectedFormat::Html => true
    @input.DetectedFormat::Ipynb => true
    @input.DetectedFormat::Docx => true
    @input.DetectedFormat::Pptx => true
    @input.DetectedFormat::Xlsx => true
    @input.DetectedFormat::Odt => true
    @input.DetectedFormat::Ods => true
    @input.DetectedFormat::Odp => true
    @input.DetectedFormat::Zip => true
    @input.DetectedFormat::Epub => true
    @input.DetectedFormat::Pdf => true
    _ => false
  }
}
