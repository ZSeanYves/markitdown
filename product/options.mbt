///|
/// Top-level convert strategy modes exposed by the product.
pub(all) enum ConvertMode {
  Balanced
  Accurate
  Stream
} derive(Eq)

///|
/// Fidelity target requested by the caller after mode normalization.
pub(all) enum FidelityMode {
  Balanced
  Accurate
} derive(Eq)

///|
/// Public output views selected before the render stage.
pub(all) enum OutputMode {
  Markdown
  Debug
  Rag
} derive(Eq)

///|
/// Coarse execution profiles selected by route planning for differently sized
/// inputs.
pub(all) enum ExecutionProfile {
  Standard
  MediumAdaptive
  LargeAdaptive
} derive(Eq)

///|
/// Lowering profiles that tune how aggressively parsers and pipeline preserve
/// semantics.
pub(all) enum LoweringProfile {
  Canonical
  AccurateSemantic
  StreamCanonical
  LargeAdaptive
} derive(Eq)

///|
/// Render profiles that shape Markdown or JSON emission details.
pub(all) enum RenderProfile {
  DefaultMarkdown
  SectionFlushMarkdown
  SparseTableMarkdown
  NotesAppendixFirst
  AssetManifestFirst
  PageWindowMarkdown
  RecordBatchMarkdown
} derive(Eq)

///|
/// Quantitative probe signal kinds collected during route planning.
pub(all) enum ProbeSignalKind {
  CharCount
  LineCount
  BlockCount
  ListItemCount
  NodeCount
  MaxDepth
  RowCount
  ColCount
  CellCount
  CellEstimate
  OutputCount
  AttachmentCount
  AssetCount
  EntryCount
  PageCount
  SlideCount
  SheetCount
  ScalarCount
  ObjectCount
  ArrayCount
  HiddenRowCount
  HiddenSheetCount
  CoveredCellCount
  NoteCount
  CommentCount
  ScannedPageCount
  NativeTextPageCount
} derive(Eq)

///|
/// Accurate-mode features that can be enabled selectively per format.
pub(all) enum AccurateFeature {
  PdfPageAppendix
  PdfWindowedAssembly
  DocxTextboxInline
  DocxAlternateContentRestore
  DocxNotesAppendix
  XlsxHiddenSheets
  XlsxHiddenRows
  XlsxMergedSpans
  PptxReadingOrder
  PptxGroupSummary
  PptxHiddenSlideSemantics
  PptxNotesAppendix
  OdtRichNotes
  OdtCommentsAppendix
  OdsHiddenSheets
  OdsHiddenRows
  OdsCoveredCellSpans
  OdpNotesAppendix
  OdpSlideSummary
} derive(Eq)

///|
/// Accurate-mode features that are intentionally opt-in on a per-format basis.
///
/// Keeping them in an explicit profile lets convert, parser, pipeline, render,
/// and provenance stay aligned on the exact semantic upgrades in effect.
pub struct AccurateFeatureProfile {
  features : Array[AccurateFeature]
}

///|
/// Return an empty accurate-feature profile.
pub fn empty_accurate_feature_profile() -> AccurateFeatureProfile {
  { features: [] }
}

///|
/// Wrap a set of accurate features into a profile value.
pub fn make_accurate_feature_profile(
  features : Array[AccurateFeature],
) -> AccurateFeatureProfile {
  { features, }
}

///|
/// Return the stable diagnostics/provenance name for one accurate feature.
pub fn accurate_feature_name(feature : AccurateFeature) -> String {
  match feature {
    PdfPageAppendix => "pdf_page_appendix"
    PdfWindowedAssembly => "pdf_windowed_assembly"
    DocxTextboxInline => "docx_textbox_inline"
    DocxAlternateContentRestore => "docx_alternate_content_restore"
    DocxNotesAppendix => "docx_notes_appendix"
    XlsxHiddenSheets => "xlsx_hidden_sheets"
    XlsxHiddenRows => "xlsx_hidden_rows"
    XlsxMergedSpans => "xlsx_merged_spans"
    PptxReadingOrder => "pptx_reading_order"
    PptxGroupSummary => "pptx_group_summary"
    PptxHiddenSlideSemantics => "pptx_hidden_slide_semantics"
    PptxNotesAppendix => "pptx_notes_appendix"
    OdtRichNotes => "odt_rich_notes"
    OdtCommentsAppendix => "odt_comments_appendix"
    OdsHiddenSheets => "ods_hidden_sheets"
    OdsHiddenRows => "ods_hidden_rows"
    OdsCoveredCellSpans => "ods_covered_cell_spans"
    OdpNotesAppendix => "odp_notes_appendix"
    OdpSlideSummary => "odp_slide_summary"
  }
}

///|
/// Return all enabled feature names in stable string form.
pub fn accurate_feature_profile_names(
  profile : AccurateFeatureProfile,
) -> Array[String] {
  profile.features.map(accurate_feature_name)
}

///|
/// Return whether `feature` is enabled in `profile`.
pub fn accurate_feature_enabled(
  profile : AccurateFeatureProfile,
  feature : AccurateFeature,
) -> Bool {
  profile.features.contains(feature)
}

///|
/// Return the accurate-mode features currently defined for the detected format.
pub fn accurate_features_for_detected_format(
  format : @input.DetectedFormat,
) -> Array[AccurateFeature] {
  match format {
    Pdf => [PdfPageAppendix, PdfWindowedAssembly]
    Docx => [DocxTextboxInline, DocxAlternateContentRestore, DocxNotesAppendix]
    Xlsx => [XlsxHiddenSheets, XlsxHiddenRows, XlsxMergedSpans]
    Pptx =>
      [
        PptxReadingOrder,
        PptxGroupSummary,
        PptxHiddenSlideSemantics,
        PptxNotesAppendix,
      ]
    Odt => [OdtRichNotes, OdtCommentsAppendix]
    Ods => [OdsHiddenSheets, OdsHiddenRows, OdsCoveredCellSpans]
    Odp => [OdpNotesAppendix, OdpSlideSummary]
    _ => []
  }
}

///|
/// Coarse resource ceilings shared by probing, parsing, and lowering.
///
/// These are deliberately product-wide rather than format-local so route
/// planning and parser execution make decisions from the same limits.
pub struct ResourceLimits {
  max_rows : Int
  max_cols : Int
  max_cells : Int
  max_line_chars : Int
  max_input_bytes : Int64
  max_asset_bytes : Int64
  max_total_asset_bytes : Int64
  external_command_timeout_ms : Int
  max_external_output_bytes : Int64
}

///|
/// Normalized product options shared across routing, parsing, pipeline, and
/// rendering.
///
/// `mode` captures the primary strategy, while the remaining fields keep the
/// derived fidelity/output view plus resource and RAG policy stable across
/// layers.
pub struct ProductOptions {
  mode : ConvertMode
  fidelity_mode : FidelityMode
  output_mode : OutputMode
  stream_requested : Bool
  limits : ResourceLimits
  rag_options : @rag.RagOptions
}

///|
/// Return the default resource ceilings for the canonical product path.
pub fn default_resource_limits() -> ResourceLimits {
  {
    max_rows: 2000,
    max_cols: 50,
    max_cells: 100000,
    max_line_chars: 4000,
    max_input_bytes: 512L * 1024L * 1024L,
    max_asset_bytes: 32L * 1024L * 1024L,
    max_total_asset_bytes: 128L * 1024L * 1024L,
    external_command_timeout_ms: 300000,
    max_external_output_bytes: 8L * 1024L * 1024L,
  }
}

///|
/// Build explicit product resource ceilings.
pub fn make_resource_limits(
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  max_line_chars? : Int = 4000,
  max_input_bytes? : Int64 = 512L * 1024L * 1024L,
  max_asset_bytes? : Int64 = 32L * 1024L * 1024L,
  max_total_asset_bytes? : Int64 = 128L * 1024L * 1024L,
  external_command_timeout_ms? : Int = 300000,
  max_external_output_bytes? : Int64 = 8L * 1024L * 1024L,
) -> ResourceLimits {
  {
    max_rows,
    max_cols,
    max_cells,
    max_line_chars,
    max_input_bytes,
    max_asset_bytes,
    max_total_asset_bytes,
    external_command_timeout_ms,
    max_external_output_bytes,
  }
}

///|
/// Return baseline product defaults for the balanced Markdown path.
pub fn default_product_options() -> ProductOptions {
  {
    mode: Balanced,
    fidelity_mode: Balanced,
    output_mode: Markdown,
    stream_requested: false,
    limits: default_resource_limits(),
    rag_options: @rag.default_rag_options(),
  }
}

///|
/// Compose product options that can be shared by route planning, parsing,
/// pipeline passes, and renderers.
pub fn make_product_options(
  mode : ConvertMode,
  limits : ResourceLimits,
  fidelity_mode? : FidelityMode = fidelity_mode_for_convert_mode(mode),
  output_mode? : OutputMode = Markdown,
  stream_requested? : Bool = mode == Stream,
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
) -> ProductOptions {
  { mode, fidelity_mode, output_mode, stream_requested, limits, rag_options }
}

///|
/// Stable diagnostics/provenance label for a convert mode.
pub fn convert_mode_name(mode : ConvertMode) -> String {
  match mode {
    Balanced => "balanced"
    Accurate => "accurate"
    Stream => "stream"
  }
}

///|
/// Return the default fidelity target implied by a convert mode.
pub fn fidelity_mode_for_convert_mode(mode : ConvertMode) -> FidelityMode {
  match mode {
    Accurate => Accurate
    _ => Balanced
  }
}

///|
/// Return the default renderer-facing output mode implied by a convert mode.
pub fn output_mode_for_convert_mode(mode : ConvertMode) -> OutputMode {
  ignore(mode)
  Markdown
}

///|
/// Derive the effective strategy mode from fidelity plus explicit stream
/// request.
pub fn convert_mode_from_modes(
  fidelity_mode : FidelityMode,
  stream_requested : Bool,
) -> ConvertMode {
  if stream_requested {
    Stream
  } else {
    match fidelity_mode {
      Accurate => Accurate
      Balanced => Balanced
    }
  }
}

///|
/// Stable diagnostics/provenance label for one fidelity mode.
pub fn fidelity_mode_name(mode : FidelityMode) -> String {
  match mode {
    Balanced => "balanced"
    Accurate => "accurate"
  }
}

///|
/// Stable diagnostics/provenance label for one output mode.
pub fn output_mode_name(mode : OutputMode) -> String {
  match mode {
    Markdown => "markdown"
    Debug => "debug"
    Rag => "rag"
  }
}

///|
/// Stable diagnostics/provenance label for one execution profile.
pub fn execution_profile_name(profile : ExecutionProfile) -> String {
  match profile {
    Standard => "standard"
    MediumAdaptive => "medium_adaptive"
    LargeAdaptive => "large_adaptive"
  }
}

///|
/// Stable diagnostics/provenance label for one lowering profile.
pub fn lowering_profile_name(profile : LoweringProfile) -> String {
  match profile {
    Canonical => "canonical"
    AccurateSemantic => "accurate_semantic"
    StreamCanonical => "stream_canonical"
    LargeAdaptive => "large_adaptive"
  }
}

///|
/// Stable diagnostics/provenance label for one render profile.
pub fn render_profile_name(profile : RenderProfile) -> String {
  match profile {
    DefaultMarkdown => "default_markdown"
    SectionFlushMarkdown => "section_flush_markdown"
    SparseTableMarkdown => "sparse_table_markdown"
    NotesAppendixFirst => "notes_appendix_first"
    AssetManifestFirst => "asset_manifest_first"
    PageWindowMarkdown => "page_window_markdown"
    RecordBatchMarkdown => "record_batch_markdown"
  }
}

///|
/// Return whether the current output mode is the debug JSON view.
pub fn debug_output_mode(mode : OutputMode) -> Bool {
  mode == Debug
}
