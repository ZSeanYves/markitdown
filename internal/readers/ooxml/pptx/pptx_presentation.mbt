///|
async fn parse_source_presentation(
  ctx : PptxSourceParseContext,
  part_graph : PptxPartGraph,
) -> PptxSourcePresentation {
  let part_name = part_graph.root_presentation_part.unwrap_or(
    "ppt/presentation.xml",
  )
  let source_key = pptx_source_key(part_name, "presentation")
  track_source_node(ctx, part_name, "presentation")
  let entries = parse_presentation_slide_entries(ctx, part_name)
  { part_name, slide_refs: entries, source_key, }
}

///|
async fn parse_presentation_slide_entries(
  ctx : PptxSourceParseContext,
  part_name : String,
) -> Array[PptxSlideRef] {
  let raw : Array[(String, String?, Bool, String)] = []
  let ordinal = Ref(0L)
  ignore(
    @ox.visit_part_xml_tokens(
      ctx.pkg,
      part_name,
      token => {
        if token is StartElement(name, attributes, _, _) &&
          presentation_cursor_slide_name(name) {
          if presentation_cursor_rid(attributes) is Some(rid) {
            ordinal.val += 1L
            let slide_id = presentation_cursor_attribute(attributes, "id")
            let hidden = match
              presentation_cursor_attribute(attributes, "show") {
              Some(value) => value == "0" || value.to_lower() == "false"
              None => false
            }
            let node_key = "slide-ref-" + ordinal.val.to_string()
            presentation_cursor_retain(
              @dzip.archive_budget_context(ctx.pkg.archive),
              [rid, slide_id.unwrap_or(""), node_key],
            )
            raw.push((rid, slide_id, hidden, node_key))
          }
        }
      },
      allow_syntax_recovery=true,
      allow_unbound_prefixes=true,
    ),
  ) catch {
    error => {
      // Tail integrity is validated before a recoverable XML error reaches
      // this boundary. Never publish a successful prefix document or perform
      // more relationship projection after a latched hard failure.
      ensure_pptx_package_integrity(ctx.pkg)
      match error {
        MissingPart(_) => return []
        InvalidXml(message) => raise PptxError::ParseError(message)
        _ => raise PptxError::OoxmlFailure(error.to_string())
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

///|
fn presentation_cursor_slide_name(name : @xml.XmlCursorName) -> Bool {
  name.local_name == "sldId" &&
  (match name.namespace_uri {
    Some(uri) =>
      uri == "http://schemas.openxmlformats.org/presentationml/2006/main" ||
      uri == "http://purl.oclc.org/ooxml/presentationml/main"
    None => name.raw == "p:sldId"
  })
}

///|
fn presentation_cursor_rid(
  attributes : Array[@xml.XmlCursorAttribute],
) -> String? {
  for attribute in attributes {
    if attribute.namespace_declaration || attribute.name.local_name != "id" {
      continue
    }
    let relationship = match attribute.name.namespace_uri {
      Some(uri) =>
        uri ==
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships" ||
        uri == "http://purl.oclc.org/ooxml/officeDocument/relationships"
      None => attribute.name.raw == "r:id"
    }
    if relationship {
      return Some(attribute.value)
    }
  }
  None
}

///|
fn presentation_cursor_attribute(
  attributes : Array[@xml.XmlCursorAttribute],
  key : String,
) -> String? {
  for attribute in attributes {
    if !attribute.namespace_declaration &&
      attribute.name.namespace_uri is None &&
      attribute.name.raw == key {
      return Some(attribute.value)
    }
  }
  None
}

///|
fn presentation_cursor_utf8_size(value : String) -> Int64 {
  let mut size = 0L
  for scalar in value.iter() {
    let code = scalar.to_int()
    size += if code < 0x80 {
      1L
    } else if code < 0x800 {
      2L
    } else if code < 0x10000 {
      3L
    } else {
      4L
    }
  }
  size
}

///|
fn presentation_cursor_retain(
  budget_context : @budget.BudgetContext?,
  values : Array[String],
) -> Unit raise @ox.OoxmlError {
  if budget_context is Some(context) {
    let mut metadata = 0L
    let mut payload = 0L
    for value in values {
      metadata += presentation_cursor_utf8_size(value)
      payload += value.length().to_int64() * 2L
    }
    match context.account.charge(SourceMetadataBytes, metadata) {
      Err(error) => raise BudgetExceeded(error)
      Ok(_) => ()
    }
    match (context.retain_resident)(CacheBytes, payload) {
      Err(error) => raise BudgetExceeded(error)
      Ok(_) => ()
    }
  }
}
