///|
priv struct PdfVisibleAnnotationNote {
  _annotation_index : Int
  text : String
  object_ref : String?
}

///|
fn collect_visible_annotation_notes(
  page : PdfConvertPage,
) -> Array[PdfVisibleAnnotationNote] {
  let out : Array[PdfVisibleAnnotationNote] = []
  let seen_keys : Map[String, Bool] = Map([])

  for annotation in page.annotations {
    if !should_emit_annotation_note_in_markdown(annotation) {
      continue
    }
    match render_visible_annotation_note(annotation, page._page_index) {
      Some(text) => {
        let dedupe_key = visible_annotation_note_dedupe_key(annotation, text)
        if seen_keys.contains(dedupe_key) {
          continue
        }
        seen_keys.set(dedupe_key, true)
        out.push({
          _annotation_index: annotation._annotation_index,
          text,
          object_ref: annotation.object_ref,
        })
      }
      None => ()
    }
  }

  out
}

///|
fn visible_annotation_note_dedupe_key(
  annotation : PdfConvertAnnotation,
  text : String,
) -> String {
  let subtype = annotation.subtype.trim().to_owned()
  let normalized_text = text.trim().to_owned()
  subtype + "|" + annotation.flags.to_string() + "|" + normalized_text
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
