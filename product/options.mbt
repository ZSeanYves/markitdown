///|
pub(all) enum ConvertMode {
  Balanced
  Accurate
  Stream
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
pub(all) enum ExecutionProfile {
  Standard
  MediumAdaptive
  LargeAdaptive
} derive(Eq)

///|
pub(all) enum LoweringProfile {
  Canonical
  AccurateSemantic
  StreamCanonical
  LargeAdaptive
} derive(Eq)

///|
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
} derive(Eq)

///|
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
pub struct AccurateFeatureProfile {
  features : Array[AccurateFeature]
}

///|
pub fn empty_accurate_feature_profile() -> AccurateFeatureProfile {
  { features: [] }
}

///|
pub fn make_accurate_feature_profile(
  features : Array[AccurateFeature],
) -> AccurateFeatureProfile {
  { features, }
}

///|
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
pub fn accurate_feature_profile_names(
  profile : AccurateFeatureProfile,
) -> Array[String] {
  profile.features.map(accurate_feature_name)
}

///|
pub fn accurate_feature_enabled(
  profile : AccurateFeatureProfile,
  feature : AccurateFeature,
) -> Bool {
  profile.features.contains(feature)
}

///|
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
  output_mode? : OutputMode = OutputMode::Markdown,
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
    ConvertMode::Balanced => "balanced"
    ConvertMode::Accurate => "accurate"
    ConvertMode::Stream => "stream"
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
  ignore(mode)
  OutputMode::Markdown
}

///|
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
pub fn execution_profile_name(profile : ExecutionProfile) -> String {
  match profile {
    ExecutionProfile::Standard => "standard"
    ExecutionProfile::MediumAdaptive => "medium_adaptive"
    ExecutionProfile::LargeAdaptive => "large_adaptive"
  }
}

///|
pub fn lowering_profile_name(profile : LoweringProfile) -> String {
  match profile {
    LoweringProfile::Canonical => "canonical"
    LoweringProfile::AccurateSemantic => "accurate_semantic"
    LoweringProfile::StreamCanonical => "stream_canonical"
    LoweringProfile::LargeAdaptive => "large_adaptive"
  }
}

///|
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
pub fn debug_output_mode(mode : OutputMode) -> Bool {
  mode == OutputMode::Debug
}

///|
pub fn pdf_cleanup_enabled(options : ProductOptions) -> Bool {
  options.pdf_cleanup_mode != PdfCleanupMode::Disabled
}
