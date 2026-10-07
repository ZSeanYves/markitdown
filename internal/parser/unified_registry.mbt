///|
/// Create an empty shared parser registry façade.
pub fn empty_unified_registry() -> UnifiedParserRegistry {
  { parsers: Map([]), }
}

///|
fn sync_registration(parser : Parser) -> ParserRegistration {
  {
    name: parser.name,
    mode: parser.mode,
    capability: parser.capability,
    sync_parser: Some(parser),
    async_parser: None,
  }
}

///|
fn async_registration(parser : AsyncParser) -> ParserRegistration {
  {
    name: parser.name,
    mode: parser.mode,
    capability: parser.capability,
    sync_parser: None,
    async_parser: Some(parser),
  }
}

///|
fn register_entry(
  registry : UnifiedParserRegistry,
  format : @input.DetectedFormat,
  entry : ParserRegistration,
) -> Unit {
  let key = registry_key(format)
  let entries = registry.parsers.get(key).unwrap_or([])
  let next : Array[ParserRegistration] = []
  next.append(entries[:])
  next.push(entry)
  registry.parsers.set(key, next)
}

///|
/// Register a synchronous parser in the migration façade.
pub fn unified_registry_register(
  registry : UnifiedParserRegistry,
  format : @input.DetectedFormat,
  parser : Parser,
) -> Unit {
  register_entry(registry, format, sync_registration(parser))
}

///|
/// Register an asynchronous parser in the migration façade.
pub fn unified_registry_register_async(
  registry : UnifiedParserRegistry,
  format : @input.DetectedFormat,
  parser : AsyncParser,
) -> Unit {
  register_entry(registry, format, async_registration(parser))
}

///|
/// Copy a synchronous registry into the migration façade.
pub fn unified_registry_from_sync(
  registry : ParserRegistry,
) -> UnifiedParserRegistry {
  let unified = empty_unified_registry()
  for entry in registry.parsers {
    let registrations : Array[ParserRegistration] = []
    for parser in entry.1 {
      registrations.push(sync_registration(parser))
    }
    unified.parsers.set(entry.0, registrations)
  }
  unified
}

///|
/// Project the synchronous registrations from the unified façade for legacy
/// format helpers that only perform pure lowering. The projection is an
/// adapter boundary, never a second dispatch path: product entrypoints keep
/// the unified registry and use this only while a nested format helper is
/// being migrated to async.
pub fn unified_registry_sync_projection(
  registry : UnifiedParserRegistry,
) -> ParserRegistry {
  let projected = empty_registry()
  for entry in registry.parsers {
    let parsers : Array[Parser] = []
    for registration in entry.1 {
      match registration.sync_parser {
        Some(parser) => parsers.push(parser)
        None => ()
      }
    }
    if parsers.length() > 0 {
      projected.parsers.set(entry.0, parsers)
    }
  }
  projected
}

///|
fn lookup_entry(
  registry : UnifiedParserRegistry,
  context : ParseContext,
) -> ParserRegistration? {
  let entries = match
    registry.parsers.get(registry_key(context.detected_format)) {
    Some(value) => value
    None => return None
  }
  match context.requested_mode {
    Some(mode) => {
      let mut i = entries.length()
      while i > 0 {
        i = i - 1
        match entries.get(i) {
          Some(entry) if entry.mode == mode => return Some(entry)
          _ => ()
        }
      }
    }
    None => ()
  }
  entries.get(0)
}

///|
/// Async façade dispatch. Existing synchronous parsers are adapted only at
/// this boundary; parser implementations and the product pipeline remain
/// unchanged.
pub async fn unified_registry_parse(
  registry : UnifiedParserRegistry,
  source : @input.InputSource,
  context : ParseContext,
) -> Result[ParseResult, String] {
  match lookup_entry(registry, context) {
    Some(entry) =>
      match entry.async_parser {
        Some(parser) => (parser.parse)(source, context)
        None =>
          match entry.sync_parser {
            Some(parser) => (parser.parse)(source, context)
            None =>
              Err("parser registration has no implementation: " + entry.name)
          }
      }
    None =>
      Err(
        "no parser registered for format: " +
        @input.detected_format_name(context.detected_format),
      )
  }
}

///|
/// Open a pull stream from a synchronous parser in the façade.
pub fn unified_registry_open_event_stream(
  registry : UnifiedParserRegistry,
  source : @input.InputSource,
  context : ParseContext,
) -> Result[ParseEventStream?, String] {
  match lookup_entry(registry, context) {
    Some(entry) =>
      match entry.sync_parser {
        Some(parser) =>
          match parser.stream_events {
            Some(open) => open(source, context)
            None => Ok(None)
          }
        None => Ok(None)
      }
    None =>
      Err(
        "no parser registered for format: " +
        @input.detected_format_name(context.detected_format),
      )
  }
}

///|
async test "unified parser registry adapts sync and async entries" {
  let registry = empty_unified_registry()
  unified_registry_register(
    registry,
    Txt,
    make_parser("sync", DomAstModel, default_parser_capability(), fn(_, _) {
      Ok(
        parse_result_with_document(
          "sync",
          DomAstModel,
          @core.empty_document_ir(),
          @core.empty_diagnostics(),
        ),
      )
    }),
  )
  unified_registry_register_async(
    registry,
    Txt,
    make_async_parser(
      "async",
      BlockStreaming,
      parser_capability(false, true, true),
      fn(_, _) {
        Ok(
          parse_result_with_blocks(
            "async",
            BlockStreaming,
            [],
            @core.empty_diagnostics(),
          ),
        )
      },
    ),
  )
  assert_true(
    unified_registry_parse(
      registry,
      @input.input_from_text("fixture"),
      new_parse_context(Txt),
    ).unwrap().parser_name ==
    "sync",
  )
  assert_true(
    unified_registry_parse(registry, @input.input_from_text("fixture"), {
      ..new_parse_context(Txt),
      requested_mode: Some(BlockStreaming),
    }).unwrap().parser_name ==
    "async",
  )
}

///|
async test "unified parser registry copies the canonical default" {
  let source = empty_registry()
  registry_register(
    source,
    Txt,
    make_parser("default", DomAstModel, default_parser_capability(), fn(_, _) {
      Ok(
        parse_result_with_document(
          "default",
          DomAstModel,
          @core.empty_document_ir(),
          @core.empty_diagnostics(),
        ),
      )
    }),
  )
  let unified = unified_registry_from_sync(source)
  let result = unified_registry_parse(
    unified,
    @input.input_from_text("fixture"),
    new_parse_context(Txt),
  )
  assert_true(result.unwrap().parser_name == "default")
}
