///|
const ZIP_PARSER_NAME : String = "zip_container_parser"

///|
pub fn zip_container_parser(
  registry_provider : () -> @parser.ParserRegistry,
) -> @parser.Parser {
  @parser.make_parser(
    ZIP_PARSER_NAME,
    @parser.ParserMode::ContainerRecursive,
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
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let archive = try @dzip.open_zip(bytes) |> Ok catch {
    e => Err(e.to_string())
  }
  let archive = match archive {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let report = @dzip.inspect_zip_archive(archive)
  Ok(
    @internal.zip_parse_with_archive(
      source,
      context,
      registry_provider(),
      archive,
      report,
    ),
  )
}
