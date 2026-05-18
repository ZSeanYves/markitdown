///|
priv struct RawAnnotationCollectResult {
  annotations : Array[RawAnnotationInfo]
  forms : Array[RawFormFieldInfo]
  issues : Array[PdfRawIssue]
}

///|
/// 注释颜色。
fn color_from_pdf_object(
  pdf : @pdf.Pdf,
  obj : @pdf.PdfObject?,
) -> @model.PdfColor? {
  try {
    match obj {
      Some(@pdf.PdfObject::Array([r, g, b])) =>
        Some({
          r: pdf.getnum(r).to_int(),
          g: pdf.getnum(g).to_int(),
          b: pdf.getnum(b).to_int(),
        })
      _ => None
    }
  } catch {
    _ => None
  }
}

///|
fn uri_from_annotation_action(
  pdf : @pdf.Pdf,
  action : @pdf.PdfObject?,
) -> String? {
  match action {
    Some(action_obj) =>
      match pdf.lookup_direct("/S", action_obj) {
        Some(@pdf.PdfObject::Name(name)) if name.equal_string_bytes("/URI") =>
          string_from_pdf_object(pdf.lookup_direct("/URI", action_obj))
        _ => None
      }
    None => None
  }
}

///|
fn dest_string_from_annotation(
  pdf : @pdf.Pdf,
  annot_obj : @pdf.PdfObject,
) -> String? {
  match pdf.lookup_direct("/Dest", annot_obj) {
    Some(dest) => Some(dest.to_string())
    None =>
      match pdf.lookup_direct("/A", annot_obj) {
        Some(action) =>
          match pdf.lookup_direct("/D", action) {
            Some(dest) => Some(dest.to_string())
            None => None
          }
        None => None
      }
  }
}

///|
fn target_page_from_destination(
  pdf : @pdf.Pdf,
  dest_obj : @pdf.PdfObject,
) -> Int? {
  try {
    let target = @pdfdest.Destination::read(pdf, dest_obj)
    let target_page = @pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(target)
    if target_page > 0 {
      Some(target_page)
    } else {
      None
    }
  } catch {
    _ => None
  }
}

///|
fn target_page_from_annotation(
  pdf : @pdf.Pdf,
  annot_obj : @pdf.PdfObject,
) -> Int? {
  match pdf.lookup_direct("/Dest", annot_obj) {
    Some(dest) => target_page_from_destination(pdf, dest)
    None =>
      match pdf.lookup_direct("/A", annot_obj) {
        Some(action) =>
          match pdf.lookup_direct("/S", action) {
            Some(@pdf.PdfObject::Name(name)) if name.equal_string_bytes("/GoTo") =>
              match pdf.lookup_direct("/D", action) {
                Some(dest) => target_page_from_destination(pdf, dest)
                None => None
              }
            _ => None
          }
        None => None
      }
  }
}

///|
fn annotation_issue(
  kind : PdfRawIssueKind,
  severity : PdfRawIssueSeverity,
  page_index : Int,
  annot_ref : @pdf.PdfObject,
  message : String,
) -> PdfRawIssue {
  {
    kind,
    severity,
    page_index: Some(page_index),
    object_ref: raw_ref_from_pdf_object(annot_ref),
    source_ref: None,
    message,
  }
}

///|
fn bool_from_pdf_name_flag(name : String?) -> Bool? {
  match name {
    Some(raw) => if raw == "/Off" { Some(false) } else { Some(true) }
    None => None
  }
}

///|
fn lookup_form_field_in_chain(
  pdf : @pdf.Pdf,
  annot_obj : @pdf.PdfObject,
  key : String,
) -> @pdf.PdfObject? {
  let current = Ref(Some(annot_obj))
  let visited : Map[Int, Bool] = Map([])

  while current.val is Some(_) {
    let obj = current.val.unwrap()
    match pdf.lookup_direct(key, obj) {
      Some(value) => return Some(value)
      None => ()
    }

    let parent = pdf.lookup_direct("/Parent", obj)
    match parent {
      Some(@pdf.PdfObject::Indirect(obj_num)) =>
        match visited.get(obj_num) {
          Some(_) => return None
          None => {
            visited.set(obj_num, true)
            current.val = Some(pdf.direct(@pdf.PdfObject::Indirect(obj_num)))
          }
        }
      Some(parent_obj) => current.val = Some(pdf.direct(parent_obj))
      None => current.val = None
    }
  }

  None
}

///|
fn lookup_form_field_name_in_chain(
  pdf : @pdf.Pdf,
  annot_obj : @pdf.PdfObject,
  key : String,
) -> String? {
  name_string_from_pdf_object(lookup_form_field_in_chain(pdf, annot_obj, key))
}

///|
fn field_options_from_pdf_object(
  _pdf : @pdf.Pdf,
  obj : @pdf.PdfObject?,
) -> Array[String] {
  let out : Array[String] = []
  match obj {
    Some(@pdf.PdfObject::Array(items)) =>
      for item in items {
        match item {
          @pdf.PdfObject::String(_) =>
            match string_from_pdf_object(Some(item)) {
              Some(text) => out.push(text)
              None => ()
            }
          @pdf.PdfObject::Array(pair) =>
            if pair.length() >= 2 {
              match pair[1] {
                @pdf.PdfObject::String(_) =>
                  match string_from_pdf_object(Some(pair[1])) {
                    Some(text) => out.push(text)
                    None => ()
                  }
                _ =>
                  match pair[0] {
                    @pdf.PdfObject::String(_) =>
                      match string_from_pdf_object(Some(pair[0])) {
                        Some(text) => out.push(text)
                        None => ()
                      }
                    _ => ()
                  }
              }
            } else {
              ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  out
}

///|
fn field_value_from_pdf_object(
  _pdf : @pdf.Pdf,
  obj : @pdf.PdfObject?,
) -> String? {
  match obj {
    Some(@pdf.PdfObject::String(_)) =>
      match string_from_pdf_object(obj) {
        Some(text) => if text.trim() == "" { None } else { Some(text) }
        None => None
      }
    Some(@pdf.PdfObject::Name(name)) => Some(name.to_string_bytes())
    Some(@pdf.PdfObject::Array(items)) => {
      let values : Array[String] = []
      for item in items {
        match item {
          @pdf.PdfObject::String(_) =>
            match string_from_pdf_object(Some(item)) {
              Some(text) => if text.trim() != "" { values.push(text) }
              None => ()
            }
          @pdf.PdfObject::Name(name) => values.push(name.to_string_bytes())
          _ => ()
        }
      }
      if values.is_empty() {
        None
      } else {
        Some(values.join(", "))
      }
    }
    _ => None
  }
}

///|
fn annotation_flags_from_pdf_object(
  pdf : @pdf.Pdf,
  annot_obj : @pdf.PdfObject,
) -> Int {
  match pdf.lookup_direct("/F", annot_obj) {
    Some(@pdf.PdfObject::Integer(flags)) => flags
    Some(value) => pdf.getnum(value).to_int() catch { _ => 0 }
    None => 0
  }
}

///|
fn form_field_from_pdf_object(
  pdf : @pdf.Pdf,
  annot_ref : @pdf.PdfObject,
  page_index : Int,
  annotation_index : Int,
) -> RawFormFieldInfo? {
  let annot_obj = pdf.direct(annot_ref)
  match annot_obj {
    @pdf.PdfObject::Dictionary(_) => {
      let subtype = name_string_from_pdf_object(
        pdf.lookup_direct("/Subtype", annot_obj),
      )
      if subtype != Some("/Widget") {
        return None
      }

      let field_type = lookup_form_field_name_in_chain(pdf, annot_obj, "/FT")
      match field_type {
        Some(ft) => {
          let bbox = match pdf.lookup_direct("/Rect", annot_obj) {
            Some(rect_obj) => parse_pdf_rect(pdf, rect_obj)
            None => None
          }
          let flags = annotation_flags_from_pdf_object(pdf, annot_obj)
          Some({
            id: "form-" +
            page_index.to_string() +
            "-" +
            annotation_index.to_string(),
            page_index,
            object_ref: raw_ref_from_pdf_object(annot_ref),
            field_type: ft,
            flags,
            field_name: string_from_pdf_object(
              lookup_form_field_in_chain(pdf, annot_obj, "/T"),
            ),
            field_label: string_from_pdf_object(
              lookup_form_field_in_chain(pdf, annot_obj, "/TU"),
            ),
            field_value: field_value_from_pdf_object(
              pdf,
              lookup_form_field_in_chain(pdf, annot_obj, "/V"),
            ),
            bbox,
            options: field_options_from_pdf_object(
              pdf,
              lookup_form_field_in_chain(pdf, annot_obj, "/Opt"),
            ),
            checked_state: if ft == "/Btn" {
              bool_from_pdf_name_flag(
                lookup_form_field_name_in_chain(pdf, annot_obj, "/V"),
              )
            } else {
              None
            },
            source_refs: [],
          })
        }
        None => None
      }
    }
    _ => None
  }
}

///|
fn annotation_from_pdf_object(
  pdf : @pdf.Pdf,
  annot_ref : @pdf.PdfObject,
  page_index : Int,
  annotation_index : Int,
) -> Result[RawAnnotationInfo, PdfRawIssue] {
  let annot_obj = pdf.direct(annot_ref)
  match annot_obj {
    @pdf.PdfObject::Dictionary(_) => {
      let bbox = match pdf.lookup_direct("/Rect", annot_obj) {
        Some(rect_obj) => parse_pdf_rect(pdf, rect_obj)
        None => None
      }
      match bbox {
        Some(bbox) => {
          let action = pdf.lookup_direct("/A", annot_obj)
          let flags = annotation_flags_from_pdf_object(pdf, annot_obj)
          Ok({
            id: "annot-" +
            page_index.to_string() +
            "-" +
            annotation_index.to_string(),
            page_index,
            object_ref: raw_ref_from_pdf_object(annot_ref),
            subtype: name_string_from_pdf_object(
              pdf.lookup_direct("/Subtype", annot_obj),
            ).unwrap_or(""),
            flags,
            bbox: Some(bbox),
            contents: string_from_pdf_object(
              pdf.lookup_direct("/Contents", annot_obj),
            ),
            subject: string_from_pdf_object(
              pdf.lookup_direct("/Subj", annot_obj),
            ),
            uri: uri_from_annotation_action(pdf, action),
            dest: dest_string_from_annotation(pdf, annot_obj),
            target_page: target_page_from_annotation(pdf, annot_obj),
            color: color_from_pdf_object(
              pdf,
              pdf.lookup_direct("/C", annot_obj),
            ),
            source_refs: [],
          })
        }
        None =>
          Err(
            annotation_issue(
              PdfRawIssueKind::AnnotationParseWarning,
              PdfRawIssueSeverity::Warning,
              page_index,
              annot_ref,
              "annotation missing or malformed /Rect bbox",
            ),
          )
      }
    }
    _ =>
      Err(
        annotation_issue(
          PdfRawIssueKind::AnnotationParseWarning,
          PdfRawIssueSeverity::Warning,
          page_index,
          annot_ref,
          "annotation is not a dictionary object",
        ),
      )
  }
}

///|
/// 采集页面注释。
fn collect_annotations_from_page(
  pdf : @pdf.Pdf,
  page : @pdfpage.Page,
  page_index : Int,
) -> RawAnnotationCollectResult {
  let out : Array[RawAnnotationInfo] = Array::new()
  let forms : Array[RawFormFieldInfo] = Array::new()
  let issues : Array[PdfRawIssue] = Array::new()
  match pdf.lookup_direct("/Annots", page.rest) {
    Some(@pdf.PdfObject::Array(annots)) =>
      for i = 0; i < annots.length(); i = i + 1 {
        match form_field_from_pdf_object(pdf, annots[i], page_index, i) {
          Some(form) => forms.push(form)
          None => ()
        }
        match annotation_from_pdf_object(pdf, annots[i], page_index, i) {
          Ok(annotation) => out.push(annotation)
          Err(issue) => issues.push(issue)
        }
      }
    Some(_) =>
      issues.push({
        kind: PdfRawIssueKind::AnnotationParseWarning,
        severity: PdfRawIssueSeverity::Warning,
        page_index: Some(page_index),
        object_ref: None,
        source_ref: None,
        message: "page /Annots entry is present but not an array",
      })
    _ => ()
  }
  { annotations: out, forms, issues }
}
