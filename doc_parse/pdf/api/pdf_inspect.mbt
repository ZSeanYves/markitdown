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
/// Structured PDF error info for package-facing audit/debug use.
pub struct PdfErrorInfo {
  kind : PdfErrorKind
  message : String
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
  raw_content_stream_ref_count : Int
  text_block_count : Int
  line_count : Int
  span_count : Int
  char_count : Int
  image_count : Int
  annotation_count : Int
  vector_count : Int
  form_count : Int
  object_count : Int
  reading_order_candidate_count : Int
  artifact_candidate_count : Int
  page_number_candidate_count : Int
  header_footer_candidate_count : Int
  has_text_signal : Bool
  has_any_signal : Bool
  is_low_signal : Bool
  is_empty_signal : Bool
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
  has_any_signal : Bool
  is_low_signal : Bool
  is_empty_signal : Bool
  total_text_block_count : Int
  total_line_count : Int
  total_span_count : Int
  total_char_count : Int
  total_image_count : Int
  total_annotation_count : Int
  total_vector_count : Int
  total_form_count : Int
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
  let lower = message.to_lower()
  let kind = classify_pdf_error_kind(err, lower)
  { kind, message }
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
  let vector_count = page.vectors.length()
  let form_count = page.forms.length()
  let object_count = @model.page_object_count(page)
  let reading_order_candidate_count = page.reading_order_candidates.length()
  let artifact_candidate_count = page.artifact_candidates.length()
  let page_number_candidate_count = @model.page_page_number_candidate_count(
    page,
  )
  let header_footer_candidate_count = @model.page_header_footer_candidate_count(
    page,
  )
  let raw_content_stream_ref_count = page.raw_content_stream_refs.length()

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
      kind: PdfInspectIssueKind::EmptyExtraction,
      severity: PdfInspectSeverity::Error,
      page_index: Some(page.page_index),
      message: "page has no text/image/annotation/vector/form signal",
    })
  } else if is_low_signal {
    issues.push({
      kind: PdfInspectIssueKind::LowSignalExtraction,
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
    raw_content_stream_ref_count,
    text_block_count,
    line_count,
    span_count,
    char_count,
    image_count,
    annotation_count,
    vector_count,
    form_count,
    object_count,
    reading_order_candidate_count,
    artifact_candidate_count,
    page_number_candidate_count,
    header_footer_candidate_count,
    has_text_signal,
    has_any_signal,
    is_low_signal,
    is_empty_signal,
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
  let mut total_vector_count = 0
  let mut total_form_count = 0
  let mut has_text_signal = false
  let mut has_any_signal = false

  for page in doc.pages {
    let info = inspect_pdf_page(page)
    total_text_block_count = total_text_block_count + info.text_block_count
    total_line_count = total_line_count + info.line_count
    total_span_count = total_span_count + info.span_count
    total_char_count = total_char_count + info.char_count
    total_image_count = total_image_count + info.image_count
    total_annotation_count = total_annotation_count + info.annotation_count
    total_vector_count = total_vector_count + info.vector_count
    total_form_count = total_form_count + info.form_count

    if info.has_text_signal {
      has_text_signal = true
    }
    if info.has_any_signal {
      has_any_signal = true
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
    has_any_signal,
    is_low_signal: !has_text_signal && has_any_signal,
    is_empty_signal: !has_any_signal,
    total_text_block_count,
    total_line_count,
    total_span_count,
    total_char_count,
    total_image_count,
    total_annotation_count,
    total_vector_count,
    total_form_count,
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
fn classify_pdf_error_kind(err : PdfError, lower : String) -> PdfErrorKind {
  if lower.contains("encrypted") {
    return PdfErrorKind::Encrypted
  }

  if lower.contains("object stream") {
    return PdfErrorKind::UnsupportedObjectStream
  }

  if lower.contains("filter") {
    return PdfErrorKind::UnsupportedFilter
  }

  if lower.contains("content stream") {
    return PdfErrorKind::MalformedContentStream
  }

  if lower.contains("tounicode") || lower.contains("to unicode") {
    return PdfErrorKind::BadToUnicode
  }

  if lower.contains("font encoding") || lower.contains("missing font") {
    return PdfErrorKind::MissingFontEncoding
  }

  if lower.contains("empty extraction") || lower.contains("empty page") {
    return PdfErrorKind::EmptyExtraction
  }

  if lower.contains("low signal") || lower.contains("low-signal") {
    return PdfErrorKind::LowSignalExtraction
  }

  if lower.contains("malformed") || lower.contains("invalid") {
    return PdfErrorKind::Malformed
  }

  if lower.trim() == "" {
    return PdfErrorKind::Unknown
  }

  match err {
    PdfError::AdapterFailed(msg) => {
      let msg_lower = msg.to_lower()
      if msg_lower.contains("encrypted") {
        PdfErrorKind::Encrypted
      } else if msg_lower.contains("object stream") {
        PdfErrorKind::UnsupportedObjectStream
      } else if msg_lower.contains("filter") {
        PdfErrorKind::UnsupportedFilter
      } else if msg_lower.contains("content stream") {
        PdfErrorKind::MalformedContentStream
      } else if msg_lower.contains("tounicode") ||
        msg_lower.contains("to unicode") {
        PdfErrorKind::BadToUnicode
      } else if msg_lower.contains("font encoding") ||
        msg_lower.contains("missing font") {
        PdfErrorKind::MissingFontEncoding
      } else {
        PdfErrorKind::AdapterFailed
      }
    }
    PdfError::BuildFailed(msg) => {
      let msg_lower = msg.to_lower()
      if msg_lower.contains("page") &&
        (
          msg_lower.contains("length") ||
          msg_lower.contains("mismatch") ||
          msg_lower.contains("failed")
        ) {
        PdfErrorKind::PartialPageFailure
      } else if msg_lower.contains("empty") {
        PdfErrorKind::EmptyExtraction
      } else {
        PdfErrorKind::BuildFailed
      }
    }
    PdfError::Unsupported(msg) => {
      let msg_lower = msg.to_lower()
      if msg_lower.contains("encrypted") {
        PdfErrorKind::Encrypted
      } else if msg_lower.contains("object stream") {
        PdfErrorKind::UnsupportedObjectStream
      } else if msg_lower.contains("filter") {
        PdfErrorKind::UnsupportedFilter
      } else if msg_lower.contains("content stream") {
        PdfErrorKind::MalformedContentStream
      } else if msg_lower.contains("tounicode") ||
        msg_lower.contains("to unicode") {
        PdfErrorKind::BadToUnicode
      } else if msg_lower.contains("font encoding") ||
        msg_lower.contains("missing font") {
        PdfErrorKind::MissingFontEncoding
      } else if msg_lower.contains("low signal") ||
        msg_lower.contains("low-signal") {
        PdfErrorKind::LowSignalExtraction
      } else {
        PdfErrorKind::Unsupported
      }
    }
  }
}
