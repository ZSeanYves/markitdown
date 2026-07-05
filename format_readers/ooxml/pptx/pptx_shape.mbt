///|
priv struct ShapeContainerContext {
  part_name : String
  group_prefix : String?
  offset_x : Int
  offset_y : Int
  scale_x_num : Int
  scale_x_den : Int
  scale_y_num : Int
  scale_y_den : Int
  depth : Int
  shape_count : Ref[Int]
}

///|
fn default_shape_container_context(part_name : String) -> ShapeContainerContext {
  {
    part_name,
    group_prefix: None,
    offset_x: 0,
    offset_y: 0,
    scale_x_num: 1,
    scale_x_den: 1,
    scale_y_num: 1,
    scale_y_den: 1,
    depth: 0,
    shape_count: { val: 0 },
  }
}

///|
fn parse_source_slide(
  ctx : PptxSourceParseContext,
  slide_ref : PptxSlideRef,
  authors : Array[PptxCommentAuthor],
) -> PptxSourceSlide raise {
  let part_name = slide_ref.part_name
  let source_key = pptx_source_key(
    part_name,
    "slide-" + slide_ref.slide_index.to_string(),
  )
  track_source_node(ctx, part_name, source_key.node_key)
  if !@ox.has_part(ctx.pkg, part_name) {
    ctx.warnings.push(
      pptx_warning(
        PptxWarningKind::MissingSlidePart,
        PptxWarningSeverity::Warning,
        part_name,
        source_key.node_key,
        slide_ref.relationship_id,
        None,
        "missing slide part: " + part_name,
      ),
    )
    return {
      slide_ref,
      layout_ref: None,
      master_ref: None,
      objects: [],
      notes: None,
      comments: [],
      warnings: [],
      source_key,
    }
  }
  let xml = match read_source_part_bytes(ctx, part_name) {
    Some(bytes) => bytes
    None => Bytes::from_array([])
  }
  let rels = read_source_relationships(ctx, part_name)
  let layout_ref = find_slide_layout_ref(rels)
  let master_ref = match layout_ref {
    Some(layout) => find_layout_master_ref(ctx, layout.part_name)
    None => None
  }
  let objects = parse_slide_objects(ctx, part_name, xml)
  let notes = parse_notes_for_slide(ctx, part_name)
  let comments = parse_comments_for_slide(ctx, part_name, authors)
  {
    slide_ref,
    layout_ref,
    master_ref,
    objects,
    notes,
    comments,
    warnings: [],
    source_key,
  }
}

///|
fn find_slide_layout_ref(rels : Array[PptxRelationship]) -> PptxLayoutRef? {
  for rel in rels {
    if rel.rel_type.has_suffix("/slideLayout") &&
      rel.resolved_target.has_prefix("ppt/slideLayouts/") &&
      rel.resolved_target.has_suffix(".xml") {
      return Some({
        part_name: rel.resolved_target,
        relationship_id: Some(rel.id),
      })
    }
  }
  None
}

///|
fn find_layout_master_ref(
  ctx : PptxSourceParseContext,
  layout_part : String,
) -> PptxMasterRef? {
  for rel in read_source_relationships(ctx, layout_part) {
    if rel.rel_type.has_suffix("/slideMaster") &&
      rel.resolved_target.has_prefix("ppt/slideMasters/") &&
      rel.resolved_target.has_suffix(".xml") {
      return Some({
        part_name: rel.resolved_target,
        relationship_id: Some(rel.id),
      })
    }
  }
  None
}

///|
fn parse_slide_objects(
  ctx : PptxSourceParseContext,
  part_name : String,
  slide_xml : Bytes,
) -> Array[PptxObject] raise {
  match find_sp_tree_inner(slide_xml) {
    Some(inner) =>
      parse_shape_container(
        ctx,
        inner,
        default_shape_container_context(part_name),
      )
    None => []
  }
}

///|
fn find_sp_tree_inner(slide_xml : Bytes) -> Bytes? raise {
  let start = find_bytes(slide_xml, pat("<p:spTree"), 0).unwrap_or(-1)
  if start < 0 {
    return None
  }
  let gt = find_bytes(slide_xml, pat(">"), start).unwrap_or(-1)
  if gt < 0 {
    return None
  }
  let end_ = match
    find_matching_named_element_close(slide_xml, start, "p:spTree") {
    Some(v) => v
    None => {
      let close0 = find_bytes(slide_xml, pat("</p:spTree>"), gt + 1).unwrap_or(
        -1,
      )
      if close0 < 0 {
        -1
      } else {
        close0 + pat("</p:spTree>").length()
      }
    }
  }
  let close_len = pat("</p:spTree>").length()
  if end_ < close_len || end_ - close_len < gt + 1 {
    None
  } else {
    Some(slide_xml[gt + 1:end_ - close_len].to_owned())
  }
}

///|
fn parse_shape_container(
  ctx : PptxSourceParseContext,
  inner : Bytes,
  c : ShapeContainerContext,
) -> Array[PptxObject] raise {
  if c.depth > ctx.budget.max_group_depth {
    ctx.warnings.push(
      pptx_warning(
        PptxWarningKind::OverBudget,
        PptxWarningSeverity::Warning,
        c.part_name,
        "group-depth",
        None,
        c.group_prefix,
        "pptx group depth budget exceeded",
      ),
    )
    return []
  }
  let out : Array[PptxObject] = []
  let mut pos = 0
  let mut child_count = 0
  while pos < inner.length() {
    let start0 = find_bytes(inner, pat("<p:"), pos)
    match start0 {
      None => break
      Some(start) =>
        match read_open_tag_name(inner, start) {
          None => break
          Some(name) => {
            child_count += 1
            if child_count > ctx.budget.max_child_shapes_per_group {
              if child_count == ctx.budget.max_child_shapes_per_group + 1 {
                ctx.warnings.push(
                  pptx_warning(
                    PptxWarningKind::OverBudget,
                    PptxWarningSeverity::Warning,
                    c.part_name,
                    "group-child-count",
                    None,
                    c.group_prefix,
                    "pptx child-shape budget exceeded",
                  ),
                )
              }
              match slice_full_element(inner, start, name) {
                Some((_block, next_pos)) => pos = next_pos
                None => break
              }
              continue
            }
            if counts_as_slide_object(name) &&
              !consume_shape_budget(ctx, c, name, child_count) {
              match slice_full_element(inner, start, name) {
                Some((_block, next_pos)) => pos = next_pos
                None => break
              }
              continue
            }
            match slice_full_element(inner, start, name) {
              Some((block, next_pos)) => {
                match name {
                  "p:grpSp" =>
                    out.push(
                      PptxObject::Group(parse_group_shape(ctx, block, c)),
                    )
                  "p:sp" =>
                    out.push(PptxObject::Shape(parse_shape(ctx, block, c)))
                  "p:pic" =>
                    out.push(PptxObject::Picture(parse_picture(ctx, block, c)))
                  "p:graphicFrame" =>
                    out.push(parse_graphic_frame(ctx, block, c))
                  "p:cxnSp" =>
                    out.push(
                      PptxObject::Connector(parse_connector(ctx, block, c)),
                    )
                  "p:nvGrpSpPr" | "p:grpSpPr" => ()
                  _ => {
                    let unsupported_key = pptx_source_key(
                      c.part_name,
                      name + "-" + child_count.to_string(),
                    )
                    ctx.warnings.push(
                      pptx_warning(
                        PptxWarningKind::UnsupportedObject,
                        PptxWarningSeverity::Warning,
                        c.part_name,
                        unsupported_key.node_key,
                        None,
                        c.group_prefix,
                        "unsupported slide object: " + name,
                      ),
                    )
                    out.push(
                      PptxObject::Unsupported({
                        kind: name,
                        message: "unsupported slide object: " + name,
                        source_key: unsupported_key,
                      }),
                    )
                  }
                }
                pos = next_pos
              }
              None => break
            }
          }
        }
    }
  }
  out
}

///|
fn counts_as_slide_object(name : String) -> Bool {
  name != "p:nvGrpSpPr" && name != "p:grpSpPr"
}

///|
fn consume_shape_budget(
  ctx : PptxSourceParseContext,
  c : ShapeContainerContext,
  name : String,
  child_count : Int,
) -> Bool {
  c.shape_count.val += 1
  if c.shape_count.val > ctx.budget.max_shapes_per_slide {
    if c.shape_count.val == ctx.budget.max_shapes_per_slide + 1 {
      push_over_budget_warning(
        ctx,
        c.part_name,
        name + "-" + child_count.to_string(),
        None,
        c.group_prefix,
        "pptx shape budget exceeded for part: " + c.part_name,
      )
    }
    false
  } else {
    true
  }
}

///|
fn parse_group_shape(
  ctx : PptxSourceParseContext,
  group_xml : Bytes,
  c : ShapeContainerContext,
) -> PptxGroupShape raise {
  let shape_id = read_cnvpr_attr(group_xml, "id")
  let name = read_cnvpr_attr(group_xml, "name")
  let object_ref = object_ref("group", shape_id, c.group_prefix)
  let geometry = read_geometry(group_xml, c)
  let child_context = compose_group_context(group_xml, c, object_ref)
  let inner = group_inner_content(group_xml).unwrap_or(Bytes::from_array([]))
  let children = parse_shape_container(ctx, inner, child_context)
  let source_key = pptx_source_key(c.part_name, object_ref.unwrap_or("group"))
  track_source_node(ctx, c.part_name, source_key.node_key)
  {
    shape_id,
    name,
    object_ref,
    geometry: Some(geometry),
    children,
    reading_order: None,
    source_key,
  }
}

///|
fn parse_shape(
  ctx : PptxSourceParseContext,
  sp_xml : Bytes,
  c : ShapeContainerContext,
) -> PptxShape raise {
  let shape_id = read_cnvpr_attr(sp_xml, "id")
  let name = read_cnvpr_attr(sp_xml, "name")
  let object_ref = object_ref("shape", shape_id, c.group_prefix)
  let direct_placeholder = read_placeholder(sp_xml)
  let source_key = pptx_source_key(c.part_name, object_ref.unwrap_or("shape"))
  track_source_node(ctx, c.part_name, source_key.node_key)
  {
    shape_id,
    name,
    shape_type: read_attr_value_in_first_tag_bytes(
      sp_xml, "<a:prstGeom", "prst",
    ),
    object_ref,
    geometry: Some(read_geometry(sp_xml, c)),
    direct_placeholder,
    placeholder: None,
    text_body: parse_text_body(ctx, c.part_name, sp_xml, source_key.node_key),
    hyperlinks: collect_shape_hyperlinks(ctx, c.part_name, sp_xml, source_key),
    reading_order: None,
    source_key,
  }
}

///|
fn parse_picture(
  ctx : PptxSourceParseContext,
  pic_xml : Bytes,
  c : ShapeContainerContext,
) -> PptxPicture raise {
  let shape_id = read_cnvpr_attr(pic_xml, "id")
  let name = read_cnvpr_attr(pic_xml, "name")
  let object_ref = object_ref("picture", shape_id, c.group_prefix)
  let source_key = pptx_source_key(c.part_name, object_ref.unwrap_or("picture"))
  track_source_node(ctx, c.part_name, source_key.node_key)
  {
    shape_id,
    name,
    object_ref,
    media: read_picture_media_ref(ctx, c.part_name, pic_xml, source_key),
    geometry: Some(read_geometry(pic_xml, c)),
    reading_order: None,
    source_key,
  }
}

///|
fn parse_connector(
  ctx : PptxSourceParseContext,
  xml : Bytes,
  c : ShapeContainerContext,
) -> PptxConnector raise {
  let shape_id = read_cnvpr_attr(xml, "id")
  let name = read_cnvpr_attr(xml, "name")
  let source_key = pptx_source_key(
    c.part_name,
    object_ref("connector", shape_id, c.group_prefix).unwrap_or("connector"),
  )
  track_source_node(ctx, c.part_name, source_key.node_key)
  { shape_id, name, geometry: Some(read_geometry(xml, c)), source_key }
}

///|
fn parse_graphic_frame(
  ctx : PptxSourceParseContext,
  frame_xml : Bytes,
  c : ShapeContainerContext,
) -> PptxObject raise {
  let shape_id = read_cnvpr_attr(frame_xml, "id")
  let object_ref0 = object_ref("graphicFrame", shape_id, c.group_prefix)
  let source_key = pptx_source_key(
    c.part_name,
    object_ref0.unwrap_or("graphicFrame"),
  )
  track_source_node(ctx, c.part_name, source_key.node_key)
  if contains_bytes(frame_xml, pat("<a:tbl")) {
    return PptxObject::Table(
      parse_table(
        ctx,
        c.part_name,
        frame_xml,
        Some(read_geometry(frame_xml, c)),
        source_key,
      ),
    )
  }
  match read_attr_value_in_first_tag_bytes(frame_xml, "<c:chart", "r:id") {
    Some(rid) => {
      let target = resolve_graphic_frame_target(
        ctx,
        c.part_name,
        source_key,
        object_ref0,
        rid,
        "chart",
      )
      let (title, cached_text, cached_categories, cached_values, cached_series) = read_chart_cached_facts(
        ctx, target,
      )
      return PptxObject::Chart({
        relationship_id: Some(rid),
        target_part: target,
        title,
        cached_text,
        cached_categories,
        cached_values,
        cached_series,
        source_key,
      })
    }
    None => ()
  }
  let kind = if contains_bytes(frame_xml, pat("diagram")) {
    "SmartArt"
  } else if contains_bytes(frame_xml, pat("oleObj")) {
    "OLE"
  } else {
    "UnknownGraphicFrame"
  }
  ctx.warnings.push(
    pptx_warning(
      PptxWarningKind::UnsupportedObject,
      PptxWarningSeverity::Warning,
      c.part_name,
      source_key.node_key,
      None,
      object_ref0,
      "unsupported graphic frame: " + kind,
    ),
  )
  let rel_id = read_graphic_frame_relationship_id(frame_xml, kind)
  let target = match rel_id {
    Some(rid) =>
      resolve_graphic_frame_target(
        ctx,
        c.part_name,
        source_key,
        object_ref0,
        rid,
        kind,
      )
    None => None
  }
  match kind {
    "SmartArt" =>
      PptxObject::SmartArt({
        relationship_id: rel_id,
        target_part: target,
        source_key,
      })
    "OLE" =>
      PptxObject::Ole({
        relationship_id: rel_id,
        target_part: target,
        source_key,
      })
    _ =>
      PptxObject::Unsupported({
        kind,
        message: "unsupported graphic frame",
        source_key,
      })
  }
}

///|
fn resolve_graphic_frame_target(
  ctx : PptxSourceParseContext,
  part_name : String,
  source_key : PptxSourceKey,
  object_ref : String?,
  rel_id : String,
  kind : String,
) -> String? {
  match find_source_relationship_by_id(ctx, part_name, rel_id) {
    Some(rel) => Some(rel.resolved_target)
    None => {
      ctx.warnings.push(
        pptx_warning(
          PptxWarningKind::MissingRelationshipTarget,
          PptxWarningSeverity::Warning,
          part_name,
          source_key.node_key,
          Some(rel_id),
          object_ref,
          "missing " + kind + " relationship target: " + rel_id,
        ),
      )
      None
    }
  }
}

///|
fn read_graphic_frame_relationship_id(
  frame_xml : Bytes,
  kind : String,
) -> String? raise {
  if kind == "OLE" {
    match read_attr_value_in_first_tag_bytes(frame_xml, "<p:oleObj", "r:id") {
      Some(rid) => return Some(rid)
      None => ()
    }
  }
  if kind == "SmartArt" {
    match read_attr_value_in_first_tag_bytes(frame_xml, "<dgm:relIds", "r:dm") {
      Some(rid) => return Some(rid)
      None => ()
    }
    match read_attr_value_in_first_tag_bytes(frame_xml, "<dgm:relIds", "r:lo") {
      Some(rid) => return Some(rid)
      None => ()
    }
    match read_attr_value_in_first_tag_bytes(frame_xml, "<dgm:relIds", "r:qs") {
      Some(rid) => return Some(rid)
      None => ()
    }
    match read_attr_value_in_first_tag_bytes(frame_xml, "<dgm:relIds", "r:cs") {
      Some(rid) => return Some(rid)
      None => ()
    }
  }
  None
}

///|
fn read_chart_cached_facts(
  ctx : PptxSourceParseContext,
  target : String?,
) -> (
  String?,
  Array[String],
  Array[String],
  Array[String],
  Array[PptxChartSeries],
) raise {
  let part = match target {
    Some(p) => p
    None => return (None, [], [], [], [])
  }
  let xml = match read_source_part_bytes(ctx, part) {
    Some(bytes) => bytes
    None => return (None, [], [], [], [])
  }
  let title = first_text_value(xml, "<a:t>", "</a:t>")
  let values = collect_chart_values(xml, 64)
  let text_values : Array[String] = []
  let numeric_values : Array[String] = []
  for value in values {
    if is_number_like(value) {
      numeric_values.push(value)
    } else {
      text_values.push(value)
    }
  }
  let series = collect_chart_series(xml, 32)
  let categories : Array[String] = []
  for ser in series {
    for cat in ser.categories {
      push_unique_string(categories, cat)
    }
  }
  if contains_bytes(xml, pat("<c:externalData")) &&
    !pptx_chart_cache_is_sufficient(series, categories, numeric_values) {
    ctx.warnings.push(
      pptx_warning(
        PptxWarningKind::UnsupportedObject,
        PptxWarningSeverity::Warning,
        part,
        "chart-external-data",
        None,
        None,
        "unsupported chart external workbook data: " + part,
      ),
    )
  }
  (title, text_values, categories, numeric_values, series)
}

///|
fn pptx_chart_cache_is_sufficient(
  series : Array[PptxChartSeries],
  categories : Array[String],
  numeric_values : Array[String],
) -> Bool {
  for ser in series {
    let series_categories = if ser.preferred_categories.length() > 0 {
      ser.preferred_categories
    } else {
      ser.categories
    }
    let pair_count = if series_categories.length() < ser.values.length() {
      series_categories.length()
    } else {
      ser.values.length()
    }
    if pair_count > 0 {
      return true
    }
  }
  categories.length() > 0 && numeric_values.length() > 0
}

///|
fn collect_chart_series(
  xml : Bytes,
  limit : Int,
) -> Array[PptxChartSeries] raise {
  let out : Array[PptxChartSeries] = []
  let mut pos = 0
  while out.length() < limit {
    let start = find_bytes(xml, pat("<c:ser"), pos).unwrap_or(-1)
    if start < 0 {
      break
    }
    match slice_full_element(xml, start, "c:ser") {
      Some((block, next_pos)) => {
        out.push(parse_chart_series(block))
        pos = next_pos
      }
      None => break
    }
  }
  out
}

///|
fn parse_chart_series(ser_xml : Bytes) -> PptxChartSeries raise {
  let tx_values = collect_chart_values_in_element(ser_xml, "<c:tx", 16)
  let categories = collect_chart_values_in_element(ser_xml, "<c:cat", 64)
  let preferred_categories = collect_chart_preferred_categories(ser_xml, 64)
  let values = collect_chart_values_in_element(ser_xml, "<c:val", 64)
  let name = if tx_values.length() == 0 { None } else { Some(tx_values[0]) }
  let text : Array[String] = []
  let all = collect_chart_values(ser_xml, 64)
  for value in all {
    let is_series_name = match name {
      Some(n) => n == value
      None => false
    }
    if !is_number_like(value) &&
      !string_array_contains(categories, value) &&
      !string_array_contains(preferred_categories, value) &&
      !is_series_name {
      push_unique_string(text, value)
    }
  }
  { name, categories, values, text, preferred_categories }
}

///|
fn collect_chart_values_in_element(
  xml : Bytes,
  open_prefix : String,
  limit : Int,
) -> Array[String] raise {
  match
    find_element_inner(
      xml,
      open_prefix,
      "</" + open_prefix[1:].to_owned() + ">",
    ) {
    Some(inner) => collect_chart_values(inner, limit)
    None => []
  }
}

///|
fn collect_chart_preferred_categories(
  ser_xml : Bytes,
  limit : Int,
) -> Array[String] raise {
  match find_element_inner(ser_xml, "<c:cat", "</c:cat>") {
    Some(inner) => {
      let multi = collect_multilevel_chart_categories(inner, limit)
      if multi.length() > 0 {
        multi
      } else {
        collect_indexed_chart_values(inner, limit).map(item => item.1)
      }
    }
    None => []
  }
}

///|
fn collect_multilevel_chart_categories(
  xml : Bytes,
  limit : Int,
) -> Array[String] raise {
  let levels = collect_multilevel_chart_levels(xml, limit)
  if levels.length() == 0 {
    return []
  }
  let top = levels[levels.length() - 1]
  if top.length() == 0 {
    return []
  }
  let out : Array[String] = []
  for entry in top {
    let value = entry.1.trim().to_owned()
    if value != "" {
      out.push(value)
    }
  }
  out
}

///|
fn collect_multilevel_chart_levels(
  xml : Bytes,
  limit : Int,
) -> Array[Array[(Int, String)]] raise {
  let out : Array[Array[(Int, String)]] = []
  let mut pos = 0
  while out.length() < limit {
    let start = find_bytes(xml, pat("<c:lvl"), pos).unwrap_or(-1)
    if start < 0 {
      break
    }
    match slice_full_element(xml, start, "c:lvl") {
      Some((block, next_pos)) => {
        out.push(collect_indexed_chart_values(block, limit))
        pos = next_pos
      }
      None => break
    }
  }
  out
}

///|
fn collect_indexed_chart_values(
  xml : Bytes,
  limit : Int,
) -> Array[(Int, String)] raise {
  let out : Array[(Int, String)] = []
  let mut pos = 0
  while out.length() < limit {
    let start = find_bytes(xml, pat("<c:pt"), pos).unwrap_or(-1)
    if start < 0 {
      break
    }
    match slice_full_element(xml, start, "c:pt") {
      Some((block, next_pos)) => {
        let idx = parse_chart_point_index(block)
        let value = first_text_value(block, "<c:v>", "</c:v>")
          .unwrap_or("")
          .trim()
          .to_owned()
        if value != "" {
          out.push((idx, value))
        }
        pos = next_pos
      }
      None => break
    }
  }
  out
}

///|
fn parse_chart_point_index(pt_xml : Bytes) -> Int raise {
  parse_int_or_zero(read_attr_value_in_first_tag_bytes(pt_xml, "<c:pt", "idx"))
}

///|
fn collect_chart_values(xml : Bytes, limit : Int) -> Array[String] raise {
  let out : Array[String] = []
  let open = pat("<c:v>")
  let close = pat("</c:v>")
  let mut pos = 0
  while out.length() < limit {
    let start = find_bytes(xml, open, pos).unwrap_or(-1)
    if start < 0 {
      break
    }
    let content_start = start + open.length()
    let end_ = find_bytes(xml, close, content_start).unwrap_or(-1)
    if end_ < 0 {
      break
    }
    let value = xml_unescape(bytes_slice_to_string(xml, content_start, end_))
      .trim()
      .to_owned()
    if value != "" {
      out.push(value)
    }
    pos = end_ + close.length()
  }
  out
}

///|
fn push_unique_string(out : Array[String], value : String) -> Unit {
  if !string_array_contains(out, value) {
    out.push(value)
  }
}

///|
fn string_array_contains(values : Array[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn is_number_like(value : String) -> Bool {
  let chars = value.trim().to_array()
  if chars.length() == 0 {
    return false
  }
  let mut saw_digit = false
  for i = 0; i < chars.length(); i = i + 1 {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      saw_digit = true
    } else if ch == '.' || ch == '-' || ch == '+' || ch == ',' {
      ()
    } else {
      return false
    }
  }
  saw_digit
}

///|
fn read_cnvpr_attr(xml : Bytes, attr : String) -> String? raise {
  normalize_optional_attr(
    read_attr_value_in_first_tag_bytes(xml, "<p:cNvPr", attr),
  )
}

///|
fn object_ref(kind : String, id : String?, prefix : String?) -> String? {
  let local_ref = match id {
    Some(value) =>
      if value.trim() == "" {
        None
      } else {
        Some(kind + "-" + value.trim().to_owned())
      }
    None => None
  }
  match prefix {
    Some(p) =>
      match local_ref {
        Some(l) => Some(p + "/" + l)
        None => Some(p)
      }
    None => local_ref
  }
}

///|
fn read_placeholder(xml : Bytes) -> PptxPlaceholder? raise {
  let start = find_bytes(xml, pat("<p:ph"), 0).unwrap_or(-1)
  if start < 0 {
    return None
  }
  let end_ = find_bytes(xml, pat(">"), start).unwrap_or(-1)
  if end_ < 0 {
    return None
  }
  let tag = xml[start:end_ + 1].to_owned()
  let raw = read_attr_value_in_tag_bytes(tag, "type")
  let kind = match raw.unwrap_or("") {
    "title" => PptxPlaceholderKind::Title
    "ctrTitle" => PptxPlaceholderKind::CenterTitle
    "subTitle" => PptxPlaceholderKind::Subtitle
    "body" => PptxPlaceholderKind::Body
    "ftr" => PptxPlaceholderKind::Footer
    "dt" => PptxPlaceholderKind::Date
    "sldNum" => PptxPlaceholderKind::SlideNumber
    "pic" => PptxPlaceholderKind::Picture
    "tbl" => PptxPlaceholderKind::Table
    _ => PptxPlaceholderKind::Unknown
  }
  Some({ kind, index: read_attr_value_in_tag_bytes(tag, "idx"), raw_type: raw })
}

///|
fn read_geometry(xml : Bytes, c : ShapeContainerContext) -> PptxGeometry raise {
  let xfrm = find_transform_element(xml, "<a:xfrm")
  let (x0, y0, w0, h0, rot) = match xfrm {
    Some(xfrm_xml) => {
      let (x, y) = read_transform_pair(xfrm_xml, "<a:off")
      let (w, h) = read_transform_pair(xfrm_xml, "<a:ext")
      (
        x,
        y,
        w,
        h,
        read_attr_value_in_first_tag_bytes(xfrm_xml, "<a:xfrm", "rot"),
      )
    }
    None => (0, 0, 0, 0, None)
  }
  {
    x: Some(c.offset_x + scale_coord(x0, c.scale_x_num, c.scale_x_den)),
    y: Some(c.offset_y + scale_coord(y0, c.scale_y_num, c.scale_y_den)),
    width: Some(scale_coord(w0, c.scale_x_num, c.scale_x_den)),
    height: Some(scale_coord(h0, c.scale_y_num, c.scale_y_den)),
    rotation: match rot {
      Some(v) => Some(parse_int_or_zero(Some(v)))
      None => None
    },
  }
}

///|
fn scale_coord(value : Int, num : Int, den : Int) -> Int {
  if den <= 0 {
    value
  } else {
    let scaled = value.to_int64() * num.to_int64() / den.to_int64()
    if scaled > 2147483647L {
      2147483647
    } else if scaled < -2147483648L {
      -2147483648
    } else {
      scaled.to_int()
    }
  }
}

///|
fn find_transform_element(xml : Bytes, open_prefix : String) -> Bytes? raise {
  let p0 = find_bytes(xml, pat(open_prefix), 0).unwrap_or(-1)
  if p0 < 0 {
    return None
  }
  match find_matching_named_element_close(xml, p0, open_prefix[1:].to_owned()) {
    Some(end_) => Some(xml[p0:end_].to_owned())
    None => {
      let gt = find_bytes(xml, pat(">"), p0).unwrap_or(-1)
      if gt < 0 {
        None
      } else {
        Some(xml[p0:gt + 1].to_owned())
      }
    }
  }
}

///|
fn read_transform_pair(xml : Bytes, tag_prefix : String) -> (Int, Int) raise {
  let p0 = find_bytes(xml, pat(tag_prefix), 0).unwrap_or(-1)
  if p0 < 0 {
    return (0, 0)
  }
  let gt = find_bytes(xml, pat(">"), p0).unwrap_or(-1)
  if gt < 0 {
    return (0, 0)
  }
  let tag = xml[p0:gt + 1].to_owned()
  let a = if tag_prefix == "<a:ext" || tag_prefix == "<a:chExt" {
    "cx"
  } else {
    "x"
  }
  let b = if tag_prefix == "<a:ext" || tag_prefix == "<a:chExt" {
    "cy"
  } else {
    "y"
  }
  (
    parse_int_or_zero(read_attr_value_in_tag_bytes(tag, a)),
    parse_int_or_zero(read_attr_value_in_tag_bytes(tag, b)),
  )
}

///|
fn group_inner_content(group_xml : Bytes) -> Bytes? raise {
  let first_gt = find_bytes(group_xml, pat(">"), 0).unwrap_or(-1)
  if first_gt < 0 {
    return None
  }
  let end_ = find_matching_named_element_close(group_xml, 0, "p:grpSp").unwrap_or(
    -1,
  )
  let close_len = pat("</p:grpSp>").length()
  if end_ < close_len {
    None
  } else {
    Some(group_xml[first_gt + 1:end_ - close_len].to_owned())
  }
}

///|
fn compose_group_context(
  group_xml : Bytes,
  parent : ShapeContainerContext,
  group_ref : String?,
) -> ShapeContainerContext raise {
  let group_geom = read_geometry(group_xml, parent)
  let child_xfrm = find_transform_element(group_xml, "<a:xfrm")
  let (chx, chy, chcx, chcy) = match child_xfrm {
    Some(xfrm) => {
      let (x, y) = read_transform_pair(xfrm, "<a:chOff")
      let (w, h) = read_transform_pair(xfrm, "<a:chExt")
      (x, y, w, h)
    }
    None => (0, 0, 0, 0)
  }
  let gx = group_geom.x.unwrap_or(0)
  let gy = group_geom.y.unwrap_or(0)
  let gw = group_geom.width.unwrap_or(0)
  let gh = group_geom.height.unwrap_or(0)
  {
    part_name: parent.part_name,
    group_prefix: match parent.group_prefix {
      Some(p) =>
        match group_ref {
          Some(g) => Some(p + "/" + g)
          None => Some(p)
        }
      None => group_ref
    },
    offset_x: gx - chx,
    offset_y: gy - chy,
    scale_x_num: if chcx > 0 {
      gw
    } else {
      parent.scale_x_num
    },
    scale_x_den: if chcx > 0 {
      chcx
    } else {
      parent.scale_x_den
    },
    scale_y_num: if chcy > 0 {
      gh
    } else {
      parent.scale_y_num
    },
    scale_y_den: if chcy > 0 {
      chcy
    } else {
      parent.scale_y_den
    },
    depth: parent.depth + 1,
    shape_count: parent.shape_count,
  }
}
