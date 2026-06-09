///|
priv struct PdfV2RawObject {
  object_ref : String
  object_number : Int
  generation : Int
  body : String
  dictionary : String?
  stream_data : String?
}

///|
priv enum PdfV2ContentToken {
  Name(String)
  Number(Double)
  LiteralString(String, Bytes)
  HexString(String, Bytes)
  Array(Array[PdfV2ContentToken])
  Operator(String)
}

///|
priv struct PdfV2ContentParser {
  chars : Array[Char]
  mut pos : Int
}

///|
priv struct PdfV2TextState {
  mut in_text_object : Bool
  mut text_object_id : Int
  mut font_name : String?
  mut font_size : Double?
  mut x : Double
  mut y : Double
  mut matrix : Array[Double]
  mut content_order_index : Int
}

///|
priv struct PdfV2PageBuild {
  core_page : PdfV2CorePage
  resources_dictionary : String?
}

///|
priv struct PdfV2CMapCodeSpace {
  code_len : Int
  low : Int
  high : Int
}

///|
priv struct PdfV2CMapEntry {
  code_len : Int
  code : Int
  unicode : String
}

///|
priv struct PdfV2ToUnicodeMap {
  code_spaces : Array[PdfV2CMapCodeSpace]
  entries : Array[PdfV2CMapEntry]
  malformed_count : Int
  unsupported_count : Int
  bfchar_count : Int
  bfrange_count : Int
}

///|
priv struct PdfV2ToUnicodeTextDecode {
  text : String
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
  decode_confidence : Double
}

///|
priv struct PdfV2CMapDecodeResult {
  text : String
  unmapped_count : Int
}

///|
fn open_pdf_core_v2_minimal_reader(
  bytes : Bytes,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreDocument {
  let text = pdf_v2_bytes_to_probe_text(bytes)
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let version = parse_pdf_v2_version(text)
  if version == None {
    let diagnostic = pdf_v2_malformed_header_warning()
    warnings.push(diagnostic)
    risks.push(pdf_v2_malformed_header_risk())
  }
  if !text.contains("xref") {
    warnings.push(warn_xref_table_malformed(None))
  }
  if !text.contains("trailer") {
    warnings.push(pdf_v2_trailer_missing_warning())
  }

  let raw_objects = scan_pdf_v2_indirect_objects(text)
  if version != None && raw_objects.is_empty() {
    warnings.push(pdf_v2_no_indirect_objects_warning())
    risks.push(
      risk_low_signal_document("PDF contained no readable indirect objects"),
    )
  }
  let objects = core_objects_from_raw(raw_objects)
  let page_builds = build_pdf_v2_pages(raw_objects, warnings, risks)
  let pages : Array[PdfV2CorePage] = []
  for page in page_builds {
    pages.push(page.core_page)
  }
  if version != None && pages.is_empty() {
    warnings.push(pdf_v2_no_pages_warning())
    risks.push(risk_low_signal_document("PDF contained no readable page tree"))
  }
  let content_streams : Array[PdfV2CoreContentStream] = []
  let text_events : Array[PdfV2CoreTextEvent] = []
  for page_build in page_builds {
    read_page_content_streams(
      page_build, raw_objects, content_streams, text_events, warnings, risks,
    )
  }
  let all_warnings = warnings +
    content_stream_warnings(content_streams) +
    text_event_warnings(text_events)
  let all_risks = risks +
    content_stream_risks(content_streams) +
    text_event_risks(text_events)
  let summary = pdf_v2_core_source_summary(
    bytes.length(),
    pages.length(),
    true,
    options,
  )
  {
    bytes_len: bytes.length(),
    version,
    page_count: pages.length(),
    pages,
    objects,
    content_streams,
    text_events,
    capabilities: pdf_v2_core_capability_matrix(),
    warnings: all_warnings,
    risks: all_risks,
    scanned_once: true,
    scan_boundary: options.scan_boundary,
    fallback_policy: options.fallback_policy,
    runtime_closure_policy: options.runtime_closure_policy,
    source_summary: summary,
  }
}

///|
fn pdf_v2_bytes_to_probe_text(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  for byte in bytes {
    out.write_char(byte.to_char())
  }
  out.to_string()
}

///|
fn parse_pdf_v2_version(text : String) -> String? {
  if !text.has_prefix("%PDF-") {
    return None
  }
  let chars = text.to_array()
  let mut i = 5
  let out : Array[Char] = []
  while i < chars.length() && !is_pdf_v2_space(chars[i]) {
    let ch = chars[i]
    if !(is_pdf_v2_digit(ch) || ch == '.') {
      break
    }
    out.push(ch)
    i = i + 1
  }
  if out.length() == 0 {
    None
  } else {
    Some(String::from_array(out))
  }
}

///|
fn scan_pdf_v2_indirect_objects(text : String) -> Array[PdfV2RawObject] {
  let objects : Array[PdfV2RawObject] = []
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    if !is_pdf_v2_digit(chars[i]) {
      i = i + 1
      continue
    }
    let start = i
    match parse_pdf_v2_uint_at(chars, i) {
      Some((object_number, after_object)) => {
        let mut cursor = skip_pdf_v2_spaces(chars, after_object)
        match parse_pdf_v2_uint_at(chars, cursor) {
          Some((generation, after_generation)) => {
            cursor = skip_pdf_v2_spaces(chars, after_generation)
            if matches_pdf_v2_word(chars, cursor, "obj") {
              let body_start = trim_pdf_v2_line_start(chars, cursor + 3)
              match text[body_start:].find("endobj") {
                Some(rel_end) => {
                  let body_end = body_start + rel_end
                  let body = text[body_start:body_end].to_owned()
                  objects.push(raw_object(object_number, generation, body))
                  i = body_end + "endobj".length()
                }
                None => i = start + 1
              }
            } else {
              i = start + 1
            }
          }
          None => i = start + 1
        }
      }
      None => i = start + 1
    }
  }
  objects
}

///|
fn raw_object(
  object_number : Int,
  generation : Int,
  body : String,
) -> PdfV2RawObject {
  let dictionary = extract_pdf_v2_first_dictionary(body)
  {
    object_ref: pdf_v2_object_ref_text(object_number, generation),
    object_number,
    generation,
    body,
    dictionary,
    stream_data: extract_pdf_v2_stream_data(body),
  }
}

///|
fn core_objects_from_raw(
  raw_objects : Array[PdfV2RawObject],
) -> Array[PdfV2CoreObject] {
  let objects : Array[PdfV2CoreObject] = []
  for raw in raw_objects {
    objects.push({
      object_ref: raw.object_ref,
      object_number: raw.object_number,
      generation: raw.generation,
      kind: core_object_kind(raw),
      raw: raw.body,
      dictionary: raw.dictionary,
      stream_ref: if raw.stream_data == None {
        None
      } else {
        Some(raw.object_ref + "#stream:0")
      },
    })
  }
  objects
}

///|
fn core_object_kind(raw : PdfV2RawObject) -> PdfV2CoreObjectKind {
  match raw.dictionary {
    Some(dict) => {
      let typ = pdf_v2_name_after_key(dict, "Type")
      match typ {
        Some("Catalog") => PdfV2CoreObjectKind::Catalog
        Some("Pages") => PdfV2CoreObjectKind::Pages
        Some("Page") => PdfV2CoreObjectKind::Page
        Some("Font") => PdfV2CoreObjectKind::Font
        _ =>
          if raw.stream_data == None {
            PdfV2CoreObjectKind::Other
          } else {
            PdfV2CoreObjectKind::Stream
          }
      }
    }
    None =>
      if raw.stream_data == None {
        PdfV2CoreObjectKind::Other
      } else {
        PdfV2CoreObjectKind::Stream
      }
  }
}

///|
fn build_pdf_v2_pages(
  objects : Array[PdfV2RawObject],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Array[PdfV2PageBuild] {
  let page_refs = ordered_page_refs(objects)
  let pages : Array[PdfV2PageBuild] = []
  for page_ref in page_refs {
    match find_raw_object(objects, page_ref) {
      Some(page_obj) =>
        match page_obj.dictionary {
          Some(dict) => {
            let page_index = pages.length()
            let inherited_resources = inherited_page_resources(dict, objects)
            pages.push({
              core_page: {
                page_index,
                boxes: page_boxes_from_dict(dict, objects),
                rotation: page_rotation_from_dict(dict, objects),
                user_unit: page_user_unit_from_dict(dict, objects),
                object_ref: Some(page_obj.object_ref),
                content_stream_refs: content_refs_from_page_dict(dict),
              },
              resources_dictionary: inherited_resources,
            })
          }
          None => {
            warnings.push(
              warn_malformed_object(
                page_obj.object_ref,
                Some(page_object_source_ref(0, page_obj.object_ref)),
              ),
            )
            risks.push(
              pdf_v2_risk_for_context(
                PdfV2RiskKind::MalformedObject,
                PdfV2RiskSeverity::Error,
                pdf_v2_diagnostic_context(
                  PdfV2CoreCapabilityKind::PageTree,
                  Some(page_object_source_ref(0, page_obj.object_ref)),
                  Some(page_obj.object_ref),
                  None,
                  [page_obj.object_ref],
                ),
                "page object has no readable dictionary",
                ["page_tree", "malformed_page_object", "no_fallback"],
                PdfV2Recoverability::RecoverableWithLoss,
              ),
            )
          }
        }
      None => ()
    }
  }
  pages
}

///|
fn ordered_page_refs(objects : Array[PdfV2RawObject]) -> Array[String] {
  let refs : Array[String] = []
  match catalog_pages_ref(objects) {
    Some(root_ref) => collect_page_refs_from_tree(root_ref, objects, refs, [])
    None => ()
  }
  if refs.is_empty() {
    for object in objects {
      if core_object_kind(object) == PdfV2CoreObjectKind::Page {
        refs.push(object.object_ref)
      }
    }
  }
  refs
}

///|
fn catalog_pages_ref(objects : Array[PdfV2RawObject]) -> String? {
  for object in objects {
    if core_object_kind(object) == PdfV2CoreObjectKind::Catalog {
      match object.dictionary {
        Some(dict) => return pdf_v2_ref_after_key(dict, "Pages")
        None => ()
      }
    }
  }
  None
}

///|
fn collect_page_refs_from_tree(
  object_ref : String,
  objects : Array[PdfV2RawObject],
  out : Array[String],
  seen : Array[String],
) -> Unit {
  if seen.contains(object_ref) {
    return
  }
  let next_seen = seen + [object_ref]
  match find_raw_object(objects, object_ref) {
    Some(object) =>
      match core_object_kind(object) {
        PdfV2CoreObjectKind::Page => out.push(object_ref)
        PdfV2CoreObjectKind::Pages =>
          match object.dictionary {
            Some(dict) =>
              for child_ref in pdf_v2_refs_in_array_after_key(dict, "Kids") {
                collect_page_refs_from_tree(child_ref, objects, out, next_seen)
              }
            None => ()
          }
        _ => ()
      }
    None => ()
  }
}

///|
fn inherited_page_resources(
  page_dict : String,
  objects : Array[PdfV2RawObject],
) -> String? {
  match resources_dict_from_dict(page_dict, objects) {
    Some(resources) => return Some(resources)
    None => ()
  }
  match pdf_v2_ref_after_key(page_dict, "Parent") {
    Some(parent_ref) =>
      match find_raw_object(objects, parent_ref) {
        Some(parent) =>
          match parent.dictionary {
            Some(parent_dict) => resources_dict_from_dict(parent_dict, objects)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn resources_dict_from_dict(
  dict : String,
  objects : Array[PdfV2RawObject],
) -> String? {
  match pdf_v2_ref_after_key(dict, "Resources") {
    Some(ref_text) =>
      match find_raw_object(objects, ref_text) {
        Some(resource_obj) => resource_obj.dictionary
        None => None
      }
    None => pdf_v2_inline_dictionary_after_key(dict, "Resources")
  }
}

///|
fn read_page_content_streams(
  page_build : PdfV2PageBuild,
  objects : Array[PdfV2RawObject],
  content_streams : Array[PdfV2CoreContentStream],
  text_events : Array[PdfV2CoreTextEvent],
  warnings : Array[PdfV2Warning],
  _risks : Array[PdfV2Risk],
) -> Unit {
  for stream_index in 0..<page_build.core_page.content_stream_refs.length() {
    let stream_object_ref = page_build.core_page.content_stream_refs[stream_index]
    let source_ref = content_source_ref(
      page_build.core_page.page_index,
      Some(stream_object_ref),
      stream_index,
      None,
      None,
      None,
    )
    match find_raw_object(objects, stream_object_ref) {
      Some(object) =>
        match object.stream_data {
          Some(stream_data) => {
            let stream = build_content_stream_fact(
              page_build.core_page.page_index,
              stream_index,
              object,
              stream_data,
              source_ref,
            )
            let base_event_count = text_events.length()
            content_streams.push(stream)
            match stream.decoded_text {
              Some(decoded) =>
                interpret_pdf_v2_content_stream(
                  decoded, page_build, objects, stream, text_events,
                )
              None => ()
            }
            if stream.decode_supported &&
              text_events.length() == base_event_count {
              warnings.push(
                pdf_v2_no_text_ops_warning(
                  source_ref,
                  Some(stream_object_ref),
                  page_build.core_page.page_index,
                ),
              )
            }
          }
          None =>
            warnings.push(
              warn_malformed_object(stream_object_ref, Some(source_ref)),
            )
        }
      None =>
        warnings.push(warn_missing_object(stream_object_ref, Some(source_ref)))
    }
  }
}

///|
fn build_content_stream_fact(
  page_index : Int,
  stream_index : Int,
  object : PdfV2RawObject,
  stream_data : String,
  source_ref : PdfV2SourceRef,
) -> PdfV2CoreContentStream {
  let filters = match object.dictionary {
    Some(dict) => pdf_v2_filter_names(dict)
    None => []
  }
  let stream_warnings : Array[PdfV2Warning] = []
  let stream_risks : Array[PdfV2Risk] = []
  let raw_bytes = string_to_pdf_v2_bytes(stream_data)
  let decoded = decode_pdf_v2_content_stream_bytes(
    raw_bytes,
    filters,
    source_ref,
    object.object_ref,
    stream_warnings,
    stream_risks,
  )
  if !decoded.supported {
    let flate_only = filters.length() == 1 && filters[0] == "FlateDecode"
    if !flate_only {
      for filter in filters {
        let diagnostic = filter_diagnostic_for_name(
          filter,
          Some(source_ref),
          Some(object.object_ref),
        )
        match diagnostic.warning {
          Some(warning) => stream_warnings.push(warning)
          None => ()
        }
        match diagnostic.risk {
          Some(risk) => stream_risks.push(risk)
          None => ()
        }
      }
    }
  }
  {
    stream_ref: object.object_ref + "#stream:" + stream_index.to_string(),
    object_ref: Some(object.object_ref),
    page_index,
    stream_index,
    raw_bytes: Some(raw_bytes),
    decoded_text: decoded.text,
    filter_names: filters,
    decode_supported: decoded.supported,
    warnings: stream_warnings,
    risks: stream_risks,
    source_ref,
  }
}

///|
priv struct PdfV2StreamDecodeResult {
  text : String?
  supported : Bool
}

///|
fn decode_pdf_v2_content_stream_bytes(
  raw_bytes : Bytes,
  filters : Array[String],
  source_ref : PdfV2SourceRef,
  object_ref : String,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> PdfV2StreamDecodeResult {
  if filters.is_empty() {
    return { text: Some(bytes_to_pdf_v2_text(raw_bytes)), supported: true }
  }
  if filters.length() == 1 && filters[0] == "FlateDecode" {
    let inflated = @zlib.decompress(raw_bytes) catch {
      _ => {
        let diagnostic = warn_compressed_stream_decode_failure(
          "FlateDecode",
          Some(source_ref),
          Some(object_ref),
        )
        match diagnostic.warning {
          Some(warning) => warnings.push(warning)
          None => ()
        }
        match diagnostic.risk {
          Some(risk) => risks.push(risk)
          None => ()
        }
        return { text: None, supported: false }
      }
    }
    return { text: Some(bytes_to_pdf_v2_text(inflated)), supported: true }
  }
  if filters.contains("FlateDecode") && filters.length() > 1 {
    let context = pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::StreamFilter,
      Some(source_ref),
      Some(object_ref),
      Some(source_ref.page_index),
      filters,
    )
    warnings.push(
      pdf_v2_warning_for_context(
        PdfV2WarningKind::PartialCapability,
        PdfV2Severity::Warning,
        context,
        "FlateDecode filter chains are not yet supported",
        ["flate_decode_filter_chain_unsupported", "no_fallback"],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    )
    risks.push(
      pdf_v2_risk_for_context(
        PdfV2RiskKind::PartialCapability,
        PdfV2RiskSeverity::Warning,
        context,
        "compressed stream filter chain blocks source facts",
        ["flate_decode_filter_chain_unsupported", "abstain_candidate"],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    )
  }
  { text: None, supported: false }
}

///|
fn bytes_to_pdf_v2_text(bytes : Bytes) -> String {
  let out = StringBuilder::new()
  for byte in bytes {
    out.write_char(byte.to_char())
  }
  out.to_string()
}

///|
fn filter_diagnostic_for_name(
  raw_name : String,
  source_ref : PdfV2SourceRef?,
  object_ref : String?,
) -> PdfV2FilterDiagnostic {
  match raw_name {
    "FlateDecode" =>
      warn_compressed_stream_decode_failure(raw_name, source_ref, object_ref)
    "LZWDecode" =>
      warn_compressed_stream_decode_failure(raw_name, source_ref, object_ref)
    "ASCII85Decode" =>
      warn_compressed_stream_decode_failure(raw_name, source_ref, object_ref)
    "ASCIIHexDecode" =>
      warn_compressed_stream_decode_failure(raw_name, source_ref, object_ref)
    "RunLengthDecode" =>
      warn_compressed_stream_decode_failure(raw_name, source_ref, object_ref)
    "CCITTFaxDecode" =>
      warn_rare_filter_unsupported(
        PdfV2FilterName::CCITTFaxDecode,
        raw_name,
        source_ref,
        object_ref,
      )
    "JBIG2Decode" =>
      warn_rare_filter_unsupported(
        PdfV2FilterName::JBIG2Decode,
        raw_name,
        source_ref,
        object_ref,
      )
    "JPXDecode" =>
      warn_rare_filter_unsupported(
        PdfV2FilterName::JPXDecode,
        raw_name,
        source_ref,
        object_ref,
      )
    "Crypt" =>
      warn_rare_filter_unsupported(
        PdfV2FilterName::Crypt,
        raw_name,
        source_ref,
        object_ref,
      )
    _ => warn_unknown_filter(raw_name, source_ref, object_ref)
  }
}

///|
fn interpret_pdf_v2_content_stream(
  content : String,
  page_build : PdfV2PageBuild,
  objects : Array[PdfV2RawObject],
  stream : PdfV2CoreContentStream,
  text_events : Array[PdfV2CoreTextEvent],
) -> Unit {
  let tokens = tokenize_pdf_v2_content_stream(content)
  let operands : Array[PdfV2ContentToken] = []
  let state : PdfV2TextState = {
    in_text_object: false,
    text_object_id: 0,
    font_name: None,
    font_size: None,
    x: 0.0,
    y: 0.0,
    matrix: [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
    content_order_index: 0,
  }
  let mut op_index = 0
  for token in tokens {
    match token {
      PdfV2ContentToken::Operator(op) => {
        handle_pdf_v2_content_operator(
          op, operands, state, page_build, objects, stream, text_events, op_index,
        )
        operands.clear()
        op_index = op_index + 1
      }
      _ => operands.push(token)
    }
  }
  if state.in_text_object {
    let source_ref = content_source_ref(
      page_build.core_page.page_index,
      stream.object_ref,
      stream.stream_index,
      Some(op_index),
      Some(state.content_order_index),
      Some(state.text_object_id),
    )
    text_events.push(
      malformed_text_marker_event(
        "unterminated_text_object",
        page_build.core_page.page_index,
        stream,
        source_ref,
      ),
    )
  }
}

///|
fn handle_pdf_v2_content_operator(
  op : String,
  operands : Array[PdfV2ContentToken],
  state : PdfV2TextState,
  page_build : PdfV2PageBuild,
  objects : Array[PdfV2RawObject],
  stream : PdfV2CoreContentStream,
  text_events : Array[PdfV2CoreTextEvent],
  op_index : Int,
) -> Unit {
  match op {
    "BT" => {
      if state.in_text_object {
        let source_ref = content_source_ref(
          page_build.core_page.page_index,
          stream.object_ref,
          stream.stream_index,
          Some(op_index),
          Some(state.content_order_index),
          Some(state.text_object_id),
        )
        text_events.push(
          malformed_text_marker_event(
            "nested_text_object",
            page_build.core_page.page_index,
            stream,
            source_ref,
          ),
        )
      }
      state.in_text_object = true
      state.text_object_id = state.text_object_id + 1
      state.x = 0.0
      state.y = 0.0
      state.matrix = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
    }
    "ET" => {
      if !state.in_text_object {
        let source_ref = content_source_ref(
          page_build.core_page.page_index,
          stream.object_ref,
          stream.stream_index,
          Some(op_index),
          Some(state.content_order_index),
          Some(state.text_object_id),
        )
        text_events.push(
          malformed_text_marker_event(
            "text_end_without_begin",
            page_build.core_page.page_index,
            stream,
            source_ref,
          ),
        )
      }
      state.in_text_object = false
    }
    "Tf" => handle_tf_operator(operands, state)
    "Td" | "TD" => handle_td_operator(operands, state)
    "Tm" => handle_tm_operator(operands, state)
    "T*" => move_pdf_v2_next_text_line(state)
    "Tj" =>
      emit_pdf_v2_text_show(
        op,
        text_from_pdf_v2_operand(last_operand(operands)),
        state,
        page_build,
        objects,
        stream,
        text_events,
        op_index,
      )
    "TJ" =>
      emit_pdf_v2_text_show(
        op,
        text_from_pdf_v2_array_operand(last_operand(operands)),
        state,
        page_build,
        objects,
        stream,
        text_events,
        op_index,
      )
    "'" => {
      move_pdf_v2_next_text_line(state)
      emit_pdf_v2_text_show(
        op,
        text_from_pdf_v2_operand(last_operand(operands)),
        state,
        page_build,
        objects,
        stream,
        text_events,
        op_index,
      )
    }
    "\"" => {
      move_pdf_v2_next_text_line(state)
      emit_pdf_v2_text_show(
        op,
        text_from_pdf_v2_operand(last_operand(operands)),
        state,
        page_build,
        objects,
        stream,
        text_events,
        op_index,
      )
    }
    _ =>
      if state.in_text_object || op_looks_like_pdf_v2_text_operator(op) {
        let source_ref = content_source_ref(
          page_build.core_page.page_index,
          stream.object_ref,
          stream.stream_index,
          Some(op_index),
          Some(state.content_order_index),
          Some(state.text_object_id),
        )
        text_events.push(
          unsupported_operator_marker_event(
            op,
            page_build.core_page.page_index,
            stream,
            source_ref,
          ),
        )
      }
  }
}

///|
fn handle_tf_operator(
  operands : Array[PdfV2ContentToken],
  state : PdfV2TextState,
) -> Unit {
  if operands.length() < 2 {
    return
  }
  match operands[operands.length() - 2] {
    PdfV2ContentToken::Name(name) => state.font_name = Some(name)
    _ => ()
  }
  match operands[operands.length() - 1] {
    PdfV2ContentToken::Number(size) => state.font_size = Some(size)
    _ => ()
  }
}

///|
fn handle_td_operator(
  operands : Array[PdfV2ContentToken],
  state : PdfV2TextState,
) -> Unit {
  if operands.length() < 2 {
    return
  }
  match operands[operands.length() - 2] {
    PdfV2ContentToken::Number(tx) => state.x = state.x + tx
    _ => ()
  }
  match operands[operands.length() - 1] {
    PdfV2ContentToken::Number(ty) => state.y = state.y + ty
    _ => ()
  }
  state.matrix = [1.0, 0.0, 0.0, 1.0, state.x, state.y]
}

///|
fn handle_tm_operator(
  operands : Array[PdfV2ContentToken],
  state : PdfV2TextState,
) -> Unit {
  if operands.length() < 6 {
    return
  }
  let offset = operands.length() - 6
  let values : Array[Double] = []
  for i in 0..<6 {
    match operands[offset + i] {
      PdfV2ContentToken::Number(value) => values.push(value)
      _ => return
    }
  }
  state.matrix = values
  state.x = values[4]
  state.y = values[5]
}

///|
fn move_pdf_v2_next_text_line(state : PdfV2TextState) -> Unit {
  let line_height = match state.font_size {
    Some(size) => size
    None => 12.0
  }
  state.y = state.y - line_height
  state.matrix = [1.0, 0.0, 0.0, 1.0, state.x, state.y]
}

///|
fn emit_pdf_v2_text_show(
  op : String,
  text_pair : (String, Bytes)?,
  state : PdfV2TextState,
  page_build : PdfV2PageBuild,
  objects : Array[PdfV2RawObject],
  stream : PdfV2CoreContentStream,
  text_events : Array[PdfV2CoreTextEvent],
  op_index : Int,
) -> Unit {
  match text_pair {
    Some((text, raw_bytes)) => {
      let content_order = state.content_order_index
      state.content_order_index = state.content_order_index + 1
      let source_ref = content_source_ref(
        page_build.core_page.page_index,
        stream.object_ref,
        stream.stream_index,
        Some(op_index),
        Some(content_order),
        Some(state.text_object_id),
      )
      let diagnostics = font_decode_diagnostics(
        text,
        raw_bytes,
        state.font_name,
        page_build,
        objects,
        source_ref,
        stream.object_ref,
      )
      let malformed_warnings = if state.in_text_object {
        []
      } else {
        [
          pdf_v2_warning_for_context(
            PdfV2WarningKind::MalformedSource,
            PdfV2Severity::Warning,
            pdf_v2_diagnostic_context(
              PdfV2CoreCapabilityKind::TextOperator,
              Some(source_ref),
              stream.object_ref,
              Some(page_build.core_page.page_index),
              [],
            ),
            "text showing operator appeared outside BT/ET",
            ["malformed_text_object", "text_retained"],
            PdfV2Recoverability::RecoverableWithLoss,
          ),
        ]
      }
      let confidence = if malformed_warnings.is_empty() {
        diagnostics.decode_confidence
      } else if diagnostics.decode_confidence < 0.72 {
        diagnostics.decode_confidence
      } else {
        0.72
      }
      text_events.push({
        id: "text_" +
        page_build.core_page.page_index.to_string() +
        "_" +
        content_order.to_string(),
        page_index: page_build.core_page.page_index,
        content_order_index: content_order,
        object_ref: stream.object_ref,
        stream_ref: Some(stream.stream_ref),
        stream_index: Some(stream.stream_index),
        op_index: Some(op_index),
        text_object_id: Some(state.text_object_id),
        operator: op,
        text: if diagnostics.decoded_text == "" && raw_bytes.length() > 0 {
          "[pdf-v2-undecoded-text]"
        } else {
          diagnostics.decoded_text
        },
        raw_bytes: Some(raw_bytes),
        font_name: state.font_name,
        font_size: state.font_size,
        origin: Some({ x: state.x, y: state.y }),
        text_matrix: state.matrix,
        decode_confidence: confidence,
        warnings: diagnostics.warnings + malformed_warnings,
        risks: diagnostics.risks,
        source_ref,
        reason_tags: [
          "pdf_v2_real_content_stream",
          "text_operator_" + op,
          "best_effort_simple_text_decode",
        ] +
        diagnostics.reason_tags,
      })
    }
    None => ()
  }
}

///|
priv struct PdfV2FontDiagnostics {
  decoded_text : String
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  reason_tags : Array[String]
  decode_confidence : Double
}

///|
fn font_decode_diagnostics(
  fallback_text : String,
  raw_bytes : Bytes,
  font_name : String?,
  page_build : PdfV2PageBuild,
  objects : Array[PdfV2RawObject],
  source_ref : PdfV2SourceRef,
  stream_object_ref : String?,
) -> PdfV2FontDiagnostics {
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let reason_tags : Array[String] = []
  match font_name {
    None => {
      let resource = make_resource_ref(
        PdfV2ResourceKind::Font,
        "(current-font)",
        page_build.core_page.page_index,
        stream_object_ref,
        Some(source_ref),
      )
      let diagnostic = warn_missing_font_resource(resource)
      warnings.push(diagnostic.warning)
      risks.push(
        risk_glyph_decode_low_confidence(Some(source_ref), stream_object_ref),
      )
      reason_tags.push("missing_font_resource")
      return pdf_v2_font_diagnostics_result(
        fallback_text, warnings, risks, reason_tags, 0.72,
      )
    }
    Some(name) =>
      match page_build.resources_dictionary {
        None => {
          let resource = make_resource_ref(
            PdfV2ResourceKind::Font,
            name,
            page_build.core_page.page_index,
            stream_object_ref,
            Some(source_ref),
          )
          let diagnostic = warn_missing_font_resource(resource)
          warnings.push(diagnostic.warning)
          risks.push(
            risk_glyph_decode_low_confidence(
              Some(source_ref),
              stream_object_ref,
            ),
          )
          reason_tags.push("missing_font_resource")
          return pdf_v2_font_diagnostics_result(
            fallback_text, warnings, risks, reason_tags, 0.72,
          )
        }
        Some(resources) =>
          match font_ref_from_resources(resources, name) {
            None => {
              let resource = make_resource_ref(
                PdfV2ResourceKind::Font,
                name,
                page_build.core_page.page_index,
                stream_object_ref,
                Some(source_ref),
              )
              let diagnostic = warn_missing_font_resource(resource)
              warnings.push(diagnostic.warning)
              risks.push(
                risk_glyph_decode_low_confidence(
                  Some(source_ref),
                  stream_object_ref,
                ),
              )
              reason_tags.push("missing_font_resource")
              return pdf_v2_font_diagnostics_result(
                fallback_text, warnings, risks, reason_tags, 0.72,
              )
            }
            Some(font_ref) => {
              let resource = make_resource_ref(
                PdfV2ResourceKind::Font,
                name,
                page_build.core_page.page_index,
                Some(font_ref),
                Some(source_ref),
              )
              match find_raw_object(objects, font_ref) {
                Some(font_obj) =>
                  match font_obj.dictionary {
                    Some(font_dict) => {
                      match pdf_v2_ref_after_key(font_dict, "ToUnicode") {
                        Some(to_unicode_ref) => {
                          let decoded = decode_pdf_v2_text_with_tounicode(
                            fallback_text, raw_bytes, to_unicode_ref, resource, objects,
                            source_ref,
                          )
                          warnings.append(decoded.warnings)
                          risks.append(decoded.risks)
                          reason_tags.append(decoded.reason_tags)
                          return pdf_v2_font_diagnostics_result(
                            decoded.text,
                            warnings,
                            risks,
                            reason_tags,
                            decoded.decode_confidence,
                          )
                        }
                        None => {
                          let diagnostic = warn_to_unicode_missing_or_malformed(
                            resource,
                          )
                          warnings.push(diagnostic.warning)
                          risks.push(
                            risk_glyph_decode_low_confidence(
                              Some(source_ref),
                              Some(font_ref),
                            ),
                          )
                          reason_tags.push("tounicode_missing")
                          reason_tags.push("to_unicode_missing_or_malformed")
                        }
                      }
                      if !font_dict.contains("/ToUnicode") &&
                        !font_dict.contains("/Encoding") &&
                        !font_dict.contains("/BaseFont") {
                        let diagnostic = warn_unknown_font_encoding(resource)
                        warnings.push(diagnostic.warning)
                        risks.push(
                          risk_glyph_decode_low_confidence(
                            Some(source_ref),
                            Some(font_ref),
                          ),
                        )
                        reason_tags.push("unknown_font_encoding")
                      }
                    }
                    None => {
                      let diagnostic = warn_unknown_font_encoding(resource)
                      warnings.push(diagnostic.warning)
                      risks.push(
                        risk_glyph_decode_low_confidence(
                          Some(source_ref),
                          Some(font_ref),
                        ),
                      )
                      reason_tags.push("unknown_font_encoding")
                    }
                  }
                None => {
                  let diagnostic = warn_missing_font_resource(resource)
                  warnings.push(diagnostic.warning)
                  risks.push(
                    risk_glyph_decode_low_confidence(
                      Some(source_ref),
                      Some(font_ref),
                    ),
                  )
                  reason_tags.push("missing_font_resource")
                }
              }
            }
          }
      }
  }
  pdf_v2_font_diagnostics_result(
    fallback_text,
    warnings,
    risks,
    reason_tags,
    if warnings.is_empty() {
      0.95
    } else {
      0.72
    },
  )
}

///|
fn pdf_v2_font_diagnostics_result(
  decoded_text : String,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  reason_tags : Array[String],
  decode_confidence : Double,
) -> PdfV2FontDiagnostics {
  { decoded_text, warnings, risks, reason_tags, decode_confidence }
}

///|
fn decode_pdf_v2_text_with_tounicode(
  fallback_text : String,
  raw_bytes : Bytes,
  to_unicode_ref : String,
  font_resource : PdfV2ResourceRef,
  objects : Array[PdfV2RawObject],
  source_ref : PdfV2SourceRef,
) -> PdfV2ToUnicodeTextDecode {
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let reason_tags : Array[String] = ["tounicode_stream_found"]
  match find_raw_object(objects, to_unicode_ref) {
    Some(cmap_object) =>
      match cmap_object.stream_data {
        Some(stream_data) => {
          let raw_stream_bytes = string_to_pdf_v2_bytes(stream_data)
          let filters = match cmap_object.dictionary {
            Some(dict) => pdf_v2_filter_names(dict)
            None => []
          }
          let decoded_stream = decode_pdf_v2_content_stream_bytes(
            raw_stream_bytes,
            filters,
            source_ref,
            cmap_object.object_ref,
            warnings,
            risks,
          )
          if !decoded_stream.supported {
            append_pdf_v2_unsupported_filter_diagnostics(
              filters,
              source_ref,
              cmap_object.object_ref,
              warnings,
              risks,
            )
            append_tounicode_malformed_diagnostic(
              font_resource, warnings, risks, source_ref, to_unicode_ref,
            )
            reason_tags.push("tounicode_stream_filter_unsupported")
            return tounicode_decode_result(
              fallback_text, warnings, risks, reason_tags, 0.72,
            )
          }
          reason_tags.push("tounicode_stream_decoded")
          match decoded_stream.text {
            Some(cmap_text) => {
              let cmap = parse_pdf_v2_to_unicode_cmap(cmap_text)
              if cmap.unsupported_count > 0 {
                append_tounicode_unsupported_diagnostic(
                  font_resource, warnings, risks, source_ref, to_unicode_ref,
                )
                reason_tags.push("tounicode_unsupported_construct")
              }
              if cmap.entries.is_empty() || cmap.malformed_count > 0 {
                append_tounicode_malformed_diagnostic(
                  font_resource, warnings, risks, source_ref, to_unicode_ref,
                )
                reason_tags.push("tounicode_malformed")
                return tounicode_decode_result(
                  fallback_text, warnings, risks, reason_tags, 0.72,
                )
              }
              reason_tags.push("tounicode_cmap_parsed")
              if cmap.bfchar_count > 0 {
                reason_tags.push("tounicode_bfchar_applied")
              }
              if cmap.bfrange_count > 0 {
                reason_tags.push("tounicode_bfrange_applied")
              }
              let decoded = decode_pdf_v2_bytes_with_tounicode_map(
                raw_bytes, cmap,
              )
              if decoded.unmapped_count > 0 {
                append_tounicode_unmapped_diagnostic(
                  font_resource, warnings, risks, source_ref, to_unicode_ref,
                )
                reason_tags.push("tounicode_code_unmapped")
                reason_tags.push("text_retained")
                return tounicode_decode_result(
                  decoded.text,
                  warnings,
                  risks,
                  reason_tags,
                  0.55,
                )
              }
              reason_tags.push("decode_source_tounicode")
              tounicode_decode_result(
                decoded.text,
                warnings,
                risks,
                reason_tags,
                0.99,
              )
            }
            None => {
              append_tounicode_malformed_diagnostic(
                font_resource, warnings, risks, source_ref, to_unicode_ref,
              )
              reason_tags.push("tounicode_malformed")
              tounicode_decode_result(
                fallback_text, warnings, risks, reason_tags, 0.72,
              )
            }
          }
        }
        None => {
          append_tounicode_malformed_diagnostic(
            font_resource, warnings, risks, source_ref, to_unicode_ref,
          )
          reason_tags.push("tounicode_malformed")
          tounicode_decode_result(
            fallback_text, warnings, risks, reason_tags, 0.72,
          )
        }
      }
    None => {
      append_tounicode_malformed_diagnostic(
        font_resource, warnings, risks, source_ref, to_unicode_ref,
      )
      reason_tags.push("tounicode_malformed")
      tounicode_decode_result(fallback_text, warnings, risks, reason_tags, 0.72)
    }
  }
}

///|
fn tounicode_decode_result(
  text : String,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  reason_tags : Array[String],
  decode_confidence : Double,
) -> PdfV2ToUnicodeTextDecode {
  { text, warnings, risks, reason_tags, decode_confidence }
}

///|
fn append_tounicode_malformed_diagnostic(
  font_resource : PdfV2ResourceRef,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  source_ref : PdfV2SourceRef,
  object_ref : String,
) -> Unit {
  let diagnostic = warn_to_unicode_missing_or_malformed(font_resource)
  warnings.push(diagnostic.warning)
  risks.push(
    risk_glyph_decode_low_confidence(Some(source_ref), Some(object_ref)),
  )
}

///|
fn append_tounicode_unmapped_diagnostic(
  font_resource : PdfV2ResourceRef,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  source_ref : PdfV2SourceRef,
  object_ref : String,
) -> Unit {
  warnings.push(
    pdf_v2_warning_for_context(
      PdfV2WarningKind::GlyphDecodeLowConfidence,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::ToUnicode,
        Some(source_ref),
        Some(object_ref),
        Some(font_resource.page_index),
        [font_resource.name],
      ),
      "ToUnicode map did not cover every glyph code",
      [
        "tounicode_code_unmapped", "glyph_decode_low_confidence", "text_retained",
      ],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  )
  risks.push(
    risk_glyph_decode_low_confidence(Some(source_ref), Some(object_ref)),
  )
}

///|
fn append_tounicode_unsupported_diagnostic(
  font_resource : PdfV2ResourceRef,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  source_ref : PdfV2SourceRef,
  object_ref : String,
) -> Unit {
  warnings.push(
    pdf_v2_warning_for_context(
      PdfV2WarningKind::UnsupportedFeature,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::Cmap,
        Some(source_ref),
        Some(object_ref),
        Some(font_resource.page_index),
        [font_resource.name],
      ),
      "ToUnicode CMap contains unsupported constructs",
      ["tounicode_unsupported_construct", "text_retained"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  )
  risks.push(
    risk_glyph_decode_low_confidence(Some(source_ref), Some(object_ref)),
  )
}

///|
fn append_pdf_v2_unsupported_filter_diagnostics(
  filters : Array[String],
  source_ref : PdfV2SourceRef,
  object_ref : String,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Unit {
  let flate_only = filters.length() == 1 && filters[0] == "FlateDecode"
  if flate_only {
    return
  }
  for filter in filters {
    let diagnostic = filter_diagnostic_for_name(
      filter,
      Some(source_ref),
      Some(object_ref),
    )
    match diagnostic.warning {
      Some(warning) => warnings.push(warning)
      None => ()
    }
    match diagnostic.risk {
      Some(risk) => risks.push(risk)
      None => ()
    }
  }
}

///|
fn parse_pdf_v2_to_unicode_cmap(text : String) -> PdfV2ToUnicodeMap {
  let tokens = tokenize_pdf_v2_content_stream(text)
  let code_spaces : Array[PdfV2CMapCodeSpace] = []
  let entries : Array[PdfV2CMapEntry] = []
  let operands : Array[PdfV2ContentToken] = []
  let mut section = ""
  let mut malformed_count = 0
  let mut unsupported_count = 0
  let mut bfchar_count = 0
  let mut bfrange_count = 0
  for token in tokens {
    match token {
      PdfV2ContentToken::Operator(op) =>
        match op {
          "begincodespacerange" => {
            section = "codespace"
            operands.clear()
          }
          "endcodespacerange" => {
            malformed_count += parse_pdf_v2_cmap_codespaces(
              operands, code_spaces,
            )
            operands.clear()
            section = ""
          }
          "beginbfchar" => {
            section = "bfchar"
            operands.clear()
          }
          "endbfchar" => {
            let before = entries.length()
            malformed_count += parse_pdf_v2_cmap_bfchar(operands, entries)
            bfchar_count += entries.length() - before
            operands.clear()
            section = ""
          }
          "beginbfrange" => {
            section = "bfrange"
            operands.clear()
          }
          "endbfrange" => {
            let before = entries.length()
            malformed_count += parse_pdf_v2_cmap_bfrange(operands, entries)
            bfrange_count += entries.length() - before
            operands.clear()
            section = ""
          }
          "usecmap" => unsupported_count += 1
          _ =>
            if section != "" {
              operands.push(token)
            } else {
              operands.clear()
            }
        }
      _ => if section != "" { operands.push(token) }
    }
  }
  if section != "" {
    malformed_count += 1
  }
  {
    code_spaces,
    entries,
    malformed_count,
    unsupported_count,
    bfchar_count,
    bfrange_count,
  }
}

///|
fn parse_pdf_v2_cmap_codespaces(
  operands : Array[PdfV2ContentToken],
  out : Array[PdfV2CMapCodeSpace],
) -> Int {
  let mut malformed = 0
  let mut i = 0
  while i + 1 < operands.length() {
    match (cmap_hex_value(operands[i]), cmap_hex_value(operands[i + 1])) {
      (Some(low), Some(high)) =>
        if low.code_len == high.code_len {
          out.push({ code_len: low.code_len, low: low.value, high: high.value })
        } else {
          malformed += 1
        }
      _ => malformed += 1
    }
    i = i + 2
  }
  if i < operands.length() {
    malformed += 1
  }
  malformed
}

///|
fn parse_pdf_v2_cmap_bfchar(
  operands : Array[PdfV2ContentToken],
  out : Array[PdfV2CMapEntry],
) -> Int {
  let mut malformed = 0
  let mut i = 0
  while i + 1 < operands.length() {
    match (cmap_hex_value(operands[i]), cmap_unicode_value(operands[i + 1])) {
      (Some(code), Some(unicode)) =>
        out.push({ code_len: code.code_len, code: code.value, unicode })
      _ => malformed += 1
    }
    i = i + 2
  }
  if i < operands.length() {
    malformed += 1
  }
  malformed
}

///|
fn parse_pdf_v2_cmap_bfrange(
  operands : Array[PdfV2ContentToken],
  out : Array[PdfV2CMapEntry],
) -> Int {
  let mut malformed = 0
  let mut i = 0
  while i + 2 < operands.length() {
    match (cmap_hex_value(operands[i]), cmap_hex_value(operands[i + 1])) {
      (Some(start), Some(stop)) =>
        if start.code_len != stop.code_len || stop.value < start.value {
          malformed += 1
        } else {
          malformed += append_pdf_v2_cmap_bfrange_dest(
            start,
            stop,
            operands[i + 2],
            out,
          )
        }
      _ => malformed += 1
    }
    i = i + 3
  }
  if i < operands.length() {
    malformed += 1
  }
  malformed
}

///|
priv struct PdfV2CMapHexValue {
  value : Int
  code_len : Int
}

///|
fn cmap_hex_value(token : PdfV2ContentToken) -> PdfV2CMapHexValue? {
  match token {
    PdfV2ContentToken::HexString(_, bytes) =>
      Some({
        value: bytes_to_pdf_v2_big_endian_int(bytes),
        code_len: bytes.length(),
      })
    _ => None
  }
}

///|
fn cmap_unicode_value(token : PdfV2ContentToken) -> String? {
  match token {
    PdfV2ContentToken::HexString(_, bytes) =>
      unicode_string_from_cmap_bytes(bytes)
    _ => None
  }
}

///|
fn append_pdf_v2_cmap_bfrange_dest(
  start : PdfV2CMapHexValue,
  stop : PdfV2CMapHexValue,
  dest : PdfV2ContentToken,
  out : Array[PdfV2CMapEntry],
) -> Int {
  let count = stop.value - start.value + 1
  if count > 2048 {
    return 1
  }
  match dest {
    PdfV2ContentToken::HexString(_, bytes) => {
      for offset in 0..<count {
        match unicode_string_from_incremented_cmap_bytes(bytes, offset) {
          Some(unicode) =>
            out.push({
              code_len: start.code_len,
              code: start.value + offset,
              unicode,
            })
          None => return 1
        }
      }
      0
    }
    PdfV2ContentToken::Array(items) => {
      if items.length() < count {
        return 1
      }
      for offset in 0..<count {
        match cmap_unicode_value(items[offset]) {
          Some(unicode) =>
            out.push({
              code_len: start.code_len,
              code: start.value + offset,
              unicode,
            })
          None => return 1
        }
      }
      0
    }
    _ => 1
  }
}

///|
fn decode_pdf_v2_bytes_with_tounicode_map(
  bytes : Bytes,
  cmap : PdfV2ToUnicodeMap,
) -> PdfV2CMapDecodeResult {
  let out = StringBuilder::new()
  let mut unmapped_count = 0
  let mut i = 0
  while i < bytes.length() {
    match match_pdf_v2_cmap_entry(bytes, i, cmap) {
      Some((entry, next)) => {
        out.write_string(entry.unicode)
        i = next
      }
      None => {
        unmapped_count += 1
        out.write_string(fallback_text_for_pdf_v2_code_byte(bytes[i]))
        i = i + 1
      }
    }
  }
  { text: out.to_string(), unmapped_count }
}

///|
fn match_pdf_v2_cmap_entry(
  bytes : Bytes,
  offset : Int,
  cmap : PdfV2ToUnicodeMap,
) -> (PdfV2CMapEntry, Int)? {
  let lengths = pdf_v2_cmap_candidate_lengths(cmap)
  for code_len in lengths {
    if offset + code_len <= bytes.length() &&
      pdf_v2_cmap_code_in_codespace(bytes, offset, code_len, cmap) {
      let code = pdf_v2_bytes_range_to_int(bytes, offset, code_len)
      match find_pdf_v2_cmap_entry(cmap.entries, code_len, code) {
        Some(entry) => return Some((entry, offset + code_len))
        None => ()
      }
    }
  }
  None
}

///|
fn pdf_v2_cmap_candidate_lengths(cmap : PdfV2ToUnicodeMap) -> Array[Int] {
  let lengths : Array[Int] = []
  for space in cmap.code_spaces {
    if !lengths.contains(space.code_len) {
      lengths.push(space.code_len)
    }
  }
  if lengths.is_empty() {
    for entry in cmap.entries {
      if !lengths.contains(entry.code_len) {
        lengths.push(entry.code_len)
      }
    }
  }
  sort_pdf_v2_lengths_desc(lengths)
}

///|
fn sort_pdf_v2_lengths_desc(values : Array[Int]) -> Array[Int] {
  let sorted = values.copy()
  for i in 0..<sorted.length() {
    let mut best = i
    for j in (i + 1)..<sorted.length() {
      if sorted[j] > sorted[best] {
        best = j
      }
    }
    if best != i {
      let tmp = sorted[i]
      sorted[i] = sorted[best]
      sorted[best] = tmp
    }
  }
  sorted
}

///|
fn pdf_v2_cmap_code_in_codespace(
  bytes : Bytes,
  offset : Int,
  code_len : Int,
  cmap : PdfV2ToUnicodeMap,
) -> Bool {
  if cmap.code_spaces.is_empty() {
    return true
  }
  let code = pdf_v2_bytes_range_to_int(bytes, offset, code_len)
  for space in cmap.code_spaces {
    if space.code_len == code_len && code >= space.low && code <= space.high {
      return true
    }
  }
  false
}

///|
fn find_pdf_v2_cmap_entry(
  entries : Array[PdfV2CMapEntry],
  code_len : Int,
  code : Int,
) -> PdfV2CMapEntry? {
  for entry in entries {
    if entry.code_len == code_len && entry.code == code {
      return Some(entry)
    }
  }
  None
}

///|
fn unicode_string_from_cmap_bytes(bytes : Bytes) -> String? {
  if bytes.length() == 0 || bytes.length() % 2 != 0 {
    return None
  }
  let out = StringBuilder::new()
  let mut i = 0
  while i + 1 < bytes.length() {
    let unit = bytes[i].to_int() * 256 + bytes[i + 1].to_int()
    if unit >= 0xD800 && unit <= 0xDBFF && i + 3 < bytes.length() {
      let low = bytes[i + 2].to_int() * 256 + bytes[i + 3].to_int()
      if low >= 0xDC00 && low <= 0xDFFF {
        let scalar = 0x10000 + (unit - 0xD800) * 1024 + (low - 0xDC00)
        out.write_char(Int::unsafe_to_char(scalar))
        i = i + 4
        continue
      }
      return None
    }
    if unit >= 0xD800 && unit <= 0xDFFF {
      return None
    }
    out.write_char(Int::unsafe_to_char(unit))
    i = i + 2
  }
  Some(out.to_string())
}

///|
fn unicode_string_from_incremented_cmap_bytes(
  bytes : Bytes,
  offset : Int,
) -> String? {
  if bytes.length() < 2 || bytes.length() % 2 != 0 {
    return None
  }
  let copy = bytes.to_array()
  let last = copy.length() - 2
  let value = copy[last].to_int() * 256 + copy[last + 1].to_int() + offset
  if value > 0xFFFF {
    return None
  }
  copy[last] = ((value >> 8) & 0xFF).to_byte()
  copy[last + 1] = (value & 0xFF).to_byte()
  unicode_string_from_cmap_bytes(Bytes::from_array(copy))
}

///|
fn bytes_to_pdf_v2_big_endian_int(bytes : Bytes) -> Int {
  let mut value = 0
  for byte in bytes {
    value = value * 256 + byte.to_int()
  }
  value
}

///|
fn pdf_v2_bytes_range_to_int(bytes : Bytes, offset : Int, len : Int) -> Int {
  let mut value = 0
  for i in 0..<len {
    value = value * 256 + bytes[offset + i].to_int()
  }
  value
}

///|
fn fallback_text_for_pdf_v2_code_byte(byte : Byte) -> String {
  let value = byte.to_int()
  if value >= 0x20 && value <= 0x7E {
    String::from_array([byte.to_char()])
  } else {
    "?"
  }
}

///|
fn tokenize_pdf_v2_content_stream(content : String) -> Array[PdfV2ContentToken] {
  let parser = PdfV2ContentParser::{ chars: content.to_array(), pos: 0 }
  parser.parse_tokens_until(None)
}

///|
fn PdfV2ContentParser::parse_tokens_until(
  self : PdfV2ContentParser,
  closing : Char?,
) -> Array[PdfV2ContentToken] {
  let tokens : Array[PdfV2ContentToken] = []
  while self.pos < self.chars.length() {
    self.skip_spaces_and_comments()
    if self.pos >= self.chars.length() {
      break
    }
    match closing {
      Some(ch) =>
        if self.chars[self.pos] == ch {
          self.pos = self.pos + 1
          break
        }
      None => ()
    }
    match self.parse_one_token() {
      Some(token) => tokens.push(token)
      None => self.pos = self.pos + 1
    }
  }
  tokens
}

///|
fn PdfV2ContentParser::parse_one_token(
  self : PdfV2ContentParser,
) -> PdfV2ContentToken? {
  if self.pos >= self.chars.length() {
    return None
  }
  let ch = self.chars[self.pos]
  if ch == '/' {
    return Some(PdfV2ContentToken::Name(self.read_name()))
  }
  if ch == '(' {
    let pair = self.read_literal_string()
    return Some(PdfV2ContentToken::LiteralString(pair.0, pair.1))
  }
  if ch == '<' &&
    self.pos + 1 < self.chars.length() &&
    self.chars[self.pos + 1] != '<' {
    let pair = self.read_hex_string()
    return Some(PdfV2ContentToken::HexString(pair.0, pair.1))
  }
  if ch == '[' {
    self.pos = self.pos + 1
    return Some(PdfV2ContentToken::Array(self.parse_tokens_until(Some(']'))))
  }
  if ch == '\'' {
    self.pos = self.pos + 1
    return Some(PdfV2ContentToken::Operator("'"))
  }
  if ch == '"' {
    self.pos = self.pos + 1
    return Some(PdfV2ContentToken::Operator("\""))
  }
  if is_pdf_v2_number_start(ch) {
    let start = self.pos
    while self.pos < self.chars.length() &&
          is_pdf_v2_number_char(self.chars[self.pos]) {
      self.pos = self.pos + 1
    }
    let raw = String::from_array(self.chars[start:self.pos].to_owned())
    match parse_pdf_v2_double(raw) {
      Some(value) => return Some(PdfV2ContentToken::Number(value))
      None => self.pos = start
    }
  }
  let word = self.read_word()
  if word == "" {
    None
  } else {
    Some(PdfV2ContentToken::Operator(word))
  }
}

///|
fn PdfV2ContentParser::skip_spaces_and_comments(
  self : PdfV2ContentParser,
) -> Unit {
  while self.pos < self.chars.length() {
    if is_pdf_v2_space(self.chars[self.pos]) {
      self.pos = self.pos + 1
      continue
    }
    if self.chars[self.pos] == '%' {
      while self.pos < self.chars.length() &&
            self.chars[self.pos] != '\n' &&
            self.chars[self.pos] != '\r' {
        self.pos = self.pos + 1
      }
      continue
    }
    break
  }
}

///|
fn PdfV2ContentParser::read_name(self : PdfV2ContentParser) -> String {
  self.pos = self.pos + 1
  let start = self.pos
  while self.pos < self.chars.length() &&
        !is_pdf_v2_delimiter(self.chars[self.pos]) {
    self.pos = self.pos + 1
  }
  String::from_array(self.chars[start:self.pos].to_owned())
}

///|
fn PdfV2ContentParser::read_word(self : PdfV2ContentParser) -> String {
  let start = self.pos
  while self.pos < self.chars.length() &&
        !is_pdf_v2_delimiter(self.chars[self.pos]) {
    self.pos = self.pos + 1
  }
  String::from_array(self.chars[start:self.pos].to_owned())
}

///|
fn PdfV2ContentParser::read_literal_string(
  self : PdfV2ContentParser,
) -> (String, Bytes) {
  self.pos = self.pos + 1
  let chars : Array[Char] = []
  let raw : Array[Byte] = []
  let mut depth = 1
  while self.pos < self.chars.length() && depth > 0 {
    let ch = self.chars[self.pos]
    if ch == '\\' {
      self.pos = self.pos + 1
      if self.pos >= self.chars.length() {
        break
      }
      let escaped = self.chars[self.pos]
      let decoded = match escaped {
        'n' => '\n'
        'r' => '\r'
        't' => '\t'
        'b' => '\u{0008}'
        'f' => '\u{000C}'
        '(' => '('
        ')' => ')'
        '\\' => '\\'
        _ => escaped
      }
      chars.push(decoded)
      push_pdf_v2_char_byte(raw, decoded)
      self.pos = self.pos + 1
      continue
    }
    if ch == '(' {
      depth = depth + 1
      chars.push(ch)
      push_pdf_v2_char_byte(raw, ch)
      self.pos = self.pos + 1
      continue
    }
    if ch == ')' {
      depth = depth - 1
      if depth == 0 {
        self.pos = self.pos + 1
        break
      }
      chars.push(ch)
      push_pdf_v2_char_byte(raw, ch)
      self.pos = self.pos + 1
      continue
    }
    chars.push(ch)
    push_pdf_v2_char_byte(raw, ch)
    self.pos = self.pos + 1
  }
  (String::from_array(chars), Bytes::from_array(raw))
}

///|
fn PdfV2ContentParser::read_hex_string(
  self : PdfV2ContentParser,
) -> (String, Bytes) {
  self.pos = self.pos + 1
  let nibbles : Array[Int] = []
  while self.pos < self.chars.length() && self.chars[self.pos] != '>' {
    let ch = self.chars[self.pos]
    match pdf_v2_hex_value(ch) {
      Some(value) => nibbles.push(value)
      None => ()
    }
    self.pos = self.pos + 1
  }
  if self.pos < self.chars.length() && self.chars[self.pos] == '>' {
    self.pos = self.pos + 1
  }
  if nibbles.length() % 2 == 1 {
    nibbles.push(0)
  }
  let raw : Array[Byte] = []
  let chars : Array[Char] = []
  let mut i = 0
  while i + 1 < nibbles.length() {
    let value = nibbles[i] * 16 + nibbles[i + 1]
    raw.push(value.to_byte())
    if value >= 0x20 && value <= 0x7E {
      chars.push(Int::unsafe_to_char(value))
    } else {
      chars.push('?')
    }
    i = i + 2
  }
  (String::from_array(chars), Bytes::from_array(raw))
}

///|
fn text_from_pdf_v2_operand(operand : PdfV2ContentToken?) -> (String, Bytes)? {
  match operand {
    Some(PdfV2ContentToken::LiteralString(text, raw)) => Some((text, raw))
    Some(PdfV2ContentToken::HexString(text, raw)) => Some((text, raw))
    _ => None
  }
}

///|
fn text_from_pdf_v2_array_operand(
  operand : PdfV2ContentToken?,
) -> (String, Bytes)? {
  match operand {
    Some(PdfV2ContentToken::Array(items)) => {
      let out = StringBuilder::new()
      let raw : Array[Byte] = []
      for item in items {
        match item {
          PdfV2ContentToken::LiteralString(text, bytes) => {
            out.write_string(text)
            raw.append(bytes.to_array())
          }
          PdfV2ContentToken::HexString(text, bytes) => {
            out.write_string(text)
            raw.append(bytes.to_array())
          }
          _ => ()
        }
      }
      Some((out.to_string(), Bytes::from_array(raw)))
    }
    _ => text_from_pdf_v2_operand(operand)
  }
}

///|
fn last_operand(operands : Array[PdfV2ContentToken]) -> PdfV2ContentToken? {
  if operands.is_empty() {
    None
  } else {
    Some(operands[operands.length() - 1])
  }
}

///|
fn malformed_text_marker_event(
  tag : String,
  page_index : Int,
  stream : PdfV2CoreContentStream,
  source_ref : PdfV2SourceRef,
) -> PdfV2CoreTextEvent {
  let warning = pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedSource,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::TextOperator,
      Some(source_ref),
      stream.object_ref,
      Some(page_index),
      [],
    ),
    "malformed PDF text object",
    [tag, "malformed_text_object", "no_silent_loss"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
  {
    id: tag,
    page_index,
    content_order_index: source_ref.content_order_index.unwrap_or(0),
    object_ref: stream.object_ref,
    stream_ref: Some(stream.stream_ref),
    stream_index: Some(stream.stream_index),
    op_index: source_ref.op_index,
    text_object_id: source_ref.text_object_id,
    operator: tag,
    text: "",
    raw_bytes: None,
    font_name: None,
    font_size: None,
    origin: None,
    text_matrix: [],
    decode_confidence: 0.0,
    warnings: [warning],
    risks: [],
    source_ref,
    reason_tags: [tag, "malformed_text_object"],
  }
}

///|
fn unsupported_operator_marker_event(
  op : String,
  page_index : Int,
  stream : PdfV2CoreContentStream,
  source_ref : PdfV2SourceRef,
) -> PdfV2CoreTextEvent {
  let warning = pdf_v2_warning_for_context(
    PdfV2WarningKind::UnsupportedFeature,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::TextOperator,
      Some(source_ref),
      stream.object_ref,
      Some(page_index),
      [op],
    ),
    "unsupported PDF content stream operator",
    ["unsupported_operator", op, "no_silent_loss"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
  {
    id: "unsupported_operator_" + op,
    page_index,
    content_order_index: source_ref.content_order_index.unwrap_or(0),
    object_ref: stream.object_ref,
    stream_ref: Some(stream.stream_ref),
    stream_index: Some(stream.stream_index),
    op_index: source_ref.op_index,
    text_object_id: source_ref.text_object_id,
    operator: op,
    text: "",
    raw_bytes: None,
    font_name: None,
    font_size: None,
    origin: None,
    text_matrix: [],
    decode_confidence: 0.0,
    warnings: [warning],
    risks: [],
    source_ref,
    reason_tags: ["unsupported_operator", op],
  }
}

///|
fn op_looks_like_pdf_v2_text_operator(op : String) -> Bool {
  op == "Tc" ||
  op == "Tw" ||
  op == "Tz" ||
  op == "TL" ||
  op == "Tr" ||
  op == "Ts"
}

///|
fn page_boxes_from_dict(
  dict : String,
  objects : Array[PdfV2RawObject],
) -> PdfV2PageBoxes {
  let media = match numbers_after_key_or_parent(dict, objects, "MediaBox") {
    Some(values) => rect_from_numbers(values, pdf_v2_default_boxes().media_box)
    None => pdf_v2_default_boxes().media_box
  }
  {
    media_box: media,
    crop_box: match numbers_after_key_or_parent(dict, objects, "CropBox") {
      Some(values) => Some(rect_from_numbers(values, media))
      None => None
    },
    bleed_box: match numbers_after_key_or_parent(dict, objects, "BleedBox") {
      Some(values) => Some(rect_from_numbers(values, media))
      None => None
    },
    trim_box: match numbers_after_key_or_parent(dict, objects, "TrimBox") {
      Some(values) => Some(rect_from_numbers(values, media))
      None => None
    },
    art_box: match numbers_after_key_or_parent(dict, objects, "ArtBox") {
      Some(values) => Some(rect_from_numbers(values, media))
      None => None
    },
  }
}

///|
fn page_rotation_from_dict(
  dict : String,
  objects : Array[PdfV2RawObject],
) -> Int {
  match number_after_key_or_parent(dict, objects, "Rotate") {
    Some(value) => value.to_int()
    None => 0
  }
}

///|
fn page_user_unit_from_dict(
  dict : String,
  objects : Array[PdfV2RawObject],
) -> Double? {
  number_after_key_or_parent(dict, objects, "UserUnit")
}

///|
fn numbers_after_key_or_parent(
  dict : String,
  objects : Array[PdfV2RawObject],
  key : String,
) -> Array[Double]? {
  match pdf_v2_numbers_in_array_after_key(dict, key) {
    Some(values) => return Some(values)
    None => ()
  }
  match pdf_v2_ref_after_key(dict, "Parent") {
    Some(parent_ref) =>
      match find_raw_object(objects, parent_ref) {
        Some(parent) =>
          match parent.dictionary {
            Some(parent_dict) =>
              pdf_v2_numbers_in_array_after_key(parent_dict, key)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn number_after_key_or_parent(
  dict : String,
  objects : Array[PdfV2RawObject],
  key : String,
) -> Double? {
  match pdf_v2_number_after_key(dict, key) {
    Some(value) => return Some(value)
    None => ()
  }
  match pdf_v2_ref_after_key(dict, "Parent") {
    Some(parent_ref) =>
      match find_raw_object(objects, parent_ref) {
        Some(parent) =>
          match parent.dictionary {
            Some(parent_dict) => pdf_v2_number_after_key(parent_dict, key)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn rect_from_numbers(values : Array[Double], default : PdfV2Rect) -> PdfV2Rect {
  if values.length() >= 4 {
    { x0: values[0], y0: values[1], x1: values[2], y1: values[3] }
  } else {
    default
  }
}

///|
fn content_refs_from_page_dict(dict : String) -> Array[String] {
  match pdf_v2_ref_after_key(dict, "Contents") {
    Some(ref_text) => [ref_text]
    None => pdf_v2_refs_in_array_after_key(dict, "Contents")
  }
}

///|
fn find_raw_object(
  objects : Array[PdfV2RawObject],
  object_ref : String,
) -> PdfV2RawObject? {
  for object in objects {
    if object.object_ref == object_ref {
      return Some(object)
    }
  }
  None
}

///|
fn extract_pdf_v2_first_dictionary(body : String) -> String? {
  let start = body.find("<<")
  guard start is Some(start_index) else { return None }
  let chars = body.to_array()
  let mut depth = 0
  let mut i = start_index
  while i + 1 < chars.length() {
    if chars[i] == '<' && chars[i + 1] == '<' {
      depth = depth + 1
      i = i + 2
      continue
    }
    if chars[i] == '>' && chars[i + 1] == '>' {
      depth = depth - 1
      i = i + 2
      if depth == 0 {
        return Some(body[start_index:i].to_owned())
      }
      continue
    }
    i = i + 1
  }
  None
}

///|
fn extract_pdf_v2_stream_data(body : String) -> String? {
  match body.find("stream") {
    Some(stream_pos) =>
      match body[stream_pos + "stream".length():].find("endstream") {
        Some(end_rel) => {
          let start = trim_pdf_v2_stream_start(
            body,
            stream_pos + "stream".length(),
          )
          let end = stream_pos + "stream".length() + end_rel
          Some(trim_pdf_v2_stream_end(body[start:end].to_owned()))
        }
        None => None
      }
    None => None
  }
}

///|
fn trim_pdf_v2_stream_start(body : String, start : Int) -> Int {
  let chars = body.to_array()
  if start < chars.length() && chars[start] == '\r' {
    if start + 1 < chars.length() && chars[start + 1] == '\n' {
      return start + 2
    }
    return start + 1
  }
  if start < chars.length() && chars[start] == '\n' {
    return start + 1
  }
  start
}

///|
fn trim_pdf_v2_stream_end(text : String) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  if end > 0 && chars[end - 1] == '\n' {
    end = end - 1
  }
  if end > 0 && chars[end - 1] == '\r' {
    end = end - 1
  }
  String::from_array(chars[:end].to_owned())
}

///|
fn pdf_v2_ref_after_key(dict : String, key : String) -> String? {
  let chars = dict.to_array()
  match position_after_pdf_v2_key(dict, key) {
    Some(pos) => {
      let mut i = skip_pdf_v2_spaces(chars, pos)
      match parse_pdf_v2_uint_at(chars, i) {
        Some((object_number, after_object)) => {
          i = skip_pdf_v2_spaces(chars, after_object)
          match parse_pdf_v2_uint_at(chars, i) {
            Some((generation, after_generation)) => {
              i = skip_pdf_v2_spaces(chars, after_generation)
              if i < chars.length() && chars[i] == 'R' {
                Some(pdf_v2_object_ref_text(object_number, generation))
              } else {
                None
              }
            }
            None => None
          }
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn pdf_v2_refs_in_array_after_key(dict : String, key : String) -> Array[String] {
  let refs : Array[String] = []
  let chars = dict.to_array()
  match position_after_pdf_v2_key(dict, key) {
    Some(pos) => {
      let mut i = skip_pdf_v2_spaces(chars, pos)
      if i >= chars.length() || chars[i] != '[' {
        return refs
      }
      i = i + 1
      while i < chars.length() && chars[i] != ']' {
        i = skip_pdf_v2_spaces(chars, i)
        match parse_pdf_v2_uint_at(chars, i) {
          Some((object_number, after_object)) => {
            let mut cursor = skip_pdf_v2_spaces(chars, after_object)
            match parse_pdf_v2_uint_at(chars, cursor) {
              Some((generation, after_generation)) => {
                cursor = skip_pdf_v2_spaces(chars, after_generation)
                if cursor < chars.length() && chars[cursor] == 'R' {
                  refs.push(pdf_v2_object_ref_text(object_number, generation))
                  i = cursor + 1
                } else {
                  i = cursor + 1
                }
              }
              None => i = cursor + 1
            }
          }
          None => i = i + 1
        }
      }
    }
    None => ()
  }
  refs
}

///|
fn pdf_v2_name_after_key(dict : String, key : String) -> String? {
  let chars = dict.to_array()
  match position_after_pdf_v2_key(dict, key) {
    Some(pos) => {
      let mut i = skip_pdf_v2_spaces(chars, pos)
      if i >= chars.length() || chars[i] != '/' {
        return None
      }
      i = i + 1
      let start = i
      while i < chars.length() && !is_pdf_v2_delimiter(chars[i]) {
        i = i + 1
      }
      Some(String::from_array(chars[start:i].to_owned()))
    }
    None => None
  }
}

///|
fn pdf_v2_number_after_key(dict : String, key : String) -> Double? {
  let chars = dict.to_array()
  match position_after_pdf_v2_key(dict, key) {
    Some(pos) => {
      let i = skip_pdf_v2_spaces(chars, pos)
      parse_pdf_v2_number_at(chars, i).map(fn(pair) { pair.0 })
    }
    None => None
  }
}

///|
fn pdf_v2_numbers_in_array_after_key(
  dict : String,
  key : String,
) -> Array[Double]? {
  let chars = dict.to_array()
  match position_after_pdf_v2_key(dict, key) {
    Some(pos) => {
      let mut i = skip_pdf_v2_spaces(chars, pos)
      if i >= chars.length() || chars[i] != '[' {
        return None
      }
      i = i + 1
      let values : Array[Double] = []
      while i < chars.length() && chars[i] != ']' {
        i = skip_pdf_v2_spaces(chars, i)
        match parse_pdf_v2_number_at(chars, i) {
          Some((value, next)) => {
            values.push(value)
            i = next
          }
          None => i = i + 1
        }
      }
      Some(values)
    }
    None => None
  }
}

///|
fn pdf_v2_inline_dictionary_after_key(dict : String, key : String) -> String? {
  let chars = dict.to_array()
  match position_after_pdf_v2_key(dict, key) {
    Some(pos) => {
      let start = skip_pdf_v2_spaces(chars, pos)
      if start + 1 >= chars.length() ||
        chars[start] != '<' ||
        chars[start + 1] != '<' {
        return None
      }
      let mut depth = 0
      let mut i = start
      while i + 1 < chars.length() {
        if chars[i] == '<' && chars[i + 1] == '<' {
          depth = depth + 1
          i = i + 2
          continue
        }
        if chars[i] == '>' && chars[i + 1] == '>' {
          depth = depth - 1
          i = i + 2
          if depth == 0 {
            return Some(dict[start:i].to_owned())
          }
          continue
        }
        i = i + 1
      }
      None
    }
    None => None
  }
}

///|
fn pdf_v2_filter_names(dict : String) -> Array[String] {
  let names : Array[String] = []
  let chars = dict.to_array()
  match position_after_pdf_v2_key(dict, "Filter") {
    Some(pos) => {
      let mut i = skip_pdf_v2_spaces(chars, pos)
      if i < chars.length() && chars[i] == '[' {
        i = i + 1
        while i < chars.length() && chars[i] != ']' {
          i = skip_pdf_v2_spaces(chars, i)
          if i < chars.length() && chars[i] == '/' {
            let start = i + 1
            i = start
            while i < chars.length() && !is_pdf_v2_delimiter(chars[i]) {
              i = i + 1
            }
            names.push(String::from_array(chars[start:i].to_owned()))
          } else {
            i = i + 1
          }
        }
      } else if i < chars.length() && chars[i] == '/' {
        let start = i + 1
        i = start
        while i < chars.length() && !is_pdf_v2_delimiter(chars[i]) {
          i = i + 1
        }
        names.push(String::from_array(chars[start:i].to_owned()))
      }
    }
    None => ()
  }
  names
}

///|
fn font_ref_from_resources(resources : String, font_name : String) -> String? {
  let needle = "/" + font_name
  let chars = resources.to_array()
  match resources.find(needle) {
    Some(pos) => {
      let mut i = skip_pdf_v2_spaces(chars, pos + needle.length())
      match parse_pdf_v2_uint_at(chars, i) {
        Some((object_number, after_object)) => {
          i = skip_pdf_v2_spaces(chars, after_object)
          match parse_pdf_v2_uint_at(chars, i) {
            Some((generation, after_generation)) => {
              i = skip_pdf_v2_spaces(chars, after_generation)
              if i < chars.length() && chars[i] == 'R' {
                Some(pdf_v2_object_ref_text(object_number, generation))
              } else {
                None
              }
            }
            None => None
          }
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn position_after_pdf_v2_key(dict : String, key : String) -> Int? {
  let needle = "/" + key
  let chars = dict.to_array()
  let mut search_start = 0
  while search_start < dict.length() {
    match dict[search_start:].find(needle) {
      Some(rel) => {
        let pos = search_start + rel
        let after = pos + needle.length()
        if after >= chars.length() || is_pdf_v2_delimiter(chars[after]) {
          return Some(after)
        }
        search_start = after
      }
      None => return None
    }
  }
  None
}

///|
fn parse_pdf_v2_number_at(chars : Array[Char], start : Int) -> (Double, Int)? {
  let mut i = start
  if i >= chars.length() || !is_pdf_v2_number_start(chars[i]) {
    return None
  }
  while i < chars.length() && is_pdf_v2_number_char(chars[i]) {
    i = i + 1
  }
  let raw = String::from_array(chars[start:i].to_owned())
  match parse_pdf_v2_double(raw) {
    Some(value) => Some((value, i))
    None => None
  }
}

///|
fn parse_pdf_v2_double(raw : String) -> Double? {
  try @string.parse_double(raw) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_pdf_v2_uint_at(chars : Array[Char], start : Int) -> (Int, Int)? {
  let mut i = start
  if i >= chars.length() || !is_pdf_v2_digit(chars[i]) {
    return None
  }
  let mut value = 0
  while i < chars.length() && is_pdf_v2_digit(chars[i]) {
    value = value * 10 + (chars[i].to_int() - '0'.to_int())
    i = i + 1
  }
  Some((value, i))
}

///|
fn skip_pdf_v2_spaces(chars : Array[Char], start : Int) -> Int {
  let mut i = start
  while i < chars.length() && is_pdf_v2_space(chars[i]) {
    i = i + 1
  }
  i
}

///|
fn trim_pdf_v2_line_start(chars : Array[Char], start : Int) -> Int {
  let mut i = start
  while i < chars.length() && (chars[i] == ' ' || chars[i] == '\t') {
    i = i + 1
  }
  if i < chars.length() && chars[i] == '\r' {
    i = i + 1
    if i < chars.length() && chars[i] == '\n' {
      i = i + 1
    }
  } else if i < chars.length() && chars[i] == '\n' {
    i = i + 1
  }
  i
}

///|
fn matches_pdf_v2_word(chars : Array[Char], start : Int, word : String) -> Bool {
  let word_chars = word.to_array()
  if start + word_chars.length() > chars.length() {
    return false
  }
  for i in 0..<word_chars.length() {
    if chars[start + i] != word_chars[i] {
      return false
    }
  }
  let after = start + word_chars.length()
  after >= chars.length() || is_pdf_v2_delimiter(chars[after])
}

///|
fn is_pdf_v2_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_pdf_v2_number_start(ch : Char) -> Bool {
  is_pdf_v2_digit(ch) || ch == '-' || ch == '+' || ch == '.'
}

///|
fn is_pdf_v2_number_char(ch : Char) -> Bool {
  is_pdf_v2_digit(ch) || ch == '-' || ch == '+' || ch == '.'
}

///|
fn is_pdf_v2_space(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '\u{000C}' ||
  ch == '\u{0000}'
}

///|
fn is_pdf_v2_delimiter(ch : Char) -> Bool {
  is_pdf_v2_space(ch) ||
  ch == '(' ||
  ch == ')' ||
  ch == '<' ||
  ch == '>' ||
  ch == '[' ||
  ch == ']' ||
  ch == '{' ||
  ch == '}' ||
  ch == '/' ||
  ch == '%'
}

///|
fn pdf_v2_hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    return Some(ch.to_int() - '0'.to_int())
  }
  if ch >= 'a' && ch <= 'f' {
    return Some(ch.to_int() - 'a'.to_int() + 10)
  }
  if ch >= 'A' && ch <= 'F' {
    return Some(ch.to_int() - 'A'.to_int() + 10)
  }
  None
}

///|
fn pdf_v2_object_ref_text(object_number : Int, generation : Int) -> String {
  object_number.to_string() + " " + generation.to_string() + " R"
}

///|
fn content_source_ref(
  page_index : Int,
  object_ref : String?,
  stream_index : Int,
  op_index : Int?,
  content_order_index : Int?,
  text_object_id : Int?,
) -> PdfV2SourceRef {
  {
    page_index,
    object_ref,
    stream_index: Some(stream_index),
    op_index,
    content_order_index,
    text_object_id,
  }
}

///|
fn page_object_source_ref(
  page_index : Int,
  object_ref : String,
) -> PdfV2SourceRef {
  {
    page_index,
    object_ref: Some(object_ref),
    stream_index: None,
    op_index: None,
    content_order_index: None,
    text_object_id: None,
  }
}

///|
fn string_to_pdf_v2_bytes(text : String) -> Bytes {
  let raw : Array[Byte] = []
  for ch in text.to_array() {
    push_pdf_v2_char_byte(raw, ch)
  }
  Bytes::from_array(raw)
}

///|
fn push_pdf_v2_char_byte(raw : Array[Byte], ch : Char) -> Unit {
  let code = ch.to_int()
  if code >= 0 && code <= 255 {
    raw.push(code.to_byte())
  } else {
    raw.push('?'.to_int().to_byte())
  }
}

///|
fn content_stream_warnings(
  streams : Array[PdfV2CoreContentStream],
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  for stream in streams {
    warnings.append(stream.warnings)
  }
  warnings
}

///|
fn content_stream_risks(
  streams : Array[PdfV2CoreContentStream],
) -> Array[PdfV2Risk] {
  let risks : Array[PdfV2Risk] = []
  for stream in streams {
    risks.append(stream.risks)
  }
  risks
}

///|
fn text_event_warnings(
  events : Array[PdfV2CoreTextEvent],
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  for event in events {
    warnings.append(event.warnings)
  }
  warnings
}

///|
fn text_event_risks(events : Array[PdfV2CoreTextEvent]) -> Array[PdfV2Risk] {
  let risks : Array[PdfV2Risk] = []
  for event in events {
    risks.append(event.risks)
  }
  risks
}

///|
fn pdf_v2_malformed_header_warning() -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedSource,
    PdfV2Severity::Error,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      None,
      None,
      None,
      [],
    ),
    "PDF header is missing or malformed",
    ["malformed_pdf_header", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_malformed_header_risk() -> PdfV2Risk {
  pdf_v2_risk_for_context(
    PdfV2RiskKind::MalformedObject,
    PdfV2RiskSeverity::Error,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      None,
      None,
      None,
      [],
    ),
    "malformed PDF header prevents reliable object graph extraction",
    ["malformed_pdf_header", "fail_closed"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_trailer_missing_warning() -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedObject,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::XrefTable,
      None,
      None,
      None,
      [],
    ),
    "PDF trailer is missing from minimal reader scan",
    ["trailer_missing", "xref", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_no_indirect_objects_warning() -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedObject,
    PdfV2Severity::Error,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      None,
      None,
      None,
      [],
    ),
    "minimal PDF reader found no indirect objects",
    ["object_graph", "empty_object_scan", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_no_pages_warning() -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::LowSignalDocument,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::PageTree,
      None,
      None,
      None,
      [],
    ),
    "minimal PDF reader found no readable pages",
    ["page_tree", "low_signal_document", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_no_text_ops_warning(
  source_ref : PdfV2SourceRef,
  object_ref : String?,
  page_index : Int,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::LowSignal,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::TextOperator,
      Some(source_ref),
      object_ref,
      Some(page_index),
      [],
    ),
    "content stream contained no supported text showing operators",
    ["no_text_operator", "content_stream", "no_silent_loss"],
    PdfV2Recoverability::Recoverable,
  )
}
