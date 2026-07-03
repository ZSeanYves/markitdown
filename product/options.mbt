///|
pub(all) enum ConvertMode {
  Fast
  Balanced
  Accurate
  Stream
  Rag
  Debug
} derive(Eq)

///|
pub(all) enum FidelityMode {
  Balanced
  Accurate
} derive(Eq)

///|
pub(all) enum OutputMode {
  Markdown
  Debug
  Rag
} derive(Eq)

///|
pub struct ResourceLimits {
  max_rows : Int
  max_cols : Int
  max_cells : Int
  max_line_chars : Int
}

///|
pub(all) enum PdfCleanupMode {
  Disabled
  Conservative
} derive(Eq)

///|
pub(all) enum PdfTableMode {
  Disabled
  Simple
} derive(Eq)

///|
pub struct ProductOptions {
  mode : ConvertMode
  fidelity_mode : FidelityMode
  output_mode : OutputMode
  stream_requested : Bool
  limits : ResourceLimits
  pdf_cleanup_mode : PdfCleanupMode
  pdf_table_mode : PdfTableMode
  rag_options : @rag.RagOptions
}

///|
pub fn default_resource_limits() -> ResourceLimits {
  { max_rows: 2000, max_cols: 50, max_cells: 100000, max_line_chars: 4000 }
}

///|
pub fn make_resource_limits(
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  max_line_chars? : Int = 4000,
) -> ResourceLimits {
  { max_rows, max_cols, max_cells, max_line_chars }
}

///|
pub fn default_pdf_cleanup_mode() -> PdfCleanupMode {
  PdfCleanupMode::Disabled
}

///|
pub fn default_pdf_table_mode() -> PdfTableMode {
  PdfTableMode::Disabled
}

///|
pub fn default_product_options() -> ProductOptions {
  {
    mode: ConvertMode::Balanced,
    fidelity_mode: FidelityMode::Balanced,
    output_mode: OutputMode::Markdown,
    stream_requested: false,
    limits: default_resource_limits(),
    pdf_cleanup_mode: default_pdf_cleanup_mode(),
    pdf_table_mode: default_pdf_table_mode(),
    rag_options: @rag.default_rag_options(),
  }
}

///|
pub fn make_product_options(
  mode : ConvertMode,
  limits : ResourceLimits,
  fidelity_mode? : FidelityMode = fidelity_mode_for_convert_mode(mode),
  output_mode? : OutputMode = output_mode_for_convert_mode(mode),
  stream_requested? : Bool = mode == ConvertMode::Stream,
  pdf_cleanup_mode? : PdfCleanupMode = default_pdf_cleanup_mode(),
  pdf_table_mode? : PdfTableMode = default_pdf_table_mode(),
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
) -> ProductOptions {
  {
    mode,
    fidelity_mode,
    output_mode,
    stream_requested,
    limits,
    pdf_cleanup_mode,
    pdf_table_mode,
    rag_options,
  }
}

///|
pub fn convert_mode_name(mode : ConvertMode) -> String {
  match mode {
    ConvertMode::Fast => "fast"
    ConvertMode::Balanced => "balanced"
    ConvertMode::Accurate => "accurate"
    ConvertMode::Stream => "stream"
    ConvertMode::Rag => "rag"
    ConvertMode::Debug => "debug"
  }
}

///|
pub fn fidelity_mode_for_convert_mode(mode : ConvertMode) -> FidelityMode {
  match mode {
    ConvertMode::Accurate => FidelityMode::Accurate
    _ => FidelityMode::Balanced
  }
}

///|
pub fn output_mode_for_convert_mode(mode : ConvertMode) -> OutputMode {
  match mode {
    ConvertMode::Debug => OutputMode::Debug
    ConvertMode::Rag => OutputMode::Rag
    _ => OutputMode::Markdown
  }
}

///|
pub fn convert_mode_from_modes(
  fidelity_mode : FidelityMode,
  output_mode : OutputMode,
) -> ConvertMode {
  match output_mode {
    OutputMode::Debug => ConvertMode::Debug
    OutputMode::Rag => ConvertMode::Rag
    OutputMode::Markdown =>
      match fidelity_mode {
        FidelityMode::Accurate => ConvertMode::Accurate
        FidelityMode::Balanced => ConvertMode::Balanced
      }
  }
}

///|
pub fn fidelity_mode_name(mode : FidelityMode) -> String {
  match mode {
    FidelityMode::Balanced => "balanced"
    FidelityMode::Accurate => "accurate"
  }
}

///|
pub fn output_mode_name(mode : OutputMode) -> String {
  match mode {
    OutputMode::Markdown => "markdown"
    OutputMode::Debug => "debug"
    OutputMode::Rag => "rag"
  }
}

///|
pub fn pdf_cleanup_mode_name(mode : PdfCleanupMode) -> String {
  match mode {
    PdfCleanupMode::Disabled => "none"
    PdfCleanupMode::Conservative => "conservative"
  }
}

///|
pub fn pdf_table_mode_name(mode : PdfTableMode) -> String {
  match mode {
    PdfTableMode::Disabled => "none"
    PdfTableMode::Simple => "simple"
  }
}

///|
pub fn debug_mode(mode : ConvertMode) -> Bool {
  mode == ConvertMode::Debug
}

///|
pub fn debug_output_mode(mode : OutputMode) -> Bool {
  mode == OutputMode::Debug
}

///|
pub fn pdf_cleanup_enabled(options : ProductOptions) -> Bool {
  options.pdf_cleanup_mode != PdfCleanupMode::Disabled
}
