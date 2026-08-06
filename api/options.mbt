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
