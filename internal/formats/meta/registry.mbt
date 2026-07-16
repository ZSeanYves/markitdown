///|
/// Register all built-in format parsers into a registry instance.
pub fn register_builtin_parsers(registry : @parser.ParserRegistry) -> Unit {
  @parser.registry_register(registry, Txt, @ftxt.txt_parser())
  @parser.registry_register(registry, Srt, @fsrt.srt_parser())
  @parser.registry_register(registry, Vtt, @fvtt.vtt_parser())
  @parser.registry_register(registry, Markdown, @fmarkdown.markdown_parser())
  @parser.registry_register(registry, Csv, @fcsv.csv_parser())
  @parser.registry_register(registry, Tsv, @ftsv.tsv_parser())
  @parser.registry_register(registry, Json, @fjson.json_parser())
  @parser.registry_register(registry, Jsonl, @fjson.jsonl_parser())
  @parser.registry_register(registry, Ndjson, @fjson.ndjson_parser())
  @parser.registry_register(registry, Ipynb, @fipynb.ipynb_parser())
  @parser.registry_register(registry, Xml, @fxml.xml_parser())
  @parser.registry_register(registry, Yaml, @fyaml.yaml_parser())
  @parser.registry_register(registry, Toml, @ftoml.toml_parser())
  @parser.registry_register(registry, Tex, @ftex.tex_parser())
  @parser.registry_register(registry, Rst, @frst.rst_parser())
  @parser.registry_register(registry, Asciidoc, @fasciidoc.asciidoc_parser())
  @parser.registry_register(registry, Html, @fhtml.html_parser())
  @parser.registry_register(
    registry,
    Eml,
    @feml.eml_parser_with_registry(fn() { builtin_registry() }),
  )
  @parser.registry_register(
    registry,
    Zip,
    @fzip.zip_container_parser(fn() { builtin_registry() }),
  )
  @parser.registry_register(
    registry,
    Epub,
    @fepub.epub_parser(fn() { builtin_registry() }),
  )
  @parser.registry_register(registry, Odt, @fodt.odt_parser())
  @parser.registry_register(registry, Ods, @fods.ods_parser())
  @parser.registry_register(registry, Odp, @fodp.odp_parser())
  @parser.registry_register(registry, Pdf, @fpdf.pdf_native_parser())
  @parser.registry_register(registry, Pdf, @fpdf.pdf_ocr_parser())
  @parser.registry_register(registry, Audio(Wav), @faudio.audio_parser())
  @parser.registry_register(registry, Audio(Mp3), @faudio.audio_parser())
  @parser.registry_register(registry, Audio(M4a), @faudio.audio_parser())
  @parser.registry_register(registry, Docx, @fdocx.docx_parser())
  @parser.registry_register(registry, Pptx, @fpptx.pptx_parser())
  @parser.registry_register(registry, Xlsx, @fxlsx.xlsx_parser())
  @parser.registry_register(registry, Image(Png), @focr.image_ocr_parser())
  @parser.registry_register(registry, Image(Jpg), @focr.image_ocr_parser())
  @parser.registry_register(registry, Image(Jpeg), @focr.image_ocr_parser())
  @parser.registry_register(registry, Image(Bmp), @focr.image_ocr_parser())
  @parser.registry_register(registry, Image(Webp), @focr.image_ocr_parser())
  @parser.registry_register(registry, Image(Tif), @focr.image_ocr_parser())
  @parser.registry_register(registry, Image(Tiff), @focr.image_ocr_parser())
}

///|
/// Construct a fresh registry populated with all built-in parsers.
pub fn builtin_registry() -> @parser.ParserRegistry {
  let registry = @parser.empty_registry()
  register_builtin_parsers(registry)
  registry
}
