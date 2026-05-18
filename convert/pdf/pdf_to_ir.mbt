///|
/// Final PDF stage: project convert blocks/images into unified IR.
///
/// Important contract notes:
/// - text blocks and image blocks are emitted in page object reading order
/// - `Origin` / `AssetOrigin` are lightweight provenance only
/// - image nearby caption recovery is conservative; ambiguous matches are skipped
///   rather than forcing low-confidence pairings
priv enum PdfIrHeadingRole {
  DocumentTitle
  SectionHeading
}

///|
priv struct PdfVisibleAnnotationNote {
  _annotation_index : Int
  text : String
  object_ref : String?
}

///|
const DEBUG_TO_IR = false

///|
fn rebuild_page_objects(page : PdfConvertPage) -> PdfConvertPage {
  let objects = build_page_objects(page.blocks, page.images)
  { ..page, objects, }
}

///|
fn convert_pdf_blocks_to_ir(
  doc : PdfConvertDocument,
  max_heading : Int,
  source_name : String,
) -> @cor.Document {
  let out = @cor.new_document()
  let has_document_title = detect_document_title_presence_for_ir(doc)
  let mut emitted_annotations_heading = false
  let mut emitted_forms_heading = false
  let list_gate_cfg = default_pdf_layout_gate_config()
  let list_gate_ctx = build_pdf_layout_gate_doc_context(doc)

  for page in doc.pages {
    let page_tables = detect_pdf_tables(page, DEBUG_TO_IR)
    let (page_image_captions, consumed_caption_block_indices) = infer_page_image_captions(
      page,
      DEBUG_TO_IR,
    )
    let consumed_table_block_indices = table_consumed_block_indices(page_tables)
    let page_font_median = page_median_font_size(page)
    let mut page_image_idx = 0
    for i = 0; i < page.objects.length(); i = i + 1 {
      match page.objects[i] {
        PdfConvertPageObject::TextBlock(block) => {
          match find_table_starting_at_block(page_tables, block) {
            Some(table) => {
              emit_pdf_table_to_ir(out, source_name, page._page_index, table)
              continue
            }
            None => ()
          }

          if consumed_table_block_indices.contains(block.block_index) {
            continue
          }
          if consumed_caption_block_indices.contains(block.block_index) {
            continue
          }
          let prev = find_prev_text_block_in_objects(page.objects, i)
          let next = find_next_text_block_in_objects(page.objects, i)

          emit_text_block_to_ir(
            out,
            source_name,
            list_gate_ctx,
            list_gate_cfg,
            page,
            page._page_index,
            block,
            prev,
            next,
            page_font_median,
            has_document_title,
            max_heading,
          )
        }
        PdfConvertPageObject::Image(image) => {
          if image.path.trim() == "" {
            continue
          }
          let nearby_caption = if page_image_idx < page_image_captions.length() {
            page_image_captions[page_image_idx]
          } else {
            None
          }
          page_image_idx += 1

          let origin : @cor.Origin = {
            source_name: Some(source_name),
            page: Some(page._page_index + 1),
            slide: None,
            sheet: None,
            block_index: Some(out.blocks.val.length()),
            heading_path: None,
            line_start: None,
            line_end: None,
            row_index: None,
            column_index: None,
            object_ref: None,
            relationship_id: None,
            key_path: None,
          }

          @cor.push_with_origin(
            out,
            @cor.Block::ImageBlock({
              path: image.path,
              alt_text: image.alt_text,
              title: None,
              caption: nearby_caption,
              origin: Some(origin),
            }),
            Some(origin),
          )

          @cor.set_asset_origin(out, image.path, {
            source_name: Some(source_name),
            page: Some(page._page_index + 1),
            slide: None,
            sheet: None,
            origin_id: Some(image.source_image_id),
            nearby_caption,
            object_ref: image.object_ref,
            relationship_id: None,
            source_path: None,
            row_index: None,
            column_index: None,
            key_path: None,
          })
        }
      }
    }

    let annotation_notes = collect_visible_annotation_notes(page)
    if !annotation_notes.is_empty() {
      if !emitted_annotations_heading {
        @cor.push(out, @cor.Block::Heading(2, "Annotations"))
        emitted_annotations_heading = true
      }

      emit_pdf_annotation_notes_to_ir(
        out,
        source_name,
        page._page_index,
        annotation_notes,
      )
    }

    let form_notes = collect_visible_form_notes(page)
    if !form_notes.is_empty() {
      if !emitted_forms_heading {
        @cor.push(out, @cor.Block::Heading(2, "Forms"))
        emitted_forms_heading = true
      }

      emit_pdf_form_notes_to_ir(out, source_name, page._page_index, form_notes)
    }
  }

  out
}

///|
fn append_pdf_outlines_to_ir(
  out : @cor.Document,
  outlines : Array[@model.PdfOutlineItem],
  source_name : String,
) -> Unit {
  if !has_renderable_pdf_outline_items(outlines) {
    return
  }
  if pdf_outlines_are_redundant_with_visible_headings(out, outlines) {
    return
  }
  @cor.push(out, @cor.Block::Heading(2, "Bookmarks"))
  emit_pdf_outline_items_to_ir(out, source_name, outlines, 0)
}

///|
fn has_renderable_pdf_outline_items(
  items : Array[@model.PdfOutlineItem],
) -> Bool {
  for item in items {
    if render_pdf_outline_item_text(item) is Some(_) {
      return true
    }
    if has_renderable_pdf_outline_items(item.children) {
      return true
    }
  }
  false
}

///|
fn pdf_outlines_are_redundant_with_visible_headings(
  out : @cor.Document,
  outlines : Array[@model.PdfOutlineItem],
) -> Bool {
  let heading_texts = visible_pdf_heading_texts(out)
  if heading_texts.is_empty() {
    return false
  }

  let outline_titles = Array::new()
  collect_outline_titles_for_redundancy_check(outlines, outline_titles)
  if outline_titles.is_empty() {
    return false
  }

  for title in outline_titles {
    let mut matched = false
    for heading in heading_texts {
      if heading == title {
        matched = true
        break
      }
    }
    if !matched {
      return false
    }
  }

  true
}

///|
fn visible_pdf_heading_texts(out : @cor.Document) -> Array[String] {
  let headings = Array::new()
  for block in out.blocks.val {
    match block {
      @cor.Block::Heading(_, text) =>
        if text.trim() != "" {
          headings.push(text.trim().to_owned())
        }
      _ => ()
    }
  }
  headings
}

///|
fn collect_outline_titles_for_redundancy_check(
  items : Array[@model.PdfOutlineItem],
  out : Array[String],
) -> Unit {
  for item in items {
    let title = item.title.trim().to_owned()
    if title == "" || item.page_index is None {
      out.clear()
      return
    }
    out.push(title)
    if !item.children.is_empty() {
      collect_outline_titles_for_redundancy_check(item.children, out)
      if out.is_empty() {
        return
      }
    }
  }
}

///|
fn emit_pdf_outline_items_to_ir(
  out : @cor.Document,
  source_name : String,
  items : Array[@model.PdfOutlineItem],
  level : Int,
) -> Unit {
  for item in items {
    match render_pdf_outline_item_text(item) {
      Some(text) => {
        let origin : @cor.Origin = {
          source_name: Some(source_name),
          page: item.page_index.map(fn(idx) { idx + 1 }),
          slide: None,
          sheet: None,
          block_index: Some(out.blocks.val.length()),
          heading_path: Some(["Bookmarks"]),
          line_start: None,
          line_end: None,
          row_index: None,
          column_index: None,
          object_ref: None,
          relationship_id: None,
          key_path: None,
        }
        @cor.push_with_origin(
          out,
          @cor.Block::ListItem(false, level, text),
          Some(origin),
        )
      }
      None => ()
    }

    if !item.children.is_empty() {
      emit_pdf_outline_items_to_ir(out, source_name, item.children, level + 1)
    }
  }
}

///|
fn render_pdf_outline_item_text(item : @model.PdfOutlineItem) -> String? {
  let title = item.title.trim().to_owned()
  let target = render_outline_target(item)

  match (title, target) {
    ("", Some(dest)) => Some(dest)
    ("", None) => None
    (title, Some(dest)) => Some(title + " -> " + dest)
    (title, None) => Some(title)
  }
}

///|
fn render_outline_target(item : @model.PdfOutlineItem) -> String? {
  let page_target = match item.page_index {
    Some(page_index) =>
      if page_index >= 0 {
        Some("page " + (page_index + 1).to_string())
      } else {
        None
      }
    None => None
  }
  let dest_target = match normalized_named_destination_label(item.dest) {
    Some(dest) => Some("destination " + dest)
    None => None
  }

  match (dest_target, page_target) {
    (Some(dest), Some(page)) => Some(dest + " -> " + page)
    (Some(dest), None) => Some(dest)
    (None, Some(page)) => Some(page)
    (None, None) => None
  }
}

///|
fn collect_visible_annotation_notes(
  page : PdfConvertPage,
) -> Array[PdfVisibleAnnotationNote] {
  let out : Array[PdfVisibleAnnotationNote] = []

  for annotation in page.annotations {
    if !should_emit_annotation_note_in_markdown(annotation) {
      continue
    }
    match render_visible_annotation_note(annotation, page._page_index) {
      Some(text) =>
        out.push({
          _annotation_index: annotation._annotation_index,
          text,
          object_ref: annotation.object_ref,
        })
      None => ()
    }
  }

  out
}

///|
fn collect_visible_form_notes(page : PdfConvertPage) -> Array[String] {
  let out : Array[String] = []
  for form in page.forms {
    if !should_emit_visible_widget_form_in_markdown(form) {
      continue
    }
    match render_visible_form_note(form, page._page_index) {
      Some(text) => out.push(text)
      None => ()
    }
  }
  out
}

///|
fn render_visible_form_note(
  form : PdfConvertFormField,
  page_index : Int,
) -> String? {
  let label = match normalized_optional_annotation_field(form.field_name) {
    Some(name) => name
    None => "Field " + (form._form_index + 1).to_string()
  }

  let body = match form.field_type {
    "/Tx" =>
      match normalized_optional_annotation_field(form.field_value) {
        Some(value) => Some(value)
        None => None
      }
    "/Ch" => {
      let value = normalized_optional_annotation_field(form.field_value)
      match value {
        Some(v) => Some(v)
        None =>
          if !form.options.is_empty() {
            Some("options: " + form.options.join(", "))
          } else {
            None
          }
      }
    }
    "/Btn" =>
      match form.checked_state {
        Some(true) => Some("checked")
        Some(false) => Some("unchecked")
        None =>
          match normalized_optional_annotation_field(form.field_value) {
            Some(v) => Some(v)
            None => None
          }
      }
    _ =>
      match normalized_optional_annotation_field(form.field_value) {
        Some(value) => Some(value)
        None => None
      }
  }

  match body {
    Some(text) =>
      if text.trim() == "" {
        None
      } else {
        Some(
          form_type_label(form.field_type) +
          " (page " +
          (page_index + 1).to_string() +
          "): " +
          label +
          " — " +
          normalize_pdf_form_value_text(text),
        )
      }
    None => None
  }
}

///|
fn should_emit_visible_widget_form_in_markdown(
  form : PdfConvertFormField,
) -> Bool {
  @model.pdf_annotation_is_view_visible(form.flags)
}

///|
fn should_emit_annotation_note_in_markdown(
  annotation : PdfConvertAnnotation,
) -> Bool {
  if @model.pdf_annotation_is_no_view(annotation.flags) ||
    @model.pdf_annotation_is_invisible(annotation.flags) {
    return false
  }
  @model.pdf_annotation_is_view_visible(annotation.flags) ||
  @model.pdf_annotation_is_printable(annotation.flags)
}

///|
fn normalize_pdf_form_value_text(text : String) -> String {
  normalize_pdf_form_value_breaks(text)
  .split("\n")
  .map(fn(line) { line.trim().to_owned() })
  .filter(fn(line) { line != "" })
  .join(" / ")
}

///|
fn normalize_pdf_form_value_breaks(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0

  while i < chars.length() {
    if chars[i] == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i = i + 2
      } else {
        i = i + 1
      }
      continue
    }

    let br_len = html_break_tag_length(chars, i)
    if br_len > 0 {
      out.push('\n')
      i = i + br_len
      continue
    }

    out.push(chars[i])
    i = i + 1
  }

  String::from_array(out)
}

///|
fn html_break_tag_length(chars : Array[Char], start : Int) -> Int {
  if start < 0 || start >= chars.length() || chars[start] != '<' {
    return 0
  }
  if start + 3 >= chars.length() {
    return 0
  }
  if !ascii_char_eq_ignore_case(chars[start + 1], 'b') {
    return 0
  }
  if !ascii_char_eq_ignore_case(chars[start + 2], 'r') {
    return 0
  }

  let mut i = start + 3
  while i < chars.length() && chars[i] == ' ' {
    i = i + 1
  }
  if i < chars.length() && chars[i] == '/' {
    i = i + 1
    while i < chars.length() && chars[i] == ' ' {
      i = i + 1
    }
  }
  if i < chars.length() && chars[i] == '>' {
    i - start + 1
  } else {
    0
  }
}

///|
fn ascii_char_eq_ignore_case(ch : Char, expected_lower : Char) -> Bool {
  if ch == expected_lower {
    true
  } else if expected_lower >= 'a' && expected_lower <= 'z' {
    let expected_upper = Char::from_int(
      expected_lower.to_int() - ('a'.to_int() - 'A'.to_int()),
    )
    ch == expected_upper
  } else {
    false
  }
}

///|
fn form_type_label(field_type : String) -> String {
  match field_type.trim() {
    "/Tx" => "Text"
    "/Ch" => "Choice"
    "/Btn" => "Button"
    raw => if raw.has_prefix("/") { raw[1:].to_owned() } else { raw.to_owned() }
  }
}

///|
fn emit_pdf_form_notes_to_ir(
  out : @cor.Document,
  source_name : String,
  page_index : Int,
  notes : Array[String],
) -> Unit {
  for text in notes {
    @cor.push_with_origin(
      out,
      @cor.Block::Paragraph(text),
      Some({
        source_name: Some(source_name),
        page: Some(page_index + 1),
        slide: None,
        sheet: None,
        block_index: Some(out.blocks.val.length()),
        heading_path: Some(["Forms"]),
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      }),
    )
  }
}

///|
fn render_visible_annotation_note(
  annotation : PdfConvertAnnotation,
  page_index : Int,
) -> String? {
  if annotation.subtype == "/Popup" {
    return None
  }
  if annotation.subtype == "/Link" {
    return render_visible_link_annotation_note(annotation, page_index)
  }

  let label = annotation_label(annotation)
  let subject = normalized_optional_annotation_field(annotation.subject)
  let contents = normalized_optional_annotation_field(annotation.contents)
  let dest = normalized_optional_annotation_field(annotation.dest)
  let subject_only = subject is Some(_) && contents is None && dest is None

  if subject_only && is_degenerate_annotation_shell(annotation) {
    return None
  }

  let payload = match (subject, contents, dest) {
    (Some(s), Some(c), _) => Some(s + " — " + c)
    (Some(s), None, Some(d)) => Some(s + " — " + d)
    (Some(s), None, None) => Some(s)
    (None, Some(c), _) => Some(c)
    (None, None, Some(d)) => Some(d)
    (None, None, None) => None
  }

  match payload {
    Some(body) =>
      if body.trim() == "" {
        None
      } else {
        Some(label + " (page " + (page_index + 1).to_string() + "): " + body)
      }
    None => None
  }
}

///|
fn render_visible_link_annotation_note(
  annotation : PdfConvertAnnotation,
  page_index : Int,
) -> String? {
  if normalized_optional_annotation_field(annotation.uri) is Some(_) {
    return None
  }

  let target = normalized_internal_link_target(annotation)
  match target {
    Some(target) => {
      let subject = normalized_optional_annotation_field(annotation.subject)
      let contents = normalized_optional_annotation_field(annotation.contents)
      let payload = match (subject, contents) {
        (Some(s), Some(c)) => s + " — " + c + " — " + target
        (Some(s), None) => s + " — " + target
        (None, Some(c)) => c + " — " + target
        (None, None) => target
      }
      Some("Link (page " + (page_index + 1).to_string() + "): " + payload)
    }
    None => None
  }
}

///|
fn normalized_internal_link_target(
  annotation : PdfConvertAnnotation,
) -> String? {
  let named_dest = normalized_named_destination_label(annotation.dest)
  match annotation.target_page {
    Some(page_number) =>
      if page_number > 0 {
        match named_dest {
          Some(dest) =>
            Some("destination " + dest + " -> page " + page_number.to_string())
          None => Some("page " + page_number.to_string())
        }
      } else {
        None
      }
    None =>
      match named_dest {
        Some(dest) => Some("destination " + dest)
        None =>
          match normalized_optional_annotation_field(annotation.dest) {
            Some(dest) => Some("destination " + dest)
            None => None
          }
      }
  }
}

///|
fn normalized_named_destination_label(dest : String?) -> String? {
  match normalized_optional_annotation_field(dest) {
    Some(raw) => {
      let trimmed = raw.trim().to_owned()
      if trimmed == "" ||
        trimmed.has_prefix("[") ||
        trimmed.has_prefix("<<") ||
        trimmed.has_prefix("Indirect(") ||
        trimmed.contains("[") ||
        trimmed.contains("]") ||
        trimmed.contains("<<") ||
        trimmed.contains(">>") {
        None
      } else if trimmed.has_prefix("(") &&
        trimmed.has_suffix(")") &&
        trimmed.length() >= 2 {
        let inner = trimmed[1:trimmed.length() - 1].trim().to_owned()
        if inner == "" {
          None
        } else {
          Some(inner)
        }
      } else if trimmed.has_prefix("/") {
        let name = trimmed[1:].trim().to_owned()
        if name == "" {
          None
        } else {
          Some(name)
        }
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn rect_extent(lo : Double, hi : Double) -> Double {
  if hi >= lo {
    hi - lo
  } else {
    lo - hi
  }
}

///|
fn is_degenerate_annotation_shell(annotation : PdfConvertAnnotation) -> Bool {
  let width = rect_extent(annotation._bbox.x0, annotation._bbox.x1)
  let height = rect_extent(annotation._bbox.y0, annotation._bbox.y1)
  width < 2.0 || height < 2.0
}

///|
fn annotation_label(annotation : PdfConvertAnnotation) -> String {
  let raw = annotation.subtype.trim().to_owned()
  if raw.has_prefix("/") {
    raw[1:].to_owned()
  } else {
    raw
  }
}

///|
fn normalized_optional_annotation_field(field : String?) -> String? {
  match field {
    Some(v) => {
      let t = v.trim().to_owned()
      if t == "" {
        None
      } else {
        Some(t)
      }
    }
    None => None
  }
}

///|
fn emit_pdf_annotation_notes_to_ir(
  out : @cor.Document,
  source_name : String,
  page_index : Int,
  notes : Array[PdfVisibleAnnotationNote],
) -> Unit {
  for note in notes {
    let origin : @cor.Origin = {
      source_name: Some(source_name),
      page: Some(page_index + 1),
      slide: None,
      sheet: None,
      block_index: Some(out.blocks.val.length()),
      heading_path: Some(["Annotations"]),
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref: note.object_ref,
      relationship_id: None,
      key_path: None,
    }
    @cor.push_with_origin(out, @cor.Block::Paragraph(note.text), Some(origin))
  }
}

///|
fn is_block_above_image(
  block : PdfConvertBlock,
  image : PdfConvertImage,
) -> Bool {
  block._bbox.y0 >= image._bbox.y1
}

///|
fn is_block_below_image(
  block : PdfConvertBlock,
  image : PdfConvertImage,
) -> Bool {
  block._bbox.y1 <= image._bbox.y0
}

///|
fn caption_vertical_gap(
  block : PdfConvertBlock,
  image : PdfConvertImage,
) -> Double {
  if is_block_above_image(block, image) {
    block._bbox.y0 - image._bbox.y1
  } else if is_block_below_image(block, image) {
    image._bbox.y0 - block._bbox.y1
  } else {
    -1.0
  }
}

///|
fn horizontal_overlap_width(a : @model.PdfRect, b : @model.PdfRect) -> Double {
  let left = max_f64(a.x0, b.x0)
  let right = min_f64(a.x1, b.x1)
  if right > left {
    right - left
  } else {
    0.0
  }
}

///|
fn block_center_x(block : PdfConvertBlock) -> Double {
  (block._bbox.x0 + block._bbox.x1) / 2.0
}

///|
fn is_within_x_span(x : Double, rect : @model.PdfRect) -> Bool {
  x >= rect.x0 && x <= rect.x1
}

///|
fn table_consumed_block_indices(
  tables : Array[PdfTableCandidate],
) -> Map[Int, Bool] {
  let out : Map[Int, Bool] = Map([])
  for table in tables {
    for block_index in table.block_indices {
      out.set(block_index, true)
    }
  }
  out
}

///|
fn find_table_starting_at_block(
  tables : Array[PdfTableCandidate],
  block : PdfConvertBlock,
) -> PdfTableCandidate? {
  for table in tables {
    if block.line_start == table.line_start {
      return Some(table)
    }
  }
  None
}

///|
fn emit_pdf_table_to_ir(
  out : @cor.Document,
  source_name : String,
  page_index : Int,
  table : PdfTableCandidate,
) -> Unit {
  let origin : @cor.Origin = {
    source_name: Some(source_name),
    page: Some(page_index + 1),
    slide: None,
    sheet: None,
    block_index: Some(out.blocks.val.length()),
    heading_path: None,
    line_start: Some(table.line_start + 1),
    line_end: Some(table.line_end + 1),
    row_index: None,
    column_index: None,
    object_ref: None,
    relationship_id: None,
    key_path: None,
  }

  @cor.push_with_origin(
    out,
    @cor.Block::RichTable({
      rows: table.rows,
      header_rows: table.header_rows,
      hints: None,
    }),
    Some(origin),
  )
}

///|
fn min_f64(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_f64(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn find_prev_text_block_in_objects(
  objects : Array[PdfConvertPageObject],
  index : Int,
) -> PdfConvertBlock? {
  let mut i = index - 1
  while i >= 0 {
    match objects[i] {
      PdfConvertPageObject::TextBlock(block) => return Some(block)
      PdfConvertPageObject::Image(_) => ()
    }

    if i == 0 {
      break
    }
    i = i - 1
  }

  None
}

///|
fn find_next_text_block_in_objects(
  objects : Array[PdfConvertPageObject],
  index : Int,
) -> PdfConvertBlock? {
  let mut i = index + 1
  while i < objects.length() {
    match objects[i] {
      PdfConvertPageObject::TextBlock(block) => return Some(block)
      PdfConvertPageObject::Image(_) => ()
    }
    i = i + 1
  }

  None
}

///|
fn emit_text_block_to_ir(
  out : @cor.Document,
  source_name : String,
  list_gate_ctx : PdfLayoutGateDocContext,
  list_gate_cfg : PdfLayoutGateConfig,
  page : PdfConvertPage,
  _page_index : Int,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
  page_font_median : Double?,
  has_document_title : Bool,
  max_heading : Int,
) -> Unit {
  let text = block.text.trim().to_owned()
  if text == "" {
    return
  }

  if DEBUG_TO_IR {
    println(
      "[to-ir/input] page=" +
      _page_index.to_string() +
      " block=" +
      block.block_index.to_string() +
      " kind=" +
      debug_block_kind_for_ir(block.kind) +
      " heading_candidate=" +
      block.is_heading_candidate.to_string() +
      " text=\"" +
      text +
      "\"",
    )
  }

  match block.kind {
    PdfConvertBlockKind::Noise => ()
    PdfConvertBlockKind::Heading => {
      let heading_text = normalize_heading_text_for_ir(text)
      let (role, depth) = decide_heading_role_and_depth_for_ir(
        heading_text, block, prev, next,
      )

      if DEBUG_TO_IR {
        println(
          "[to-ir/heading] page=" +
          _page_index.to_string() +
          " block=" +
          block.block_index.to_string() +
          " role=" +
          debug_heading_role_for_ir(role) +
          " depth=" +
          depth.to_string() +
          " text=\"" +
          heading_text +
          "\"",
        )
      }

      match role {
        PdfIrHeadingRole::DocumentTitle => {
          let level = clamp_heading_level(1, max_heading)
          let block_ir = match block.rich_inlines {
            Some(inlines) => @cor.Block::RichHeading(level, inlines)
            None => @cor.Block::Heading(level, heading_text)
          }
          @cor.push_with_origin(
            out,
            block_ir,
            Some({
              source_name: Some(source_name),
              page: Some(_page_index + 1),
              slide: None,
              sheet: None,
              block_index: Some(out.blocks.val.length()),
              heading_path: None,
              line_start: None,
              line_end: None,
              row_index: None,
              column_index: None,
              object_ref: None,
              relationship_id: None,
              key_path: None,
            }),
          )
        }
        PdfIrHeadingRole::SectionHeading => {
          let level = map_section_depth_to_heading_level_for_ir(
            depth, has_document_title, max_heading,
          )
          let block_ir = match block.rich_inlines {
            Some(inlines) => @cor.Block::RichHeading(level, inlines)
            None => @cor.Block::Heading(level, heading_text)
          }
          @cor.push_with_origin(
            out,
            block_ir,
            Some({
              source_name: Some(source_name),
              page: Some(_page_index + 1),
              slide: None,
              sheet: None,
              block_index: Some(out.blocks.val.length()),
              heading_path: None,
              line_start: None,
              line_end: None,
              row_index: None,
              column_index: None,
              object_ref: None,
              relationship_id: None,
              key_path: None,
            }),
          )
        }
      }
    }
    PdfConvertBlockKind::Paragraph => {
      let pt = text.trim().to_owned()
      match try_parse_bullet_list_item_for_ir(pt) {
        Some(item_text) =>
          if should_emit_pdf_bullet_list_item(
              list_gate_ctx,
              page,
              block.block_index,
              page_font_median,
              list_gate_cfg,
            ) {
            @cor.push_with_origin(
              out,
              @cor.Block::ListItem(false, 0, item_text),
              Some({
                source_name: Some(source_name),
                page: Some(_page_index + 1),
                slide: None,
                sheet: None,
                block_index: Some(out.blocks.val.length()),
                heading_path: None,
                line_start: None,
                line_end: None,
                row_index: None,
                column_index: None,
                object_ref: None,
                relationship_id: None,
                key_path: None,
              }),
            )
          } else {
            match block.rich_inlines {
              Some(inlines) =>
                @cor.push_with_origin(
                  out,
                  @cor.Block::RichParagraph(inlines),
                  Some({
                    source_name: Some(source_name),
                    page: Some(_page_index + 1),
                    slide: None,
                    sheet: None,
                    block_index: Some(out.blocks.val.length()),
                    heading_path: None,
                    line_start: None,
                    line_end: None,
                    row_index: None,
                    column_index: None,
                    object_ref: None,
                    relationship_id: None,
                    key_path: None,
                  }),
                )
              None =>
                @cor.push_with_origin(
                  out,
                  @cor.Block::Paragraph(pt),
                  Some({
                    source_name: Some(source_name),
                    page: Some(_page_index + 1),
                    slide: None,
                    sheet: None,
                    block_index: Some(out.blocks.val.length()),
                    heading_path: None,
                    line_start: None,
                    line_end: None,
                    row_index: None,
                    column_index: None,
                    object_ref: None,
                    relationship_id: None,
                    key_path: None,
                  }),
                )
            }
          }
        None =>
          match block.rich_inlines {
            Some(inlines) =>
              @cor.push_with_origin(
                out,
                @cor.Block::RichParagraph(inlines),
                Some({
                  source_name: Some(source_name),
                  page: Some(_page_index + 1),
                  slide: None,
                  sheet: None,
                  block_index: Some(out.blocks.val.length()),
                  heading_path: None,
                  line_start: None,
                  line_end: None,
                  row_index: None,
                  column_index: None,
                  object_ref: None,
                  relationship_id: None,
                  key_path: None,
                }),
              )
            None =>
              @cor.push_with_origin(
                out,
                @cor.Block::Paragraph(pt),
                Some({
                  source_name: Some(source_name),
                  page: Some(_page_index + 1),
                  slide: None,
                  sheet: None,
                  block_index: Some(out.blocks.val.length()),
                  heading_path: None,
                  line_start: None,
                  line_end: None,
                  row_index: None,
                  column_index: None,
                  object_ref: None,
                  relationship_id: None,
                  key_path: None,
                }),
              )
          }
      }
    }
  }
}

///|
fn try_parse_bullet_list_item_for_ir(text : String) -> String? {
  let t = text.trim().to_owned()
  if t == "" {
    return None
  }

  if t.has_prefix("•") {
    let body = t[1:].trim().to_owned()
    if body != "" {
      return Some(body)
    }
  }

  if t.has_prefix("- ") || t.has_prefix("* ") {
    let body = t[2:].trim().to_owned()
    if body != "" && !looks_like_separator_line_for_ir(body) {
      return Some(body)
    }
  }

  None
}

///|
fn looks_like_separator_line_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() < 3 {
    return false
  }

  for ch in t {
    if ch != '-' && ch != '=' && ch != '_' && ch != '*' {
      return false
    }
  }
  true
}

///|
fn debug_block_kind_for_ir(kind : PdfConvertBlockKind) -> String {
  match kind {
    PdfConvertBlockKind::Heading => "Heading"
    PdfConvertBlockKind::Paragraph => "Paragraph"
    PdfConvertBlockKind::Noise => "Noise"
  }
}

///|
fn debug_heading_role_for_ir(role : PdfIrHeadingRole) -> String {
  match role {
    PdfIrHeadingRole::DocumentTitle => "DocumentTitle"
    PdfIrHeadingRole::SectionHeading => "SectionHeading"
  }
}

///|
/// 是否存在“文档主标题”。
///
/// 这里必须非常保守：
/// - 只看首页前部
/// - 只看 heading block
/// - 不能是显式 section marker / 常见 section label
/// - 必须真的更像 sample/report/title，而不是正文小节
fn detect_document_title_presence_for_ir(doc : PdfConvertDocument) -> Bool {
  if doc.pages.length() == 0 {
    return false
  }

  let page = doc.pages[0]
  for i = 0; i < page.blocks.length(); i = i + 1 {
    let block = page.blocks[i]

    if block.kind != PdfConvertBlockKind::Heading {
      continue
    }

    if block.block_index > 2 {
      break
    }

    let t = block.text.trim().to_owned()
    if t == "" || should_never_emit_heading(t) {
      continue
    }

    let prev = if i > 0 { Some(page.blocks[i - 1]) } else { None }
    let next = if i + 1 < page.blocks.length() {
      Some(page.blocks[i + 1])
    } else {
      None
    }

    if looks_like_document_title_role_for_ir(t, block, prev, next) {
      return true
    }
  }

  false
}

///|
fn decide_heading_role_and_depth_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
) -> (PdfIrHeadingRole, Int) {
  let role = classify_heading_role_for_ir(text, block, prev, next)
  match role {
    PdfIrHeadingRole::SectionHeading => {
      let depth = infer_section_depth_for_ir(text)
      (role, if depth > 0 { depth } else { 1 })
    }
    PdfIrHeadingRole::DocumentTitle => (role, 0)
  }
}

///|
fn classify_heading_role_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
) -> PdfIrHeadingRole {
  let t = text.trim().to_owned()
  if looks_like_document_title_role_for_ir(t, block, prev, next) {
    return PdfIrHeadingRole::DocumentTitle
  }

  // `pdf_classify` is the final "is this a heading?" boundary. At this
  // stage we only decide whether an already-classified Heading is the document
  // title or a section heading.
  PdfIrHeadingRole::SectionHeading
}

///|
/// 文档主标题：非常保守。
///
/// 关键思想：
/// - 不能是常见正文节标题
/// - 不能是显式编号 section
/// - 必须在首页前部
/// - 要么像 sample/report/test 这类文档标题
/// - 要么是明显的英文/中英混合/压缩命题型主标题
fn looks_like_document_title_role_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  // 常见 section label 不当文档标题
  if looks_like_common_section_label_for_ir(t) {
    return false
  }

  // 显式 section depth 一律视为正文结构，不是 document title
  if infer_section_depth_for_ir(t) > 0 {
    return false
  }

  // 必须在首页前部
  if block._page_index != 0 || block.block_index > 2 {
    return false
  }

  if block.line_count > 2 {
    return false
  }

  if !looks_like_strong_document_title_for_ir(t) {
    return false
  }

  // 文档标题有两种典型来源：
  // 1) 词表型：report/pipeline/test/sample 等
  // 2) 压缩标题短语：Cross-page should merge / Heading vs Short Sentence
  // 3) 中英混合项目标题
  let title_shape = looks_like_document_title_phrase_for_ir(t) ||
    looks_like_mixed_document_title_for_ir(t) ||
    looks_like_compact_predicative_title_for_ir(t)

  // 版面/上下文辅助：更大字号 or 后续像正文
  let layout_support = is_visually_larger_than_neighbors(prev, block, next) ||
    next_block_looks_like_body_for_h1(next)

  title_shape || layout_support
}

///|
/// 结构深度：先算相对深度，不直接映射 H1/H2/H3。
///
/// depth=1:
/// - 第一章 / Chapter / 一、 / 1.
/// depth=2:
/// - 第一节 / 1.1 / （一）
/// depth=3:
/// - 1.1.1 / （1） / 1)
fn infer_section_depth_for_ir(text : String) -> Int {
  let t = text.trim().to_owned()
  if t == "" {
    return 0
  }

  // 章级
  if t.has_prefix("第一章") ||
    t.has_prefix("第二章") ||
    t.has_prefix("第三章") ||
    t.has_prefix("第四章") ||
    t.has_prefix("第五章") ||
    t.has_prefix("Chapter ") ||
    t.has_prefix("CHAPTER ") ||
    t.has_prefix("一、") ||
    t.has_prefix("二、") ||
    t.has_prefix("三、") ||
    t.has_prefix("四、") ||
    t.has_prefix("五、") {
    return 1
  }

  // 节级（中文“第一节”）
  if t.has_prefix("第一节") ||
    t.has_prefix("第二节") ||
    t.has_prefix("第三节") ||
    t.has_prefix("第四节") ||
    t.has_prefix("第五节") {
    return 2
  }

  let dots = count_prefix_dots_in_heading_number_for_ir(t)
  if dots >= 2 {
    return 3
  }
  if dots == 1 {
    return 2
  }

  if starts_with_top_level_number_for_ir(t) {
    return 1
  }

  if t.has_prefix("（一）") ||
    t.has_prefix("（二）") ||
    t.has_prefix("（三）") ||
    t.has_prefix("（四）") ||
    t.has_prefix("（五）") {
    return 2
  }

  if starts_with_parenthesized_digit_item_for_ir(t) ||
    starts_with_digit_paren_item_for_ir(t) {
    return 3
  }

  0
}

///|
fn starts_with_parenthesized_digit_item_for_ir(text : String) -> Bool {
  let cs = text.to_array()
  if cs.length() < 3 {
    return false
  }

  cs[0] == '（' && cs[1] >= '0' && cs[1] <= '9' && cs[2] == '）'
}

///|
fn starts_with_digit_paren_item_for_ir(text : String) -> Bool {
  let cs = text.to_array()
  if cs.length() < 2 {
    return false
  }

  cs[0] >= '0' && cs[0] <= '9' && (cs[1] == ')' || cs[1] == '）')
}

///|
fn map_section_depth_to_heading_level_for_ir(
  depth : Int,
  has_document_title : Bool,
  max_heading : Int,
) -> Int {
  let base_section_level = if has_document_title { 2 } else { 1 }
  let safe_depth = if depth <= 0 { 1 } else { depth }
  clamp_heading_level(base_section_level + safe_depth - 1, max_heading)
}

///|
/// 即使上游标了 Heading，这些也不应在 IR 层发成 heading。
fn should_never_emit_heading(text : String) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return true
  }

  if looks_like_colon_label(t) {
    return true
  }

  if @text.looks_like_intro_phrase(t) {
    return true
  }

  if @text.looks_like_figure_or_table_caption(t) {
    return true
  }

  if looks_like_bullet_item(t) {
    return true
  }

  if looks_like_numbered_body_sentence(t) {
    return true
  }

  false
}

///|
fn count_prefix_dots_in_heading_number_for_ir(s : String) -> Int {
  let cs = s.to_array()
  let n = cs.length()
  let mut i = 0
  let mut saw_digit = false
  let mut dots = 0

  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      saw_digit = true
      i += 1
      continue
    }
    if c == '.' {
      dots += 1
      i += 1
      continue
    }
    break
  }

  if saw_digit {
    dots
  } else {
    0
  }
}

///|
fn starts_with_top_level_number_for_ir(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if !has_digit || i >= n {
    return false
  }

  let c = cs[i]
  c == ' ' || c == '、' || c == ')' || c == '）' || c == '.'
}

///|
/// 英文标题形态。
fn looks_like_english_title_for_ir(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return false
  }

  if looks_like_figure_or_table_caption_for_ir(t) {
    return false
  }

  if looks_like_intro_phrase_for_ir(t) {
    return false
  }

  if looks_like_list_intro_line_for_ir(t) {
    return false
  }

  let words : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.trim().to_owned()
    if w != "" {
      words.push(w)
    }
  }

  if words.length() == 0 || words.length() > 8 {
    return false
  }

  let mut latin_words = 0
  let mut good_caps = 0

  for w in words {
    if starts_with_latin_for_ir(w) {
      latin_words += 1
      match first_char_for_ir(w) {
        Some(c) => if c >= 'A' && c <= 'Z' { good_caps += 1 }
        None => ()
      }
    }
  }

  if words.length() == 1 {
    return latin_words == 1 && good_caps == 1
  }

  latin_words >= 2 && good_caps >= 2
}

///|
/// 更像“压缩命题标题短语”。
/// 例如：
/// - Cross-page should merge
/// - Cross-page should NOT merge
/// - Heading vs Short Sentence
fn looks_like_compact_predicative_title_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    is_probable_page_number_for_ir(t) ||
    looks_like_side_marker_label_line_for_ir(t) {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() < 2 || words.length() > 6 {
    return false
  }

  let first = ascii_lower_for_ir(strip_edge_punct_for_ir(words[0]))
  if first == "this" || first == "the" || first == "a" || first == "an" {
    return false
  }

  let mut has_vs = false
  let mut has_modal = false
  let mut has_latin = false

  for w in words {
    let lw = ascii_lower_for_ir(strip_edge_punct_for_ir(w))
    if lw == "vs" {
      has_vs = true
    }
    if lw == "should" ||
      lw == "must" ||
      lw == "can" ||
      lw == "will" ||
      lw == "may" {
      has_modal = true
    }
    if starts_with_latin_for_ir(w) {
      has_latin = true
    }
  }

  if !has_latin {
    return false
  }

  if has_vs {
    return true
  }

  if has_modal &&
    words.length() <= 5 &&
    !looks_like_complete_statement_for_ir(t) {
    return true
  }

  false
}

///|
/// 更像完整正文句，而不是标题。
fn looks_like_complete_statement_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return true
  }

  if looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) ||
    looks_like_list_item_sentence_for_ir(t) {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() <= 3 {
    return false
  }

  let mut stop_hits = 0
  let mut verb_hits = 0
  let mut clause_hits = 0

  for w in words {
    let lw = ascii_lower_for_ir(strip_edge_punct_for_ir(w))
    if lw == "" {
      continue
    }

    if is_statement_stopword_for_ir(lw) {
      stop_hits += 1
    }
    if is_statement_verb_for_ir(lw) {
      verb_hits += 1
    }
    if is_statement_clause_marker_for_ir(lw) {
      clause_hits += 1
    }
  }

  if words.length() >= 8 && (stop_hits >= 2 || verb_hits >= 1) {
    return true
  }

  if clause_hits >= 1 && words.length() >= 6 {
    return true
  }

  let first = ascii_lower_for_ir(strip_edge_punct_for_ir(words[0]))
  if (first == "this" || first == "the" || first == "a" || first == "an") &&
    words.length() >= 5 &&
    verb_hits >= 1 {
    return true
  }

  false
}

///|
fn looks_like_compact_cjk_heading_for_ir(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return false
  }

  if contains_sentence_punct_inside_for_ir(t) {
    return false
  }

  if looks_like_list_item_sentence_for_ir(t) {
    return false
  }

  if looks_like_figure_or_table_caption_for_ir(t) {
    return false
  }

  if looks_like_list_intro_line_for_ir(t) {
    return false
  }

  if starts_with_latin_for_ir(t) {
    return false
  }

  let n = t.to_array().length()
  if n < 2 || n > 12 {
    return false
  }

  if t.contains(" ") {
    return false
  }

  for c in t.to_array() {
    if !is_cjkish_for_ir(c) {
      return false
    }
  }

  true
}

///|
fn looks_like_strong_document_title_for_ir(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  if is_probable_page_number_for_ir(t) ||
    looks_like_side_marker_label_line_for_ir(t) ||
    ends_like_sentence_for_heading(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) {
    return false
  }

  // 文档主标题不接受显式 section 编号。
  if infer_section_depth_for_ir(t) > 0 {
    return false
  }

  let n = t.to_array().length()
  if n < 4 || n > 80 {
    return false
  }

  looks_like_english_title_for_ir(t) ||
  looks_like_compact_cjk_heading_for_ir(t) ||
  looks_like_mixed_document_title_for_ir(t) ||
  looks_like_compact_predicative_title_for_ir(t)
}

///|
fn looks_like_mixed_document_title_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) {
    return false
  }

  let n = t.to_array().length()
  if n < 6 || n > 50 {
    return false
  }

  let words : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.trim().to_owned()
    if w != "" {
      words.push(w)
    }
  }

  if words.length() < 2 || words.length() > 10 {
    return false
  }

  let mut has_latin = false
  let mut has_non_latin = false
  let mut good_caps = 0
  for w in words {
    if starts_with_latin_for_ir(w) {
      has_latin = true
      match first_char_for_ir(w) {
        Some(c) => if c >= 'A' && c <= 'Z' { good_caps += 1 }
        None => ()
      }
    } else {
      has_non_latin = true
    }
  }

  has_latin && has_non_latin && good_caps >= 1
}

///|
fn looks_like_document_title_phrase_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if looks_like_common_section_label_for_ir(t) {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() < 2 || words.length() > 10 {
    return false
  }

  let lt = ascii_lower_for_ir(t)
  lt.contains("report") ||
  lt.contains("pipeline") ||
  lt.contains("test") ||
  lt.contains("sample") ||
  lt.contains("mvp") ||
  lt.contains("markitdown") ||
  lt.contains("moonbit")
}

///|
/// 常见 section 标题词表。
fn looks_like_common_section_label_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  let lt = ascii_lower_for_ir(t)
  if lt == "introduction" ||
    lt == "method" ||
    lt == "methods" ||
    lt == "background" ||
    lt == "summary" ||
    lt == "details" ||
    lt == "conclusion" ||
    lt == "next section" ||
    lt == "related work" ||
    lt == "discussion" ||
    lt == "results" {
    return true
  }

  if t == "技术路线" ||
    t == "研究内容" ||
    t == "研究方法" ||
    t == "研究目标" ||
    t == "研究背景" ||
    t == "项目概述" ||
    t == "总结" ||
    t == "结论" ||
    t == "下一节" {
    return true
  }

  false
}

///|
/// 后继 block 像正文：有助于文档主标题判定。
fn next_block_looks_like_body_for_h1(next : PdfConvertBlock?) -> Bool {
  match next {
    None => false
    Some(b) => {
      let t = b.text.trim().to_owned()
      if t == "" {
        return false
      }

      b.kind == PdfConvertBlockKind::Paragraph ||
      ends_like_sentence_for_heading(t) ||
      looks_like_list_item_sentence_for_ir(t)
    }
  }
}

///|
fn split_non_empty_words_for_ir(text : String) -> Array[String] {
  let out : Array[String] = []
  for sv in text.split(" ") {
    let w = sv.trim().to_owned()
    if w != "" {
      out.push(w)
    }
  }
  out
}

///|
fn ascii_lower_for_ir(text : String) -> String {
  let mut out = ""
  for c in text.to_array() {
    if c >= 'A' && c <= 'Z' {
      let d = c.to_int() - 'A'.to_int() + 'a'.to_int()
      out = out + Int::unsafe_to_char(d).to_string()
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
fn strip_edge_punct_for_ir(text : String) -> String {
  let cs = text.to_array()
  if cs.length() == 0 {
    return text
  }

  let mut start = 0
  let mut end_ = cs.length()

  while start < end_ && is_simple_edge_punct_for_ir(cs[start]) {
    start += 1
  }

  while end_ > start && is_simple_edge_punct_for_ir(cs[end_ - 1]) {
    end_ -= 1
  }

  let mut out = ""
  let mut i = start
  while i < end_ {
    out = out + cs[i].to_string()
    i += 1
  }
  out
}

///|
fn is_simple_edge_punct_for_ir(c : Char) -> Bool {
  c == '"' ||
  c == '\'' ||
  c == '(' ||
  c == ')' ||
  c == '[' ||
  c == ']' ||
  c == '{' ||
  c == '}' ||
  c == ',' ||
  c == '.' ||
  c == ':' ||
  c == ';' ||
  c == '!' ||
  c == '?' ||
  c == '“' ||
  c == '”' ||
  c == '‘' ||
  c == '’' ||
  c == '（' ||
  c == '）'
}

///|
fn is_statement_stopword_for_ir(word : String) -> Bool {
  word == "this" ||
  word == "the" ||
  word == "a" ||
  word == "an" ||
  word == "that" ||
  word == "these" ||
  word == "those" ||
  word == "it" ||
  word == "its" ||
  word == "their" ||
  word == "his" ||
  word == "her"
}

///|
fn is_statement_verb_for_ir(word : String) -> Bool {
  word == "is" ||
  word == "are" ||
  word == "was" ||
  word == "were" ||
  word == "be" ||
  word == "been" ||
  word == "being" ||
  word == "has" ||
  word == "have" ||
  word == "had" ||
  word == "does" ||
  word == "do" ||
  word == "did"
}

///|
fn is_statement_clause_marker_for_ir(word : String) -> Bool {
  word == "because" ||
  word == "which" ||
  word == "when" ||
  word == "where" ||
  word == "while" ||
  word == "although" ||
  word == "though" ||
  word == "since" ||
  word == "if"
}

///|
fn clamp_heading_level(level : Int, max_heading : Int) -> Int {
  if max_heading <= 0 {
    return 1
  }
  if level < 1 {
    return 1
  }
  if level > max_heading {
    return max_heading
  }
  level
}

///|
fn ends_like_sentence_for_heading(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？") ||
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("；") ||
  t.has_suffix(";") ||
  t.has_suffix("：") ||
  t.has_suffix(":")
}

///|
fn looks_like_list_item_sentence_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if t.has_prefix("- ") || t.has_prefix("* ") || t.has_prefix("• ") {
    return true
  }

  let cs = t.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if has_digit && i + 1 < n {
    let c = cs[i]
    if (c == '.' || c == '、' || c == ')' || c == '）') && cs[i + 1] == ' ' {
      return true
    }
  }

  false
}

///|
fn looks_like_figure_or_table_caption_for_ir(text : String) -> Bool {
  @text.looks_like_figure_or_table_caption(text)
}

///|
fn looks_like_intro_phrase_for_ir(text : String) -> Bool {
  @text.looks_like_intro_phrase(text)
}

///|
fn looks_like_list_intro_line_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if !t.has_suffix(":") && !t.has_suffix("：") {
    return false
  }

  t.to_array().length() <= 30
}

///|
fn looks_like_side_marker_label_line_for_ir(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" || !t.contains(" ") || !t.contains("-") {
    return false
  }

  let mut first = ""
  for sv in t.split(" ") {
    let w = sv.trim().to_owned()
    if w != "" {
      first = w
      break
    }
  }
  if first == "" {
    return false
  }

  if first.has_prefix("LEFT-") || first.has_prefix("RIGHT-") {
    return true
  }

  let mut has_upper = false
  for c in first.to_array() {
    let ok = (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-'
    if !ok {
      return false
    }
    if c >= 'A' && c <= 'Z' {
      has_upper = true
    }
  }

  has_upper && first.contains("-")
}

///|
fn is_probable_page_number_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if is_probable_page_number_like(t) {
    return true
  }

  t.contains("第") && t.contains("页")
}

///|
fn starts_with_latin_for_ir(s : String) -> Bool {
  match first_char_for_ir(s) {
    Some(c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
    None => false
  }
}

///|
fn first_char_for_ir(s : String) -> Char? {
  let cs = s.to_array()
  if cs.length() == 0 {
    return None
  }
  Some(cs[0])
}

///|
fn contains_sentence_punct_inside_for_ir(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n <= 2 {
    return false
  }

  let mut i = 1
  while i + 1 < n {
    let c = cs[i]
    if c == '。' ||
      c == '！' ||
      c == '？' ||
      c == '.' ||
      c == '!' ||
      c == '?' ||
      c == '；' ||
      c == ';' ||
      c == '：' ||
      c == ':' {
      return true
    }
    i = i + 1
  }

  false
}

///|
fn is_cjkish_for_ir(c : Char) -> Bool {
  is_cjk_char(c) || c == '（' || c == '）' || c == '《' || c == '》'
}

///|
/// heading 输出前做最小规范化：
/// - 当前只修中文章节标题里的缺失空格
fn normalize_heading_text_for_ir(text : String) -> String {
  let t = text.trim().to_owned()
  if t == "" {
    return t
  }

  normalize_cjk_chapter_heading_spacing(t)
}

///|
/// 在“章 / 节”后面补一个空格：
/// - 第一章项目概述 -> 第一章 项目概述
/// - 第二章技术路线 -> 第二章 技术路线
/// - 第三节方法 -> 第三节 方法
fn normalize_cjk_chapter_heading_spacing(text : String) -> String {
  let arr = text.to_array()
  if arr.is_empty() {
    return text
  }

  let mut out = ""
  let mut i = 0

  while i < arr.length() {
    let ch = arr[i]
    out = out + ch.to_string()

    if should_insert_space_after_cjk_heading_marker(arr, i) {
      out = out + " "
    }

    i = i + 1
  }

  out
}

///|
fn should_insert_space_after_cjk_heading_marker(
  arr : Array[Char],
  index : Int,
) -> Bool {
  let ch = arr[index]

  if ch != '章' && ch != '节' {
    return false
  }

  if index + 1 >= arr.length() {
    return false
  }

  let next = arr[index + 1]

  if next == ' ' {
    return false
  }

  is_cjk_char(next)
}

///|
/// 常见 CJK 统一表意文字范围 + 扩展 A + 兼容表意文字。
fn is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn is_digit_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0x30 && code <= 0x39
}
