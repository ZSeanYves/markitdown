///|
/// Construct a parser record from its name, mode, capability, and parse
/// function.
pub fn make_parser(
  name : String,
  mode : ParserMode,
  capability : ParserCapability,
  parse : (@input.InputSource, ParseContext) -> Result[ParseResult, String],
) -> Parser {
  { name, mode, capability, parse }
}

///|
/// Construct an async parser record from its name, mode, capability, and parse
/// function.
pub fn make_async_parser(
  name : String,
  mode : ParserMode,
  capability : ParserCapability,
  parse : async (@input.InputSource, ParseContext) -> Result[
    ParseResult,
    String,
  ],
) -> AsyncParser {
  { name, mode, capability, parse }
}

///|
/// Wrap a synchronous parser as an async parser without changing semantics.
pub fn async_parser_from_sync(parser : Parser) -> AsyncParser {
  make_async_parser(parser.name, parser.mode, parser.capability, fn(
    source : @input.InputSource,
    context : ParseContext,
  ) -> Result[ParseResult, String] {
    (parser.parse)(source, context)
  })
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
  metadata? : @core.DocumentMetadata = Map([]),
  assets? : Array[@core.AssetRef] = [],
  source_map? : @core.SourceMap? = None,
  assembly? : @core.DocumentAssembly? = None,
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
  metadata? : @core.DocumentMetadata = Map([]),
  assets? : Array[@core.AssetRef] = [],
  source_map? : @core.SourceMap? = None,
  assembly? : @core.DocumentAssembly? = None,
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
