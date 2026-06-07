///|
pub fn parse_pptx(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  let pptx_doc = @pptxdoc.open_pptx_document(input_path)
  lower_pptx_document(pptx_doc, @cor.basename(input_path), out_dir, max_heading)
}

///|
pub fn lower_pptx_document(
  pptx_doc : @pptxdoc.PptxDocument,
  source_name : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  let doc = @cor.new_document()
  let image_idx : Ref[Int] = { val: 0 }
  for slide in pptx_doc.slides {
    let slide_heading = if slide.hidden {
      "Slide " + slide.slide_index.to_string() + " (hidden)"
    } else {
      "Slide " + slide.slide_index.to_string()
    }
    push_origin(
      doc,
      @cor.Block::Heading(clamp_heading(2, max_heading), slide_heading),
      source_name,
      slide.slide_index,
      None,
      slide.relationship_id,
      Some(slide.part_name),
    )
    lower_slide_objects(
      doc, slide, source_name, out_dir, image_idx, max_heading,
    )
    lower_comments(doc, slide, source_name, slide_heading, max_heading)
    lower_notes(doc, slide, source_name, slide_heading, max_heading)
  }
  lower_document_warnings(doc, pptx_doc.warnings, source_name, max_heading)
  doc
}

///|
pub fn pptx_metadata_document_properties(
  pptx_doc : @pptxdoc.PptxDocument,
) -> @cor.MetadataDocumentProperties? {
  let meta = pptx_doc.metadata
  Some(
    @cor.metadata_document_properties(
      meta.title,
      meta.subject,
      meta.creator,
      meta.description,
      meta.keywords,
      meta.created,
      meta.modified,
      meta.application,
      meta.pages,
      meta.words,
      meta.slides,
      meta.sheets,
    ),
  )
}

///|
fn clamp_heading(level : Int, max_heading : Int) -> Int {
  if level < 1 {
    1
  } else if level > max_heading {
    max_heading
  } else {
    level
  }
}

///|
fn push_origin(
  doc : @cor.Document,
  block : @cor.Block,
  source_name : String,
  slide_index : Int,
  object_ref : String?,
  relationship_id : String?,
  key_path : String?,
) -> Unit {
  @cor.push_with_origin(
    doc,
    block,
    Some({
      source_name: Some(source_name),
      page: None,
      slide: Some(slide_index),
      sheet: None,
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref,
      relationship_id,
      key_path,
    }),
  )
}

///|
fn lower_slide_objects(
  doc : @cor.Document,
  slide : @pptxdoc.PptxSlide,
  source_name : String,
  out_dir : String,
  image_idx : Ref[Int],
  max_heading : Int,
) -> Unit raise {
  lower_object_sequence(
    doc,
    slide.objects,
    slide.layout_regions,
    slide.image_caption_pairs,
    source_name,
    slide.slide_index,
    out_dir,
    image_idx,
    max_heading,
  )
}

///|
fn lower_object_sequence(
  doc : @cor.Document,
  objects : Array[@pptxdoc.PptxObject],
  layout_regions : Array[@pptxdoc.PptxLayoutRegionHint],
  image_caption_pairs : Array[@pptxdoc.PptxImageCaptionPair],
  source_name : String,
  slide_index : Int,
  out_dir : String,
  image_idx : Ref[Int],
  max_heading : Int,
) -> Unit raise {
  let consumed = lower_high_confidence_regions(
    doc, objects, layout_regions, source_name, slide_index,
  )
  let caption_keys = if out_dir == "" {
    []
  } else {
    semantic_caption_keys(image_caption_pairs)
  }
  let ordered = sort_objects_for_lowering(objects)
  for item in ordered {
    let key = object_source_key(item.1)
    if source_key_array_contains(consumed, key) ||
      source_key_array_contains(caption_keys, key) {
      continue
    }
    lower_object(
      doc,
      item.1,
      layout_regions,
      image_caption_pairs,
      source_name,
      slide_index,
      out_dir,
      image_idx,
      max_heading,
    )
  }
}

///|
fn sort_objects_for_lowering(
  objects : Array[@pptxdoc.PptxObject],
) -> Array[(String, @pptxdoc.PptxObject)] {
  let out : Array[(String, @pptxdoc.PptxObject)] = []
  let mut idx = 0
  for obj in objects {
    idx += 1
    out.push((object_order_key(obj, idx), obj))
  }
  out.sort_by(fn(a, b) { a.0.compare(b.0) })
  out
}

///|
fn object_order_key(obj : @pptxdoc.PptxObject, source_order : Int) -> String {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) =>
      match shape.reading_order {
        Some(h) => h.order_key
        None =>
          "100:" + pad_int(source_order, 5) + ":" + shape.source_key.node_key
      }
    @pptxdoc.PptxObject::Picture(pic) =>
      match pic.reading_order {
        Some(h) => h.order_key
        None =>
          "050:" + pad_int(source_order, 5) + ":" + pic.source_key.node_key
      }
    @pptxdoc.PptxObject::Group(group) =>
      match group.reading_order {
        Some(h) => h.order_key
        None =>
          "030:" + pad_int(source_order, 5) + ":" + group.source_key.node_key
      }
    @pptxdoc.PptxObject::Table(table) =>
      "040:" + pad_int(source_order, 5) + ":" + table.source_key.node_key
    @pptxdoc.PptxObject::Chart(chart) =>
      "045:" + pad_int(source_order, 5) + ":" + chart.source_key.node_key
    @pptxdoc.PptxObject::SmartArt(smart) =>
      "095:" + pad_int(source_order, 5) + ":" + smart.source_key.node_key
    @pptxdoc.PptxObject::Ole(ole) =>
      "095:" + pad_int(source_order, 5) + ":" + ole.source_key.node_key
    @pptxdoc.PptxObject::Connector(conn) =>
      "090:" + pad_int(source_order, 5) + ":" + conn.source_key.node_key
    @pptxdoc.PptxObject::Unsupported(unsupported) =>
      "100:" + pad_int(source_order, 5) + ":" + unsupported.source_key.node_key
  }
}

///|
priv struct PptxLowerRegionMember {
  source_key : @pptxdoc.PptxSourceKey
  text : String
  geometry : @pptxdoc.PptxGeometry?
}

///|
fn lower_high_confidence_regions(
  doc : @cor.Document,
  objects : Array[@pptxdoc.PptxObject],
  layout_regions : Array[@pptxdoc.PptxLayoutRegionHint],
  source_name : String,
  slide_index : Int,
) -> Array[@pptxdoc.PptxSourceKey] {
  let consumed : Array[@pptxdoc.PptxSourceKey] = []
  let ordered : Array[(String, @pptxdoc.PptxLayoutRegionHint)] = []
  for region in layout_regions {
    ordered.push((region.order_key, region))
  }
  ordered.sort_by(fn(a, b) { a.0.compare(b.0) })
  for item in ordered {
    let region = item.1
    if region.confidence != @pptxdoc.PptxConfidence::High {
      continue
    }
    match region.kind {
      @pptxdoc.PptxLayoutRegionKind::TableLike => {
        let members = collect_region_members(objects, region.members)
        if members.length() >= 4 && !any_member_consumed(members, consumed) {
          lower_inferred_table_region(doc, members, source_name, slide_index)
          append_member_keys(consumed, members)
        }
      }
      @pptxdoc.PptxLayoutRegionKind::CardLike => {
        let members = collect_region_members(objects, region.members)
        if members.length() >= 2 && !any_member_consumed(members, consumed) {
          lower_card_region(doc, members, source_name, slide_index)
          append_member_keys(consumed, members)
        }
      }
      @pptxdoc.PptxLayoutRegionKind::GridLike => {
        let members = collect_region_members(objects, region.members)
        if members.length() >= 4 {
          lower_grid_region(doc, members, source_name, slide_index)
        }
      }
      _ => ()
    }
  }
  consumed
}

///|
fn lower_inferred_table_region(
  doc : @cor.Document,
  members : Array[PptxLowerRegionMember],
  source_name : String,
  slide_index : Int,
) -> Unit {
  let rows = region_members_as_rows(members)
  if rows.length() == 0 {
    return
  }
  push_origin(
    doc,
    @cor.Block::RichTable({ rows, header_rows: 1, hints: None }),
    source_name,
    slide_index,
    None,
    None,
    region_key_path(members),
  )
}

///|
fn lower_card_region(
  doc : @cor.Document,
  members : Array[PptxLowerRegionMember],
  source_name : String,
  slide_index : Int,
) -> Unit {
  let ordered = members.copy()
  ordered.sort_by(fn(a, b) { member_order_key(a).compare(member_order_key(b)) })
  let texts : Array[String] = []
  for item in ordered {
    if item.text.trim() != "" {
      texts.push(item.text.trim().to_owned())
    }
  }
  if texts.length() == 0 {
    return
  }
  push_origin(
    doc,
    @cor.Block::BlockQuote(texts.join("\n\n")),
    source_name,
    slide_index,
    None,
    None,
    region_key_path(members),
  )
}

///|
fn lower_grid_region(
  doc : @cor.Document,
  members : Array[PptxLowerRegionMember],
  source_name : String,
  slide_index : Int,
) -> Unit {
  let labels : Array[String] = []
  let ordered = members.copy()
  ordered.sort_by(fn(a, b) { member_order_key(a).compare(member_order_key(b)) })
  for item in ordered {
    if item.text.trim() != "" {
      labels.push(item.text.trim().to_owned())
    }
  }
  if labels.length() == 0 {
    return
  }
  push_origin(
    doc,
    @cor.Block::BlockQuote(labels.join("\n")),
    source_name,
    slide_index,
    None,
    None,
    region_key_path(members),
  )
}

///|
fn collect_region_members(
  objects : Array[@pptxdoc.PptxObject],
  keys : Array[@pptxdoc.PptxSourceKey],
) -> Array[PptxLowerRegionMember] {
  let members : Array[PptxLowerRegionMember] = []
  collect_region_members_into(members, objects, keys)
  members
}

///|
fn collect_region_members_into(
  members : Array[PptxLowerRegionMember],
  objects : Array[@pptxdoc.PptxObject],
  keys : Array[@pptxdoc.PptxSourceKey],
) -> Unit {
  for obj in objects {
    if source_key_array_contains(keys, object_source_key(obj)) {
      members.push({
        source_key: object_source_key(obj),
        text: object_region_text(obj),
        geometry: object_geometry(obj),
      })
    }
    match obj {
      @pptxdoc.PptxObject::Group(group) =>
        collect_region_members_into(members, group.children, keys)
      _ => ()
    }
  }
}

///|
fn object_region_text(obj : @pptxdoc.PptxObject) -> String {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) =>
      match shape.text_body {
        Some(body) => text_body_plain_text(body)
        None => shape.name.unwrap_or("")
      }
    @pptxdoc.PptxObject::Picture(pic) =>
      match pic.media {
        Some(media) => {
          let label = first_some_string(
            first_some_string(media.alt_text, media.title),
            pic.name,
          )
          label.unwrap_or("image")
        }
        None => pic.name.unwrap_or("image")
      }
    @pptxdoc.PptxObject::Table(table) => table_text_for_region(table)
    @pptxdoc.PptxObject::Group(group) => group.name.unwrap_or("group")
    @pptxdoc.PptxObject::Chart(chart) => chart.title.unwrap_or("chart")
    @pptxdoc.PptxObject::SmartArt(_) => "SmartArt"
    @pptxdoc.PptxObject::Ole(_) => "OLE"
    @pptxdoc.PptxObject::Connector(conn) => conn.name.unwrap_or("connector")
    @pptxdoc.PptxObject::Unsupported(unsupported) => unsupported.kind
  }
}

///|
fn first_some_string(a : String?, b : String?) -> String? {
  match a {
    Some(v) => Some(v)
    None => b
  }
}

///|
fn text_body_plain_text(body : @pptxdoc.PptxTextBody) -> String {
  let parts : Array[String] = []
  for para in body.paragraphs {
    let text = inline_plain_text(paragraph_inlines(para)).trim().to_owned()
    if text != "" {
      parts.push(text)
    }
  }
  parts.join("\n")
}

///|
fn table_text_for_region(table : @pptxdoc.PptxTable) -> String {
  let rows : Array[String] = []
  for row in table.rows {
    let cells : Array[String] = []
    for cell in row.cells {
      cells.push(table_cell_text(cell))
    }
    rows.push(cells.join(" | "))
  }
  rows.join("\n")
}

///|
fn object_geometry(obj : @pptxdoc.PptxObject) -> @pptxdoc.PptxGeometry? {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) => shape.geometry
    @pptxdoc.PptxObject::Picture(pic) => pic.geometry
    @pptxdoc.PptxObject::Table(table) => table.geometry
    @pptxdoc.PptxObject::Group(group) => group.geometry
    @pptxdoc.PptxObject::Connector(conn) => conn.geometry
    _ => None
  }
}

///|
fn region_members_as_rows(
  members : Array[PptxLowerRegionMember],
) -> Array[Array[String]] {
  let rows = unique_member_buckets(members, false)
  let cols = unique_member_buckets(members, true)
  let out : Array[Array[String]] = []
  for row in rows {
    let out_row : Array[String] = []
    for col in cols {
      out_row.push(member_text_at_bucket(members, row, col))
    }
    out.push(out_row)
  }
  out
}

///|
fn member_text_at_bucket(
  members : Array[PptxLowerRegionMember],
  row : Int,
  col : Int,
) -> String {
  for item in members {
    if member_bucket(item, false) == row && member_bucket(item, true) == col {
      return item.text
    }
  }
  ""
}

///|
fn unique_member_buckets(
  members : Array[PptxLowerRegionMember],
  use_x : Bool,
) -> Array[Int] {
  let buckets : Array[Int] = []
  for item in members {
    let bucket = member_bucket(item, use_x)
    if !int_array_contains(buckets, bucket) {
      buckets.push(bucket)
    }
  }
  buckets.sort()
  buckets
}

///|
fn member_bucket(item : PptxLowerRegionMember, use_x : Bool) -> Int {
  match item.geometry {
    Some(g) => {
      let coord = if use_x { g.x.unwrap_or(0) } else { g.y.unwrap_or(0) }
      coord / 250000
    }
    None => 0
  }
}

///|
fn member_order_key(item : PptxLowerRegionMember) -> String {
  let y = member_bucket(item, false)
  let x = member_bucket(item, true)
  pad_int(y, 6) + ":" + pad_int(x, 6) + ":" + item.source_key.node_key
}

///|
fn region_key_path(members : Array[PptxLowerRegionMember]) -> String? {
  if members.length() == 0 {
    None
  } else {
    Some(members[0].source_key.part_name)
  }
}

///|
fn append_member_keys(
  consumed : Array[@pptxdoc.PptxSourceKey],
  members : Array[PptxLowerRegionMember],
) -> Unit {
  for item in members {
    if !source_key_array_contains(consumed, item.source_key) {
      consumed.push(item.source_key)
    }
  }
}

///|
fn any_member_consumed(
  members : Array[PptxLowerRegionMember],
  consumed : Array[@pptxdoc.PptxSourceKey],
) -> Bool {
  for item in members {
    if source_key_array_contains(consumed, item.source_key) {
      return true
    }
  }
  false
}

///|
fn semantic_caption_keys(
  pairs : Array[@pptxdoc.PptxImageCaptionPair],
) -> Array[@pptxdoc.PptxSourceKey] {
  let out : Array[@pptxdoc.PptxSourceKey] = []
  for pair in pairs {
    if confidence_is_semantic(pair.confidence) {
      out.push(pair.caption_key)
    }
  }
  out
}

///|
fn image_caption_for_picture(
  picture_key : @pptxdoc.PptxSourceKey,
  pairs : Array[@pptxdoc.PptxImageCaptionPair],
) -> String? {
  for pair in pairs {
    if source_keys_equal(pair.picture_key, picture_key) &&
      confidence_is_semantic(pair.confidence) {
      return Some(pair.caption_text)
    }
  }
  None
}

///|
fn confidence_is_semantic(confidence : @pptxdoc.PptxConfidence) -> Bool {
  confidence == @pptxdoc.PptxConfidence::High ||
  confidence == @pptxdoc.PptxConfidence::Medium
}

///|
fn object_source_key(obj : @pptxdoc.PptxObject) -> @pptxdoc.PptxSourceKey {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) => shape.source_key
    @pptxdoc.PptxObject::Group(group) => group.source_key
    @pptxdoc.PptxObject::Picture(pic) => pic.source_key
    @pptxdoc.PptxObject::Table(table) => table.source_key
    @pptxdoc.PptxObject::Chart(chart) => chart.source_key
    @pptxdoc.PptxObject::SmartArt(smart) => smart.source_key
    @pptxdoc.PptxObject::Ole(ole) => ole.source_key
    @pptxdoc.PptxObject::Connector(conn) => conn.source_key
    @pptxdoc.PptxObject::Unsupported(unsupported) => unsupported.source_key
  }
}

///|
fn source_keys_equal(
  a : @pptxdoc.PptxSourceKey,
  b : @pptxdoc.PptxSourceKey,
) -> Bool {
  a.part_name == b.part_name && a.node_key == b.node_key
}

///|
fn source_key_array_contains(
  keys : Array[@pptxdoc.PptxSourceKey],
  key : @pptxdoc.PptxSourceKey,
) -> Bool {
  for item in keys {
    if source_keys_equal(item, key) {
      return true
    }
  }
  false
}

///|
fn int_array_contains(values : Array[Int], target : Int) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn pad_int(value : Int, width : Int) -> String {
  let mut s = value.to_string()
  while s.length() < width {
    s = "0" + s
  }
  s
}

///|
fn lower_object(
  doc : @cor.Document,
  obj : @pptxdoc.PptxObject,
  layout_regions : Array[@pptxdoc.PptxLayoutRegionHint],
  image_caption_pairs : Array[@pptxdoc.PptxImageCaptionPair],
  source_name : String,
  slide_index : Int,
  out_dir : String,
  image_idx : Ref[Int],
  max_heading : Int,
) -> Unit raise {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) =>
      lower_shape(doc, shape, source_name, slide_index, max_heading)
    @pptxdoc.PptxObject::Group(group) =>
      lower_object_sequence(
        doc,
        group.children,
        layout_regions,
        image_caption_pairs,
        source_name,
        slide_index,
        out_dir,
        image_idx,
        max_heading,
      )
    @pptxdoc.PptxObject::Picture(pic) =>
      lower_picture(
        doc,
        pic,
        image_caption_for_picture(pic.source_key, image_caption_pairs),
        source_name,
        slide_index,
        out_dir,
        image_idx,
      )
    @pptxdoc.PptxObject::Table(table) =>
      lower_table(doc, table, source_name, slide_index)
    @pptxdoc.PptxObject::Chart(chart) =>
      push_origin(
        doc,
        @cor.Block::Paragraph(
          "[Unsupported PPTX chart" +
          opt_suffix(chart.target_part) +
          chart_cache_suffix(chart) +
          "]",
        ),
        source_name,
        slide_index,
        None,
        chart.relationship_id,
        Some(chart.source_key.part_name),
      )
    @pptxdoc.PptxObject::SmartArt(smart) =>
      push_origin(
        doc,
        @cor.Block::Paragraph(
          "[Unsupported PPTX SmartArt" + opt_suffix(smart.target_part) + "]",
        ),
        source_name,
        slide_index,
        None,
        smart.relationship_id,
        Some(smart.source_key.part_name),
      )
    @pptxdoc.PptxObject::Ole(ole) =>
      push_origin(
        doc,
        @cor.Block::Paragraph(
          "[Unsupported PPTX OLE object" + opt_suffix(ole.target_part) + "]",
        ),
        source_name,
        slide_index,
        None,
        ole.relationship_id,
        Some(ole.source_key.part_name),
      )
    @pptxdoc.PptxObject::Connector(conn) =>
      push_origin(
        doc,
        @cor.Block::Paragraph(
          "[PPTX connector omitted" + opt_suffix(conn.name) + "]",
        ),
        source_name,
        slide_index,
        None,
        None,
        Some(conn.source_key.part_name),
      )
    @pptxdoc.PptxObject::Unsupported(unsupported) =>
      push_origin(
        doc,
        @cor.Block::Paragraph(
          "[Unsupported PPTX object: " + unsupported.kind + "]",
        ),
        source_name,
        slide_index,
        None,
        None,
        Some(unsupported.source_key.part_name),
      )
  }
}

///|
fn opt_suffix(value : String?) -> String {
  match value {
    Some(v) => ": " + v
    None => ""
  }
}

///|
fn chart_cache_suffix(chart : @pptxdoc.PptxChartRef) -> String {
  let parts : Array[String] = []
  if chart.cached_series.length() > 0 {
    let names : Array[String] = []
    for ser in chart.cached_series {
      match ser.name {
        Some(name) => if names.length() < 3 { names.push(name) }
        None => ()
      }
    }
    if names.length() > 0 {
      parts.push("series=" + names.join(", "))
    }
  }
  if chart.cached_categories.length() > 0 {
    parts.push("categories=" + limited_join(chart.cached_categories, 4))
  }
  if chart.cached_values.length() > 0 {
    parts.push("values=" + limited_join(chart.cached_values, 4))
  }
  if parts.length() == 0 && chart.cached_text.length() > 0 {
    parts.push("cached=" + limited_join(chart.cached_text, 4))
  }
  if parts.length() == 0 {
    ""
  } else {
    "; " + parts.join("; ")
  }
}

///|
fn limited_join(values : Array[String], limit : Int) -> String {
  let out : Array[String] = []
  for value in values {
    if out.length() < limit {
      out.push(value)
    }
  }
  out.join(", ")
}

///|
fn lower_shape(
  doc : @cor.Document,
  shape : @pptxdoc.PptxShape,
  source_name : String,
  slide_index : Int,
  max_heading : Int,
) -> Unit {
  match shape.text_body {
    Some(body) => {
      let is_title = match shape.placeholder {
        Some(ph) =>
          ph.kind == @pptxdoc.PptxPlaceholderKind::Title ||
          ph.kind == @pptxdoc.PptxPlaceholderKind::CenterTitle ||
          ph.kind == @pptxdoc.PptxPlaceholderKind::Subtitle
        None => false
      }
      let mut para_index = 0
      for para in body.paragraphs {
        para_index += 1
        let inlines = paragraph_inlines(para)
        let text = inline_plain_text(inlines)
        if text.trim() == "" {
          continue
        }
        let block = match para.list_hint {
          Some(list) =>
            if inlines_have_link(inlines) {
              @cor.Block::RichListItem(
                list.bullet.unwrap_or(@pptxdoc.PptxBulletKind::Unordered) ==
                @pptxdoc.PptxBulletKind::Ordered,
                list.level,
                inlines,
              )
            } else {
              @cor.Block::ListItem(
                list.bullet.unwrap_or(@pptxdoc.PptxBulletKind::Unordered) ==
                @pptxdoc.PptxBulletKind::Ordered,
                list.level,
                text,
              )
            }
          None =>
            if is_title && para_index == 1 {
              if inlines_have_link(inlines) {
                @cor.Block::RichHeading(clamp_heading(3, max_heading), inlines)
              } else {
                @cor.Block::Heading(clamp_heading(3, max_heading), text)
              }
            } else if inlines_have_link(inlines) {
              @cor.Block::RichParagraph(inlines)
            } else {
              @cor.Block::Paragraph(text)
            }
        }
        push_origin(
          doc,
          block,
          source_name,
          slide_index,
          shape.object_ref,
          single_shape_relationship(shape),
          Some(shape.source_key.part_name),
        )
      }
    }
    None =>
      if is_decorative_shape(shape) {
        push_origin(
          doc,
          @cor.Block::Paragraph(
            "[PPTX decorative shape omitted" + opt_suffix(shape.name) + "]",
          ),
          source_name,
          slide_index,
          shape.object_ref,
          None,
          Some(shape.source_key.part_name),
        )
      }
  }
}

///|
fn is_decorative_shape(shape : @pptxdoc.PptxShape) -> Bool {
  match shape.reading_order {
    Some(hint) => hint.bucket == @pptxdoc.PptxReadingBucket::Decorative
    None => shape.text_body is None
  }
}

///|
fn paragraph_inlines(para : @pptxdoc.PptxParagraph) -> Array[@cor.Inline] {
  let out : Array[@cor.Inline] = []
  for run in para.runs {
    for inline in run.inlines {
      match inline {
        @pptxdoc.PptxInline::Text(text) => out.push(@cor.Inline::Text(text))
        @pptxdoc.PptxInline::Break => out.push(@cor.Inline::Break)
        @pptxdoc.PptxInline::Field(text) => out.push(@cor.Inline::Text(text))
        @pptxdoc.PptxInline::Hyperlink(link, text) =>
          match link.target {
            Some(target) => out.push(@cor.Inline::Link(text, target))
            None => out.push(@cor.Inline::Text(text))
          }
        @pptxdoc.PptxInline::Unsupported(unsupported) =>
          out.push(
            @cor.Inline::Text(
              "[Unsupported PPTX inline: " + unsupported.kind + "]",
            ),
          )
      }
    }
  }
  out
}

///|
fn inline_plain_text(inlines : Array[@cor.Inline]) -> String {
  let mut out = ""
  for inline in inlines {
    match inline {
      @cor.Inline::Text(t) => out = out + t
      @cor.Inline::Break => out = out + "\n"
      @cor.Inline::Link(text, _) => out = out + text
      @cor.Inline::NoteRef(_) => ()
    }
  }
  out
}

///|
fn inlines_have_link(inlines : Array[@cor.Inline]) -> Bool {
  for inline in inlines {
    match inline {
      @cor.Inline::Link(_, _) => return true
      _ => ()
    }
  }
  false
}

///|
fn single_shape_relationship(shape : @pptxdoc.PptxShape) -> String? {
  let mut rid : String? = None
  for link in shape.hyperlinks {
    match link.relationship_id {
      Some(value) =>
        match rid {
          Some(prev) => if prev != value { return None }
          None => rid = Some(value)
        }
      None => ()
    }
  }
  rid
}

///|
fn lower_picture(
  doc : @cor.Document,
  pic : @pptxdoc.PptxPicture,
  caption : String?,
  source_name : String,
  slide_index : Int,
  out_dir : String,
  image_idx : Ref[Int],
) -> Unit {
  let media = match pic.media {
    Some(m) => m
    None => return
  }
  if media.is_external || media.unsupported {
    push_origin(
      doc,
      @cor.Block::Paragraph(
        "[Unsupported PPTX media" + opt_suffix(media.resolved_target) + "]",
      ),
      source_name,
      slide_index,
      pic.object_ref,
      media.relationship_id,
      Some(media.source_key.part_name),
    )
    return
  }
  let data = match media.data {
    Some(bytes) => bytes
    None => return
  }
  if out_dir == "" {
    return
  }
  if image_idx.val >= max_media_exports_per_deck() {
    push_origin(
      doc,
      @cor.Block::Paragraph("[Unsupported PPTX media export: budget exceeded]"),
      source_name,
      slide_index,
      pic.object_ref,
      media.relationship_id,
      Some(media.source_key.part_name),
    )
    return
  }
  let assets_dir = out_dir + "/assets"
  if !@fs.path_exists(assets_dir) {
    @fs.create_dir(assets_dir) catch {
      _ => return
    }
  }
  let ext = media.resolved_extension.unwrap_or("bin")
  let rel_path = @cor.next_image_asset_rel_path_unique(image_idx, ext, out_dir)
  @fs.write_bytes_to_file(out_dir + "/" + rel_path, data) catch {
    _ => return
  }
  let origin : @cor.Origin = {
    source_name: Some(source_name),
    page: None,
    slide: Some(slide_index),
    sheet: None,
    block_index: None,
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: pic.object_ref,
    relationship_id: media.relationship_id,
    key_path: Some(media.source_key.part_name),
  }
  @cor.push_with_origin(
    doc,
    @cor.Block::ImageBlock({
      path: rel_path,
      alt_text: match media.alt_text {
        Some(text) => Some(text)
        None => Some("slide-" + slide_index.to_string() + "-image")
      },
      title: media.title,
      caption,
      origin: Some(origin),
    }),
    Some(origin),
  )
  @cor.set_asset_origin(doc, rel_path, {
    source_name: Some(source_name),
    page: None,
    slide: Some(slide_index),
    sheet: None,
    origin_id: Some(pic.source_key.node_key),
    nearby_caption: caption,
    object_ref: pic.object_ref,
    relationship_id: media.relationship_id,
    source_path: media.resolved_target,
    row_index: None,
    column_index: None,
    key_path: Some(media.source_key.part_name),
  })
}

///|
fn max_media_exports_per_deck() -> Int {
  5000
}

///|
fn lower_table(
  doc : @cor.Document,
  table : @pptxdoc.PptxTable,
  source_name : String,
  slide_index : Int,
) -> Unit {
  let rows : Array[Array[String]] = []
  for row in table.rows {
    let out_row : Array[String] = []
    for cell in row.cells {
      out_row.push(table_cell_text(cell))
      let span = cell.grid_span.unwrap_or(1)
      if span > 1 {
        for _ in 1..<span {
          out_row.push("")
        }
      }
    }
    rows.push(out_row)
  }
  if rows.length() == 0 {
    return
  }
  push_origin(
    doc,
    @cor.Block::RichTable({ rows, header_rows: 1, hints: None }),
    source_name,
    slide_index,
    None,
    None,
    Some(table.source_key.part_name),
  )
}

///|
fn table_cell_text(cell : @pptxdoc.PptxTableCell) -> String {
  let paras : Array[String] = []
  for para in cell.paragraphs {
    let text = inline_plain_text(paragraph_inlines(para)).trim().to_owned()
    if text != "" {
      paras.push(text)
    }
  }
  paras.join("<br>")
}

///|
fn lower_comments(
  doc : @cor.Document,
  slide : @pptxdoc.PptxSlide,
  source_name : String,
  slide_heading : String,
  max_heading : Int,
) -> Unit {
  if slide.comments.length() == 0 {
    return
  }
  push_origin(
    doc,
    @cor.Block::Heading(clamp_heading(3, max_heading), "Comments"),
    source_name,
    slide.slide_index,
    None,
    None,
    Some(slide.part_name),
  )
  for comment in slide.comments {
    let prefix = match comment.author_name {
      Some(name) => name + ": "
      None =>
        if comment.author_id.trim() == "" {
          ""
        } else {
          "Author " + comment.author_id + ": "
        }
    }
    push_origin(
      doc,
      @cor.Block::ListItem(false, 0, prefix + comment.text),
      source_name,
      slide.slide_index,
      None,
      None,
      Some(comment.source_key.part_name),
    )
  }
  ignore(slide_heading)
}

///|
fn lower_notes(
  doc : @cor.Document,
  slide : @pptxdoc.PptxSlide,
  source_name : String,
  slide_heading : String,
  max_heading : Int,
) -> Unit {
  let notes = match slide.notes {
    Some(n) => n
    None => return
  }
  if notes.paragraphs.length() == 0 {
    return
  }
  push_origin(
    doc,
    @cor.Block::Heading(clamp_heading(3, max_heading), "Speaker Notes"),
    source_name,
    slide.slide_index,
    None,
    None,
    Some(notes.part_name),
  )
  for para in notes.paragraphs {
    let inlines = paragraph_inlines(para)
    let text = inline_plain_text(inlines)
    if text.trim() != "" {
      push_origin(
        doc,
        if inlines_have_link(inlines) {
          @cor.Block::RichParagraph(inlines)
        } else {
          @cor.Block::Paragraph(text)
        },
        source_name,
        slide.slide_index,
        None,
        None,
        Some(notes.part_name),
      )
    }
  }
  ignore(slide_heading)
}

///|
fn lower_document_warnings(
  doc : @cor.Document,
  warnings : Array[@pptxdoc.PptxWarning],
  source_name : String,
  max_heading : Int,
) -> Unit {
  if warnings.length() == 0 {
    return
  }
  @cor.push_with_origin(
    doc,
    @cor.Block::Heading(clamp_heading(2, max_heading), "PPTX Warnings"),
    Some({
      source_name: Some(source_name),
      page: None,
      slide: None,
      sheet: None,
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref: None,
      relationship_id: None,
      key_path: None,
    }),
  )
  for warning in warnings {
    @cor.push(doc, @cor.Block::ListItem(false, 0, warning.message))
  }
}
