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
    AccurateFeature::PdfPageAppendix => "pdf_page_appendix"
    AccurateFeature::PdfWindowedAssembly => "pdf_windowed_assembly"
    AccurateFeature::DocxTextboxInline => "docx_textbox_inline"
    AccurateFeature::DocxAlternateContentRestore =>
      "docx_alternate_content_restore"
    AccurateFeature::DocxNotesAppendix => "docx_notes_appendix"
    AccurateFeature::XlsxHiddenSheets => "xlsx_hidden_sheets"
    AccurateFeature::XlsxHiddenRows => "xlsx_hidden_rows"
    AccurateFeature::XlsxMergedSpans => "xlsx_merged_spans"
    AccurateFeature::PptxReadingOrder => "pptx_reading_order"
    AccurateFeature::PptxGroupSummary => "pptx_group_summary"
    AccurateFeature::PptxHiddenSlideSemantics => "pptx_hidden_slide_semantics"
    AccurateFeature::PptxNotesAppendix => "pptx_notes_appendix"
    AccurateFeature::OdtRichNotes => "odt_rich_notes"
    AccurateFeature::OdtCommentsAppendix => "odt_comments_appendix"
    AccurateFeature::OdsHiddenSheets => "ods_hidden_sheets"
    AccurateFeature::OdsHiddenRows => "ods_hidden_rows"
    AccurateFeature::OdsCoveredCellSpans => "ods_covered_cell_spans"
    AccurateFeature::OdpNotesAppendix => "odp_notes_appendix"
    AccurateFeature::OdpSlideSummary => "odp_slide_summary"
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
    @input.DetectedFormat::Pdf =>
      [AccurateFeature::PdfPageAppendix, AccurateFeature::PdfWindowedAssembly]
    @input.DetectedFormat::Docx =>
      [
        AccurateFeature::DocxTextboxInline,
        AccurateFeature::DocxAlternateContentRestore,
        AccurateFeature::DocxNotesAppendix,
      ]
    @input.DetectedFormat::Xlsx =>
      [
        AccurateFeature::XlsxHiddenSheets,
        AccurateFeature::XlsxHiddenRows,
        AccurateFeature::XlsxMergedSpans,
      ]
    @input.DetectedFormat::Pptx =>
      [
        AccurateFeature::PptxReadingOrder,
        AccurateFeature::PptxGroupSummary,
        AccurateFeature::PptxHiddenSlideSemantics,
        AccurateFeature::PptxNotesAppendix,
      ]
    @input.DetectedFormat::Odt =>
      [AccurateFeature::OdtRichNotes, AccurateFeature::OdtCommentsAppendix]
    @input.DetectedFormat::Ods =>
      [
        AccurateFeature::OdsHiddenSheets,
        AccurateFeature::OdsHiddenRows,
        AccurateFeature::OdsCoveredCellSpans,
      ]
    @input.DetectedFormat::Odp =>
      [AccurateFeature::OdpNotesAppendix, AccurateFeature::OdpSlideSummary]
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
  { max_rows: 2000, max_cols: 50, max_cells: 100000, max_line_chars: 4000 }
}

///|
/// Build explicit product resource ceilings.
pub fn make_resource_limits(
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  max_line_chars? : Int = 4000,
) -> ResourceLimits {
  { max_rows, max_cols, max_cells, max_line_chars }
}

///|
/// Return baseline product defaults for the balanced Markdown path.
pub fn default_product_options() -> ProductOptions {
  {
    mode: ConvertMode::Balanced,
    fidelity_mode: FidelityMode::Balanced,
    output_mode: OutputMode::Markdown,
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
  output_mode? : OutputMode = OutputMode::Markdown,
  stream_requested? : Bool = mode == ConvertMode::Stream,
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
) -> ProductOptions {
  { mode, fidelity_mode, output_mode, stream_requested, limits, rag_options }
}

///|
/// Stable diagnostics/provenance label for a convert mode.
pub fn convert_mode_name(mode : ConvertMode) -> String {
  match mode {
    ConvertMode::Balanced => "balanced"
    ConvertMode::Accurate => "accurate"
    ConvertMode::Stream => "stream"
  }
}

///|
/// Return the default fidelity target implied by a convert mode.
pub fn fidelity_mode_for_convert_mode(mode : ConvertMode) -> FidelityMode {
  match mode {
    ConvertMode::Accurate => FidelityMode::Accurate
    _ => FidelityMode::Balanced
  }
}

///|
/// Return the default renderer-facing output mode implied by a convert mode.
pub fn output_mode_for_convert_mode(mode : ConvertMode) -> OutputMode {
  ignore(mode)
  OutputMode::Markdown
}

///|
/// Derive the effective strategy mode from fidelity plus explicit stream
/// request.
pub fn convert_mode_from_modes(
  fidelity_mode : FidelityMode,
  stream_requested : Bool,
) -> ConvertMode {
  if stream_requested {
    ConvertMode::Stream
  } else {
    match fidelity_mode {
      FidelityMode::Accurate => ConvertMode::Accurate
      FidelityMode::Balanced => ConvertMode::Balanced
    }
  }
}

///|
/// Stable diagnostics/provenance label for one fidelity mode.
pub fn fidelity_mode_name(mode : FidelityMode) -> String {
  match mode {
    FidelityMode::Balanced => "balanced"
    FidelityMode::Accurate => "accurate"
  }
}

///|
/// Stable diagnostics/provenance label for one output mode.
pub fn output_mode_name(mode : OutputMode) -> String {
  match mode {
    OutputMode::Markdown => "markdown"
    OutputMode::Debug => "debug"
    OutputMode::Rag => "rag"
  }
}

///|
/// Stable diagnostics/provenance label for one execution profile.
pub fn execution_profile_name(profile : ExecutionProfile) -> String {
  match profile {
    ExecutionProfile::Standard => "standard"
    ExecutionProfile::MediumAdaptive => "medium_adaptive"
    ExecutionProfile::LargeAdaptive => "large_adaptive"
  }
}

///|
/// Stable diagnostics/provenance label for one lowering profile.
pub fn lowering_profile_name(profile : LoweringProfile) -> String {
  match profile {
    LoweringProfile::Canonical => "canonical"
    LoweringProfile::AccurateSemantic => "accurate_semantic"
    LoweringProfile::StreamCanonical => "stream_canonical"
    LoweringProfile::LargeAdaptive => "large_adaptive"
  }
}

///|
/// Stable diagnostics/provenance label for one render profile.
pub fn render_profile_name(profile : RenderProfile) -> String {
  match profile {
    RenderProfile::DefaultMarkdown => "default_markdown"
    RenderProfile::SectionFlushMarkdown => "section_flush_markdown"
    RenderProfile::SparseTableMarkdown => "sparse_table_markdown"
    RenderProfile::NotesAppendixFirst => "notes_appendix_first"
    RenderProfile::AssetManifestFirst => "asset_manifest_first"
    RenderProfile::PageWindowMarkdown => "page_window_markdown"
    RenderProfile::RecordBatchMarkdown => "record_batch_markdown"
  }
}

///|
/// Return whether the current output mode is the debug JSON view.
pub fn debug_output_mode(mode : OutputMode) -> Bool {
  mode == OutputMode::Debug
}
