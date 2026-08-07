///|
fn parse_source_presentation(
  ctx : PptxSourceParseContext,
  part_graph : PptxPartGraph,
) -> PptxSourcePresentation raise {
  let part_name = part_graph.root_presentation_part.unwrap_or(
    "ppt/presentation.xml",
  )
  let source_key = pptx_source_key(part_name, "presentation")
  track_source_node(ctx, part_name, "presentation")
  let xml = match read_source_part_text(ctx, part_name) {
    Some(text) => text
    None => return { part_name, slide_refs: [], source_key }
  }
  let entries = parse_presentation_slide_entries(ctx, part_name, xml)
  { part_name, slide_refs: entries, source_key }
}

///|
fn parse_presentation_slide_entries(
  ctx : PptxSourceParseContext,
  part_name : String,
  xml_text : String,
) -> Array[PptxSlideRef] raise {
  let bs = @utf8.encode(xml_text)
  let raw : Array[(String, String?, Bool, String)] = []
  let open_pat = pat("<p:sldId")
  let gt_pat = pat(">")
  let mut pos = 0
  let mut raw_index = 0
  while true {
    let s0 = find_bytes(bs, open_pat, pos)
    match s0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(bs, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let tag = bs[i0:gt0 + 1].to_owned()
            match read_attr_value_in_tag_bytes(tag, "r:id") {
              Some(rid) => {
                raw_index += 1
                let hidden = match read_attr_value_in_tag_bytes(tag, "show") {
                  Some(v) => v == "0" || v.to_lower() == "false"
                  None => false
                }
                raw.push(
                  (
                    rid,
                    read_attr_value_in_tag_bytes(tag, "id"),
                    hidden,
                    "slide-ref-" + raw_index.to_string(),
                  ),
                )
              }
              None => ()
            }
            pos = gt0 + 1
          }
        }
      }
    }
  }

  let out : Array[PptxSlideRef] = []
  let mut slide_index = 1
  for entry in raw {
    let (rid, slide_id, hidden, node_key) = entry
    match find_source_relationship_by_id(ctx, part_name, rid) {
      Some(rel) =>
        if rel.rel_type.has_suffix("/slide") &&
          rel.resolved_target.has_prefix("ppt/slides/") &&
          rel.resolved_target.has_suffix(".xml") {
          out.push({
            slide_id,
            slide_index,
            part_name: rel.resolved_target,
            relationship_id: Some(rid),
            hidden,
            source_key: pptx_source_key(part_name, node_key),
          })
          slide_index += 1
        } else {
          ctx.warnings.push(
            pptx_warning(
              MissingSlideRelationship,
              Warning,
              part_name,
              node_key,
              Some(rid),
              None,
              "slide relationship target is not a slide: " + rid,
            ),
          )
        }
      None =>
        ctx.warnings.push(
          pptx_warning(
            MissingSlideRelationship,
            Warning,
            part_name,
            node_key,
            Some(rid),
            None,
            "missing slide relationship: " + rid,
          ),
        )
    }
  }

  if out.length() > 0 {
    return out
  }
  out
}
