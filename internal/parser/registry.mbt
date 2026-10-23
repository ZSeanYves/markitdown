///|
/// Create an empty parser registry.
pub fn empty_registry() -> ParserRegistry {
  { parsers: Map([]), }
}

///|
/// Convert a detected format into the stable registry key used for lookup.
pub fn registry_key(format : @input.DetectedFormat) -> String {
  @input.detected_format_name(format)
}

///|
/// Register `parser` for `format`.
///
/// The first registration remains the canonical default; later registrations
/// can override mode-specific dispatch when `requested_mode` matches.
pub fn registry_register(
  registry : ParserRegistry,
  format : @input.DetectedFormat,
  parser : Parser,
) -> Unit {
  let key = registry_key(format)
  let registered = registry.parsers.get(key).unwrap_or([])
  let next : Array[Parser] = []
  next.append(registered[:])
  next.push(parser)
  registry.parsers.set(key, next)
}

///|
/// Look up the canonical default parser for `format`.
pub fn registry_lookup(
  registry : ParserRegistry,
  format : @input.DetectedFormat,
) -> Parser? {
  match registry.parsers.get(registry_key(format)) {
    Some(parsers) => parsers.get(0)
    None => None
  }
}

///|
fn parser_matches_requested_mode(
  parser : Parser,
  requested_mode : ParserMode?,
) -> Bool {
  match requested_mode {
    Some(mode) => parser.mode == mode
    None => false
  }
}

///|
/// Prefer the newest parser whose declared mode matches `context`, then fall
/// back to the canonical default registration.
fn registry_lookup_for_context(
  registry : ParserRegistry,
  context : ParseContext,
) -> Parser? {
  let parsers = match
    registry.parsers.get(registry_key(context.detected_format)) {
    Some(value) => value
    None => return None
  }
  match context.requested_mode {
    Some(_) => {
      let mut i = parsers.length()
      while i > 0 {
        i = i - 1
        match parsers.get(i) {
          Some(parser) if parser_matches_requested_mode(
              parser,
              context.requested_mode,
            ) => return Some(parser)
          _ => ()
        }
      }
    }
    None => ()
  }
  parsers.get(0)
}

///|
/// Dispatch into the registered parser for `context.detected_format`.
pub async fn registry_parse(
  registry : ParserRegistry,
  source : @input.InputSource,
  context : ParseContext,
) -> Result[ParseResult, String] {
  match registry_lookup_for_context(registry, context) {
    Some(parser) => (parser.parse)(source, context)
    None =>
      Err(
        "no parser registered for format: " +
        @input.detected_format_name(context.detected_format),
      )
  }
}

///|
/// Open the canonical parser's pull event stream when the format provides one.
/// `None` means the parser intentionally uses the buffered contract.
pub async fn registry_open_event_stream(
  registry : ParserRegistry,
  source : @input.InputSource,
  context : ParseContext,
) -> Result[ParseEventStream?, String] {
  match registry_lookup_for_context(registry, context) {
    Some(parser) =>
      match parser.open_stream {
        Some(open) => open(source, context)
        None => Ok(None)
      }
    None =>
      Err(
        "no parser registered for format: " +
        @input.detected_format_name(context.detected_format),
      )
  }
}
