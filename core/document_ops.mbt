///|
pub fn empty_document_ir() -> DocumentIR {
  {
    blocks: [],
    metadata: Map([]),
    diagnostics: empty_diagnostics(),
    assets: [],
    signals: [],
    source_map: None,
    assembly: None,
  }
}

///|
pub fn document_from_blocks(blocks : Array[CoreBlock]) -> DocumentIR {
  {
    blocks,
    metadata: Map([]),
    diagnostics: empty_diagnostics(),
    assets: [],
    signals: [],
    source_map: None,
    assembly: None,
  }
}

///|
pub fn empty_document_assembly() -> DocumentAssembly {
  {
    root_block_ids: [],
    sections: [],
    heading_paths: Map([]),
    caption_bindings: [],
    table_continuations: [],
    reading_order: [],
    asset_bindings: [],
  }
}

///|
pub fn document_with_diagnostics(
  document : DocumentIR,
  diagnostics : Diagnostics,
) -> DocumentIR {
  { ..document, diagnostics, }
}

///|
pub fn document_with_blocks(
  document : DocumentIR,
  blocks : Array[CoreBlock],
) -> DocumentIR {
  { ..document, blocks, }
}

///|
pub fn document_with_assets(
  document : DocumentIR,
  assets : Array[AssetRef],
) -> DocumentIR {
  { ..document, assets, }
}

///|
pub fn document_with_metadata(
  document : DocumentIR,
  metadata : DocumentMetadata,
) -> DocumentIR {
  { ..document, metadata, }
}

///|
pub fn document_with_signals(
  document : DocumentIR,
  signals : Array[CoreSignal],
) -> DocumentIR {
  { ..document, signals, }
}

///|
pub fn document_with_source_map(
  document : DocumentIR,
  source_map : SourceMap?,
) -> DocumentIR {
  { ..document, source_map, }
}

///|
pub fn document_with_assembly(
  document : DocumentIR,
  assembly : DocumentAssembly?,
) -> DocumentIR {
  { ..document, assembly, }
}
