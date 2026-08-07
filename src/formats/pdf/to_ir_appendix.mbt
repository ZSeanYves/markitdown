///|
pub fn pdf_native_appendix_blocks(
  metadata : Map[String, @core.JsonValue],
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  let annotation_lines = pdf_native_annotation_appendix_lines(metadata)
  if annotation_lines.length() > 0 {
    blocks.push(pdf_native_appendix_heading("Annotations"))
    blocks.push(pdf_native_appendix_list(annotation_lines))
  }
  let form_lines = pdf_native_form_appendix_lines(metadata)
  if form_lines.length() > 0 {
    blocks.push(pdf_native_appendix_heading("Forms"))
    blocks.push(pdf_native_appendix_list(form_lines))
  }
  let bookmark_lines = pdf_native_bookmark_appendix_lines(metadata)
  if bookmark_lines.length() > 0 {
    blocks.push(pdf_native_appendix_heading("Bookmarks"))
    blocks.push(pdf_native_appendix_list(bookmark_lines))
  }
  blocks
}

///|
fn pdf_native_appendix_heading(title : String) -> @core.CoreBlock {
  let heading = @core.make_block(Heading, title)
  heading.attrs.set("level", "2")
  heading
}

///|
fn pdf_native_appendix_list(lines : Array[String]) -> @core.CoreBlock {
  let items = lines.map(line => @core.make_block(ListItem, line))
  @core.block_with_children(@core.make_block(List, ""), items)
}

///|
fn pdf_native_annotation_appendix_lines(
  metadata : Map[String, @core.JsonValue],
) -> Array[String] {
  let lines : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  match metadata.get("pdf_native_annotations") {
    Some(Array(items)) => {
      let ordered : Array[@core.JsonValue] = []
      ordered.append(items[:])
      ordered.sort_by(fn(left, right) {
        pdf_native_annotation_appendix_compare(left, right)
      })
      for item in ordered {
        match pdf_native_annotation_line(item) {
          Some(line) =>
            if !seen.contains(line) {
              seen.set(line, true)
              lines.push(line)
            }
          None => ()
        }
      }
    }
    _ => ()
  }
  lines
}

///|
fn pdf_native_annotation_line(item : @core.JsonValue) -> String? {
  let payload = match item {
    Object(value) => value
    _ => return None
  }
  let subtype = pdf_native_json_string_field(payload, "subtype").unwrap_or("")
  if subtype == "" || subtype == "Widget" {
    return None
  }
  if !pdf_native_annotation_should_render(payload) {
    return None
  }
  let page = pdf_native_json_string_field(payload, "page").unwrap_or("?")
  let action_kind = pdf_native_json_string_field(payload, "action_kind")
  let target = pdf_native_json_string_field(payload, "target")
  let destination = pdf_native_json_object_field(payload, "destination")
  if subtype == "Link" {
    match action_kind {
      Some("URI") => return None
      _ => ()
    }
    let target_text = match
      pdf_native_annotation_visible_target(target, destination) {
      Some(value) => value
      None => return None
    }
    return Some("Link (page " + page + "): " + target_text)
  }
  let title = pdf_native_json_string_field(payload, "title")
  let subject = pdf_native_json_string_field(payload, "subject")
  let text = pdf_native_json_string_field(payload, "text")
  let file_name = pdf_native_json_string_field(payload, "file_name")
  let fallback_target = pdf_native_annotation_visible_target(
    target, destination,
  )
  let summary = if subtype == "FileAttachment" {
    pdf_native_fact_summary_text(title, file_name, fallback_target)
  } else {
    pdf_native_annotation_summary_text(
      subtype, title, subject, text, fallback_target,
    )
  }
  match summary {
    Some(value) =>
      Some(
        pdf_native_annotation_display_subtype(subtype) +
        " (page " +
        page +
        "): " +
        value,
      )
    None => None
  }
}

///|
fn pdf_native_annotation_summary_text(
  subtype : String,
  title : String?,
  subject : String?,
  text : String?,
  fallback_target : String?,
) -> String? {
  let normalized_title = pdf_native_nonempty_trimmed(title)
  let normalized_subject = pdf_native_nonempty_trimmed(subject)
  let normalized_text = pdf_native_nonempty_trimmed(text)
  let preferred_title = pdf_native_annotation_preferred_title(
    subtype, normalized_title, normalized_subject, normalized_text,
  )
  match (subtype, normalized_subject, normalized_title, normalized_text) {
    ("Square", Some(subject_value), Some(title_value), Some(text_value)) =>
      if title_value == text_value {
        return Some(subject_value)
      }
    ("Circle", Some(subject_value), Some(title_value), Some(text_value)) =>
      if title_value == text_value {
        return Some(subject_value)
      }
    _ => ()
  }
  pdf_native_fact_summary_text(
    preferred_title, normalized_text, fallback_target,
  )
}

///|
fn pdf_native_annotation_preferred_title(
  subtype : String,
  title : String?,
  subject : String?,
  text : String?,
) -> String? {
  let normalized_subtype = subtype.trim().to_owned()
  match subject {
    Some(value) if value.trim() != "" =>
      if pdf_native_annotation_subject_is_preferred(
          normalized_subtype, value, title, text,
        ) {
        Some(value)
      } else {
        title
      }
    _ => title
  }
}

///|
fn pdf_native_annotation_subject_is_preferred(
  subtype : String,
  subject : String,
  title : String?,
  text : String?,
) -> Bool {
  let normalized_subject = subject.trim().to_owned()
  if normalized_subject == "" {
    return false
  }
  match title {
    Some(value) if value.trim() == normalized_subject => return false
    _ => ()
  }
  match text {
    Some(value) if value.trim() == normalized_subject => return false
    _ => ()
  }
  match subtype {
    "Line" => true
    "Square" => true
    "Circle" => true
    "Underline" => true
    "StrikeOut" => true
    "Squiggly" => true
    _ => false
  }
}

///|
fn pdf_native_form_appendix_lines(
  metadata : Map[String, @core.JsonValue],
) -> Array[String] {
  let lines : Array[String] = []
  match metadata.get("pdf_native_form_fields") {
    Some(Array(items)) => {
      let ordered : Array[@core.JsonValue] = []
      ordered.append(items[:])
      ordered.sort_by(fn(left, right) {
        pdf_native_form_appendix_compare(left, right)
      })
      for item in ordered {
        match pdf_native_form_line(item) {
          Some(line) => lines.push(line)
          None => ()
        }
      }
    }
    _ => ()
  }
  lines
}

///|
fn pdf_native_form_line(item : @core.JsonValue) -> String? {
  let payload = match item {
    Object(value) => value
    _ => return None
  }
  let page = pdf_native_json_string_field(payload, "page").unwrap_or("?")
  let kind = pdf_native_json_string_field(payload, "field_type").unwrap_or("")
  let label = pdf_native_form_display_label(payload)
  let field_value = pdf_native_form_visible_value(
    kind,
    pdf_native_json_string_field(payload, "value"),
    pdf_native_json_string_field(payload, "default_value"),
  )
  let options = pdf_native_json_string_array_field(payload, "options")
  let prefix = pdf_native_form_display_kind(kind) + " (page " + page + "): "
  let label_text = match label {
    Some(value) => value
    None => pdf_native_form_fallback_label(kind, payload)
  }
  match (field_value, options.length()) {
    (Some(value), count) =>
      if count > 0 &&
        kind == "Ch" &&
        pdf_native_form_should_prefer_options(payload) {
        Some(
          prefix +
          label_text +
          " — options: " +
          pdf_native_form_options_summary(options),
        )
      } else {
        Some(
          prefix +
          label_text +
          " — " +
          pdf_native_form_display_value(kind, value),
        )
      }
    (None, count) if count > 0 =>
      Some(
        prefix +
        label_text +
        " — options: " +
        pdf_native_form_options_summary(options),
      )
    _ => None
  }
}

///|
fn pdf_native_bookmark_appendix_lines(
  metadata : Map[String, @core.JsonValue],
) -> Array[String] {
  let lines : Array[String] = []
  match metadata.get("pdf_native_outline_items") {
    Some(Array(items)) => {
      let ordered : Array[@core.JsonValue] = []
      ordered.append(items[:])
      ordered.sort_by(fn(left, right) {
        pdf_native_bookmark_appendix_compare(left, right)
      })
      for item in ordered {
        match pdf_native_bookmark_line(item) {
          Some(line) => lines.push(line)
          None => ()
        }
      }
    }
    _ => ()
  }
  lines
}

///|
fn pdf_native_bookmark_line(item : @core.JsonValue) -> String? {
  let payload = match item {
    Object(value) => value
    _ => return None
  }
  let title = pdf_native_json_string_field(payload, "title").unwrap_or("")
  if title.trim() == "" {
    return None
  }
  let title_text = pdf_native_bookmark_title(title, payload)
  let target = match pdf_native_bookmark_target(payload) {
    Some(value) => value
    None => return Some(title_text)
  }
  Some(title_text + " -> " + target)
}

///|
fn pdf_native_json_string_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> String? {
  match payload.get(key) {
    Some(String(value)) => Some(value)
    Some(Number(value)) => Some(value)
    Some(Bool(value)) => Some(if value { "true" } else { "false" })
    _ => None
  }
}

///|
fn pdf_native_json_number_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> Int? {
  match payload.get(key) {
    Some(Number(value)) => pdf_native_parse_int(value)
    Some(String(value)) => pdf_native_parse_int(value)
    _ => None
  }
}

///|
fn pdf_native_json_bool_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> Bool? {
  match payload.get(key) {
    Some(Bool(value)) => Some(value)
    Some(String("true")) => Some(true)
    Some(String("false")) => Some(false)
    _ => None
  }
}

///|
fn pdf_native_json_object_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> Map[String, @core.JsonValue]? {
  match payload.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_native_json_string_array_field(
  payload : Map[String, @core.JsonValue],
  key : String,
) -> Array[String] {
  match payload.get(key) {
    Some(Array(items)) =>
      items
      .map(item => pdf_native_json_metric_string(item))
      .filter(item => item.trim() != "")
    _ => []
  }
}

///|
fn pdf_native_form_display_kind(kind : String) -> String {
  match kind {
    "Btn" => "Button"
    "Ch" => "Choice"
    "Tx" => "Text"
    _ => if kind.trim() != "" { kind } else { "Field" }
  }
}

///|
fn pdf_native_annotation_display_subtype(subtype : String) -> String {
  match subtype {
    "FileAttachment" => "FileAttachment"
    _ => subtype
  }
}

///|
fn pdf_native_annotation_appendix_compare(
  left : @core.JsonValue,
  right : @core.JsonValue,
) -> Int {
  let left_payload = match left {
    Object(value) => value
    _ => return 0
  }
  let right_payload = match right {
    Object(value) => value
    _ => return 0
  }
  pdf_native_compare_payload_fields(left_payload, right_payload, [
    "page", "annotation_index", "object_id", "subtype", "text", "title",
  ])
}

///|
fn pdf_native_form_appendix_compare(
  left : @core.JsonValue,
  right : @core.JsonValue,
) -> Int {
  let left_payload = match left {
    Object(value) => value
    _ => return 0
  }
  let right_payload = match right {
    Object(value) => value
    _ => return 0
  }
  pdf_native_compare_payload_fields(left_payload, right_payload, [
    "page", "object_id", "widget_object_id", "alternate_name", "field_name", "field_type",
  ])
}

///|
fn pdf_native_bookmark_appendix_compare(
  left : @core.JsonValue,
  right : @core.JsonValue,
) -> Int {
  let left_payload = match left {
    Object(value) => value
    _ => return 0
  }
  let right_payload = match right {
    Object(value) => value
    _ => return 0
  }
  pdf_native_compare_payload_fields(left_payload, right_payload, [
    "order_index", "level", "page", "title", "object_id",
  ])
}

///|
fn pdf_native_compare_payload_fields(
  left : Map[String, @core.JsonValue],
  right : Map[String, @core.JsonValue],
  keys : Array[String],
) -> Int {
  for key in keys {
    let left_number = pdf_native_json_number_field(left, key)
    let right_number = pdf_native_json_number_field(right, key)
    match (left_number, right_number) {
      (Some(lv), Some(rv)) =>
        if lv < rv {
          return -1
        } else if lv > rv {
          return 1
        }
      _ => ()
    }
    let left_text = pdf_native_json_string_field(left, key).unwrap_or("")
    let right_text = pdf_native_json_string_field(right, key).unwrap_or("")
    if left_text < right_text {
      return -1
    } else if left_text > right_text {
      return 1
    }
  }
  0
}

///|
fn pdf_native_annotation_visible_target(
  target : String?,
  destination : Map[String, @core.JsonValue]?,
) -> String? {
  match target {
    Some(value) if !pdf_native_looks_like_uri(value) && value.trim() != "" =>
      Some(value)
    _ => pdf_native_destination_visible_target(destination)
  }
}

///|
fn pdf_native_annotation_should_render(
  payload : Map[String, @core.JsonValue],
) -> Bool {
  let hidden = pdf_native_json_bool_field(payload, "flag_hidden").unwrap_or(
    false,
  )
  let print = pdf_native_json_bool_field(payload, "flag_print").unwrap_or(false)
  let no_view = pdf_native_json_bool_field(payload, "flag_no_view").unwrap_or(
    false,
  )
  if no_view && !print {
    return false
  }
  if hidden && !print {
    return false
  }
  true
}

///|
fn pdf_native_destination_visible_target(
  destination : Map[String, @core.JsonValue]?,
) -> String? {
  let payload = match destination {
    Some(value) => value
    None => return None
  }
  match pdf_native_json_string_field(payload, "target_page_index") {
    Some(page) if page.trim() != "" => Some("page " + page)
    _ =>
      match pdf_native_json_string_field(payload, "name") {
        Some(value) if value.trim() != "" =>
          Some(
            "named destination \"" +
            pdf_native_appendix_quoted(value.trim().to_owned()) +
            "\"",
          )
        _ =>
          if pdf_native_destination_has_visible_hint(payload) {
            Some("unresolved destination")
          } else {
            None
          }
      }
  }
}

///|
fn pdf_native_destination_has_visible_hint(
  payload : Map[String, @core.JsonValue],
) -> Bool {
  match pdf_native_json_string_field(payload, "raw_value") {
    Some(value) if value.trim() != "" => true
    _ =>
      match pdf_native_json_string_field(payload, "kind") {
        Some(value) if value.trim() != "" => true
        _ =>
          pdf_native_json_number_field(payload, "target_page_object_id")
          is Some(_) ||
          pdf_native_json_number_field(payload, "object_id") is Some(_)
      }
  }
}

///|
fn pdf_native_form_display_label(
  payload : Map[String, @core.JsonValue],
) -> String? {
  match pdf_native_json_string_field(payload, "alternate_name") {
    Some(value) if value.trim() != "" => return Some(value.trim().to_owned())
    _ => ()
  }
  match pdf_native_json_string_field(payload, "field_name") {
    Some(value) if value.trim() != "" => Some(value.trim().to_owned())
    _ => None
  }
}

///|
fn pdf_native_form_visible_value(
  _kind : String,
  value : String?,
  default_value : String?,
) -> String? {
  match value {
    Some(text) if text.trim() != "" => Some(text.trim().to_owned())
    _ =>
      match default_value {
        Some(text) if text.trim() != "" => Some(text.trim().to_owned())
        _ => None
      }
  }
}

///|
fn pdf_native_form_display_value(kind : String, value : String) -> String {
  match kind {
    "Btn" =>
      if value == "true" {
        "checked"
      } else if value == "false" {
        "unchecked"
      } else {
        value
      }
    _ => value
  }
}

///|
fn pdf_native_form_options_summary(options : Array[String]) -> String {
  options.join(", ")
}

///|
fn pdf_native_form_fallback_label(
  kind : String,
  payload : Map[String, @core.JsonValue],
) -> String {
  match kind {
    "Btn" =>
      match pdf_native_json_string_field(payload, "field_name") {
        Some(value) if value.trim() != "" => value.trim().to_owned()
        _ => "Button"
      }
    "Ch" => "Choice"
    "Tx" => "Text"
    _ => "Field"
  }
}

///|
fn pdf_native_form_should_prefer_options(
  payload : Map[String, @core.JsonValue],
) -> Bool {
  let flags = pdf_native_json_number_field(payload, "flags").unwrap_or(0)
  let read_only = (flags & 1) != 0
  read_only
}

///|
fn pdf_native_bookmark_title(
  title : String,
  payload : Map[String, @core.JsonValue],
) -> String {
  match pdf_native_json_number_field(payload, "level") {
    Some(level) if level > 0 => title
    _ => title
  }
}

///|
fn pdf_native_bookmark_target(
  payload : Map[String, @core.JsonValue],
) -> String? {
  let destination_target = pdf_native_destination_visible_target(
    pdf_native_json_object_field(payload, "destination"),
  )
  match pdf_native_json_string_field(payload, "target") {
    Some(value) if value.trim() != "" =>
      if pdf_native_looks_like_raw_destination_target(value) {
        destination_target
      } else {
        Some(value)
      }
    _ => destination_target
  }
}

///|
fn pdf_native_looks_like_raw_destination_target(value : String) -> Bool {
  let trimmed = value.trim().to_owned()
  trimmed.has_prefix("/") ||
  trimmed.contains("<<") ||
  trimmed.contains("[") ||
  trimmed.contains(" R ") ||
  trimmed.has_suffix(" R") ||
  trimmed.contains("/Fit") ||
  trimmed.contains("/XYZ")
}

///|
fn pdf_native_fact_summary_text(
  title : String?,
  text : String?,
  fallback_target : String?,
) -> String? {
  match (title, text) {
    (Some(left), Some(right)) if left.trim() != "" && right.trim() != "" =>
      Some(left + " — " + right)
    (Some(left), _) if left.trim() != "" => Some(left)
    (_, Some(right)) if right.trim() != "" => Some(right)
    _ => fallback_target
  }
}

///|
fn pdf_native_nonempty_trimmed(value : String?) -> String? {
  match value {
    Some(text) => {
      let trimmed = text.trim()
      if trimmed == "" {
        None
      } else {
        Some(trimmed.to_owned())
      }
    }
    None => None
  }
}

///|
fn pdf_native_looks_like_uri(value : String) -> Bool {
  let lowered = value.to_lower()
  lowered.has_prefix("http://") ||
  lowered.has_prefix("https://") ||
  lowered.has_prefix("file://") ||
  lowered.has_prefix("mailto:")
}

///|
fn pdf_native_parse_int(value : String) -> Int? {
  Some(@string.parse_int(value.trim().to_owned()) catch { _ => return None })
}

///|
fn pdf_native_appendix_quoted(value : String) -> String {
  value.replace(old="\"", new="\\\"")
}

///|
fn pdf_native_json_metric_string(value : @core.JsonValue) -> String {
  match value {
    String(text) => text
    Number(text) => text
    Bool(flag) => if flag { "true" } else { "false" }
    _ => ""
  }
}

///|
fn pdf_native_annotation_json(
  annotation : PdfNativeAnnotation,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("subtype", String(annotation.subtype))
  payload.set("page", Number(annotation.page_index.to_string()))
  match annotation.bbox {
    Some(bbox) => payload.set("bbox", pdf_native_bbox_json(bbox))
    None => ()
  }
  match annotation.text {
    Some(value) => payload.set("text", String(value))
    None => ()
  }
  match annotation.title {
    Some(value) => payload.set("title", String(value))
    None => ()
  }
  match annotation.subject {
    Some(value) => payload.set("subject", String(value))
    None => ()
  }
  match annotation.file_name {
    Some(value) => payload.set("file_name", String(value))
    None => ()
  }
  match annotation.name {
    Some(value) => payload.set("name", String(value))
    None => ()
  }
  match annotation.modified_at {
    Some(value) => payload.set("modified_at", String(value))
    None => ()
  }
  match annotation.action_kind {
    Some(value) => payload.set("action_kind", String(value))
    None => ()
  }
  match annotation.target {
    Some(value) => payload.set("target", String(value))
    None => ()
  }
  match annotation.annotation_index {
    Some(value) => payload.set("annotation_index", Number(value.to_string()))
    None => ()
  }
  match annotation.object_id {
    Some(value) => payload.set("object_id", Number(value.to_string()))
    None => ()
  }
  match annotation.destination {
    Some(value) =>
      payload.set("destination", pdf_native_destination_json(value))
    None => ()
  }
  Object(payload)
}

///|
fn pdf_native_form_field_json(field : PdfNativeFormField) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  match field.page_index {
    Some(value) => payload.set("page", Number(value.to_string()))
    None => ()
  }
  match field.field_type {
    Some(value) => payload.set("field_type", String(value))
    None => ()
  }
  match field.field_name {
    Some(value) => payload.set("field_name", String(value))
    None => ()
  }
  match field.alternate_name {
    Some(value) => payload.set("alternate_name", String(value))
    None => ()
  }
  match field.value {
    Some(value) => payload.set("value", String(value))
    None => ()
  }
  match field.default_value {
    Some(value) => payload.set("default_value", String(value))
    None => ()
  }
  if field.options.length() > 0 {
    payload.set("options", Array(field.options.map(value => String(value))))
  }
  match field.bbox {
    Some(bbox) => payload.set("bbox", pdf_native_bbox_json(bbox))
    None => ()
  }
  match field.object_id {
    Some(value) => payload.set("object_id", Number(value.to_string()))
    None => ()
  }
  match field.widget_object_id {
    Some(value) => payload.set("widget_object_id", Number(value.to_string()))
    None => ()
  }
  match field.flags {
    Some(value) => payload.set("flags", Number(value.to_string()))
    None => ()
  }
  Object(payload)
}

///|
fn pdf_native_outline_item_json(item : PdfNativeOutlineItem) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("title", String(item.title))
  payload.set("level", Number(item.level.to_string()))
  payload.set("order_index", Number(item.order_index.to_string()))
  match item.page_index {
    Some(value) => payload.set("page", Number(value.to_string()))
    None => ()
  }
  match item.action_kind {
    Some(value) => payload.set("action_kind", String(value))
    None => ()
  }
  match item.target {
    Some(value) => payload.set("target", String(value))
    None => ()
  }
  match item.destination {
    Some(value) =>
      payload.set("destination", pdf_native_destination_json(value))
    None => ()
  }
  match item.object_id {
    Some(value) => payload.set("object_id", Number(value.to_string()))
    None => ()
  }
  Object(payload)
}

///|
fn pdf_native_destination_json(
  destination : PdfNativeDestination,
) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  match destination.page_index {
    Some(value) => payload.set("page_index", Number(value.to_string()))
    None => ()
  }
  match destination.target_page_index {
    Some(value) => payload.set("target_page_index", Number(value.to_string()))
    None => ()
  }
  match destination.target_page_object_id {
    Some(value) =>
      payload.set("target_page_object_id", Number(value.to_string()))
    None => ()
  }
  match destination.kind {
    Some(value) => payload.set("kind", String(value))
    None => ()
  }
  match destination.raw_value {
    Some(value) => payload.set("raw_value", String(value))
    None => ()
  }
  match destination.name {
    Some(value) => payload.set("name", String(value))
    None => ()
  }
  match destination.object_id {
    Some(value) => payload.set("object_id", Number(value.to_string()))
    None => ()
  }
  Object(payload)
}

///|
fn pdf_native_bbox_json(bbox : PdfBBox) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("x", Number(bbox.x.to_string()))
  payload.set("y", Number(bbox.y.to_string()))
  payload.set("width", Number(bbox.width.to_string()))
  payload.set("height", Number(bbox.height.to_string()))
  payload.set("x1", Number(pdf_bbox_right(bbox).to_string()))
  payload.set("y1", Number(pdf_bbox_bottom(bbox).to_string()))
  Object(payload)
}

///|
fn pdf_native_core_bbox_json(bbox : @core.BBox) -> @core.JsonValue {
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("x0", Number(bbox.x0.to_string()))
  payload.set("y0", Number(bbox.y0.to_string()))
  payload.set("x1", Number(bbox.x1.to_string()))
  payload.set("y1", Number(bbox.y1.to_string()))
  Object(payload)
}
