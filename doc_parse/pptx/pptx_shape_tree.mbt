///|
fn parse_pptx_shape_tree(
  slide_xml : Bytes,
  ctx : PptxShapeParseContext,
) -> Array[PptxShape] raise {
  match find_sp_tree_inner(slide_xml) {
    Some(inner) => parse_shape_container(inner, default_group_context(), ctx)
    None => []
  }
}

///|
fn parse_shape_container(
  inner : Bytes,
  group_ctx : PptxGroupContext,
  ctx : PptxShapeParseContext,
) -> Array[PptxShape] raise {
  let out : Array[PptxShape] = []
  let mut pos = 0
  while pos < inner.length() {
    let start0 = find_bytes(inner, pat("<p:"), pos)
    match start0 {
      None => break
      Some(start) =>
        match read_open_tag_name(inner, start) {
          None => break
          Some(name) =>
            match name {
              "p:grpSp" =>
                match slice_full_element(inner, start, name) {
                  Some((block, next_pos)) => {
                    out.push(parse_group_shape(block, group_ctx, ctx))
                    pos = next_pos
                  }
                  None => break
                }
              "p:sp" =>
                match slice_full_element(inner, start, name) {
                  Some((block, next_pos)) => {
                    out.push(parse_text_shape(block, group_ctx, ctx))
                    pos = next_pos
                  }
                  None => break
                }
              "p:pic" =>
                match slice_full_element(inner, start, name) {
                  Some((block, next_pos)) => {
                    out.push(parse_picture_shape(block, group_ctx, ctx))
                    pos = next_pos
                  }
                  None => break
                }
              "p:graphicFrame" =>
                match slice_full_element(inner, start, name) {
                  Some((block, next_pos)) => {
                    out.push(parse_graphic_frame_shape(block, group_ctx, ctx))
                    pos = next_pos
                  }
                  None => break
                }
              _ =>
                match skip_full_element(inner, start, name) {
                  Some(next_pos) => pos = next_pos
                  None => break
                }
            }
        }
    }
  }
  out
}

///|
fn classify_text_shape_kind(sp_xml : Bytes) -> PptxShapeKind {
  if shape_is_title_like(sp_xml) || shape_is_body_like(sp_xml) {
    PptxShapeKind::Placeholder
  } else if shape_is_text_box_like(sp_xml) {
    PptxShapeKind::TextBox
  } else {
    PptxShapeKind::Shape
  }
}

///|
fn parse_group_shape(
  group_xml : Bytes,
  parent_ctx : PptxGroupContext,
  ctx : PptxShapeParseContext,
) -> PptxShape raise {
  let group_ref = read_group_object_ref(group_xml)
  let child_ctx = compose_group_context(parent_ctx, group_xml, group_ref)
  let inner = group_inner_content(group_xml).unwrap_or(Bytes::from_array([]))
  let (lx, ly, lw, lh) = read_local_transform_bounds(group_xml)
  {
    shape_id: read_cnvpr_id(group_xml),
    name: read_cnvpr_name(group_xml),
    kind: PptxShapeKind::Group,
    object_ref: group_ref,
    x: apply_group_transform_axis(parent_ctx, lx, true),
    y: apply_group_transform_axis(parent_ctx, ly, false),
    w: scale_coord(lw, parent_ctx.scale_x_num, parent_ctx.scale_x_den),
    h: scale_coord(lh, parent_ctx.scale_y_num, parent_ctx.scale_y_den),
    is_title_shape: false,
    is_body_shape: false,
    children: parse_shape_container(inner, child_ctx, ctx),
    text_paragraphs: [],
    table: None,
    media_ref: None,
    hyperlink_refs: [],
  }
}

///|
fn parse_text_shape(
  sp_xml : Bytes,
  group_ctx : PptxGroupContext,
  ctx : PptxShapeParseContext,
) -> PptxShape raise {
  let (lx, ly, lw, lh) = read_local_transform_bounds(sp_xml)
  let object_ref = read_cnvpr_object_ref(
    sp_xml,
    "shape",
    group_ctx.group_ref_prefix,
  )
  let paragraphs = parse_pptx_text_paragraphs_from_shape(
    sp_xml, ctx, object_ref,
  )
  let hyperlink_refs = collect_hyperlinks_from_paragraphs(paragraphs)
  {
    shape_id: read_cnvpr_id(sp_xml),
    name: read_cnvpr_name(sp_xml),
    kind: classify_text_shape_kind(sp_xml),
    object_ref,
    x: apply_group_transform_axis(group_ctx, lx, true),
    y: apply_group_transform_axis(group_ctx, ly, false),
    w: scale_coord(lw, group_ctx.scale_x_num, group_ctx.scale_x_den),
    h: scale_coord(lh, group_ctx.scale_y_num, group_ctx.scale_y_den),
    is_title_shape: shape_is_title_like(sp_xml),
    is_body_shape: shape_is_body_like(sp_xml),
    children: [],
    text_paragraphs: paragraphs,
    table: None,
    media_ref: None,
    hyperlink_refs,
  }
}

///|
fn parse_picture_shape(
  pic_xml : Bytes,
  group_ctx : PptxGroupContext,
  ctx : PptxShapeParseContext,
) -> PptxShape raise {
  let (lx, ly, lw, lh) = read_local_transform_bounds(pic_xml)
  let object_ref = read_cnvpr_object_ref(
    pic_xml,
    "picture",
    group_ctx.group_ref_prefix,
  )
  {
    shape_id: read_cnvpr_id(pic_xml),
    name: read_cnvpr_name(pic_xml),
    kind: PptxShapeKind::Picture,
    object_ref,
    x: apply_group_transform_axis(group_ctx, lx, true),
    y: apply_group_transform_axis(group_ctx, ly, false),
    w: scale_coord(lw, group_ctx.scale_x_num, group_ctx.scale_x_den),
    h: scale_coord(lh, group_ctx.scale_y_num, group_ctx.scale_y_den),
    is_title_shape: false,
    is_body_shape: false,
    children: [],
    text_paragraphs: [],
    table: None,
    media_ref: read_picture_media_ref(pic_xml, ctx, object_ref),
    hyperlink_refs: [],
  }
}

///|
fn parse_graphic_frame_shape(
  frame_xml : Bytes,
  group_ctx : PptxGroupContext,
  ctx : PptxShapeParseContext,
) -> PptxShape raise {
  let (lx, ly, lw, lh) = read_local_transform_bounds(frame_xml)
  let object_ref = read_cnvpr_object_ref(
    frame_xml,
    "graphicFrame",
    group_ctx.group_ref_prefix,
  )
  let table = parse_pptx_table_from_frame(frame_xml, ctx, object_ref)
  let hyperlink_refs = match table {
    Some(t) => collect_hyperlinks_from_table(t)
    None => []
  }
  {
    shape_id: read_cnvpr_id(frame_xml),
    name: read_cnvpr_name(frame_xml),
    kind: match table {
      Some(_) => PptxShapeKind::Table
      None => PptxShapeKind::Unknown
    },
    object_ref,
    x: apply_group_transform_axis(group_ctx, lx, true),
    y: apply_group_transform_axis(group_ctx, ly, false),
    w: scale_coord(lw, group_ctx.scale_x_num, group_ctx.scale_x_den),
    h: scale_coord(lh, group_ctx.scale_y_num, group_ctx.scale_y_den),
    is_title_shape: false,
    is_body_shape: false,
    children: [],
    text_paragraphs: [],
    table,
    media_ref: None,
    hyperlink_refs,
  }
}
