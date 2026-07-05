///|
/// Conservative baseline capability for parsers that directly return
/// `DocumentIR`.
pub fn default_parser_capability() -> ParserCapability {
  make_parser_capability(
    ParserMode::DomAstModel,
    false,
    StreamingGranularity::None,
    true,
    false,
    false,
    false,
    false,
    true,
    true,
    false,
    false,
    false,
    true,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
/// Small convenience helper for parsers/tests that only need to describe the
/// public IR shape they emit.
pub fn parser_capability(
  supports_events : Bool,
  supports_blocks : Bool,
  supports_document_ir : Bool,
) -> ParserCapability {
  let parser_mode = if supports_events {
    ParserMode::StreamingEvent
  } else if supports_blocks {
    ParserMode::BlockStreaming
  } else {
    ParserMode::DomAstModel
  }
  let granularity = if supports_events {
    StreamingGranularity::Record
  } else if supports_blocks {
    StreamingGranularity::Block
  } else {
    StreamingGranularity::None
  }
  make_parser_capability(
    parser_mode,
    supports_events || supports_blocks,
    granularity,
    !supports_document_ir,
    supports_events || supports_blocks,
    false,
    supports_events,
    supports_blocks,
    supports_document_ir,
    supports_document_ir || supports_events || supports_blocks,
    false,
    supports_events || supports_blocks,
    false,
    supports_document_ir,
    supports_document_ir,
    supports_document_ir,
    supports_document_ir,
    supports_document_ir,
    supports_document_ir,
  )
}

///|
/// Low-level capability constructor used by all parser helper builders.
pub fn make_parser_capability(
  parser_mode : ParserMode,
  supports_streaming : Bool,
  streaming_granularity : StreamingGranularity,
  requires_random_access : Bool,
  source_single_pass_preferred : Bool,
  source_single_pass_strict : Bool,
  supports_events : Bool,
  supports_blocks : Bool,
  supports_document_ir : Bool,
  produces_text : Bool,
  produces_structure : Bool,
  produces_layout : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  {
    parser_mode,
    supports_streaming,
    streaming_granularity,
    requires_random_access,
    source_single_pass_preferred,
    source_single_pass_strict,
    supports_events,
    supports_blocks,
    supports_document_ir,
    produces_text,
    produces_structure,
    produces_layout,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  }
}

///|
/// Build a DOM-style capability while still allowing optional streaming or
/// block side routes.
pub fn dom_ast_parser_capability(
  streaming_granularity : StreamingGranularity,
  supports_streaming : Bool,
  supports_events : Bool,
  supports_blocks : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::DomAstModel,
    supports_streaming,
    streaming_granularity,
    false,
    true,
    false,
    supports_events,
    supports_blocks,
    true,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}

///|
/// Build a capability for parsers whose primary public product is a block
/// stream.
pub fn block_stream_parser_capability(
  streaming_granularity : StreamingGranularity,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::BlockStreaming,
    true,
    streaming_granularity,
    false,
    true,
    false,
    false,
    true,
    true,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}

///|
/// Build a capability for parsers whose primary public product is an event
/// stream.
pub fn streaming_event_parser_capability(
  streaming_granularity : StreamingGranularity,
  supports_document_ir : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::StreamingEvent,
    true,
    streaming_granularity,
    false,
    true,
    false,
    true,
    false,
    supports_document_ir,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}

///|
/// Build a package parser capability that can still expose block streaming for
/// large-route fallbacks.
pub fn package_with_block_route_parser_capability(
  streaming_granularity : StreamingGranularity,
  requires_random_access : Bool,
  source_single_pass_preferred : Bool,
  source_single_pass_strict : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::PackageSinglePass,
    true,
    streaming_granularity,
    requires_random_access,
    source_single_pass_preferred,
    source_single_pass_strict,
    false,
    true,
    true,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}

///|
/// Build a capability for recursive container parsers that dispatch inner
/// documents through the root registry.
pub fn container_recursive_parser_capability(
  streaming_granularity : StreamingGranularity,
  requires_random_access : Bool,
  source_single_pass_preferred : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::ContainerRecursive,
    true,
    streaming_granularity,
    requires_random_access,
    source_single_pass_preferred,
    false,
    false,
    true,
    true,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}
