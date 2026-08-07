///|
fn push_unique_string(items : Array[String], value : String) -> Unit {
  for existing in items {
    if existing == value {
      return
    }
  }
  items.push(value)
}

///|
fn docx_source_ref_from_key(
  state : DocxLoweringState,
  key : @ddocx.DocxSourceKey,
  relationship_id : String?,
  shape_id : String?,
) -> @core.SourceRef {
  let container_path = @input.input_path(state.source).unwrap_or(
    state.source.source_name,
  )
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(state.source.source_name),
    Some("docx"),
    Some(container_path),
    Some(key.part_name),
    None,
    Some("xml"),
    Some(key.part_name),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(state.source.source_name),
    Some("docx"),
    Some(key.part_name),
    None,
    None,
    None,
    shape_id,
    relationship_id,
  )
  let with_block = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(office, "part_name", key.part_name),
      "block_index",
      key.block_index.to_string(),
    ),
    "paragraph_index",
    key.block_index.to_string(),
  )
  @core.source_ref_with_extra(with_block, "node_key", key.node_key)
}

///|
fn docx_part_source_ref(
  state : DocxLoweringState,
  part_name : String,
  relationship_id : String?,
) -> @core.SourceRef {
  let container_path = @input.input_path(state.source).unwrap_or(
    state.source.source_name,
  )
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(state.source.source_name),
    Some("docx"),
    Some(container_path),
    Some(part_name),
    None,
    Some("xml"),
    Some(part_name),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(state.source.source_name),
    Some("docx"),
    Some(part_name),
    None,
    None,
    None,
    None,
    relationship_id,
  )
  @core.source_ref_with_extra(office, "part_name", part_name)
}

///|
fn bump_metric(diagnostics : @core.Diagnostics, key : String) -> Unit {
  let current = metric_int(diagnostics, key)
  diagnostics.metrics.set(key, (current + 1).to_string())
}

///|
fn count_docx_macro_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    match part.content_type {
      Some(value) => if value.contains("macroEnabled") { count += 1 }
      None => ()
    }
  }
  count
}

///|
fn count_docx_ole_object_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.contains("/embeddings/") ||
      part.part_name.contains("oleObject") {
      count += 1
    }
  }
  count
}

///|
fn docx_media_path_ext(path : String) -> String {
  let trimmed = path.trim().to_lower()
  match trimmed.split(".").to_array().last() {
    Some(ext) =>
      if ext == "png" ||
        ext == "jpg" ||
        ext == "jpeg" ||
        ext == "gif" ||
        ext == "bmp" ||
        ext == "tif" ||
        ext == "tiff" ||
        ext == "webp" ||
        ext == "svg" {
        if ext == "jpeg" {
          "jpg"
        } else {
          ext.to_owned()
        }
      } else {
        "bin"
      }
    None => "bin"
  }
}

///|
fn docx_media_content_type_ext(content_type : String?) -> String? {
  match content_type {
    Some(value) => {
      let lower = value.trim().to_lower()
      if lower == "image/png" {
        Some("png")
      } else if lower == "image/jpeg" || lower == "image/jpg" {
        Some("jpg")
      } else if lower == "image/gif" {
        Some("gif")
      } else if lower == "image/bmp" {
        Some("bmp")
      } else if lower == "image/tif" || lower == "image/tiff" {
        Some("tiff")
      } else if lower == "image/webp" {
        Some("webp")
      } else if lower == "image/svg+xml" {
        Some("svg")
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn docx_media_output_ext(
  media : @ddocx.DocxMediaRef,
  target_part : String,
) -> String {
  match docx_media_content_type_ext(media.content_type) {
    Some(ext) => ext
    None => docx_media_path_ext(target_part)
  }
}

///|
fn docx_media_should_render_as_image(
  media : @ddocx.DocxMediaRef,
  target_part : String,
) -> Bool {
  let ext = docx_media_output_ext(media, target_part)
  ext == "png" ||
  ext == "jpg" ||
  ext == "gif" ||
  ext == "bmp" ||
  ext == "tiff" ||
  ext == "webp" ||
  ext == "svg"
}

///|
fn docx_media_should_export_asset(
  media : @ddocx.DocxMediaRef,
  target_part : String,
) -> Bool {
  docx_media_should_render_as_image(media, target_part)
}

///|
fn docx_materialize_companion_assets(
  state : DocxLoweringState,
  companions : Array[@ddocx.DocxMediaRef],
  shape_id : String?,
) -> Unit {
  for media in companions {
    match media.target_mode {
      Some(External) => continue
      _ => ()
    }
    if media.target_exists == Some(false) {
      continue
    }
    let target_part = match media.target_part {
      Some(value) => value
      None => continue
    }
    if !docx_media_should_export_asset(media, target_part) {
      continue
    }
    if !docx_asset_within_budget(state, target_part) {
      docx_record_asset_budget_skip(state, "docx:" + target_part, target_part)
      continue
    }
    let source_ref = docx_source_ref_from_key(
      state,
      media.source_key,
      media.relationship_id,
      shape_id,
    )
    let output_path = docx_asset_output_path(state, target_part, media)
    let asset = ensure_docx_asset_ref(state, media, output_path, source_ref)
    ignore(asset)
  }
}

///|
fn docx_asset_within_budget(
  state : DocxLoweringState,
  target_part : String,
) -> Bool {
  if state.asset_ids.contains(target_part) {
    return true
  }
  let declared = match @ox.part_declared_size(state.pkg, target_part) {
    Some(value) => value.to_int64()
    None => return false
  }
  @parser.asset_payload_within_limits(
    state.context,
    declared,
    docx_declared_asset_bytes(state.assets),
  )
}

///|
fn docx_declared_asset_bytes(assets : Array[@core.AssetRef]) -> Int64 {
  let mut total = 0L
  for asset in assets {
    match asset.attrs.get("declared_asset_bytes") {
      Some(raw) => total += (@string.parse_int(raw) catch { _ => 0 }).to_int64()
      None => ()
    }
  }
  total
}

///|
fn docx_record_asset_budget_skip(
  state : DocxLoweringState,
  asset_id : String,
  target_part : String,
) -> Unit {
  let observed = @ox.part_declared_size(state.pkg, target_part).unwrap_or(-1)
  @parser.record_asset_payload_budget_skip(
    state.diagnostics,
    asset_id,
    "single_or_total_asset_bytes",
    observed.to_int64(),
    @parser.max_asset_payload_bytes(state.context),
  )
  bump_metric(state.diagnostics, "skipped_asset_count")
}

///|
fn docx_two_digits(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn docx_image_alt_text(media : @ddocx.DocxMediaRef) -> String {
  match media.alt_text {
    Some(value) => if value.trim() != "" { return value.trim().to_owned() }
    None => ()
  }
  match media.title {
    Some(value) => if value.trim() != "" { return value.trim().to_owned() }
    None => ()
  }
  "image"
}

///|
fn normalize_docx_optional_text(value : String?) -> String? {
  match value {
    Some(text) =>
      if text.trim() == "" {
        None
      } else {
        Some(text.trim().to_owned())
      }
    None => None
  }
}

///|
fn docx_note_marker_label(label : String, note_kind : String) -> String {
  match note_kind {
    "comment" => "[comment " + label + "]"
    "endnote" => "[^e" + label + "]"
    _ => "[^" + label + "]"
  }
}

///|
fn docx_reference_inline(
  state : DocxLoweringState,
  source_key : @ddocx.DocxSourceKey,
  note_kind~ : String,
  note_id~ : String,
  marker~ : String,
) -> @core.CoreInline {
  let source_ref = docx_source_ref_from_key(state, source_key, None, None)
  let inline = @core.make_inline_text(marker, source_ref~)
  let inline = @core.inline_with_attr(inline, "annotation_role", "note_ref")
  let inline = @core.inline_with_attr(inline, "annotation_kind", note_kind)
  let inline = @core.inline_with_attr(inline, "annotation_id", note_id)
  let inline = @core.inline_with_attr(inline, "annotation_marker", marker)
  @core.inline_with_attr(inline, "render_literal", "true")
}

///|
fn docx_inline_spacing_source_ref(
  source_ref : @core.SourceRef,
) -> @core.SourceRef {
  source_ref
}

///|
fn docx_paragraph_heading_level(
  style : @ddocx.DocxStyle?,
  p : @ddocx.DocxParagraph,
) -> Int? {
  ignore(p)
  match style {
    Some(value) => docx_style_heading_level(value)
    None => None
  }
}

///|
fn docx_style_heading_level(style : @ddocx.DocxStyle) -> Int? {
  match docx_heading_level_from_label(style.style_id) {
    Some(level) => Some(level)
    None =>
      match style.name {
        Some(name) => docx_heading_level_from_label(name)
        None => None
      }
  }
}

///|
fn docx_heading_level_from_label(label : String) -> Int? {
  let normalized = docx_normalize_style_label(label)
  if normalized == "heading1" {
    Some(1)
  } else if normalized == "heading2" {
    Some(2)
  } else if normalized == "heading3" {
    Some(3)
  } else if normalized == "heading4" {
    Some(4)
  } else if normalized == "heading5" {
    Some(5)
  } else if normalized == "heading6" {
    Some(6)
  } else {
    None
  }
}

///|
fn docx_paragraph_list_lowering(
  docx : @ddocx.DocxDocument,
  p : @ddocx.DocxParagraph,
) -> (Bool, Int)? {
  match docx_resolve_paragraph_list_level(docx, p) {
    Some(level) =>
      match level.num_fmt {
        Some(num_fmt) => {
          let normalized = docx_normalize_style_label(num_fmt)
          if normalized == "bullet" {
            Some((false, docx_numbering_level_index(level.ilvl)))
          } else if normalized == "decimal" {
            Some((true, docx_numbering_level_index(level.ilvl)))
          } else {
            None
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn docx_resolve_paragraph_list_level(
  docx : @ddocx.DocxDocument,
  p : @ddocx.DocxParagraph,
) -> @ddocx.DocxNumberingLevel? {
  match @ddocx.docx_resolve_paragraph_numbering_level(docx, p) {
    Some(level) => return Some(level)
    None => ()
  }
  let style_id = match p.style_id {
    Some(value) => docx_normalize_style_label(value)
    None => return None
  }
  for level in docx.numbering.levels {
    if docx_numbering_level_style_matches(level, style_id) {
      return Some(level)
    }
  }
  None
}

///|
fn docx_numbering_level_style_matches(
  level : @ddocx.DocxNumberingLevel,
  normalized_style_id : String,
) -> Bool {
  match level.paragraph_style_id {
    Some(value) =>
      if docx_normalize_style_label(value) == normalized_style_id {
        return true
      }
    None => ()
  }
  match level.style_link {
    Some(value) =>
      if docx_normalize_style_label(value) == normalized_style_id {
        return true
      }
    None => ()
  }
  match level.num_style_link {
    Some(value) =>
      if docx_normalize_style_label(value) == normalized_style_id {
        return true
      }
    None => ()
  }
  false
}

///|
fn docx_numbering_level_index(ilvl : String) -> Int {
  match docx_parse_nonnegative_int(ilvl) {
    Some(value) => value
    None => 0
  }
}

///|
fn docx_paragraph_is_code_style(
  style : @ddocx.DocxStyle?,
  p : @ddocx.DocxParagraph,
  plain_text : String,
) -> Bool {
  match style {
    Some(value) =>
      docx_style_label_matches(value, [
        "code", "pre", "preformatted", "htmlpreformatted", "sourcecode",
      ]) ||
      docx_paragraph_has_code_shape(p, plain_text)
    None =>
      match p.style_id {
        Some(style_id) =>
          docx_style_labels_match(style_id, None, [
            "code", "pre", "preformatted", "htmlpreformatted", "sourcecode",
          ]) ||
          docx_paragraph_has_code_shape(p, plain_text)
        None => docx_paragraph_has_code_shape(p, plain_text)
      }
  }
}

///|
fn docx_paragraph_is_quote_style(
  style : @ddocx.DocxStyle?,
  p : @ddocx.DocxParagraph,
) -> Bool {
  match style {
    Some(value) =>
      docx_style_label_matches(value, [
        "quote", "intensequote", "blockquote", "blockquotetext",
      ])
    None =>
      match p.style_id {
        Some(style_id) =>
          docx_style_labels_match(style_id, None, [
            "quote", "intensequote", "blockquote", "blockquotetext",
          ])
        None => false
      }
  }
}

///|
fn docx_style_label_matches(
  style : @ddocx.DocxStyle,
  labels : Array[String],
) -> Bool {
  docx_style_labels_match(style.style_id, style.name, labels)
}

///|
fn docx_style_labels_match(
  style_id_raw : String,
  style_name_raw : String?,
  labels : Array[String],
) -> Bool {
  let style_id = docx_normalize_style_label(style_id_raw)
  for label in labels {
    if style_id == label {
      return true
    }
  }
  match style_name_raw {
    Some(name) => {
      let style_name = docx_normalize_style_label(name)
      for label in labels {
        if style_name == label {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn docx_lookup_footnote(
  state : DocxLoweringState,
  note_id : String,
) -> @ddocx.DocxNote? {
  state.footnotes_by_id.get(note_id)
}

///|
fn docx_lookup_endnote(
  state : DocxLoweringState,
  note_id : String,
) -> @ddocx.DocxNote? {
  state.endnotes_by_id.get(note_id)
}

///|
fn docx_lookup_comment(
  state : DocxLoweringState,
  comment_id : String,
) -> @ddocx.DocxComment? {
  state.comments_by_id.get(comment_id)
}

///|
fn docx_paragraph_has_code_shape(
  p : @ddocx.DocxParagraph,
  plain_text : String,
) -> Bool {
  let normalized = plain_text
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
  if !normalized.contains("\n") {
    return false
  }
  if docx_paragraph_alignment_is_center(p) {
    return false
  }
  let lines = normalized
    .split("\n")
    .map(fn(value) { value.to_owned() })
    .filter(fn(value) { value.trim() != "" })
    .iter()
    .collect()
  if lines.length() < 2 {
    return false
  }
  let mut text_like_line_count = 0
  let mut codeish = false
  for line in lines {
    let trimmed = line.trim()
    if trimmed != "" {
      text_like_line_count += 1
    }
    if trimmed.contains("=") ||
      trimmed.contains("(") ||
      trimmed.contains(")") ||
      trimmed.contains(";") ||
      trimmed.contains("{") ||
      trimmed.contains("}") {
      codeish = true
    }
  }
  if codeish {
    return true
  }
  ignore(text_like_line_count)
  false
}

///|
fn render_docx_plain_text_only(inlines : Array[@ddocx.DocxInline]) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline {
      Text(text) => out.write_string(text)
      Tab => out.write_string("\t")
      LineBreak => out.write_string("\n")
      Break(value) => out.write_string(render_docx_break_text(value))
      Hyperlink(link) => out.write_string(link.text)
      ContentControl(control) => out.write_string(control.text)
      FieldUnsupported(field) => out.write_string(render_docx_field_text(field))
      Math(math) => out.write_string(render_docx_math_text(math))
      TrackedChange(change) =>
        out.write_string(render_docx_tracked_change_text(change))
      SmartTag(smart_tag) =>
        out.write_string(render_docx_plain_text_only(smart_tag.child_inlines))
      Symbol(symbol) => out.write_string(render_docx_symbol_text(symbol))
      Hyphen(hyphen) => out.write_string(render_docx_hyphen_text(hyphen))
      FootnoteRef(id) =>
        out.write_string(docx_note_marker_label(id, "footnote"))
      EndnoteRef(id) => out.write_string(docx_note_marker_label(id, "endnote"))
      CommentRef(id) =>
        out.write_string(" " + docx_note_marker_label(id, "comment"))
      _ => ()
    }
  }
  normalize_docx_ref_marker_spacing(out.to_string())
}

///|
fn docx_paragraph_alignment_is_center(p : @ddocx.DocxParagraph) -> Bool {
  match p.alignment {
    Some(value) => docx_normalize_style_label(value) == "center"
    None => false
  }
}

///|
fn docx_paragraph_is_page_number_field_only(p : @ddocx.DocxParagraph) -> Bool {
  let text = render_docx_plain_text_only(p.inlines).trim().to_owned()
  if text == "" {
    return false
  }
  let mut saw_page_field = false
  for inline in p.inlines {
    match inline {
      FieldUnsupported(field) =>
        match field.instruction {
          Some(instruction) =>
            if docx_normalize_style_label(instruction).contains("page") {
              saw_page_field = true
            }
          None => ()
        }
      _ => ()
    }
  }
  if !saw_page_field {
    return false
  }
  let normalized = docx_normalize_style_label(text)
    .replace(old="[", new="")
    .replace(old="]", new="")
  let digits_only = normalized
    .replace(old="page", new="")
    .replace(old=" ", new="")
  if digits_only == "" {
    return false
  }
  for ch in digits_only {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn docx_list_item_text(text : String) -> String {
  text
  .replace(old="\r\n", new="\n")
  .replace(old="\r", new="\n")
  .split("\n")
  .map(fn(value) { value.trim().to_owned() })
  .filter(fn(value) { value != "" })
  .iter()
  .collect()
  .join("<br>")
}

///|
fn render_docx_break_text(value : @ddocx.DocxBreak) -> String {
  match value.kind {
    Line => "\n"
    CarriageReturn => "\n"
    TextWrapping => "\n"
    Page => "\n"
    Column => "\n"
    Unknown => ""
  }
}

///|
fn render_docx_field_text(field : @ddocx.DocxField) -> String {
  match field.result_text {
    Some(value) => value
    None =>
      match field.instruction {
        Some(value) => "[" + value + "]"
        None => ""
      }
  }
}

///|
fn render_docx_math_text(math : @ddocx.DocxMath) -> String {
  match math.text_signature {
    Some(value) => value
    None => "[math]"
  }
}

///|
fn render_docx_tracked_change_text(change : @ddocx.DocxTrackedChange) -> String {
  if change.text.trim() != "" {
    change.text
  } else {
    render_docx_plain_text_only(change.child_inlines)
  }
}

///|
fn render_docx_symbol_text(symbol : @ddocx.DocxSymbol) -> String {
  match parse_docx_hex_codepoint(symbol.char_hex) {
    Some(codepoint) =>
      if codepoint >= 0x20 && codepoint <= 0x7E {
        String::from_array([Int::unsafe_to_char(codepoint)])
      } else {
        ""
      }
    None => ""
  }
}

///|
fn render_docx_hyphen_text(hyphen : @ddocx.DocxHyphen) -> String {
  match hyphen.kind {
    Soft => ""
    NoBreak => "-"
  }
}

///|
fn parse_docx_hex_codepoint(value : String?) -> Int? {
  match value {
    Some(text) => {
      let trimmed = text.trim().to_owned()
      if trimmed == "" {
        return None
      }
      let chars = trimmed.to_array()
      let mut acc = 0
      for ch in chars {
        let digit = if ch >= '0' && ch <= '9' {
          ch.to_int() - '0'.to_int()
        } else if ch >= 'A' && ch <= 'F' {
          10 + ch.to_int() - 'A'.to_int()
        } else if ch >= 'a' && ch <= 'f' {
          10 + ch.to_int() - 'a'.to_int()
        } else {
          return None
        }
        acc = acc * 16 + digit
      }
      Some(acc)
    }
    None => None
  }
}

///|
fn docx_comment_author_prefix(author : String?) -> String {
  match author {
    Some(value) =>
      if value.trim() == "" {
        ""
      } else {
        value.trim().to_owned() + ": "
      }
    None => ""
  }
}

///|
fn docx_part_body_slot_label(body : @ddocx.DocxPartBody) -> String {
  match body.slot_type {
    Some(value) => docx_part_body_slot_label_from_text(value)
    None =>
      match body.relationship_id {
        Some(value) => docx_part_body_slot_label_from_text(value)
        None => "Default"
      }
  }
}

///|
fn docx_part_body_slot_label_from_text(value : String) -> String {
  let normalized = docx_normalize_style_label(value)
  if normalized.contains("even") {
    "Even"
  } else if normalized.contains("first") {
    "First"
  } else {
    "Default"
  }
}

///|
fn docx_textbox_appendix_title(
  textbox : @ddocx.DocxTextBox,
  display_index : Int,
) -> String {
  let prefix = if textbox.owner_part.has_prefix("word/header") {
    "Header Text Box "
  } else if textbox.owner_part.has_prefix("word/footer") {
    "Footer Text Box "
  } else {
    "Text Box "
  }
  prefix + display_index.to_string()
}

///|
fn docx_blocks_have_visible_content(blocks : Array[@ddocx.DocxBlock]) -> Bool {
  for block in blocks {
    match block {
      Paragraph(p) =>
        if !docx_paragraph_is_page_number_field_only(p) &&
          docx_inlines_have_visible_content(p.inlines) {
          return true
        }
      Table(table) => if table.rows.length() > 0 { return true }
      ContentControl(control) =>
        if control.text.trim() != "" ||
          docx_blocks_have_visible_content(control.blocks) {
          return true
        }
      TablePlaceholder(_) | Unsupported(_) => return true
      StructuralMarker(_) => ()
    }
  }
  false
}

///|
fn docx_inlines_have_visible_content(
  inlines : Array[@ddocx.DocxInline],
) -> Bool {
  for inline in inlines {
    match inline {
      Text(text) => if text.trim() != "" { return true }
      Tab | LineBreak | Break(_) => ()
      Hyperlink(link) => if link.text.trim() != "" { return true }
      Media(_) => return true
      Drawing(drawing) =>
        if drawing.media is Some(_) ||
          docx_inlines_have_visible_content(drawing.child_inlines) {
          return true
        }
      Shape(shape) =>
        if shape.media is Some(_) ||
          docx_inlines_have_visible_content(shape.child_inlines) {
          return true
        }
      ContentControl(control) =>
        if control.text.trim() != "" ||
          docx_inlines_have_visible_content(control.inlines) ||
          docx_blocks_have_visible_content(control.blocks) {
          return true
        }
      FieldUnsupported(field) =>
        if render_docx_field_text(field).trim() != "" ||
          docx_inlines_have_visible_content(field.child_inlines) {
          return true
        }
      Math(math) =>
        if render_docx_math_text(math).trim() != "" ||
          docx_inlines_have_visible_content(math.child_inlines) {
          return true
        }
      TrackedChange(change) =>
        if render_docx_tracked_change_text(change).trim() != "" ||
          docx_inlines_have_visible_content(change.child_inlines) {
          return true
        }
      SmartTag(smart_tag) =>
        if docx_inlines_have_visible_content(smart_tag.child_inlines) {
          return true
        }
      Symbol(symbol) =>
        if render_docx_symbol_text(symbol).trim() != "" {
          return true
        }
      Hyphen(hyphen) =>
        if render_docx_hyphen_text(hyphen).trim() != "" {
          return true
        }
      FootnoteRef(_) | EndnoteRef(_) | CommentRef(_) | UnsupportedInline(_) =>
        return true
      Bookmark(_) | StructuralMarker(_) | TextBoxRef(_) | Unsupported(_) => ()
    }
  }
  false
}

///|
fn normalize_docx_ref_marker_spacing(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0
  let mut pending_spaces = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '\n' || ch == '\r' {
      while pending_spaces > 0 {
        out.push(' ')
        pending_spaces -= 1
      }
      out.push(ch)
      i += 1
    } else if docx_marker_space_char(ch) {
      pending_spaces += 1
      i += 1
    } else if docx_chars_has_literal_at(chars, i, "[^") ||
      docx_chars_has_literal_at(chars, i, "[comment ") {
      let had_space = pending_spaces > 0
      pending_spaces = 0
      match docx_marker_end(chars, i) {
        Some(end_index) => {
          let after_index = end_index + 1
          let move_space = had_space &&
            after_index < chars.length() &&
            docx_marker_needs_following_space(chars[after_index])
          if had_space && !move_space {
            out.push(' ')
          }
          while i <= end_index {
            out.push(chars[i])
            i += 1
          }
          if move_space {
            out.push(' ')
          }
        }
        None => {
          while pending_spaces > 0 {
            out.push(' ')
            pending_spaces -= 1
          }
          out.push(ch)
          i += 1
        }
      }
    } else {
      while pending_spaces > 0 {
        out.push(' ')
        pending_spaces -= 1
      }
      out.push(ch)
      i += 1
    }
  }
  while pending_spaces > 0 {
    out.push(' ')
    pending_spaces -= 1
  }
  String::from_array(out)
}

///|
fn normalize_docx_marker_rich_inlines(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for index in 0..<inlines.length() {
    let inline = inlines[index]
    if docx_note_marker_inline(inline) {
      let needs_leading_space = docx_next_inline_needs_leading_space(
        inlines,
        index + 1,
      )
      let moved_space = if needs_leading_space {
        docx_trim_trailing_space_inline(out)
      } else {
        false
      }
      out.push(inline)
      if moved_space && needs_leading_space {
        out.push(
          @core.make_inline_text(
            " ",
            source_ref=docx_inline_spacing_source_ref(
              inline.source_ref.unwrap_or(@core.empty_source_ref()),
            ),
          ),
        )
      }
      continue
    }
    if docx_comment_marker_inline(inline) {
      docx_ensure_space_before_comment_marker(out, inline)
      out.push(inline)
      if docx_next_inline_needs_leading_space(inlines, index + 1) {
        out.push(
          @core.make_inline_text(
            " ",
            source_ref=docx_inline_spacing_source_ref(
              inline.source_ref.unwrap_or(@core.empty_source_ref()),
            ),
          ),
        )
      }
      continue
    }
    out.push(inline)
  }
  out
}

///|
fn docx_trim_trailing_space_inline(out : Array[@core.CoreInline]) -> Bool {
  match out.last() {
    Some(last) =>
      if last.kind == Text {
        let (trimmed, changed) = docx_trim_trailing_spaces(last.text)
        if changed {
          ignore(out.pop())
          if trimmed != "" {
            out.push({ ..last, text: trimmed })
          }
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn docx_trim_trailing_spaces(text : String) -> (String, Bool) {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 {
    let ch = chars[end - 1]
    if ch == ' ' || ch == '\t' {
      end -= 1
    } else {
      break
    }
  }
  if end == chars.length() {
    (text, false)
  } else {
    (String::from_array(chars[:end]), true)
  }
}

///|
fn docx_ensure_space_before_comment_marker(
  out : Array[@core.CoreInline],
  marker : @core.CoreInline,
) -> Unit {
  match out.last() {
    Some(last) => if docx_note_marker_inline(last) { return }
    None => ()
  }
  match out.last() {
    Some(last) =>
      if last.kind == Text && docx_inline_text_ends_with_space(last.text) {
        return
      }
    None => ()
  }
  out.push(
    @core.make_inline_text(
      " ",
      source_ref=docx_inline_spacing_source_ref(
        marker.source_ref.unwrap_or(@core.empty_source_ref()),
      ),
    ),
  )
}

///|
fn docx_inline_text_ends_with_space(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  let ch = chars[chars.length() - 1]
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn docx_next_inline_needs_leading_space(
  inlines : Array[@core.CoreInline],
  start : Int,
) -> Bool {
  let mut index = start
  while index < inlines.length() {
    let inline = inlines[index]
    match inline.kind {
      LineBreak => return false
      Text | Link | Code | Image =>
        return docx_text_requires_leading_space(inline.text)
    }
    index += 1
  }
  false
}

///|
fn docx_text_requires_leading_space(text : String) -> Bool {
  for ch in text.to_array() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      return false
    }
    return docx_marker_needs_following_space(ch)
  }
  false
}

///|
fn docx_rendered_table_has_visible_cells(block : @core.CoreBlock) -> Bool {
  for row in block.children {
    for cell in row.children {
      if cell.text.trim() != "" {
        return true
      }
    }
  }
  false
}

///|
fn docx_note_marker_inline(inline : @core.CoreInline) -> Bool {
  if inline.kind != Text {
    return false
  }
  inline.attrs.get("annotation_role") == Some("note_ref") &&
  inline.attrs.get("annotation_kind") != Some("comment")
}

///|
fn docx_comment_marker_inline(inline : @core.CoreInline) -> Bool {
  if inline.kind != Text {
    return false
  }
  inline.attrs.get("annotation_role") == Some("note_ref") &&
  inline.attrs.get("annotation_kind") == Some("comment")
}

///|
fn docx_marker_space_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r'
}

///|
fn docx_chars_has_literal_at(
  chars : Array[Char],
  index : Int,
  literal : String,
) -> Bool {
  let target = literal.to_array()
  if index + target.length() > chars.length() {
    return false
  }
  let mut offset = 0
  while offset < target.length() {
    if chars[index + offset] != target[offset] {
      return false
    }
    offset += 1
  }
  true
}

///|
fn docx_marker_end(chars : Array[Char], index : Int) -> Int? {
  let mut i = index
  while i < chars.length() {
    if chars[i] == ']' {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn docx_marker_needs_following_space(ch : Char) -> Bool {
  !(ch == '.' ||
  ch == ',' ||
  ch == ';' ||
  ch == ':' ||
  ch == ')' ||
  ch == ']' ||
  ch == '!' ||
  ch == '?')
}

///|
fn docx_normalize_style_label(label : String) -> String {
  let out = StringBuilder::new()
  for ch in label.trim().to_lower().to_array() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn docx_parse_nonnegative_int(text : String) -> Int? {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return None
  }
  let parsed = @string.parse_int(trimmed) catch { _ => return None }
  if parsed < 0 {
    None
  } else {
    Some(parsed)
  }
}
