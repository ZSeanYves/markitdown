///|
/// Construct a parser record from its name, mode, capability, and parse
/// function.
pub fn make_parser(
  name : String,
  mode : ParserMode,
  capability : ParserCapability,
  parse : async (@input.InputSource, ParseContext) -> Result[
    ParseResult,
    String,
  ],
  open_stream~ : (async (@input.InputSource, ParseContext) -> Result[
    ParseEventStream?,
    String,
  ])? = None,
) -> Parser {
  {
    name,
    mode,
    capability,
    parse: async fn(source, context) {
      let source = match context.input_source {
        Some(parent) => @input.input_source_inherit_session(source, parent)
        None => source
      }
      let session = @input.begin_input_session(
        source,
        max_bytes=max_input_bytes(context),
      )
      defer @input.end_input_session(session)
      let cleanup = @input.begin_input_cleanup_scope(session)
      defer ignore(@input.cleanup_input_scope(cleanup))
      let context = parse_context_with_input_source(context, session.source)
      if @input.input_source_error(session.source) is Some(message) {
        return Err(message)
      }
      let result = parse(session.source, context)
      ignore(@input.cleanup_input_scope(cleanup))
      match @input.input_source_error(session.source) {
        Some(message) => Err(message)
        None => result
      }
    },
    open_stream: open_stream.map(fn(open) {
      async fn(source, context) {
        open_parser_stream_with_cleanup(open, source, context)
      }
    }),
  }
}

///|
/// Construct the side-channel summary used by a pull parser after EOF.
pub fn parse_stream_summary(
  parser_name : String,
  mode : ParserMode,
  capabilities : ParserCapability,
  diagnostics : @core.Diagnostics,
  metadata~ : @core.DocumentMetadata = Map([]),
  assets~ : Array[@core.AssetRef] = [],
  source_map~ : @core.SourceMap? = None,
  assembly~ : @core.DocumentAssembly? = None,
) -> ParseStreamSummary {
  {
    parser_name,
    mode,
    capabilities,
    metadata,
    assets,
    source_map,
    assembly,
    diagnostics,
  }
}

///|
/// Construct the asynchronous parser pull protocol. Pure scanners may run
/// inside these callbacks; the protocol always advances asynchronously.
pub fn make_parse_event_stream(
  next : async () -> Result[@core.CoreEvent?, String],
  finish : async () -> Result[ParseStreamSummary, String],
  close~ : async () -> Result[Unit, String] = fn() { Ok(()) },
) -> ParseEventStream {
  {
    next: async fn() {
      @async.sleep(0)
      next()
    },
    finish,
    close_stream: close,
  }
}

///|
/// Abort without requesting a successful summary. It is safe to use in a
/// cancellation defer; owned stream resources and temporary cleanup are closed
/// independently of finish. Callers must not silently abandon a live stream.
pub async fn ParseEventStream::close(
  self : ParseEventStream,
) -> Result[Unit, String] noraise + nocancel {
  @async.protect_from_cancel(() => (self.close_stream)()) catch {
    error => Err("parser stream close failed: " + error.to_string())
  }
}

///|
/// Wrap an event-stream parser result with the default event capability.
pub fn parse_result_with_events(
  parser_name : String,
  mode : ParserMode,
  events : Array[@core.CoreEvent],
  diagnostics : @core.Diagnostics,
) -> ParseResult {
  {
    parser_name,
    mode,
    capabilities: parser_capability(true, false, false),
    event_stream: Some(events),
    block_stream: None,
    document: None,
    metadata: Map([]),
    assets: [],
    source_map: None,
    assembly: None,
    diagnostics,
  }
}

///|
/// Wrap an event-stream parser result with an explicit capability plus
/// metadata/assets/provenance side channels.
pub fn parse_result_with_events_capability(
  parser_name : String,
  mode : ParserMode,
  events : Array[@core.CoreEvent],
  diagnostics : @core.Diagnostics,
  capability : ParserCapability,
  metadata~ : @core.DocumentMetadata = Map([]),
  assets~ : Array[@core.AssetRef] = [],
  source_map~ : @core.SourceMap? = None,
  assembly~ : @core.DocumentAssembly? = None,
) -> ParseResult {
  if diagnostics.metrics.get("builder_input_kind") == None {
    diagnostics.metrics.set("builder_input_kind", "event_stream")
  }
  {
    parser_name,
    mode,
    capabilities: capability,
    event_stream: Some(events),
    block_stream: None,
    document: None,
    metadata,
    assets,
    source_map,
    assembly,
    diagnostics,
  }
}

///|
/// Wrap a block-stream parser result with the default block capability.
pub fn parse_result_with_blocks(
  parser_name : String,
  mode : ParserMode,
  blocks : Array[@core.CoreBlock],
  diagnostics : @core.Diagnostics,
) -> ParseResult {
  {
    parser_name,
    mode,
    capabilities: parser_capability(false, true, false),
    event_stream: None,
    block_stream: Some(blocks),
    document: None,
    metadata: Map([]),
    assets: [],
    source_map: None,
    assembly: None,
    diagnostics,
  }
}

///|
/// Wrap a block-stream parser result with an explicit capability plus
/// metadata/assets/provenance side channels.
pub fn parse_result_with_blocks_capability(
  parser_name : String,
  mode : ParserMode,
  blocks : Array[@core.CoreBlock],
  diagnostics : @core.Diagnostics,
  capability : ParserCapability,
  metadata~ : @core.DocumentMetadata = Map([]),
  assets~ : Array[@core.AssetRef] = [],
  source_map~ : @core.SourceMap? = None,
  assembly~ : @core.DocumentAssembly? = None,
) -> ParseResult {
  if diagnostics.metrics.get("builder_input_kind") == None {
    diagnostics.metrics.set("builder_input_kind", "block_stream")
  }
  {
    parser_name,
    mode,
    capabilities: capability,
    event_stream: None,
    block_stream: Some(blocks),
    document: None,
    metadata,
    assets,
    source_map,
    assembly,
    diagnostics,
  }
}

///|
/// Wrap a document parser result with the default document capability.
pub fn parse_result_with_document(
  parser_name : String,
  mode : ParserMode,
  document : @core.DocumentIR,
  diagnostics : @core.Diagnostics,
) -> ParseResult {
  {
    parser_name,
    mode,
    capabilities: parser_capability(false, false, true),
    event_stream: None,
    block_stream: None,
    document: Some(document),
    metadata: document.metadata,
    assets: document.assets,
    source_map: document.source_map,
    assembly: document.assembly,
    diagnostics,
  }
}

///|
/// Wrap a document parser result with an explicit capability.
pub fn parse_result_with_document_capability(
  parser_name : String,
  mode : ParserMode,
  document : @core.DocumentIR,
  diagnostics : @core.Diagnostics,
  capability : ParserCapability,
) -> ParseResult {
  if diagnostics.metrics.get("builder_input_kind") == None {
    diagnostics.metrics.set("builder_input_kind", "document")
  }
  {
    parser_name,
    mode,
    capabilities: capability,
    event_stream: None,
    block_stream: None,
    document: Some(document),
    metadata: document.metadata,
    assets: document.assets,
    source_map: document.source_map,
    assembly: document.assembly,
    diagnostics,
  }
}
