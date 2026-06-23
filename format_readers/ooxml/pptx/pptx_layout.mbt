///|
fn parse_source_layouts(
  ctx : PptxSourceParseContext,
) -> Array[PptxSourceLayout] raise {
  let out : Array[PptxSourceLayout] = []
  let parts = @ox.list_parts_by_prefix(ctx.pkg, "ppt/slideLayouts/")
  for part in parts {
    if !part.has_suffix(".xml") {
      continue
    }
    let xml = match read_source_part_bytes(ctx, part) {
      Some(bytes) => bytes
      None => Bytes::from_array([])
    }
    let placeholders = parse_placeholder_candidates(ctx, part, xml)
    out.push({
      part_name: part,
      master_ref: find_layout_master_ref(ctx, part),
      placeholders,
      source_key: pptx_source_key(part, "layout"),
    })
  }
  out
}

///|
fn parse_source_masters(
  ctx : PptxSourceParseContext,
) -> Array[PptxSourceMaster] raise {
  let out : Array[PptxSourceMaster] = []
  let parts = @ox.list_parts_by_prefix(ctx.pkg, "ppt/slideMasters/")
  for part in parts {
    if !part.has_suffix(".xml") {
      continue
    }
    let xml = match read_source_part_bytes(ctx, part) {
      Some(bytes) => bytes
      None => Bytes::from_array([])
    }
    out.push({
      part_name: part,
      placeholders: parse_placeholder_candidates(ctx, part, xml),
      source_key: pptx_source_key(part, "master"),
    })
  }
  out
}

///|
fn parse_placeholder_candidates(
  ctx : PptxSourceParseContext,
  part_name : String,
  xml : Bytes,
) -> Array[PptxPlaceholderCandidate] raise {
  let out : Array[PptxPlaceholderCandidate] = []
  match find_sp_tree_inner(xml) {
    Some(inner) => {
      let objects = parse_shape_container(
        ctx,
        inner,
        default_shape_container_context(part_name),
      )
      let warned : Ref[Bool] = { val: false }
      collect_placeholder_candidates_from_objects(
        ctx, out, objects, part_name, warned,
      )
    }
    None => ()
  }
  out
}

///|
fn collect_placeholder_candidates_from_objects(
  ctx : PptxSourceParseContext,
  out : Array[PptxPlaceholderCandidate],
  objects : Array[PptxObject],
  part_name : String,
  warned : Ref[Bool],
) -> Unit {
  for obj in objects {
    match obj {
      PptxObject::Shape(shape) =>
        match shape.direct_placeholder {
          Some(ph) =>
            if out.length() >= ctx.budget.max_layout_master_candidates {
              if !warned.val {
                warned.val = true
                push_over_budget_warning(
                  ctx,
                  part_name,
                  "placeholders",
                  None,
                  None,
                  "pptx layout/master placeholder candidate budget exceeded",
                )
              }
            } else {
              out.push({
                placeholder: ph,
                shape_id: shape.shape_id,
                name: shape.name,
                geometry: shape.geometry,
                source_key: shape.source_key,
              })
            }
          None => ()
        }
      PptxObject::Group(group) =>
        collect_placeholder_candidates_from_objects(
          ctx,
          out,
          group.children,
          part_name,
          warned,
        )
      _ => ()
    }
  }
}
