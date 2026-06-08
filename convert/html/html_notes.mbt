///|
/// M11 quarantine: raw note planning is retained as an obsolete scanner
/// artifact. Normal runtime consumes parser-owned note facts and keeps only
/// convert-owned note placement policy.
priv struct HtmlNotePlan {
  refs_by_signature : Map[String, @cor.NoteRef]
  body_ranges : Array[(Int, Int)]
  definitions : Array[@cor.NoteDefinition]
}

///|
priv struct HtmlNoteTarget {
  id : String
  body : String
  open_start : Int
  end_after_close : Int
}

///|
fn empty_html_note_plan() -> HtmlNotePlan {
  { refs_by_signature: Map([]), body_ranges: [], definitions: [] }
}

///|
fn build_html_note_plan(bs : Bytes) -> HtmlNotePlan {
  let refs_by_signature : Map[String, @cor.NoteRef] = {}
  let body_ranges : Array[(Int, Int)] = []
  let definitions : Array[@cor.NoteDefinition] = []
  let targets = collect_html_note_targets(bs)
  if targets.length() == 0 {
    return { refs_by_signature, body_ranges, definitions }
  }

  let seen_targets : Map[String, Bool] = {}
  let open_a = pat("<a")
  let close_a = pat("</a>")
  let gt_pat = pat(">")
  let mut pos = 0
  while true {
    let a0 = find_bytes_case_insensitive(bs, open_a, pos)
    match a0 {
      None => break
      Some(i0) => {
        let gt0 = find_bytes(bs, gt_pat, i0)
        match gt0 {
          None => break
          Some(q0) => {
            let tag0 = @utf8.decode(bs[i0:q0 + 1].to_owned(), ignore_bom=false) catch {
              _ => ""
            }
            let href = sanitize_html_href(
                read_html_attr_value(tag0, "href").unwrap_or(""),
              )
              .unwrap_or("")
              .trim()
              .to_owned()
            match html_fragment_id_from_href(href) {
              None => ()
              Some(target_id) =>
                match find_html_note_target(targets, target_id) {
                  None => ()
                  Some(target) =>
                    if html_anchor_is_strong_noteref(tag0) {
                      let inner_start = q0 + 1
                      let a_end0 = find_bytes_case_insensitive(
                        bs, close_a, inner_start,
                      )
                      match a_end0 {
                        None => ()
                        Some(a_end) => {
                          let marker = html_note_marker_from_bytes(
                            bs[inner_start:a_end].to_owned(),
                          )
                          if marker != "" {
                            let note_id = html_clean_note_id(target.id)
                            let note = make_html_note_ref(note_id, marker)
                            refs_by_signature[html_note_ref_signature(
                              href, marker,
                            )] = note
                            if !seen_targets.contains(note_id) {
                              seen_targets[note_id] = true
                              body_ranges.push(
                                (target.open_start, target.end_after_close),
                              )
                              definitions.push(
                                make_html_note_definition(
                                  note_id, marker, target,
                                ),
                              )
                            }
                          }
                        }
                      }
                    }
                }
            }
            pos = q0 + 1
          }
        }
      }
    }
  }

  { refs_by_signature, body_ranges, definitions }
}

///|
fn collect_html_note_targets(bs : Bytes) -> Array[HtmlNoteTarget] {
  let out : Array[HtmlNoteTarget] = []
  let lt = pat("<")
  let gt = pat(">")
  let mut pos = 0
  while true {
    let p0 = find_bytes(bs, lt, pos)
    match p0 {
      None => break
      Some(p) => {
        let q0 = find_bytes(bs, gt, p)
        match q0 {
          None => break
          Some(q) => {
            let tag0 = @utf8.decode(bs[p:q + 1].to_owned(), ignore_bom=false) catch {
              _ => ""
            }
            match html_open_tag_name(tag0) {
              None => ()
              Some(tag_name) =>
                match read_html_attr_value(tag0, "id") {
                  None => ()
                  Some(raw_id) => {
                    let id = html_unescape(raw_id).trim().to_owned()
                    if id != "" &&
                      html_tag_can_be_note_body(tag_name) &&
                      html_tag_is_footnote_like(tag_name, tag0, id) {
                      match find_matching_tag_end(bs, p, tag_name) {
                        None => ()
                        Some(close_idx) => {
                          let body = html_note_body_from_bytes(
                            bs[q + 1:close_idx].to_owned(),
                          )
                          if body != "" {
                            out.push({
                              id,
                              body,
                              open_start: p,
                              end_after_close: close_idx +
                              ("</" + tag_name + ">").length(),
                            })
                          }
                        }
                      }
                    }
                  }
                }
            }
            pos = q + 1
          }
        }
      }
    }
  }
  out
}

///|
fn find_html_note_target(
  targets : Array[HtmlNoteTarget],
  id : String,
) -> HtmlNoteTarget? {
  let wanted = id.trim().to_owned()
  for target in targets {
    if target.id == wanted {
      return Some(target)
    }
  }
  None
}

///|
fn html_note_body_range_end(plan : HtmlNotePlan, start : Int) -> Int? {
  for range in plan.body_ranges {
    let (range_start, range_end) = range
    if range_start == start {
      return Some(range_end)
    }
  }
  None
}

///|
fn html_anchor_is_strong_noteref(tag : String) -> Bool {
  html_attr_token_contains(tag, "epub:type", "noteref") ||
  html_attr_token_contains(tag, "role", "doc-noteref")
}

///|
fn html_tag_is_footnote_like(
  tag_name : String,
  tag : String,
  id : String,
) -> Bool {
  html_attr_token_contains(tag, "epub:type", "footnote") ||
  html_attr_token_contains(tag, "role", "doc-footnote") ||
  html_footnote_like_text(tag_name) ||
  html_footnote_like_text(id) ||
  read_html_attr_value(tag, "class")
  .map(fn(value) { html_footnote_like_text(value) })
  .unwrap_or(false)
}

///|
fn html_tag_can_be_note_body(tag_name : String) -> Bool {
  tag_name == "aside" ||
  tag_name == "section" ||
  tag_name == "li" ||
  tag_name == "div"
}

///|
fn html_attr_token_contains(
  tag : String,
  attr_name : String,
  token : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => html_token_text_contains(value, token)
  }
}

///|
fn html_token_text_contains(value : String, token : String) -> Bool {
  let lower = value.to_lower()
  let wanted = token.to_lower()
  lower.contains(wanted)
}

///|
fn html_footnote_like_text(value : String) -> Bool {
  let lower = value.to_lower()
  lower.contains("footnote") ||
  lower.contains("endnote") ||
  lower == "fn" ||
  lower.has_prefix("fn-") ||
  lower.has_prefix("fn_") ||
  lower.has_prefix("fn:")
}

///|
fn html_fragment_id_from_href(href : String) -> String? {
  let trimmed = href.trim().to_owned()
  if !trimmed.has_prefix("#") || trimmed.length() <= 1 {
    return None
  }
  Some(html_unescape(trimmed[1:].to_owned()).trim().to_owned())
}

///|
fn html_clean_note_id(id : String) -> String {
  let trimmed = id.trim().to_owned()
  if trimmed.has_prefix("fn:") && trimmed.length() > 3 {
    trimmed[3:].to_owned()
  } else {
    trimmed
  }
}

///|
fn html_note_marker_from_bytes(bs : Bytes) -> String {
  let marker = render_inlines(html_inlines_from_bytes(bs)).trim().to_owned()
  if marker == "" {
    ""
  } else {
    marker
  }
}

///|
fn html_note_body_from_bytes(bs : Bytes) -> String {
  render_inlines(html_inlines_from_bytes(bs)).trim().to_owned()
}

///|
fn make_html_note_ref(note_id : String, marker : String) -> @cor.NoteRef {
  {
    note_id,
    marker,
    kind: @cor.NoteKind::Footnote,
    source_kind: @cor.NoteSourceKind::HtmlNoteRef,
    confidence: @cor.NoteConfidence::High,
    body_status: @cor.NoteBodyStatus::Resolved,
  }
}

///|
fn make_html_note_definition(
  note_id : String,
  marker : String,
  target : HtmlNoteTarget,
) -> @cor.NoteDefinition {
  {
    note_id,
    marker,
    kind: @cor.NoteKind::Footnote,
    blocks: [@cor.Block::Paragraph(target.body)],
    placement: @cor.NotePlacement::DocumentEnd,
    source_kind: @cor.NoteSourceKind::HtmlFootnoteBody,
    body_status: @cor.NoteBodyStatus::Resolved,
    origin: None,
  }
}

///|
fn html_note_ref_signature(href : String, marker : String) -> String {
  href.trim().to_owned() + "\u{1F}" + marker.trim().to_owned()
}

///|
fn render_html_note_ref_inline(note : @cor.NoteRef) -> String {
  if note.body_status == @cor.NoteBodyStatus::Resolved &&
    note.note_id.trim() != "" {
    return "[^" + note.note_id.trim().to_owned() + "]"
  }
  let marker = note.marker.trim().to_owned()
  if marker == "" {
    ""
  } else if marker.has_prefix("^") {
    marker
  } else {
    "^" + marker
  }
}
