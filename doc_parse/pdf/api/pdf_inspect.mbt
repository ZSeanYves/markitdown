///|
/// PDF error kind classifier.
pub enum PdfErrorKind {
  AdapterFailed
  BuildFailed
  Unsupported
  Encrypted
  Malformed
  UnsupportedObjectStream
  UnsupportedFilter
  MalformedContentStream
  MissingFontEncoding
  BadToUnicode
  PartialPageFailure
  EmptyExtraction
  LowSignalExtraction
  Unknown
}

///|
/// PDF error classifier mapping status.
pub enum PdfErrorMappingKind {
  DirectVariant
  TypedIssue
  BestEffortMessage
}

///|
/// Structured PDF error info for package-facing audit/debug use.
pub struct PdfErrorInfo {
  kind : PdfErrorKind
  message : String
  mapping : PdfErrorMappingKind
}

///|
/// PDF inspect issue severity.
pub enum PdfInspectSeverity {
  Warning
  Error
}

///|
/// PDF inspect issue source.
pub enum PdfInspectIssueSource {
  Raw
  Model
}

///|
/// PDF inspect issue kind.
pub enum PdfInspectIssueKind {
  PartialPageFailure
  UnsupportedObjectStream
  AnnotationParseWarning
  ImageParseWarning
  EmptyPage
  LowSignalPage
  EmptyExtraction
  LowSignalExtraction
  EncryptedDocument
}

///|
/// PDF inspect issue.
pub struct PdfInspectIssue {
  kind : PdfInspectIssueKind
  severity : PdfInspectSeverity
  source : PdfInspectIssueSource
  page_index : Int?
  object_ref : String?
  source_ref : @model.PdfSourceRef?
  message : String
}

///|
/// PDF page inspect info.
pub struct PdfPageInspectInfo {
  page_index : Int
  page_label : String?
  rotation : Int
  media_box : @model.PdfRect
  crop_box : @model.PdfRect?
  effective_width : Double
  effective_height : Double
  raw_content_stream_ref_count : Int
  text_block_count : Int
  line_count : Int
  span_count : Int
  char_count : Int
  image_count : Int
  annotation_count : Int
  link_annotation_count : Int
  vector_count : Int
  form_count : Int
  object_count : Int
  source_ref_count : Int
  reading_order_candidate_count : Int
  artifact_candidate_count : Int
  page_number_candidate_count : Int
  header_footer_candidate_count : Int
  has_text_signal : Bool
  has_image_signal : Bool
  has_any_signal : Bool
  text_signal_level : String
  image_only : Bool
  ocr_recommended : Bool
  is_low_signal : Bool
  is_empty_signal : Bool
  raw_issue_count : Int
  model_issue_count : Int
  issue_count : Int
  issues : Array[PdfInspectIssue]
}

///|
/// PDF document inspect report.
pub struct PdfDocumentInspectReport {
  version : String
  page_count : Int
  successful_page_count : Int
  failed_page_count : Int
  metadata : @model.PdfDocumentMetadata
  outline_count : Int
  encrypted : Bool
  has_xref_stream : Bool
  has_object_stream : Bool
  has_text_signal : Bool
  has_image_signal : Bool
  has_embedded_text : Bool
  has_page_images : Bool
  has_annotation_signal : Bool
  has_any_signal : Bool
  text_signal_level : String
  native_text_char_count : Int
  page_image_count : Int
  image_only : Bool
  ocr_recommended : Bool
  is_low_signal : Bool
  is_empty_signal : Bool
  page_failure_count : Int
  text_page_count : Int
  empty_page_count : Int
  low_signal_page_count : Int
  total_text_block_count : Int
  total_line_count : Int
  total_span_count : Int
  total_char_count : Int
  total_image_count : Int
  total_annotation_count : Int
  total_link_annotation_count : Int
  total_vector_count : Int
  total_form_count : Int
  total_source_ref_count : Int
  unsupported_feature_count : Int
  raw_issue_count : Int
  model_issue_count : Int
  issue_count : Int
  warning_count : Int
  error_count : Int
  pages : Array[PdfPageInspectInfo]
  issues : Array[PdfInspectIssue]
}

///|
/// Classify a public PDF error into a structured kind/message pair.
pub fn classify_pdf_error(err : PdfError) -> PdfErrorInfo {
  let message = err.to_string()
  let detail = pdf_error_detail(err)
  let lower = detail.to_lower()
  let (kind, mapping) = classify_pdf_error_kind(err, lower)
  { kind, message, mapping }
}

///|
/// Classify a structured inspect issue into a PDF error kind when the issue has
/// a direct error-kind analogue.
pub fn classify_pdf_inspect_issue(issue : PdfInspectIssue) -> PdfErrorInfo? {
  match pdf_error_kind_from_inspect_issue(issue) {
    Some(kind) =>
      Some({
        kind,
        message: issue.message,
        mapping: PdfErrorMappingKind::TypedIssue,
      })
    None => None
  }
}

///|
/// Prefer typed inspect issues when they provide a stronger classification than
/// a top-level error variant alone.
pub fn classify_pdf_error_with_issues(
  err : PdfError,
  issues : Array[PdfInspectIssue],
) -> PdfErrorInfo {
  for issue in issues {
    match classify_pdf_inspect_issue(issue) {
      Some(info) =>
        return {
          kind: info.kind,
          message: err.to_string(),
          mapping: PdfErrorMappingKind::TypedIssue,
        }
      None => ()
    }
  }
  classify_pdf_error(err)
}

///|
/// Inspect a single PDF page model.
pub fn inspect_pdf_page(page : @model.PdfPageModel) -> PdfPageInspectInfo {
  inspect_pdf_page_core(None, page)
}

///|
/// Inspect a full PDF document model.
pub fn inspect_pdf_document(
  doc : @model.PdfDocumentModel,
) -> PdfDocumentInspectReport {
  inspect_pdf_document_core(None, doc)
}

///|
/// Structured report entrypoint for path-based consumers.
pub async fn extract_document_inspect_report(
  path : String,
  config : PdfConfig,
) -> Result[PdfDocumentInspectReport, PdfError] {
  match extract_document_debug_bundle(path, config) {
    Ok(bundle) => Ok(inspect_pdf_document_core(Some(bundle.raw), bundle.doc))
    Err(err) => Err(err)
  }
}

///|
fn inspect_pdf_document_core(
  raw : @raw.RawPdfDocumentExtract?,
  doc : @model.PdfDocumentModel,
) -> PdfDocumentInspectReport {
  let pages = Array::new()
  let issues = Array::new()

  let mut total_text_block_count = 0
  let mut total_line_count = 0
  let mut total_span_count = 0
  let mut total_char_count = 0
  let mut total_image_count = 0
  let mut total_annotation_count = 0
  let mut total_link_annotation_count = 0
  let mut total_vector_count = 0
  let mut total_form_count = 0
  let mut total_source_ref_count = 0
  let mut has_text_signal = false
  let mut has_image_signal = false
  let mut has_annotation_signal = false
  let mut has_any_signal = false
  let mut text_page_count = 0
  let mut empty_page_count = 0
  let mut low_signal_page_count = 0
  let mut raw_issue_count = 0
  let mut model_issue_count = 0

  for i = 0; i < doc.pages.length(); i = i + 1 {
    let page = doc.pages[i]
    let raw_page = match raw {
      Some(raw_doc) =>
        if i < raw_doc.pages.length() {
          Some(raw_doc.pages[i])
        } else {
          None
        }
      _ => None
    }
    let info = inspect_pdf_page_core(raw_page, page)
    total_text_block_count = total_text_block_count + info.text_block_count
    total_line_count = total_line_count + info.line_count
    total_span_count = total_span_count + info.span_count
    total_char_count = total_char_count + info.char_count
    total_image_count = total_image_count + info.image_count
    total_annotation_count = total_annotation_count + info.annotation_count
    total_link_annotation_count = total_link_annotation_count +
      info.link_annotation_count
    total_vector_count = total_vector_count + info.vector_count
    total_form_count = total_form_count + info.form_count
    total_source_ref_count = total_source_ref_count + info.source_ref_count

    if info.has_text_signal {
      has_text_signal = true
      text_page_count = text_page_count + 1
    }
    if info.image_count > 0 {
      has_image_signal = true
    }
    if info.annotation_count > 0 {
      has_annotation_signal = true
    }
    if info.has_any_signal {
      has_any_signal = true
    }
    if info.is_empty_signal {
      empty_page_count = empty_page_count + 1
    }
    if info.is_low_signal {
      low_signal_page_count = low_signal_page_count + 1
    }

    for issue in info.issues {
      match issue.source {
        PdfInspectIssueSource::Raw => raw_issue_count = raw_issue_count + 1
        PdfInspectIssueSource::Model =>
          model_issue_count = model_issue_count + 1
      }
      issues.push(issue)
    }

    pages.push(info)
  }

  match raw {
    Some(raw_doc) =>
      for issue in collect_document_raw_inspect_issues(raw_doc) {
        raw_issue_count = raw_issue_count + 1
        issues.push(issue)
      }
    None =>
      if doc.is_encrypted {
        let issue = make_model_issue(
          PdfInspectIssueKind::EncryptedDocument,
          PdfInspectSeverity::Warning,
          None,
          None,
          None,
          "document is encrypted",
        )
        model_issue_count = model_issue_count + 1
        issues.push(issue)
      }
  }

  let page_count = doc.pages.length()
  let successful_page_count = page_count
  let failed_page_count = if doc.page_count > page_count {
    doc.page_count - page_count
  } else {
    0
  }

  for
    issue in collect_document_model_issues(
      doc, has_text_signal, has_any_signal, failed_page_count,
    ) {
    model_issue_count = model_issue_count + 1
    issues.push(issue)
  }

  let mut warning_count = 0
  let mut error_count = 0
  let mut unsupported_feature_count = 0
  for issue in issues {
    match issue.severity {
      PdfInspectSeverity::Warning => warning_count = warning_count + 1
      PdfInspectSeverity::Error => error_count = error_count + 1
    }
    match issue.kind {
      PdfInspectIssueKind::UnsupportedObjectStream =>
        unsupported_feature_count = unsupported_feature_count + 1
      _ => ()
    }
  }

  let text_signal_level = classify_document_text_signal_level(
    total_char_count, has_image_signal, low_signal_page_count,
  )
  let has_embedded_text = has_text_signal
  let has_page_images = has_image_signal
  let image_only = !has_text_signal && has_image_signal
  let ocr_recommended = image_only ||
    (text_signal_level == "low" && has_page_images)

  {
    version: doc.version,
    page_count: doc.page_count,
    successful_page_count,
    failed_page_count,
    metadata: doc.metadata,
    outline_count: doc.outlines.length(),
    encrypted: doc.is_encrypted,
    has_xref_stream: doc.has_xref_stream,
    has_object_stream: doc.has_object_stream,
    has_text_signal,
    has_image_signal,
    has_embedded_text,
    has_page_images,
    has_annotation_signal,
    has_any_signal,
    text_signal_level,
    native_text_char_count: total_char_count,
    page_image_count: total_image_count,
    image_only,
    ocr_recommended,
    is_low_signal: !has_text_signal && has_any_signal,
    is_empty_signal: !has_any_signal,
    page_failure_count: failed_page_count,
    text_page_count,
    empty_page_count,
    low_signal_page_count,
    total_text_block_count,
    total_line_count,
    total_span_count,
    total_char_count,
    total_image_count,
    total_annotation_count,
    total_link_annotation_count,
    total_vector_count,
    total_form_count,
    total_source_ref_count,
    unsupported_feature_count,
    raw_issue_count,
    model_issue_count,
    issue_count: issues.length(),
    warning_count,
    error_count,
    pages,
    issues,
  }
}

///|
fn classify_pdf_error_kind(
  err : PdfError,
  lower : String,
) -> (PdfErrorKind, PdfErrorMappingKind) {
  match classify_best_effort_pdf_error_kind(lower) {
    Some(kind) => (kind, PdfErrorMappingKind::BestEffortMessage)
    None =>
      match err {
        PdfError::AdapterFailed(_) =>
          (PdfErrorKind::AdapterFailed, PdfErrorMappingKind::DirectVariant)
        PdfError::BuildFailed(_) =>
          (PdfErrorKind::BuildFailed, PdfErrorMappingKind::DirectVariant)
        PdfError::Unsupported(_) =>
          (PdfErrorKind::Unsupported, PdfErrorMappingKind::DirectVariant)
      }
  }
}

///|
fn classify_best_effort_pdf_error_kind(lower : String) -> PdfErrorKind? {
  if lower.trim() == "" {
    return Some(PdfErrorKind::Unknown)
  }

  if lower.contains("encrypted") {
    return Some(PdfErrorKind::Encrypted)
  }

  if lower.contains("object stream") &&
    (
      lower.contains("unsupported") ||
      lower.contains("not supported") ||
      lower.contains("cannot")
    ) {
    return Some(PdfErrorKind::UnsupportedObjectStream)
  }

  if (
      lower.contains("unsupported filter") ||
      lower.contains("filter not supported")
    ) &&
    lower.contains("filter") {
    return Some(PdfErrorKind::UnsupportedFilter)
  }

  if lower.contains("malformed content stream") ||
    lower.contains("invalid content stream") {
    return Some(PdfErrorKind::MalformedContentStream)
  }

  if lower.contains("bad tounicode") ||
    lower.contains("invalid tounicode") ||
    lower.contains("bad to unicode") ||
    lower.contains("invalid to unicode") {
    return Some(PdfErrorKind::BadToUnicode)
  }

  if lower.contains("missing font encoding") ||
    lower.contains("font encoding missing") {
    return Some(PdfErrorKind::MissingFontEncoding)
  }

  if lower.contains("raw pages length !=") ||
    (
      lower.contains("page") &&
      lower.contains("failed") &&
      lower.contains("extract")
    ) {
    return Some(PdfErrorKind::PartialPageFailure)
  }

  if lower.contains("empty extraction") || lower.contains("empty page") {
    return Some(PdfErrorKind::EmptyExtraction)
  }

  if lower.contains("low signal extraction") ||
    lower.contains("low-signal extraction") {
    return Some(PdfErrorKind::LowSignalExtraction)
  }

  if lower.contains("malformed pdf") ||
    lower.contains("invalid pdf") ||
    lower.contains("malformed xref") ||
    lower.contains("invalid xref") {
    return Some(PdfErrorKind::Malformed)
  }

  None
}

///|
fn pdf_error_detail(err : PdfError) -> String {
  match err {
    PdfError::AdapterFailed(msg) => msg
    PdfError::BuildFailed(msg) => msg
    PdfError::Unsupported(msg) => msg
  }
}

///|
fn inspect_pdf_page_core(
  raw_page : @raw.RawPdfPageExtract?,
  page : @model.PdfPageModel,
) -> PdfPageInspectInfo {
  let text_block_count = @model.page_text_block_count(page)
  let line_count = @model.page_line_count(page)
  let span_count = @model.page_span_count(page)
  let char_count = @model.page_char_count(page)
  let image_count = page.images.length()
  let annotation_count = page.annotations.length()
  let link_annotation_count = page_link_annotation_count(page)
  let vector_count = page.vectors.length()
  let form_count = page.forms.length()
  let object_count = @model.page_object_count(page)
  let source_ref_count = page_source_ref_count(page)
  let reading_order_candidate_count = page.reading_order_candidates.length()
  let artifact_candidate_count = page.artifact_candidates.length()
  let page_number_candidate_count = @model.page_page_number_candidate_count(
    page,
  )
  let header_footer_candidate_count = @model.page_header_footer_candidate_count(
    page,
  )
  let raw_content_stream_ref_count = page.raw_content_stream_refs.length()
  let effective_box = page_effective_box(page)

  let has_text_signal = text_block_count > 0 ||
    line_count > 0 ||
    span_count > 0 ||
    char_count > 0
  let has_image_signal = image_count > 0
  let has_any_signal = has_text_signal ||
    has_image_signal ||
    annotation_count > 0 ||
    vector_count > 0 ||
    form_count > 0
  let text_signal_level = classify_page_text_signal_level(
    char_count, has_image_signal, has_any_signal,
  )
  let image_only = !has_text_signal && has_image_signal
  let ocr_recommended = has_image_signal &&
    (text_signal_level == "none" || text_signal_level == "low")
  let is_empty_signal = !has_any_signal
  let is_low_signal = !has_text_signal && has_any_signal

  let issues = Array::new()
  let mut raw_issue_count = 0
  let mut model_issue_count = 0

  match raw_page {
    Some(raw_info) =>
      for issue in collect_page_raw_inspect_issues(raw_info) {
        raw_issue_count = raw_issue_count + 1
        issues.push(issue)
      }
    None => ()
  }

  for
    issue in collect_page_model_issues(
      page.page_index,
      has_text_signal,
      has_any_signal,
    ) {
    model_issue_count = model_issue_count + 1
    issues.push(issue)
  }

  {
    page_index: page.page_index,
    page_label: page.page_label,
    rotation: page.rotation,
    media_box: page.boxes.media_box,
    crop_box: page.boxes.crop_box,
    effective_width: @model.rect_width(effective_box),
    effective_height: @model.rect_height(effective_box),
    raw_content_stream_ref_count,
    text_block_count,
    line_count,
    span_count,
    char_count,
    image_count,
    annotation_count,
    link_annotation_count,
    vector_count,
    form_count,
    object_count,
    source_ref_count,
    reading_order_candidate_count,
    artifact_candidate_count,
    page_number_candidate_count,
    header_footer_candidate_count,
    has_text_signal,
    has_image_signal,
    has_any_signal,
    text_signal_level,
    image_only,
    ocr_recommended,
    is_low_signal,
    is_empty_signal,
    raw_issue_count,
    model_issue_count,
    issue_count: issues.length(),
    issues,
  }
}

///|
fn make_model_issue(
  kind : PdfInspectIssueKind,
  severity : PdfInspectSeverity,
  page_index : Int?,
  object_ref : String?,
  source_ref : @model.PdfSourceRef?,
  message : String,
) -> PdfInspectIssue {
  {
    kind,
    severity,
    source: PdfInspectIssueSource::Model,
    page_index,
    object_ref,
    source_ref,
    message,
  }
}

///|
fn collect_page_model_issues(
  page_index : Int,
  has_text_signal : Bool,
  has_any_signal : Bool,
) -> Array[PdfInspectIssue] {
  let issues = Array::new()
  if !has_any_signal {
    issues.push(
      make_model_issue(
        PdfInspectIssueKind::EmptyPage,
        PdfInspectSeverity::Error,
        Some(page_index),
        None,
        None,
        "page has no text/image/annotation/vector/form signal",
      ),
    )
  } else if !has_text_signal {
    issues.push(
      make_model_issue(
        PdfInspectIssueKind::LowSignalPage,
        PdfInspectSeverity::Warning,
        Some(page_index),
        None,
        None,
        "page has no text signal but retains other structural signal",
      ),
    )
  }
  issues
}

///|
fn collect_document_model_issues(
  doc : @model.PdfDocumentModel,
  has_text_signal : Bool,
  has_any_signal : Bool,
  failed_page_count : Int,
) -> Array[PdfInspectIssue] {
  let issues = Array::new()
  if doc.pages.is_empty() {
    issues.push(
      make_model_issue(
        PdfInspectIssueKind::EmptyExtraction,
        PdfInspectSeverity::Error,
        None,
        None,
        None,
        "document has no pages",
      ),
    )
  } else if failed_page_count > 0 {
    issues.push(
      make_model_issue(
        PdfInspectIssueKind::PartialPageFailure,
        PdfInspectSeverity::Error,
        None,
        None,
        None,
        "document model exposes fewer pages than declared page_count",
      ),
    )
  }

  if !has_text_signal && has_any_signal {
    issues.push(
      make_model_issue(
        PdfInspectIssueKind::LowSignalExtraction,
        PdfInspectSeverity::Warning,
        None,
        None,
        None,
        "document has structural signal but no text signal",
      ),
    )
  }
  issues
}

///|
/// Report-only text-signal summary:
/// - `none`: no native text chars recovered
/// - `low`: some native text exists, but page-image signal suggests partial /
///   mixed extraction where OCR might still help
/// - `normal`: native text signal is the dominant path
fn classify_document_text_signal_level(
  total_char_count : Int,
  has_image_signal : Bool,
  low_signal_page_count : Int,
) -> String {
  if total_char_count <= 0 {
    return "none"
  }

  if has_image_signal && (low_signal_page_count > 0 || total_char_count < 96) {
    return "low"
  }

  "normal"
}

///|
/// Page-level hint used for inspect/debug only.
fn classify_page_text_signal_level(
  char_count : Int,
  has_image_signal : Bool,
  has_any_signal : Bool,
) -> String {
  if char_count <= 0 {
    if has_any_signal {
      return "none"
    }
    return "none"
  }

  if has_image_signal && char_count < 24 {
    return "low"
  }

  "normal"
}

///|
fn map_raw_issue_severity(
  severity : @raw.PdfRawIssueSeverity,
) -> PdfInspectSeverity {
  match severity {
    @raw.PdfRawIssueSeverity::Warning => PdfInspectSeverity::Warning
    @raw.PdfRawIssueSeverity::Error => PdfInspectSeverity::Error
  }
}

///|
fn map_raw_issue_kind(kind : @raw.PdfRawIssueKind) -> PdfInspectIssueKind {
  match kind {
    @raw.PdfRawIssueKind::EncryptedDocument =>
      PdfInspectIssueKind::EncryptedDocument
    @raw.PdfRawIssueKind::UnsupportedObjectStream =>
      PdfInspectIssueKind::UnsupportedObjectStream
    @raw.PdfRawIssueKind::AnnotationParseWarning =>
      PdfInspectIssueKind::AnnotationParseWarning
    @raw.PdfRawIssueKind::ImageParseWarning =>
      PdfInspectIssueKind::ImageParseWarning
  }
}

///|
fn model_source_ref_from_raw_opt(
  source_ref : @raw.RawSourceRef?,
) -> @model.PdfSourceRef? {
  match source_ref {
    Some(_ref) =>
      Some({
        page_index: _ref.page_index,
        source_stream_index: _ref.source_stream_index,
        source_op_index: _ref.source_op_index,
        text_object_id: _ref.text_object_id,
        content_order_index: _ref.content_order_index,
        source_object_ref: raw_pdf_ref_to_string(_ref.source_object_ref),
      })
    None => None
  }
}

///|
fn inspect_issue_from_raw_issue(issue : @raw.PdfRawIssue) -> PdfInspectIssue {
  {
    kind: map_raw_issue_kind(issue.kind),
    severity: map_raw_issue_severity(issue.severity),
    source: PdfInspectIssueSource::Raw,
    page_index: issue.page_index,
    object_ref: raw_pdf_ref_to_string(issue.object_ref),
    source_ref: model_source_ref_from_raw_opt(issue.source_ref),
    message: issue.message,
  }
}

///|
fn collect_page_raw_inspect_issues(
  raw_page : @raw.RawPdfPageExtract,
) -> Array[PdfInspectIssue] {
  let issues = Array::new()
  for issue in raw_page.issues {
    issues.push(inspect_issue_from_raw_issue(issue))
  }
  issues
}

///|
fn collect_document_raw_inspect_issues(
  raw_doc : @raw.RawPdfDocumentExtract,
) -> Array[PdfInspectIssue] {
  let issues = Array::new()
  for issue in raw_doc.issues {
    issues.push(inspect_issue_from_raw_issue(issue))
  }
  issues
}

///|
fn pdf_error_kind_from_inspect_issue(issue : PdfInspectIssue) -> PdfErrorKind? {
  match issue.kind {
    PdfInspectIssueKind::EncryptedDocument => Some(PdfErrorKind::Encrypted)
    PdfInspectIssueKind::UnsupportedObjectStream =>
      Some(PdfErrorKind::UnsupportedObjectStream)
    PdfInspectIssueKind::PartialPageFailure =>
      Some(PdfErrorKind::PartialPageFailure)
    PdfInspectIssueKind::EmptyPage => Some(PdfErrorKind::EmptyExtraction)
    PdfInspectIssueKind::LowSignalPage =>
      Some(PdfErrorKind::LowSignalExtraction)
    PdfInspectIssueKind::EmptyExtraction => Some(PdfErrorKind::EmptyExtraction)
    PdfInspectIssueKind::LowSignalExtraction =>
      Some(PdfErrorKind::LowSignalExtraction)
    PdfInspectIssueKind::AnnotationParseWarning => None
    PdfInspectIssueKind::ImageParseWarning => None
  }
}

///|
fn is_link_annotation(annotation : @model.PdfAnnotationObject) -> Bool {
  annotation.subtype.to_lower() == "link" ||
  annotation.uri is Some(_) ||
  annotation.dest is Some(_) ||
  annotation.target_page is Some(_)
}

///|
fn page_link_annotation_count(page : @model.PdfPageModel) -> Int {
  let mut total = 0
  for annotation in page.annotations {
    if is_link_annotation(annotation) {
      total = total + 1
    }
  }
  total
}

///|
fn page_source_ref_count(page : @model.PdfPageModel) -> Int {
  let mut total = 0
  for block in page.text_blocks {
    total = total + @model.block_source_ref_count(block)
  }
  for image in page.images {
    total = total + image.source_refs.length()
  }
  for vector in page.vectors {
    total = total + vector.source_refs.length()
  }
  for annotation in page.annotations {
    total = total + annotation.source_refs.length()
  }
  for form in page.forms {
    total = total + form.source_refs.length()
  }
  total
}

///|
fn page_effective_box(page : @model.PdfPageModel) -> @model.PdfRect {
  match page.boxes.crop_box {
    Some(box) => box
    None => page.boxes.media_box
  }
}
