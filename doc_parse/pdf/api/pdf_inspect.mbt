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
/// PDF inspect issue kind.
pub enum PdfInspectIssueKind {
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
  page_index : Int?
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
  has_any_signal : Bool
  is_low_signal : Bool
  is_empty_signal : Bool
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
  has_annotation_signal : Bool
  has_any_signal : Bool
  is_low_signal : Bool
  is_empty_signal : Bool
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
/// Inspect a single PDF page model.
pub fn inspect_pdf_page(page : @model.PdfPageModel) -> PdfPageInspectInfo {
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
  let has_any_signal = has_text_signal ||
    image_count > 0 ||
    annotation_count > 0 ||
    vector_count > 0 ||
    form_count > 0
  let is_empty_signal = !has_any_signal
  let is_low_signal = !has_text_signal && has_any_signal

  let issues = Array::new()
  if is_empty_signal {
    issues.push({
      kind: PdfInspectIssueKind::EmptyPage,
      severity: PdfInspectSeverity::Error,
      page_index: Some(page.page_index),
      message: "page has no text/image/annotation/vector/form signal",
    })
  } else if is_low_signal {
    issues.push({
      kind: PdfInspectIssueKind::LowSignalPage,
      severity: PdfInspectSeverity::Warning,
      page_index: Some(page.page_index),
      message: "page has no text signal but retains other structural signal",
    })
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
    has_any_signal,
    is_low_signal,
    is_empty_signal,
    issue_count: issues.length(),
    issues,
  }
}

///|
/// Inspect a full PDF document model.
pub fn inspect_pdf_document(
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

  for page in doc.pages {
    let info = inspect_pdf_page(page)
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
      issues.push(issue)
    }

    pages.push(info)
  }

  if doc.is_encrypted {
    issues.push({
      kind: PdfInspectIssueKind::EncryptedDocument,
      severity: PdfInspectSeverity::Warning,
      page_index: None,
      message: "document is encrypted",
    })
  }

  if doc.pages.is_empty() {
    issues.push({
      kind: PdfInspectIssueKind::EmptyExtraction,
      severity: PdfInspectSeverity::Error,
      page_index: None,
      message: "document has no pages",
    })
  } else if !has_text_signal && has_any_signal {
    issues.push({
      kind: PdfInspectIssueKind::LowSignalExtraction,
      severity: PdfInspectSeverity::Warning,
      page_index: None,
      message: "document has structural signal but no text signal",
    })
  }

  let mut warning_count = 0
  let mut error_count = 0
  for issue in issues {
    match issue.severity {
      PdfInspectSeverity::Warning => warning_count = warning_count + 1
      PdfInspectSeverity::Error => error_count = error_count + 1
    }
  }

  let page_count = doc.pages.length()
  let successful_page_count = page_count
  let failed_page_count = if doc.page_count > page_count {
    doc.page_count - page_count
  } else {
    0
  }

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
    has_annotation_signal,
    has_any_signal,
    is_low_signal: !has_text_signal && has_any_signal,
    is_empty_signal: !has_any_signal,
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
    issue_count: issues.length(),
    warning_count,
    error_count,
    pages,
    issues,
  }
}

///|
/// Structured report entrypoint for path-based consumers.
pub async fn extract_document_inspect_report(
  path : String,
  config : PdfConfig,
) -> Result[PdfDocumentInspectReport, PdfError] {
  match extract_document_model(path, config) {
    Ok(doc) => Ok(inspect_pdf_document(doc))
    Err(err) => Err(err)
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
