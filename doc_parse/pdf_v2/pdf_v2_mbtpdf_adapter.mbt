///|
fn pdf_v2_adapter_source_ref(
  page_index : Int?,
  object_id : String?,
  stream_index : Int?,
  op_index : Int?,
  content_order_index : Int?,
  kind : PdfV2SourceKind,
) -> PdfV2SourceRef {
  { page_index, object_id, stream_index, op_index, content_order_index, kind }
}

///|
fn pdf_v2_adapter_object_ref(object_number : Int) -> String {
  "\{object_number} 0 R"
}

///|
fn pdf_v2_adapter_stream_object_ref(stream : @pdf.PdfObject) -> String? {
  match stream {
    Indirect(i) => Some(pdf_v2_adapter_object_ref(i))
    _ => None
  }
}

///|
fn pdf_v2_adapter_warning(
  kind : PdfV2WarningKind,
  severity : PdfV2Severity,
  message : String,
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2Warning {
  pdf_v2_warning(kind, severity, message, [source_ref], reason_tags)
}

///|
fn pdf_v2_adapter_risk(
  kind : PdfV2RiskKind,
  severity : PdfV2Severity,
  message : String,
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2Risk {
  { kind, severity, message, source_refs: [source_ref], reason_tags }
}

///|
fn pdf_v2_adapter_error_result(
  kind : PdfV2WarningKind,
  risk_kind : PdfV2RiskKind,
  message : String,
  reason_tags : Array[String],
) -> PdfV2CoreOpenResult {
  let source_ref = pdf_v2_document_source_ref()
  let warning = pdf_v2_adapter_warning(
    kind,
    PdfV2Severity::Error,
    message,
    source_ref,
    reason_tags,
  )
  let risk = pdf_v2_adapter_risk(
    risk_kind,
    PdfV2Severity::Error,
    message,
    source_ref,
    reason_tags,
  )
  PdfV2CoreOpenResult::CoreOpenErr([warning], [risk], message)
}

///|
fn pdf_v2_adapter_read_error_result(message : String) -> PdfV2CoreOpenResult {
  let reason_tags = if message.contains("Encryption") ||
    message.contains("encryption") {
    ["mbtpdf_reader", "encrypted_or_restricted", "fail_closed", "no_fallback"]
  } else {
    ["mbtpdf_reader", "malformed", "fail_closed", "no_fallback"]
  }
  if reason_tags.contains("encrypted_or_restricted") {
    pdf_v2_adapter_error_result(
      PdfV2WarningKind::EncryptedOrRestricted,
      PdfV2RiskKind::EncryptedOrRestricted,
      "PDF v2 mbtpdf reader rejected encrypted or restricted input: " + message,
      reason_tags,
    )
  } else {
    pdf_v2_adapter_error_result(
      PdfV2WarningKind::MalformedObject,
      PdfV2RiskKind::Malformed,
      "PDF v2 mbtpdf reader failed closed: " + message,
      reason_tags,
    )
  }
}

///|
fn pdf_v2_adapter_page_limit(
  total_pages : Int,
  options : PdfV2CoreOpenOptions,
) -> Int {
  match options.max_pages {
    Some(limit) if limit <= 0 => 0
    Some(limit) if limit < total_pages => limit
    _ => total_pages
  }
}

///|
fn pdf_v2_adapter_push_capped_event(
  events : Array[PdfV2CoreEvent],
  event : PdfV2CoreEvent,
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
) -> Bool {
  match options.max_events {
    Some(limit) if events.length() >= limit => {
      event_cap_hit.val = true
      false
    }
    _ => {
      events.push(event)
      true
    }
  }
}

///|
fn pdf_v2_adapter_bbox(pdf : @pdf.Pdf, object : @pdf.PdfObject) -> PdfV2BBox? {
  try {
    let (x0, y0, x1, y1) = pdf.parse_rectangle(object)
    Some({ x0, y0, x1, y1 })
  } catch {
    _ => None
  }
}

///|
fn pdf_v2_adapter_user_unit(pdf : @pdf.Pdf, page : @pdfpage.Page) -> Double? {
  match page.rest.lookup_immediate("/UserUnit") {
    Some(value) => Some(pdf.getnum(value)) catch { _ => None }
    None => None
  }
}

///|
fn pdf_v2_adapter_resources_present(resources : @pdf.PdfObject) -> Bool {
  match resources {
    Dictionary(entries) => entries.length() > 0
    Null => false
    _ => true
  }
}

///|
fn pdf_v2_adapter_core_event(
  kind : PdfV2CoreEventKind,
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2CoreEvent {
  {
    kind,
    page_index: source_ref.page_index,
    text: None,
    bbox: None,
    object_ref: source_ref.object_id,
    source_ref,
    reason_tags,
    warnings: [],
  }
}

///|
fn pdf_v2_adapter_page_ref(
  page_index : Int,
  page_object : Int?,
) -> PdfV2SourceRef {
  pdf_v2_adapter_source_ref(
    Some(page_index),
    page_object.map(pdf_v2_adapter_object_ref),
    None,
    None,
    None,
    PdfV2SourceKind::Page,
  )
}

///|
fn pdf_v2_adapter_page_fact(
  pdf : @pdf.Pdf,
  page_index : Int,
  page : @pdfpage.Page,
  page_ref : PdfV2SourceRef,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> PdfV2CorePageFact {
  let media_box = match pdf_v2_adapter_bbox(pdf, page.mediabox) {
    Some(box) => box
    None => {
      let message = "PDF v2 adapter could not parse page MediaBox"
      warnings.push(
        pdf_v2_adapter_warning(
          PdfV2WarningKind::MalformedObject,
          PdfV2Severity::Warning,
          message,
          page_ref,
          ["page_fact", "mediabox", "malformed"],
        ),
      )
      risks.push(
        pdf_v2_adapter_risk(
          PdfV2RiskKind::Malformed,
          PdfV2Severity::Warning,
          message,
          page_ref,
          ["page_fact", "mediabox", "malformed"],
        ),
      )
      pdf_v2_empty_bbox()
    }
  }
  let crop_box = match page.cropbox {
    Some(crop) => pdf_v2_adapter_bbox(pdf, crop)
    None => None
  }
  {
    page_index,
    page_label: None,
    media_box,
    crop_box,
    rotate: page.rotate.to_int(),
    user_unit: pdf_v2_adapter_user_unit(pdf, page),
    resources_present: pdf_v2_adapter_resources_present(page.resources),
    source_ref: page_ref,
  }
}

///|
fn pdf_v2_adapter_add_cap_warning(
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  message : String,
  reason_tags : Array[String],
) -> Unit {
  let source_ref = pdf_v2_document_source_ref()
  warnings.push(
    pdf_v2_adapter_warning(
      PdfV2WarningKind::PerformanceCap,
      PdfV2Severity::Warning,
      message,
      source_ref,
      reason_tags,
    ),
  )
  risks.push(
    pdf_v2_adapter_risk(
      PdfV2RiskKind::PerformanceCapReached,
      PdfV2Severity::Warning,
      message,
      source_ref,
      reason_tags,
    ),
  )
}

///|
fn pdf_v2_adapter_add_encryption_warning(
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Unit {
  let source_ref = pdf_v2_document_source_ref()
  let message = "PDF v2 adapter opened encrypted or restricted PDF metadata"
  warnings.push(
    pdf_v2_adapter_warning(
      PdfV2WarningKind::EncryptedOrRestricted,
      PdfV2Severity::Warning,
      message,
      source_ref,
      ["mbtpdf_reader", "encrypted_or_restricted", "no_fallback"],
    ),
  )
  risks.push(
    pdf_v2_adapter_risk(
      PdfV2RiskKind::EncryptedOrRestricted,
      PdfV2Severity::Warning,
      message,
      source_ref,
      ["mbtpdf_reader", "encrypted_or_restricted", "no_fallback"],
    ),
  )
}

///|
fn pdf_v2_adapter_add_stream_events(
  page_index : Int,
  page : @pdfpage.Page,
  events : Array[PdfV2CoreEvent],
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
  content_order : Ref[Int],
) -> Unit {
  for stream_index = 0
      stream_index < page.content.length()
      stream_index = stream_index + 1 {
    let stream = page.content[stream_index]
    let source_ref = pdf_v2_adapter_source_ref(
      Some(page_index),
      pdf_v2_adapter_stream_object_ref(stream),
      Some(stream_index),
      None,
      Some(content_order.val),
      PdfV2SourceKind::ContentStream,
    )
    content_order.val = content_order.val + 1
    let _ = pdf_v2_adapter_push_capped_event(
      events,
      pdf_v2_adapter_core_event(
        PdfV2CoreEventKind::ContentStreamBegin,
        source_ref,
        ["content_stream", "begin", "mbtpdf"],
      ),
      options,
      event_cap_hit,
    )
  }
}

///|
fn pdf_v2_adapter_add_stream_end_events(
  page_index : Int,
  page : @pdfpage.Page,
  events : Array[PdfV2CoreEvent],
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
  content_order : Ref[Int],
) -> Unit {
  for stream_index = 0
      stream_index < page.content.length()
      stream_index = stream_index + 1 {
    let stream = page.content[stream_index]
    let source_ref = pdf_v2_adapter_source_ref(
      Some(page_index),
      pdf_v2_adapter_stream_object_ref(stream),
      Some(stream_index),
      None,
      Some(content_order.val),
      PdfV2SourceKind::ContentStream,
    )
    content_order.val = content_order.val + 1
    let _ = pdf_v2_adapter_push_capped_event(
      events,
      pdf_v2_adapter_core_event(
        PdfV2CoreEventKind::ContentStreamEnd,
        source_ref,
        ["content_stream", "end", "mbtpdf"],
      ),
      options,
      event_cap_hit,
    )
  }
}

///|
fn pdf_v2_adapter_add_located_ops(
  pdf : @pdf.Pdf,
  page_index : Int,
  page : @pdfpage.Page,
  events : Array[PdfV2CoreEvent],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  options : PdfV2CoreOpenOptions,
  event_cap_hit : Ref[Bool],
  content_order : Ref[Int],
) -> Unit {
  if page.content.length() == 0 {
    return
  }
  let located_result : Result[Array[@pdfops.LocatedOp], Error] = try
    @pdfops.Op::parse_operators_with_source(pdf, page.resources, page.content)
    |> Ok
  catch {
    err => Err(err)
  }
  match located_result {
    Ok(located) =>
      for item in located {
        let object_ref = item.source_object_ref.map(pdf_v2_adapter_object_ref)
        let source_ref = pdf_v2_adapter_source_ref(
          Some(page_index),
          object_ref,
          Some(item.source_stream_index),
          Some(item.source_op_index),
          Some(content_order.val),
          PdfV2SourceKind::Unknown,
        )
        content_order.val = content_order.val + 1
        let event : PdfV2CoreEvent = {
          kind: PdfV2CoreEventKind::Unknown,
          page_index: Some(page_index),
          text: None,
          bbox: None,
          object_ref,
          source_ref,
          reason_tags: ["raw_op", "unknown_mapping", "mbtpdf_located_op"],
          warnings: [],
        }
        let _ = pdf_v2_adapter_push_capped_event(
          events, event, options, event_cap_hit,
        )
      }
    Err(err) => {
      let source_ref = pdf_v2_adapter_source_ref(
        Some(page_index),
        None,
        None,
        None,
        Some(content_order.val),
        PdfV2SourceKind::Malformed,
      )
      content_order.val = content_order.val + 1
      let message = "PDF v2 adapter could not parse page content operators: " +
        err.to_string()
      let warning = pdf_v2_adapter_warning(
        PdfV2WarningKind::MalformedObject,
        PdfV2Severity::Warning,
        message,
        source_ref,
        ["content_ops", "malformed", "mbtpdf"],
      )
      warnings.push(warning)
      risks.push(
        pdf_v2_adapter_risk(
          PdfV2RiskKind::Malformed,
          PdfV2Severity::Warning,
          message,
          source_ref,
          ["content_ops", "malformed", "mbtpdf"],
        ),
      )
      let event : PdfV2CoreEvent = {
        kind: PdfV2CoreEventKind::Malformed,
        page_index: Some(page_index),
        text: None,
        bbox: None,
        object_ref: None,
        source_ref,
        reason_tags: ["content_ops", "malformed", "mbtpdf"],
        warnings: [warning],
      }
      let _ = pdf_v2_adapter_push_capped_event(
        events, event, options, event_cap_hit,
      )
    }
  }
}

///|
fn pdf_v2_adapter_core_from_pdf(
  pdf : @pdf.Pdf,
  reader : @pdfread.PdfRead,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreOpenResult {
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  match reader.what_encryption(pdf) {
    Some(_) if options.fail_on_encrypted => {
      let source_ref = pdf_v2_document_source_ref()
      let message = "PDF v2 adapter fail_on_encrypted rejected encrypted PDF"
      let warning = pdf_v2_adapter_warning(
        PdfV2WarningKind::EncryptedOrRestricted,
        PdfV2Severity::Error,
        message,
        source_ref,
        ["mbtpdf_reader", "encrypted_or_restricted", "fail_closed"],
      )
      let risk = pdf_v2_adapter_risk(
        PdfV2RiskKind::EncryptedOrRestricted,
        PdfV2Severity::Error,
        message,
        source_ref,
        ["mbtpdf_reader", "encrypted_or_restricted", "fail_closed"],
      )
      return PdfV2CoreOpenResult::CoreOpenErr([warning], [risk], message)
    }
    Some(_) => pdf_v2_adapter_add_encryption_warning(warnings, risks)
    None => ()
  }

  let page_doc = @pdfpage.PdfPageDoc::new(pdf)
  let pages_result : Result[Array[@pdfpage.Page], Error] = try
    page_doc.pages_of_pagetree() |> Ok
  catch {
    err => Err(err)
  }
  let pages = match pages_result {
    Ok(items) => items
    Err(err) => {
      let message = "PDF v2 adapter failed to read page tree: " +
        err.to_string()
      return pdf_v2_adapter_error_result(
        PdfV2WarningKind::MalformedObject,
        PdfV2RiskKind::ObjectGraphIssue,
        message,
        ["page_tree", "malformed", "fail_closed", "no_fallback"],
      )
    }
  }

  let page_limit = pdf_v2_adapter_page_limit(pages.length(), options)
  if page_limit < pages.length() {
    pdf_v2_adapter_add_cap_warning(
      warnings,
      risks,
      "PDF v2 adapter stopped at max_pages=\{page_limit} of \{pages.length()} pages",
      ["max_pages", "performance_cap", "no_fallback"],
    )
  }

  let page_facts : Array[PdfV2CorePageFact] = []
  let events : Array[PdfV2CoreEvent] = []
  let event_cap_hit : Ref[Bool] = { val: false }
  let content_order : Ref[Int] = { val: 0 }
  for page_index = 0; page_index < page_limit; page_index = page_index + 1 {
    let page = pages[page_index]
    let page_object = page_doc.page_object_number(page_index + 1) catch {
      _ => None
    }
    let page_ref = pdf_v2_adapter_page_ref(page_index, page_object)
    page_facts.push(
      pdf_v2_adapter_page_fact(pdf, page_index, page, page_ref, warnings, risks),
    )
    let page_begin_ref = pdf_v2_adapter_source_ref(
      page_ref.page_index,
      page_ref.object_id,
      page_ref.stream_index,
      page_ref.op_index,
      Some(content_order.val),
      page_ref.kind,
    )
    content_order.val = content_order.val + 1
    let _ = pdf_v2_adapter_push_capped_event(
      events,
      pdf_v2_adapter_core_event(PdfV2CoreEventKind::PageBegin, page_begin_ref, [
        "page", "begin", "mbtpdf",
      ]),
      options,
      event_cap_hit,
    )
    pdf_v2_adapter_add_stream_events(
      page_index, page, events, options, event_cap_hit, content_order,
    )
    pdf_v2_adapter_add_located_ops(
      pdf, page_index, page, events, warnings, risks, options, event_cap_hit, content_order,
    )
    pdf_v2_adapter_add_stream_end_events(
      page_index, page, events, options, event_cap_hit, content_order,
    )
    let page_end_ref = pdf_v2_adapter_source_ref(
      page_ref.page_index,
      page_ref.object_id,
      page_ref.stream_index,
      page_ref.op_index,
      Some(content_order.val),
      page_ref.kind,
    )
    content_order.val = content_order.val + 1
    let _ = pdf_v2_adapter_push_capped_event(
      events,
      pdf_v2_adapter_core_event(PdfV2CoreEventKind::PageEnd, page_end_ref, [
        "page", "end", "mbtpdf",
      ]),
      options,
      event_cap_hit,
    )
  }

  if event_cap_hit.val {
    let max_events = match options.max_events {
      Some(limit) => limit
      None => events.length()
    }
    pdf_v2_adapter_add_cap_warning(
      warnings,
      risks,
      "PDF v2 adapter stopped at max_events=\{max_events}",
      ["max_events", "performance_cap", "no_fallback"],
    )
  }

  let core : PdfV2CoreDocument = {
    page_count: page_facts.length(),
    capabilities: pdf_v2_core_supported_capabilities(),
    page_facts,
    warnings,
    risks,
    source_summary: pdf_v2_source_summary(
      events.length(),
      page_facts.length(),
      warnings.length(),
      risks.length(),
    ),
  }
  PdfV2CoreOpenResult::CoreOpenOk(core, events)
}

///|
fn pdf_v2_open_core_document_from_bytes(
  bytes : Bytes,
  source : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreOpenResult {
  let input = @pdfio.Input::of_bytes(bytes.to_array(), source~)
  let reader = @pdfread.PdfRead::new(error_on_malformed=true, logger=_ => ())
  let pdf_result : Result[@pdf.Pdf, Error] = try
    @pdfe.with_silenced_logs(fn() raise {
      reader.pdf_of_input(None, None, input)
    })
    |> Ok
  catch {
    err => Err(err)
  }
  match pdf_result {
    Ok(pdf) => pdf_v2_adapter_core_from_pdf(pdf, reader, options)
    Err(err) => pdf_v2_adapter_read_error_result(err.to_string())
  }
}

///|
pub fn pdf_v2_open_core_document_from_path(
  path : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreOpenResult {
  if !@fs.path_exists(path) {
    return pdf_v2_adapter_error_result(
      PdfV2WarningKind::MalformedObject,
      PdfV2RiskKind::ObjectGraphIssue,
      "PDF v2 adapter input path does not exist: " + path,
      ["path", "missing", "fail_closed", "no_fallback"],
    )
  }
  let bytes_result : Result[Bytes, Error] = try
    @fs.read_file_to_bytes(path) |> Ok
  catch {
    err => Err(err)
  }
  match bytes_result {
    Ok(bytes) => pdf_v2_open_core_document_from_bytes(bytes, path, options)
    Err(err) =>
      pdf_v2_adapter_error_result(
        PdfV2WarningKind::MalformedObject,
        PdfV2RiskKind::ObjectGraphIssue,
        "PDF v2 adapter could not read input path: " + err.to_string(),
        ["path", "read_error", "fail_closed", "no_fallback"],
      )
  }
}

///|
pub fn pdf_v2_open_source_document_from_path(
  path : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2SourceOpenResult {
  match pdf_v2_open_core_document_from_path(path, options) {
    CoreOpenOk(core, events) =>
      PdfV2SourceOpenResult::SourceOpenOk(
        pdf_v2_source_document_from_core(core, events),
      )
    CoreOpenErr(warnings, risks, message) =>
      PdfV2SourceOpenResult::SourceOpenErr(warnings, risks, message)
  }
}
