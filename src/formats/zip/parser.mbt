///|
const ZIP_PARSER_NAME : String = "zip_container_parser"

///|
pub fn zip_container_parser(
  registry_provider : () -> @parser.ParserRegistry,
) -> @parser.Parser {
  @parser.make_parser(
    ZIP_PARSER_NAME,
    ContainerRecursive,
    @internal.zip_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_zip_container_result(source, context, registry_provider)
    },
  )
}

///|
fn parse_zip_container_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  registry_provider : () -> @parser.ParserRegistry,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @dzipsource.prepare_zip_from_source(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  Ok(
    @internal.zip_parse_with_archive(
      prepared.prepared_source,
      context,
      registry_provider(),
      prepared.archive,
      prepared.inspect,
    ),
  )
}
