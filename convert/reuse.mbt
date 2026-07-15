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
      MarkdownPrepared(prepared) =>
        if format == Markdown {
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
      MarkdownLargeLiteral(prepared_source, text, line_count) =>
        if format == Markdown {
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
      HtmlPrepared(prepared) =>
        if format == Html {
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
      IpynbPrepared(prepared) =>
        if format == Ipynb {
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
      JsonPrepared(prepared) =>
        if format == Json && context.requested_mode == Some(StreamingEvent) {
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
      TextMarkupPrepared(prepared) =>
        match format {
          Tex =>
            Some(
              Ok(
                @fshared.parse_text_markup_result_with_prepared_document(
                  prepared,
                  context,
                  @ftex.tex_text_markup_hooks(),
                ),
              ),
            )
          Rst =>
            Some(
              Ok(
                @fshared.parse_text_markup_result_with_prepared_document(
                  prepared,
                  context,
                  @frst.rst_text_markup_hooks(),
                ),
              ),
            )
          Asciidoc =>
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
      TomlPrepared(prepared) =>
        if format == Toml {
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
      XmlPrepared(prepared) =>
        if format == Xml && context.requested_mode == Some(StreamingEvent) {
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
      DocxPrepared(prepared, _artifact) =>
        if format == Docx {
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
      PptxPrepared(prepared, _artifact) =>
        if format == Pptx {
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
      OdtPrepared(prepared) =>
        if format == Odt {
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
      OdsPrepared(prepared) =>
        if format == Ods {
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
      OdpPrepared(prepared) =>
        if format == Odp {
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
      XlsxPrepared(prepared) =>
        if format == Xlsx {
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
      PdfNativeDocument(document) =>
        if format == Pdf {
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
      ZipPrepared(prepared) =>
        if format == Zip {
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
      EpubPrepared(prepared) =>
        if format == Epub {
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
      YamlPrepared(prepared) =>
        if format == Yaml && context.requested_mode == Some(StreamingEvent) {
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
    Html => true
    Ipynb => true
    Docx => true
    Pptx => true
    Xlsx => true
    Odt => true
    Ods => true
    Odp => true
    Zip => true
    Epub => true
    Pdf => true
    _ => false
  }
}
