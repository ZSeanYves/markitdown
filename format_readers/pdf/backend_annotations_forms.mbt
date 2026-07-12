///|
fn pdf_annotation_from_object(
  source : @input.InputSource,
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  page_index : Int,
  annotation_index : Int,
  object_id : Int,
  page_numbers : Map[Int, Int],
) -> PdfNativeAnnotation? {
  let subtype = match pdf_extract_name_after(object.dict_text, "/Subtype") {
    Some(value) => value
    None => return None
  }
  let resolved_page_index = pdf_page_index_from_object(
    object.dict_text,
    page_numbers,
  ).unwrap_or(page_index)
  let flags = pdf_extract_int_after(object.dict_text, "/F")
  if !pdf_annotation_should_surface(subtype, flags) {
    return None
  }
  let bbox = pdf_extract_rect_after(object.dict_text, "/Rect")
  let source_ref = match bbox {
    Some(value) =>
      Some(
        pdf_native_source_ref(
          source,
          resolved_page_index,
          value,
          None,
          None,
          0.0,
        ),
      )
    None => None
  }
  let action = pdf_annotation_action_summary(
    object.dict_text,
    object_index,
    resolved_page_index,
    source_ref,
    page_numbers,
  )
  let destination = match
    pdf_destination_from_key(
      object.dict_text,
      "/Dest",
      object_index,
      resolved_page_index,
      source_ref,
      page_numbers,
    ) {
    Some(value) => Some(value)
    None => action.2
  }
  let target = match action.1 {
    Some(value) => Some(value)
    None =>
      match destination {
        Some(dest) => pdf_destination_target_text(dest)
        None => None
      }
  }
  let text = pdf_annotation_text(object.dict_text)
  Some(
    make_pdf_native_annotation(
      resolved_page_index,
      subtype,
      bbox~,
      text~,
      title=pdf_extract_string_after(object.dict_text, "/T"),
      subject=pdf_extract_string_after(object.dict_text, "/Subj"),
      file_name=pdf_annotation_file_name(object.dict_text, object_index),
      name=pdf_extract_string_after(object.dict_text, "/NM"),
      modified_at=pdf_extract_string_after(object.dict_text, "/M"),
      action_kind=action.0,
      target~,
      destination~,
      source_ref~,
      annotation_index=Some(annotation_index),
      object_id=Some(object_id),
    ),
  )
}

///|
fn pdf_annotation_text(dict_text : String) -> String? {
  for key in ["/Contents", "/TU", "/T", "/V"] {
    match pdf_extract_string_after(dict_text, key) {
      Some(value) if value.trim() != "" =>
        return Some(pdf_annotation_normalized_text(value))
      _ => ()
    }
  }
  None
}

///|
fn pdf_annotation_normalized_text(value : String) -> String {
  value
  .split("\n")
  .to_array()
  .map(line => line.trim().to_owned())
  .filter(line => line != "")
  .join(" / ")
}

///|
fn pdf_annotation_should_surface(subtype : String, flags : Int?) -> Bool {
  if subtype == "Widget" {
    return true
  }
  let value = flags.unwrap_or(0)
  let hidden = pdf_annotation_flag_is_set(value, 1)
  let print = pdf_annotation_flag_is_set(value, 2)
  let no_view = pdf_annotation_flag_is_set(value, 5)
  if no_view && !print {
    return false
  }
  if hidden && !print {
    return false
  }
  true
}

///|
fn pdf_annotation_flag_is_set(flags : Int, bit_index : Int) -> Bool {
  (flags & (1 << bit_index)) != 0
}

///|
fn pdf_annotation_file_name(
  dict_text : String,
  object_index : Map[Int, PdfNativeObject],
) -> String? {
  let file_spec = match
    pdf_inline_or_referenced_dict_text(dict_text, "/FS", object_index) {
    Some(value) => value
    None => return None
  }
  for key in ["/UF", "/F", "/Desc"] {
    match pdf_extract_string_after(file_spec, key) {
      Some(value) if value.trim() != "" => return Some(value.trim().to_owned())
      _ => ()
    }
  }
  None
}

///|
fn pdf_file_spec_display_name(
  dict_text : String,
  key : String,
  object_index : Map[Int, PdfNativeObject],
) -> String? {
  match pdf_extract_string_after(dict_text, key) {
    Some(value) if value.trim() != "" => return Some(value.trim().to_owned())
    _ => ()
  }
  let file_spec = match
    pdf_inline_or_referenced_dict_text(dict_text, key, object_index) {
    Some(value) => value
    None => return None
  }
  for candidate in ["/UF", "/F", "/Desc"] {
    match pdf_extract_string_after(file_spec, candidate) {
      Some(value) if value.trim() != "" => return Some(value.trim().to_owned())
      _ => ()
    }
  }
  None
}

///|
fn pdf_action_external_target_text(
  action_text : String,
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
) -> String? {
  let file_name = pdf_file_spec_display_name(action_text, "/F", object_index)
  let destination = pdf_destination_from_key(
    action_text,
    "/D",
    object_index,
    0,
    None,
    page_numbers,
  )
  let destination_text = match destination {
    Some(value) =>
      match pdf_destination_target_text(value) {
        Some(text) => Some(text)
        None =>
          match value.raw_value {
            Some(raw) if raw.trim() != "" => Some(raw.trim().to_owned())
            _ => None
          }
      }
    None =>
      match pdf_extract_raw_string_after(action_text, "/D") {
        Some(value) if value.trim() != "" => Some(value.trim().to_owned())
        _ => None
      }
  }
  match (file_name, destination_text) {
    (Some(file), Some(dest)) => Some(file + " -> " + dest)
    (Some(file), None) => Some(file)
    (None, Some(dest)) => Some(dest)
    (None, None) => Some(action_text.trim().to_owned())
  }
}

///|
fn pdf_native_backend_annotation_json(
  annotation : PdfNativeAnnotation,
  object_index : Map[Int, PdfNativeObject],
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("subtype", @core.JsonValue::String(annotation.subtype))
  payload.set(
    "page",
    @core.JsonValue::Number(annotation.page_index.to_string()),
  )
  match annotation.bbox {
    Some(bbox) => payload.set("bbox", pdf_native_backend_bbox_json_value(bbox))
    None => ()
  }
  match annotation.text {
    Some(value) => payload.set("text", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.title {
    Some(value) => payload.set("title", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.subject {
    Some(value) => payload.set("subject", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.file_name {
    Some(value) => payload.set("file_name", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.name {
    Some(value) => payload.set("name", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.modified_at {
    Some(value) => payload.set("modified_at", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.action_kind {
    Some(value) => payload.set("action_kind", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.target {
    Some(value) => payload.set("target", @core.JsonValue::String(value))
    None => ()
  }
  match annotation.annotation_index {
    Some(value) =>
      payload.set(
        "annotation_index",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match annotation.object_id {
    Some(value) =>
      payload.set("object_id", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match annotation.destination {
    Some(value) =>
      payload.set("destination", pdf_native_backend_destination_json(value))
    None => ()
  }
  match annotation.object_id {
    Some(object_id) =>
      match object_index.get(object_id) {
        Some(object) =>
          match pdf_extract_int_after(object.dict_text, "/F") {
            Some(value) => {
              payload.set("flags", @core.JsonValue::Number(value.to_string()))
              payload.set(
                "flag_hidden",
                @core.JsonValue::Bool((value & (1 << 1)) != 0),
              )
              payload.set(
                "flag_print",
                @core.JsonValue::Bool((value & (1 << 2)) != 0),
              )
              payload.set(
                "flag_no_view",
                @core.JsonValue::Bool((value & (1 << 5)) != 0),
              )
            }
            None => ()
          }
        None => ()
      }
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_backend_destination_json(
  destination : PdfNativeDestination,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  match destination.page_index {
    Some(value) =>
      payload.set("page_index", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  match destination.target_page_index {
    Some(value) =>
      payload.set(
        "target_page_index",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match destination.target_page_object_id {
    Some(value) =>
      payload.set(
        "target_page_object_id",
        @core.JsonValue::Number(value.to_string()),
      )
    None => ()
  }
  match destination.kind {
    Some(value) => payload.set("kind", @core.JsonValue::String(value))
    None => ()
  }
  match destination.raw_value {
    Some(value) => payload.set("raw_value", @core.JsonValue::String(value))
    None => ()
  }
  match destination.name {
    Some(value) => payload.set("name", @core.JsonValue::String(value))
    None => ()
  }
  match destination.object_id {
    Some(value) =>
      payload.set("object_id", @core.JsonValue::Number(value.to_string()))
    None => ()
  }
  @core.JsonValue::Object(payload)
}

///|
fn pdf_native_backend_bbox_json_value(bbox : PdfBBox) -> @core.JsonValue {
  @core.JsonValue::Object(
    Map([
      ("x", @core.JsonValue::String(bbox.x.to_string())),
      ("y", @core.JsonValue::String(bbox.y.to_string())),
      ("width", @core.JsonValue::String(bbox.width.to_string())),
      ("height", @core.JsonValue::String(bbox.height.to_string())),
    ]),
  )
}

///|
fn pdf_annotation_action_summary(
  dict_text : String,
  object_index : Map[Int, PdfNativeObject],
  page_index : Int,
  source_ref : @core.SourceRef?,
  page_numbers : Map[Int, Int],
) -> (String?, String?, PdfNativeDestination?) {
  let action_text = match
    pdf_inline_or_referenced_dict_text(dict_text, "/A", object_index) {
    Some(value) => value
    None => return (None, None, None)
  }
  let action_kind = pdf_extract_name_after(action_text, "/S")
  match action_kind {
    Some("URI") =>
      (Some("URI"), pdf_extract_string_after(action_text, "/URI"), None)
    Some("GoTo") => {
      let destination = pdf_destination_from_key(
        action_text, "/D", object_index, page_index, source_ref, page_numbers,
      )
      (
        Some("GoTo"),
        match destination {
          Some(dest) => pdf_destination_target_text(dest)
          None => None
        },
        destination,
      )
    }
    Some("GoToR") =>
      (
        Some("GoToR"),
        pdf_action_external_target_text(action_text, object_index, page_numbers),
        None,
      )
    Some("Launch") =>
      (
        Some("Launch"),
        match
          pdf_action_external_target_text(
            action_text, object_index, page_numbers,
          ) {
          Some(value) => Some(value)
          None => pdf_extract_raw_string_after(action_text, "/F")
        },
        None,
      )
    Some(kind) =>
      (
        Some(kind),
        match
          pdf_action_external_target_text(
            action_text, object_index, page_numbers,
          ) {
          Some(value) => Some(value)
          None => Some(action_text.trim().to_owned())
        },
        None,
      )
    None => (None, None, None)
  }
}

///|
fn pdf_destination_from_key(
  dict_text : String,
  key : String,
  object_index : Map[Int, PdfNativeObject],
  page_index : Int,
  source_ref : @core.SourceRef?,
  page_numbers : Map[Int, Int],
) -> PdfNativeDestination? {
  match pdf_extract_dict_value(dict_text, key) {
    Some(value) =>
      pdf_destination_from_value(
        value, object_index, page_index, source_ref, page_numbers,
      )
    None => None
  }
}

///|
fn pdf_destination_from_value(
  value : PdfNativeDictValue,
  object_index : Map[Int, PdfNativeObject],
  page_index : Int,
  source_ref : @core.SourceRef?,
  page_numbers : Map[Int, Int],
) -> PdfNativeDestination? {
  match value {
    PdfNativeDictValue::Reference(object_id, generation) => {
      ignore(generation)
      match object_index.get(object_id) {
        Some(object) =>
          match pdf_extract_dict_value(object.dict_text, "/D") {
            Some(inner) =>
              pdf_destination_from_value(
                inner, object_index, page_index, source_ref, page_numbers,
              )
            None =>
              Some(
                make_pdf_native_destination(
                  page_index=Some(page_index),
                  raw_value=Some(object.dict_text),
                  source_ref~,
                  object_id=Some(object_id),
                ),
              )
          }
        None => None
      }
    }
    PdfNativeDictValue::Array(tokens) =>
      pdf_destination_from_tokens(tokens, page_index, source_ref, page_numbers)
    PdfNativeDictValue::Name(name) =>
      Some(
        make_pdf_native_destination(
          page_index=Some(page_index),
          raw_value=Some("/" + name),
          name=Some(name),
          source_ref~,
        ),
      )
    PdfNativeDictValue::LiteralString(text) =>
      Some(
        make_pdf_native_destination(
          page_index=Some(page_index),
          raw_value=Some(pdf_normalize_pdf_text(text.decoded)),
          name=Some(pdf_normalize_pdf_text(text.decoded)),
          source_ref~,
        ),
      )
    PdfNativeDictValue::HexString(hex) =>
      match pdf_decode_hex_pdf_text(hex, None) {
        Some(decoded) =>
          Some(
            make_pdf_native_destination(
              page_index=Some(page_index),
              raw_value=Some(decoded),
              name=Some(decoded),
              source_ref~,
            ),
          )
        None => None
      }
    PdfNativeDictValue::Dict(dict_text) =>
      match pdf_extract_dict_value(dict_text, "/D") {
        Some(inner) =>
          pdf_destination_from_value(
            inner, object_index, page_index, source_ref, page_numbers,
          )
        None =>
          Some(
            make_pdf_native_destination(
              page_index=Some(page_index),
              raw_value=Some(dict_text),
              source_ref~,
            ),
          )
      }
    _ => None
  }
}

///|
fn pdf_destination_from_tokens(
  tokens : Array[PdfNativeContentToken],
  page_index : Int,
  source_ref : @core.SourceRef?,
  page_numbers : Map[Int, Int],
) -> PdfNativeDestination? {
  let target_page_object_id = pdf_collect_reference_ids_from_tokens(tokens).get(
    0,
  )
  let target_page_index = match target_page_object_id {
    Some(object_id) => page_numbers.get(object_id)
    None => None
  }
  let kind = if tokens.length() >= 4 { pdf_token_name(tokens[3]) } else { None }
  let raw_value = pdf_destination_tokens_text(tokens)
  Some(
    make_pdf_native_destination(
      page_index=Some(page_index),
      target_page_index~,
      target_page_object_id~,
      kind~,
      raw_value=Some(raw_value),
      source_ref~,
      object_id=target_page_object_id,
    ),
  )
}

///|
fn pdf_destination_tokens_text(tokens : Array[PdfNativeContentToken]) -> String {
  let parts : Array[String] = []
  for token in tokens {
    match token {
      PdfNativeContentToken::Name(value) => parts.push("/" + value)
      PdfNativeContentToken::Word(value) => parts.push(value)
      PdfNativeContentToken::Number(value) => parts.push(value.to_string())
      PdfNativeContentToken::LiteralString(value) =>
        parts.push(pdf_normalize_pdf_text(value.decoded))
      PdfNativeContentToken::HexString(value) =>
        match pdf_decode_hex_pdf_text(value, None) {
          Some(decoded) => parts.push(decoded)
          None => parts.push(value)
        }
      _ => ()
    }
  }
  parts.join(" ")
}

///|
fn pdf_destination_target_text(destination : PdfNativeDestination) -> String? {
  match destination.target_page_index {
    Some(page) => Some("page " + page.to_string())
    None =>
      match destination.name {
        Some(value) if value.trim() != "" =>
          Some(
            "named destination \"" +
            pdf_destination_display_name(value.trim().to_owned()) +
            "\"",
          )
        _ =>
          if pdf_destination_has_visible_hint(destination) {
            Some("unresolved destination")
          } else {
            None
          }
      }
  }
}

///|
fn pdf_destination_display_name(name : String) -> String {
  name.replace(old="\"", new="\\\"")
}

///|
fn pdf_destination_has_visible_hint(destination : PdfNativeDestination) -> Bool {
  match destination.raw_value {
    Some(value) if value.trim() != "" => true
    _ =>
      match destination.kind {
        Some(value) if value.trim() != "" => true
        _ =>
          destination.target_page_object_id is Some(_) ||
          destination.object_id is Some(_)
      }
  }
}

///|
fn pdf_inline_or_referenced_dict_text(
  dict_text : String,
  key : String,
  object_index : Map[Int, PdfNativeObject],
) -> String? {
  match pdf_extract_dict_value(dict_text, key) {
    Some(PdfNativeDictValue::Dict(value)) => Some(value)
    Some(PdfNativeDictValue::Reference(object_id, generation)) => {
      ignore(generation)
      match object_index.get(object_id) {
        Some(object) => Some(object.dict_text)
        None => None
      }
    }
    _ => None
  }
}

///|
fn pdf_extract_form_fields(
  source : @input.InputSource,
  trailer_hints : Array[String],
  object_index : Map[Int, PdfNativeObject],
  page_numbers : Map[Int, Int],
  annotation_pages : Map[Int, Int],
) -> Array[PdfNativeFormField] {
  let catalog = match pdf_catalog_object(trailer_hints, object_index) {
    Some(value) => value
    None => return []
  }
  let acroform = match
    pdf_inline_or_referenced_dict_text(
      catalog.dict_text,
      "/AcroForm",
      object_index,
    ) {
    Some(value) => value
    None => return []
  }
  let refs = pdf_extract_object_references_after(acroform, "/Fields")
  let out : Array[PdfNativeFormField] = []
  let visited : Map[Int, Bool] = Map([])
  let seen : Map[String, Bool] = Map([])
  for ref_id in refs {
    match object_index.get(ref_id) {
      Some(object) =>
        out.append(
          pdf_form_fields_from_object(
            source,
            object,
            object_index,
            ref_id,
            None,
            None,
            None,
            None,
            None,
            [],
            None,
            page_numbers,
            annotation_pages,
            None,
            visited,
            seen,
            0,
          )[:],
        )
      None => ()
    }
  }
  out
}

///|
fn pdf_form_fields_from_object(
  source : @input.InputSource,
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
  object_id : Int,
  inherited_type : String?,
  inherited_name : String?,
  inherited_alt_name : String?,
  inherited_value : String?,
  inherited_default_value : String?,
  inherited_options : Array[String],
  inherited_flags : Int?,
  page_numbers : Map[Int, Int],
  annotation_pages : Map[Int, Int],
  inherited_page_index : Int?,
  visited : Map[Int, Bool],
  seen : Map[String, Bool],
  depth : Int,
) -> Array[PdfNativeFormField] {
  if depth >= 32 || visited.get(object_id).unwrap_or(false) {
    return []
  }
  visited.set(object_id, true)
  let field_type = match pdf_extract_name_after(object.dict_text, "/FT") {
    Some(value) => Some(value)
    None => inherited_type
  }
  let field_name = pdf_form_field_inherit_text(
    pdf_extract_string_after(object.dict_text, "/T"),
    inherited_name,
  )
  let alt_name = pdf_form_field_inherit_text(
    pdf_extract_string_after(object.dict_text, "/TU"),
    inherited_alt_name,
  )
  let field_value = match pdf_extract_form_value(object.dict_text, field_type) {
    Some(value) => Some(value)
    None => inherited_value
  }
  let default_value = match pdf_extract_form_default_value(object.dict_text) {
    Some(value) => Some(value)
    None => inherited_default_value
  }
  let direct_options = pdf_extract_form_options(object.dict_text)
  let options = if direct_options.length() > 0 {
    direct_options
  } else {
    inherited_options
  }
  let flags = match pdf_extract_int_after(object.dict_text, "/Ff") {
    Some(value) => Some(value)
    None => inherited_flags
  }
  let kids = pdf_extract_object_references_after(object.dict_text, "/Kids")
  let page_index = match
    pdf_page_index_from_object(object.dict_text, page_numbers) {
    Some(value) => Some(value)
    None =>
      match annotation_pages.get(object_id) {
        Some(value) => Some(value)
        None => inherited_page_index
      }
  }
  let bbox = pdf_extract_rect_after(object.dict_text, "/Rect")
  let is_widget = match pdf_extract_name_after(object.dict_text, "/Subtype") {
    Some("Widget") => true
    _ => bbox is Some(_) || annotation_pages.contains(object_id)
  }
  let source_ref = match (page_index, bbox) {
    (Some(page), Some(rect)) =>
      Some(pdf_native_source_ref(source, page, rect, None, None, 0.0))
    _ => None
  }
  let widget_object_id = if is_widget { Some(object_id) } else { None }
  let should_emit = if is_widget {
    true
  } else if kids.length() == 0 {
    pdf_form_field_has_visible_facts(
      field_type, field_name, alt_name, field_value, default_value, options,
    )
  } else {
    false
  }
  let dedup_key = match widget_object_id {
    Some(value) => "widget:" + value.to_string()
    None => "field:" + object_id.to_string()
  }
  let field = if should_emit && !seen.get(dedup_key).unwrap_or(false) {
    seen.set(dedup_key, true)
    [
      make_pdf_native_form_field(
        page_index~,
        field_type~,
        field_name~,
        alternate_name=alt_name,
        value=field_value,
        default_value~,
        options~,
        bbox~,
        source_ref~,
        object_id=Some(object_id),
        widget_object_id~,
        flags~,
      ),
    ]
  } else {
    []
  }
  let out : Array[PdfNativeFormField] = []
  out.append(field[:])
  for kid_id in kids {
    match object_index.get(kid_id) {
      Some(kid) =>
        out.append(
          pdf_form_fields_from_object(
            source,
            kid,
            object_index,
            kid_id,
            field_type,
            field_name,
            alt_name,
            field_value,
            default_value,
            options,
            flags,
            page_numbers,
            annotation_pages,
            page_index,
            visited,
            seen,
            depth + 1,
          )[:],
        )
      None => ()
    }
  }
  out
}

///|
fn pdf_form_field_inherit_text(value : String?, inherited : String?) -> String? {
  match value {
    Some(text) if text.trim() != "" => Some(text)
    _ => inherited
  }
}

///|
fn pdf_form_field_has_visible_facts(
  field_type : String?,
  field_name : String?,
  alt_name : String?,
  value : String?,
  default_value : String?,
  options : Array[String],
) -> Bool {
  if field_type is Some(_) {
    true
  } else {
    match field_name {
      Some(text) if text.trim() != "" => true
      _ =>
        match alt_name {
          Some(text) if text.trim() != "" => true
          _ =>
            match value {
              Some(text) if text.trim() != "" => true
              _ =>
                match default_value {
                  Some(text) if text.trim() != "" => true
                  _ => options.length() > 0
                }
            }
        }
    }
  }
}

///|
fn pdf_extract_form_value(dict_text : String, field_type : String?) -> String? {
  match field_type {
    Some("Btn") =>
      match pdf_extract_string_after(dict_text, "/V") {
        Some("Off") => Some("false")
        Some(_) => Some("true")
        None =>
          match pdf_extract_name_after(dict_text, "/AS") {
            Some("Off") => Some("false")
            Some(_) => Some("true")
            None => Some("false")
          }
      }
    Some("Ch") =>
      match pdf_extract_string_array_after(dict_text, "/V") {
        [] => None
        [value] => Some(pdf_annotation_normalized_text(value))
        values =>
          Some(
            values
            .map(value => pdf_annotation_normalized_text(value))
            .join(", "),
          )
      }
    _ =>
      match pdf_extract_raw_string_after(dict_text, "/V") {
        Some(value) => Some(pdf_form_normalized_value_text(value))
        None => None
      }
  }
}

///|
fn pdf_extract_form_default_value(dict_text : String) -> String? {
  match pdf_extract_string_array_after(dict_text, "/DV") {
    [] =>
      match pdf_extract_raw_string_after(dict_text, "/DV") {
        Some(value) => Some(pdf_form_normalized_value_text(value))
        None => None
      }
    [value] => Some(pdf_form_normalized_value_text(value))
    values =>
      Some(
        values.map(value => pdf_form_normalized_value_text(value)).join(", "),
      )
  }
}

///|
fn pdf_extract_form_options(dict_text : String) -> Array[String] {
  let raw = pdf_extract_string_array_after(dict_text, "/Opt")
  let deduped : Array[String] = []
  for value in raw {
    let normalized = pdf_form_normalized_value_text(value)
    if normalized != "" && !deduped.contains(normalized) {
      deduped.push(normalized)
    }
  }
  deduped
}

///|
fn pdf_form_normalized_value_text(value : String) -> String {
  let segments : Array[String] = []
  let current : Array[Char] = []
  let chars = value.to_array()
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    if ch == '\r' || ch == '\n' {
      let segment = pdf_normalize_pdf_text(String::from_array(current))
      if segment != "" {
        segments.push(segment)
      }
      current.clear()
      if ch == '\r' && index + 1 < chars.length() && chars[index + 1] == '\n' {
        index += 1
      }
    } else {
      current.push(ch)
    }
    index += 1
  }
  let tail = pdf_normalize_pdf_text(String::from_array(current))
  if tail != "" {
    segments.push(tail)
  }
  segments.join(" / ")
}
