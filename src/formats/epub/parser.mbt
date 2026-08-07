///|
const EPUB_PARSER_NAME : String = "epub_parser"

///|
pub fn epub_parser(
  registry_provider : () -> @parser.ParserRegistry,
) -> @parser.Parser {
  @parser.make_parser(
    EPUB_PARSER_NAME,
    PackageSinglePass,
    @internal.epub_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_epub_container_result(source, context, registry_provider)
    },
  )
}

///|
fn parse_epub_container_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry_provider : () -> @parser.ParserRegistry,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @depub.prepare_epub_package_from_source(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(
    @internal.epub_parse_with_package(
      prepared.prepared_source,
      context,
      registry_provider(),
      prepared.opened_package,
      prepared.inspect,
    ),
  )
}
