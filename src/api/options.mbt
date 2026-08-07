///|
/// Return the default production resource ceilings.
pub fn ResourceLimits::default() -> ResourceLimits {
  let limits = @product.default_resource_limits()
  {
    max_rows: limits.max_rows,
    max_cols: limits.max_cols,
    max_cells: limits.max_cells,
    max_line_chars: limits.max_line_chars,
    max_input_bytes: limits.max_input_bytes,
    max_asset_bytes: limits.max_asset_bytes,
    max_total_asset_bytes: limits.max_total_asset_bytes,
    external_command_timeout_ms: limits.external_command_timeout_ms,
    max_external_output_bytes: limits.max_external_output_bytes,
  }
}

///|
/// Return a copy with a new maximum row count.
pub fn ResourceLimits::with_max_rows(
  self : ResourceLimits,
  max_rows : Int,
) -> ResourceLimits {
  { ..self, max_rows, }
}

///|
/// Return a copy with a new maximum column count.
pub fn ResourceLimits::with_max_cols(
  self : ResourceLimits,
  max_cols : Int,
) -> ResourceLimits {
  { ..self, max_cols, }
}

///|
/// Return a copy with a new maximum cell count.
pub fn ResourceLimits::with_max_cells(
  self : ResourceLimits,
  max_cells : Int,
) -> ResourceLimits {
  { ..self, max_cells, }
}

///|
/// Return a copy with a new maximum rendered line length.
pub fn ResourceLimits::with_max_line_chars(
  self : ResourceLimits,
  max_line_chars : Int,
) -> ResourceLimits {
  { ..self, max_line_chars, }
}

///|
/// Return a copy with a new maximum input size.
pub fn ResourceLimits::with_max_input_bytes(
  self : ResourceLimits,
  max_input_bytes : Int64,
) -> ResourceLimits {
  { ..self, max_input_bytes, }
}

///|
/// Return a copy with a new per-asset payload limit.
pub fn ResourceLimits::with_max_asset_bytes(
  self : ResourceLimits,
  max_asset_bytes : Int64,
) -> ResourceLimits {
  { ..self, max_asset_bytes, }
}

///|
/// Return a copy with a new aggregate asset payload limit.
pub fn ResourceLimits::with_max_total_asset_bytes(
  self : ResourceLimits,
  max_total_asset_bytes : Int64,
) -> ResourceLimits {
  { ..self, max_total_asset_bytes, }
}

///|
/// Return a copy with a new external-command timeout.
pub fn ResourceLimits::with_external_command_timeout_ms(
  self : ResourceLimits,
  external_command_timeout_ms : Int,
) -> ResourceLimits {
  { ..self, external_command_timeout_ms, }
}

///|
/// Return a copy with a new external-command output limit.
pub fn ResourceLimits::with_max_external_output_bytes(
  self : ResourceLimits,
  max_external_output_bytes : Int64,
) -> ResourceLimits {
  { ..self, max_external_output_bytes, }
}

///|
/// Return the default RAG chunking policy.
pub fn RagOptions::default() -> RagOptions {
  let options = @rag.default_rag_options()
  {
    chunk_size: options.chunk_size,
    chunk_overlap: options.chunk_overlap,
    preserve_heading_path: options.preserve_heading_path,
    preserve_source_ref: options.preserve_source_ref,
    split_tables: options.split_tables,
    split_code_blocks: options.split_code_blocks,
  }
}

///|
/// Return a copy with a new target chunk size.
pub fn RagOptions::with_chunk_size(
  self : RagOptions,
  chunk_size : Int,
) -> RagOptions {
  { ..self, chunk_size, }
}

///|
/// Return a copy with a new chunk overlap.
pub fn RagOptions::with_chunk_overlap(
  self : RagOptions,
  chunk_overlap : Int,
) -> RagOptions {
  { ..self, chunk_overlap, }
}

///|
/// Return a copy that enables or disables heading-path preservation.
pub fn RagOptions::with_preserve_heading_path(
  self : RagOptions,
  preserve_heading_path : Bool,
) -> RagOptions {
  { ..self, preserve_heading_path, }
}

///|
/// Return a copy that enables or disables source-reference preservation.
pub fn RagOptions::with_preserve_source_ref(
  self : RagOptions,
  preserve_source_ref : Bool,
) -> RagOptions {
  { ..self, preserve_source_ref, }
}

///|
/// Return a copy that enables or disables table splitting.
pub fn RagOptions::with_split_tables(
  self : RagOptions,
  split_tables : Bool,
) -> RagOptions {
  { ..self, split_tables, }
}

///|
/// Return a copy that enables or disables code-block splitting.
pub fn RagOptions::with_split_code_blocks(
  self : RagOptions,
  split_code_blocks : Bool,
) -> RagOptions {
  { ..self, split_code_blocks, }
}

///|
/// Return balanced Markdown options with automatic OCR selection.
pub fn ConvertOptions::default() -> ConvertOptions {
  {
    mode: Balanced,
    output_mode: Markdown,
    format_hint: None,
    ocr_mode: Auto,
    ocr_language: None,
    audio_language: None,
    limits: ResourceLimits::default(),
    rag: RagOptions::default(),
  }
}

///|
/// Return a copy with a new product strategy.
pub fn ConvertOptions::with_mode(
  self : ConvertOptions,
  mode : ConvertMode,
) -> ConvertOptions {
  { ..self, mode, }
}

///|
/// Return a copy with a new output representation.
pub fn ConvertOptions::with_output_mode(
  self : ConvertOptions,
  output_mode : OutputMode,
) -> ConvertOptions {
  { ..self, output_mode, }
}

///|
/// Return a copy with an explicit format label or extension.
pub fn ConvertOptions::with_format_hint(
  self : ConvertOptions,
  format_hint : String?,
) -> ConvertOptions {
  { ..self, format_hint, }
}

///|
/// Return a copy with an OCR policy and optional language hint.
pub fn ConvertOptions::with_ocr(
  self : ConvertOptions,
  ocr_mode : OcrMode,
  language? : String? = None,
) -> ConvertOptions {
  { ..self, ocr_mode, ocr_language: language }
}

///|
/// Return a copy with an optional audio-transcription language hint.
pub fn ConvertOptions::with_audio_language(
  self : ConvertOptions,
  audio_language : String?,
) -> ConvertOptions {
  { ..self, audio_language, }
}

///|
/// Return a copy with explicit resource ceilings.
pub fn ConvertOptions::with_limits(
  self : ConvertOptions,
  limits : ResourceLimits,
) -> ConvertOptions {
  { ..self, limits, }
}

///|
/// Return a copy with explicit RAG chunking policy.
pub fn ConvertOptions::with_rag(
  self : ConvertOptions,
  rag : RagOptions,
) -> ConvertOptions {
  { ..self, rag, }
}
