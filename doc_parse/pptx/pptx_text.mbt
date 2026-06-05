///|
fn paragraph_level(xml : Bytes, start : Int, end_ : Int) -> Int raise {
  let ppr_pat = pat("<a:pPr")
  let gt_pat = pat(">")
  let ppr0 = find_bytes(xml, ppr_pat, start)
  match ppr0 {
    None => 0
    Some(i0) =>
      if i0 >= end_ {
        0
      } else {
        match find_bytes(xml, gt_pat, i0) {
          None => 0
          Some(gt0) =>
            if gt0 >= end_ {
              0
            } else {
              let tag = xml[i0:gt0 + 1].to_owned()
              match read_attr_value_in_tag_bytes(tag, "lvl") {
                Some(v) => parse_nonneg_int(v)
                None => 0
              }
            }
        }
      }
  }
}

///|
fn paragraph_bullet_kind(
  xml : Bytes,
  start : Int,
  end_ : Int,
) -> PptxBulletKind? {
  let bu_char = pat("<a:buChar")
  let bu_auto = pat("<a:buAutoNum")
  let bu_blip = pat("<a:buBlip")
  let bu_none = pat("<a:buNone")

  let has_bu_none = match find_bytes(xml, bu_none, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_none {
    return None
  }

  let has_bu_auto = match find_bytes(xml, bu_auto, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_auto {
    return Some(PptxBulletKind::Ordered)
  }

  let has_bu_char = match find_bytes(xml, bu_char, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_char {
    return Some(PptxBulletKind::Unordered)
  }

  let has_bu_blip = match find_bytes(xml, bu_blip, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_blip {
    return Some(PptxBulletKind::Unordered)
  }

  None
}

///|
fn extract_plain_text_runs(xml : Bytes, start : Int, end_ : Int) -> String {
  let open_t = pat("<a:t>")
  let close_t = pat("</a:t>")

  let mut tpos = start
  let mut acc = ""
  while tpos < end_ {
    let t0 = find_bytes(xml, open_t, tpos)
    match t0 {
      None => break
      Some(t0i) => {
        if t0i >= end_ {
          break
        }
        let content_start = t0i + open_t.length()
        let t1 = find_bytes(xml, close_t, content_start)
        match t1 {
          None => break
          Some(t1i) => {
            if t1i > end_ {
              break
            }
            let seg = xml[content_start:t1i].to_owned()
            let s = @utf8.decode(seg, ignore_bom=false) catch { _ => "" }
            acc = acc + s
            tpos = t1i + close_t.length()
          }
        }
      }
    }
  }
  xml_unescape(acc)
}

///|
fn resolve_hyperlink(
  ctx : PptxShapeParseContext,
  rid : String?,
  object_ref : String?,
) -> PptxHyperlink? {
  match rid {
    Some(rel_id) =>
      match find_pptx_relationship_by_id(ctx.rels, rel_id) {
        Some(rel) =>
          if rel.rel_type.has_suffix("/hyperlink") {
            Some({
              relationship_id: Some(rel.id),
              target: Some(rel.resolved_target),
              is_external: rel.target_mode == PptxTargetMode::External,
            })
          } else {
            Some({
              relationship_id: Some(rel.id),
              target: Some(rel.resolved_target),
              is_external: false,
            })
          }
        None => {
          ctx.issues.push(
            pptx_issue(
              PptxValidationIssueKind::MissingRelationshipTarget,
              PptxValidationSeverity::Warning,
              Some(ctx.source_part),
              Some(rel_id),
              object_ref,
              "missing hyperlink relationship target: " + rel_id,
            ),
          )
          Some({
            relationship_id: Some(rel_id),
            target: None,
            is_external: false,
          })
        }
      }
    None => None
  }
}

///|
fn run_hyperlink_rid(run : Bytes) -> String? raise {
  let open_h = pat("<a:hlinkClick")
  let gt_pat = pat(">")
  let p0 = find_bytes(run, open_h, 0).unwrap_or(-1)
  if p0 < 0 {
    return None
  }
  let gt = find_bytes(run, gt_pat, p0).unwrap_or(-1)
  if gt < 0 {
    return None
  }
  let tag = run[p0:gt + 1].to_owned()
  read_attr_value_in_tag_bytes(tag, "r:id")
}

///|
fn push_hyperlink_if_present(
  out : Array[PptxHyperlink],
  link : PptxHyperlink?,
) -> Unit {
  match link {
    Some(item) => out.push(item)
    None => ()
  }
}

///|
fn parse_text_runs_from_paragraph(
  xml : Bytes,
  start : Int,
  end_ : Int,
  ctx : PptxShapeParseContext,
  object_ref : String?,
) -> (Array[PptxTextRun], Array[PptxHyperlink]) raise {
  let runs : Array[PptxTextRun] = []
  let links : Array[PptxHyperlink] = []
  let mut pos = start

  let open_r = pat("<a:r")
  let close_r = pat("</a:r>")
  let open_fld = pat("<a:fld")
  let close_fld = pat("</a:fld>")
  let open_br = pat("<a:br")
  let gt_pat = pat(">")

  while pos < end_ {
    let p_r = find_bytes(xml, open_r, pos).unwrap_or(-1)
    let p_f = find_bytes(xml, open_fld, pos).unwrap_or(-1)
    let p_b = find_bytes(xml, open_br, pos).unwrap_or(-1)

    let mut p = -1
    let mut kind = 0
    if p_r >= 0 {
      p = p_r
      kind = 1
    }
    if p_f >= 0 && (p < 0 || p_f < p) {
      p = p_f
      kind = 2
    }
    if p_b >= 0 && (p < 0 || p_b < p) {
      p = p_b
      kind = 3
    }
    if p < 0 || p >= end_ {
      break
    }

    if kind == 3 {
      let gt = find_bytes(xml, gt_pat, p).unwrap_or(-1)
      if gt < 0 || gt >= end_ {
        break
      }
      runs.push({
        kind: PptxTextRunKind::LineBreak,
        text: "",
        relationship_id: None,
        target: None,
        is_external: false,
      })
      pos = gt + 1
      continue
    }

    let gt = find_bytes(xml, gt_pat, p).unwrap_or(-1)
    if gt < 0 || gt >= end_ {
      break
    }
    let close_pat = if kind == 1 { close_r } else { close_fld }
    let close = find_bytes(xml, close_pat, gt + 1).unwrap_or(-1)
    if close < 0 || close > end_ {
      pos = gt + 1
      continue
    }

    let block = xml[p:close + close_pat.length()].to_owned()
    let text = extract_plain_text_runs(block, 0, block.length())
    let link = resolve_hyperlink(ctx, run_hyperlink_rid(block), object_ref)
    push_hyperlink_if_present(links, link)

    if text != "" {
      let (relationship_id, target, is_external) = match link {
        Some(item) => (item.relationship_id, item.target, item.is_external)
        None => (None, None, false)
      }
      runs.push({
        kind: if kind == 1 {
          PptxTextRunKind::Text
        } else {
          PptxTextRunKind::Field
        },
        text,
        relationship_id,
        target,
        is_external,
      })
    }

    pos = close + close_pat.length()
  }

  if runs.length() == 0 {
    let fallback = extract_plain_text_runs(xml, start, end_)
    if fallback != "" {
      runs.push({
        kind: PptxTextRunKind::Text,
        text: fallback,
        relationship_id: None,
        target: None,
        is_external: false,
      })
    }
  }

  (runs, links)
}

///|
fn parse_a_text_paragraphs(
  body_xml : Bytes,
  ctx : PptxShapeParseContext,
  object_ref : String?,
) -> Array[PptxTextParagraph] raise {
  let paras : Array[PptxTextParagraph] = []
  let open_p = pat("<a:p")
  let close_p = pat("</a:p>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let p0 = find_bytes(body_xml, open_p, pos)
    match p0 {
      None => break
      Some(i0) =>
        match find_bytes(body_xml, gt_pat, i0) {
          None => break
          Some(gt0) =>
            match find_bytes(body_xml, close_p, gt0 + 1) {
              None => break
              Some(end) => {
                let (runs, links) = parse_text_runs_from_paragraph(
                  body_xml,
                  gt0 + 1,
                  end,
                  ctx,
                  object_ref,
                )
                let has_content = runs.length() > 0
                if has_content {
                  paras.push({
                    runs,
                    level: paragraph_level(body_xml, gt0 + 1, end),
                    bullet_kind: paragraph_bullet_kind(body_xml, gt0 + 1, end),
                    source_shape_ref: object_ref,
                    hyperlink_refs: links,
                  })
                }
                pos = end + close_p.length()
              }
            }
        }
    }
  }

  paras
}

///|
fn parse_pptx_text_paragraphs_from_shape(
  shape_xml : Bytes,
  ctx : PptxShapeParseContext,
  object_ref : String?,
) -> Array[PptxTextParagraph] raise {
  let open_body = pat("<p:txBody")
  let close_body = pat("</p:txBody>")
  let gt_pat = pat(">")
  let body0 = find_bytes(shape_xml, open_body, 0)
  match body0 {
    None => []
    Some(i0) =>
      match find_bytes(shape_xml, gt_pat, i0) {
        None => []
        Some(gt0) =>
          match find_bytes(shape_xml, close_body, gt0 + 1) {
            None => []
            Some(end) =>
              parse_a_text_paragraphs(
                shape_xml[gt0 + 1:end].to_owned(),
                ctx,
                object_ref,
              )
          }
      }
  }
}

///|
fn parse_pptx_text_paragraphs_from_a_body(
  body_xml : Bytes,
  ctx : PptxShapeParseContext,
  object_ref : String?,
) -> Array[PptxTextParagraph] raise {
  let open_body = pat("<a:txBody")
  let close_body = pat("</a:txBody>")
  let gt_pat = pat(">")
  let body0 = find_bytes(body_xml, open_body, 0)
  match body0 {
    None => []
    Some(i0) =>
      match find_bytes(body_xml, gt_pat, i0) {
        None => []
        Some(gt0) =>
          match find_bytes(body_xml, close_body, gt0 + 1) {
            None => []
            Some(end) =>
              parse_a_text_paragraphs(
                body_xml[gt0 + 1:end].to_owned(),
                ctx,
                object_ref,
              )
          }
      }
  }
}

///|
fn collect_hyperlinks_from_paragraphs(
  paragraphs : Array[PptxTextParagraph],
) -> Array[PptxHyperlink] {
  let out : Array[PptxHyperlink] = []
  for para in paragraphs {
    for link in para.hyperlink_refs {
      out.push(link)
    }
  }
  out
}
