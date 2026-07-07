///|
const EPUB_PARSER_NAME : String = "epub_parser"

///|
pub fn epub_parser(
  registry_provider : () -> @parser.ParserRegistry,
) -> @parser.Parser {
  @parser.make_parser(
    EPUB_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
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
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let container_path = match source.path {
    Some(path) => {
      let parts = path.replace(old="\\", new="/").split("/").to_array()
      parts.last().unwrap_or(source.source_name).to_owned()
    }
    None => source.source_name
  }
  let pkg = try @depub.open_epub_package(bytes, container_path) |> Ok catch {
    e => Err(e.to_string())
  }
  let pkg = match pkg {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let inspect = @depub.inspect_epub_package(pkg)
  Ok(
    @internal.epub_parse_with_package(
      source,
      context,
      registry_provider(),
      pkg,
      inspect,
    ),
  )
}
