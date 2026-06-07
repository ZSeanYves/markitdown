///|
fn parse_text_body(
  ctx : PptxSourceParseContext,
  part_name : String,
  xml : Bytes,
  parent_key : String,
) -> PptxTextBody? raise {
  match find_element_inner(xml, "<p:txBody", "</p:txBody>") {
    Some(body) => {
      let source_key = pptx_source_key(part_name, parent_key + "/text")
      let paragraphs = parse_paragraphs(
        ctx,
        part_name,
        body,
        source_key.node_key,
      )
      if paragraphs.length() == 0 {
        None
      } else {
        Some({ paragraphs, source_key })
      }
    }
    None => None
  }
}

///|
fn parse_paragraphs(
  ctx : PptxSourceParseContext,
  part_name : String,
  body_xml : Bytes,
  parent_key : String,
) -> Array[PptxParagraph] raise {
  let out : Array[PptxParagraph] = []
  let mut pos = 0
  let mut idx = 0
  while true {
    let p0 = find_bytes(body_xml, pat("<a:p"), pos)
    match p0 {
      None => break
      Some(start) =>
        match slice_full_element(body_xml, start, "a:p") {
          Some((block, next_pos)) => {
            idx += 1
            let key = parent_key + "/p-" + idx.to_string()
            let runs = parse_runs(ctx, part_name, block, key)
            if runs.length() > 0 {
              out.push({
                runs,
                list_hint: read_list_hint(block),
                source_key: pptx_source_key(part_name, key),
              })
            }
            pos = next_pos
          }
          None => break
        }
    }
  }
  out
}

///|
fn parse_runs(
  ctx : PptxSourceParseContext,
  part_name : String,
  paragraph_xml : Bytes,
  parent_key : String,
) -> Array[PptxRun] raise {
  let out : Array[PptxRun] = []
  let mut pos = 0
  let mut idx = 0
  while pos < paragraph_xml.length() {
    let r0 = find_bytes(paragraph_xml, pat("<a:r"), pos).unwrap_or(-1)
    let f0 = find_bytes(paragraph_xml, pat("<a:fld"), pos).unwrap_or(-1)
    let b0 = find_bytes(paragraph_xml, pat("<a:br"), pos).unwrap_or(-1)
    let mut next = -1
    let mut kind = ""
    if r0 >= 0 {
      next = r0
      kind = "a:r"
    }
    if f0 >= 0 && (next < 0 || f0 < next) {
      next = f0
      kind = "a:fld"
    }
    if b0 >= 0 && (next < 0 || b0 < next) {
      next = b0
      kind = "a:br"
    }
    if next < 0 {
      break
    }
    idx += 1
    let key = parent_key + "/r-" + idx.to_string()
    if kind == "a:br" {
      let gt = find_bytes(paragraph_xml, pat(">"), next).unwrap_or(-1)
      if gt < 0 {
        break
      }
      out.push({
        inlines: [PptxInline::Break],
        source_key: pptx_source_key(part_name, key),
      })
      pos = gt + 1
    } else {
      match slice_full_element(paragraph_xml, next, kind) {
        Some((block, next_pos)) => {
          let text = extract_text_from_run(block)
          let link = resolve_run_hyperlink(ctx, part_name, block, key)
          let inlines : Array[PptxInline] = []
          match link {
            Some(h) =>
              if text != "" {
                inlines.push(PptxInline::Hyperlink(h, text))
              }
            None =>
              if text != "" {
                if kind == "a:fld" {
                  inlines.push(PptxInline::Field(text))
                } else {
                  inlines.push(PptxInline::Text(text))
                }
              }
          }
          if inlines.length() > 0 {
            out.push({ inlines, source_key: pptx_source_key(part_name, key) })
          }
          pos = next_pos
        }
        None => break
      }
    }
  }
  out
}

///|
fn extract_text_from_run(run_xml : Bytes) -> String raise {
  let mut out = ""
  let mut pos = 0
  while true {
    let t0 = find_bytes(run_xml, pat("<a:t"), pos)
    match t0 {
      None => break
      Some(start) => {
        let gt = find_bytes(run_xml, pat(">"), start).unwrap_or(-1)
        if gt < 0 {
          break
        }
        let end_ = find_bytes(run_xml, pat("</a:t>"), gt + 1).unwrap_or(-1)
        if end_ < 0 {
          break
        }
        out = out + xml_unescape(bytes_slice_to_string(run_xml, gt + 1, end_))
        pos = end_ + pat("</a:t>").length()
      }
    }
  }
  out
}

///|
fn read_list_hint(paragraph_xml : Bytes) -> PptxListHint? raise {
  let ppr0 = find_bytes(paragraph_xml, pat("<a:pPr"), 0).unwrap_or(-1)
  if ppr0 < 0 {
    return None
  }
  let gt = find_bytes(paragraph_xml, pat(">"), ppr0).unwrap_or(-1)
  if gt < 0 {
    return None
  }
  let ppr = paragraph_xml[ppr0:gt + 1].to_owned()
  let level = parse_int_or_zero(read_attr_value_in_tag_bytes(ppr, "lvl"))
  if contains_bytes(paragraph_xml, pat("<a:buNone")) {
    return None
  }
  if contains_bytes(paragraph_xml, pat("<a:buAutoNum")) {
    return Some({
      level,
      bullet: Some(PptxBulletKind::Ordered),
      source: "a:buAutoNum",
      confidence: PptxConfidence::High,
    })
  }
  if contains_bytes(paragraph_xml, pat("<a:buChar")) ||
    contains_bytes(paragraph_xml, pat("<a:buBlip")) {
    return Some({
      level,
      bullet: Some(PptxBulletKind::Unordered),
      source: "a:buChar",
      confidence: PptxConfidence::High,
    })
  }
  if level > 0 {
    return Some({
      level,
      bullet: None,
      source: "a:pPr/lvl",
      confidence: PptxConfidence::Medium,
    })
  }
  None
}

///|
fn resolve_run_hyperlink(
  ctx : PptxSourceParseContext,
  part_name : String,
  run_xml : Bytes,
  key : String,
) -> PptxHyperlink? raise {
  let rid = read_attr_value_in_first_tag_bytes(run_xml, "<a:hlinkClick", "r:id")
  let anchor = read_attr_value_in_first_tag_bytes(
    run_xml, "<a:hlinkClick", "anchor",
  )
  match rid {
    Some(rel_id) =>
      match find_source_relationship_by_id(ctx, part_name, rel_id) {
        Some(rel) =>
          Some({
            relationship_id: Some(rel_id),
            target: Some(rel.resolved_target),
            anchor,
            is_external: rel.target_mode == PptxTargetMode::External,
            broken: false,
            source_key: pptx_source_key(part_name, key + "/hlink"),
          })
        None => {
          ctx.warnings.push(
            pptx_warning(
              PptxWarningKind::MissingRelationshipTarget,
              PptxWarningSeverity::Warning,
              part_name,
              key,
              Some(rel_id),
              None,
              "missing hyperlink relationship target: " + rel_id,
            ),
          )
          Some({
            relationship_id: Some(rel_id),
            target: None,
            anchor,
            is_external: false,
            broken: true,
            source_key: pptx_source_key(part_name, key + "/hlink"),
          })
        }
      }
    None =>
      match anchor {
        Some(a) =>
          Some({
            relationship_id: None,
            target: None,
            anchor: Some(a),
            is_external: false,
            broken: false,
            source_key: pptx_source_key(part_name, key + "/hlink"),
          })
        None => None
      }
  }
}

///|
fn collect_shape_hyperlinks(
  ctx : PptxSourceParseContext,
  part_name : String,
  shape_xml : Bytes,
  source_key : PptxSourceKey,
) -> Array[PptxHyperlink] raise {
  let out : Array[PptxHyperlink] = []
  let mut pos = 0
  let mut idx = 0
  while true {
    let p0 = find_bytes(shape_xml, pat("<a:hlinkClick"), pos)
    match p0 {
      None => break
      Some(start) => {
        let gt = find_bytes(shape_xml, pat(">"), start).unwrap_or(-1)
        if gt < 0 {
          break
        }
        let tag = shape_xml[start:gt + 1].to_owned()
        idx += 1
        let rid = read_attr_value_in_tag_bytes(tag, "r:id")
        let anchor = read_attr_value_in_tag_bytes(tag, "anchor")
        match rid {
          Some(rel_id) =>
            match find_source_relationship_by_id(ctx, part_name, rel_id) {
              Some(rel) =>
                out.push({
                  relationship_id: Some(rel_id),
                  target: Some(rel.resolved_target),
                  anchor,
                  is_external: rel.target_mode == PptxTargetMode::External,
                  broken: false,
                  source_key: pptx_source_key(
                    part_name,
                    source_key.node_key + "/shape-hlink-" + idx.to_string(),
                  ),
                })
              None =>
                out.push({
                  relationship_id: Some(rel_id),
                  target: None,
                  anchor,
                  is_external: false,
                  broken: true,
                  source_key: pptx_source_key(
                    part_name,
                    source_key.node_key + "/shape-hlink-" + idx.to_string(),
                  ),
                })
            }
          None => ()
        }
        pos = gt + 1
      }
    }
  }
  out
}
