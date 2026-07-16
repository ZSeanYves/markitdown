///|
pub fn normalize_pptx_source(source : PptxSourceDocument) -> PptxDocument {
  let slides : Array[PptxSlide] = []
  let media : Array[PptxMediaRef] = []
  let warnings : Array[PptxWarning] = []
  let budget = default_pptx_parse_budget()
  for warning in source.warnings {
    warnings.push(warning)
  }
  for slide_source in source.slides {
    let objects0 = normalize_objects(
      slide_source.objects,
      slide_source.layout_ref,
      slide_source.master_ref,
      source.layouts,
      source.masters,
    )
    let layout = infer_slide_layout_regions(
      slide_source.slide_ref.part_name,
      objects0,
      budget,
    )
    let objects = apply_caption_reading_hints(
      objects0,
      layout.image_caption_pairs,
    )
    collect_media_from_objects(media, objects)
    let reading_order = collect_reading_order(objects)
    slides.push({
      slide_id: slide_source.slide_ref.slide_id,
      slide_index: slide_source.slide_ref.slide_index,
      part_name: slide_source.slide_ref.part_name,
      relationship_id: slide_source.slide_ref.relationship_id,
      hidden: slide_source.slide_ref.hidden,
      layout_ref: slide_source.layout_ref,
      master_ref: slide_source.master_ref,
      objects,
      notes: slide_source.notes,
      comments: slide_source.comments,
      layout_regions: layout.layout_regions,
      image_caption_pairs: layout.image_caption_pairs,
      reading_order,
      warnings: slide_source.warnings,
      source_key: slide_source.source_key,
    })
  }
  {
    metadata: source.metadata,
    part_graph: source.part_graph,
    presentation: source.presentation,
    slides,
    layouts: source.layouts,
    masters: source.masters,
    media,
    comment_authors: source.comment_authors,
    warnings,
  }
}

///|
fn normalize_objects(
  objects : Array[PptxObject],
  layout_ref : PptxLayoutRef?,
  master_ref : PptxMasterRef?,
  layouts : Array[PptxSourceLayout],
  masters : Array[PptxSourceMaster],
) -> Array[PptxObject] {
  let out : Array[PptxObject] = []
  let mut source_order = 0
  for obj in objects {
    source_order += 1
    out.push(
      normalize_object(
        obj, layout_ref, master_ref, layouts, masters, source_order,
      ),
    )
  }
  out
}

///|
fn normalize_object(
  obj : PptxObject,
  layout_ref : PptxLayoutRef?,
  master_ref : PptxMasterRef?,
  layouts : Array[PptxSourceLayout],
  masters : Array[PptxSourceMaster],
  source_order : Int,
) -> PptxObject {
  match obj {
    Shape(shape) => {
      let placeholder = resolve_placeholder_hint(
        shape, layout_ref, master_ref, layouts, masters,
      )
      let bucket = reading_bucket_for_shape(shape, placeholder)
      Shape({
        shape_id: shape.shape_id,
        name: shape.name,
        shape_type: shape.shape_type,
        object_ref: shape.object_ref,
        geometry: shape.geometry,
        direct_placeholder: shape.direct_placeholder,
        placeholder,
        text_body: shape.text_body,
        hyperlinks: shape.hyperlinks,
        reading_order: Some(
          reading_hint(
            bucket,
            source_order,
            shape.source_key,
            shape.geometry,
            reading_confidence_for_shape(bucket, placeholder),
            reading_reason_for_shape(bucket, placeholder),
          ),
        ),
        source_key: shape.source_key,
      })
    }
    Picture(pic) =>
      Picture({
        shape_id: pic.shape_id,
        name: pic.name,
        object_ref: pic.object_ref,
        media: pic.media,
        geometry: pic.geometry,
        reading_order: Some(
          reading_hint(
            Image,
            source_order,
            pic.source_key,
            pic.geometry,
            Medium,
            "picture geometry/source order",
          ),
        ),
        source_key: pic.source_key,
      })
    Group(group) => {
      let children = normalize_objects(
        group.children,
        layout_ref,
        master_ref,
        layouts,
        masters,
      )
      let (group_bucket, group_geometry, group_confidence, group_reason) = group_reading_anchor(
        group.geometry,
        children,
      )
      Group({
        shape_id: group.shape_id,
        name: group.name,
        object_ref: group.object_ref,
        geometry: group.geometry,
        children,
        reading_order: Some(
          reading_hint(
            group_bucket,
            source_order,
            group.source_key,
            group_geometry,
            group_confidence,
            group_reason,
          ),
        ),
        source_key: group.source_key,
      })
    }
    Table(table) => Table(table)
    Chart(chart) => Chart(chart)
    SmartArt(smart) => SmartArt(smart)
    Ole(ole) => Ole(ole)
    Connector(conn) => Connector(conn)
    Unsupported(unsupported) => Unsupported(unsupported)
  }
}

///|
fn group_reading_anchor(
  fallback_geometry : PptxGeometry?,
  children : Array[PptxObject],
) -> (PptxReadingBucket, PptxGeometry?, PptxConfidence, String) {
  let mut best_hint : PptxReadingOrderHint? = None
  let mut best_geometry : PptxGeometry? = None
  for child in children {
    match object_reading_hint(child) {
      Some(hint) =>
        match best_hint {
          Some(current) =>
            if hint.order_key.lexical_compare(current.order_key) < 0 {
              best_hint = Some(hint)
              best_geometry = object_geometry(child)
            }
          None => {
            best_hint = Some(hint)
            best_geometry = object_geometry(child)
          }
        }
      None => ()
    }
  }
  match best_hint {
    Some(hint) =>
      (
        hint.bucket,
        match best_geometry {
          Some(geometry) => Some(geometry)
          None => fallback_geometry
        },
        hint.confidence,
        "group anchored by earliest child reading order",
      )
    None => (Body, fallback_geometry, Medium, "group hierarchy")
  }
}

///|
fn object_geometry(obj : PptxObject) -> PptxGeometry? {
  match obj {
    Shape(shape) => shape.geometry
    Picture(pic) => pic.geometry
    Group(group) => group.geometry
    Table(table) => table.geometry
    Connector(conn) => conn.geometry
    _ => None
  }
}

///|
fn resolve_placeholder_hint(
  shape : PptxShape,
  layout_ref : PptxLayoutRef?,
  master_ref : PptxMasterRef?,
  layouts : Array[PptxSourceLayout],
  masters : Array[PptxSourceMaster],
) -> PptxResolvedPlaceholderHint? {
  match shape.direct_placeholder {
    Some(ph) =>
      return Some({
        kind: ph.kind,
        index: ph.index,
        source: Direct,
        confidence: High,
        reason: "direct slide placeholder",
        trace: [shape.source_key],
      })
    None => ()
  }
  match layout_ref {
    Some(layout) =>
      match
        find_placeholder_candidate(
          find_layout_candidates(layouts, layout.part_name),
          shape,
          true,
        ) {
        Some(candidate) =>
          return Some({
            kind: candidate.placeholder.kind,
            index: candidate.placeholder.index,
            source: LayoutTypeIndex,
            confidence: Medium,
            reason: "layout placeholder candidate",
            trace: [shape.source_key, candidate.source_key],
          })
        None => ()
      }
    None => ()
  }
  match master_ref {
    Some(master) =>
      match
        find_placeholder_candidate(
          find_master_candidates(masters, master.part_name),
          shape,
          true,
        ) {
        Some(candidate) =>
          return Some({
            kind: candidate.placeholder.kind,
            index: candidate.placeholder.index,
            source: MasterTypeIndex,
            confidence: Low,
            reason: "master placeholder candidate",
            trace: [shape.source_key, candidate.source_key],
          })
        None => ()
      }
    None => ()
  }
  let inferred = infer_placeholder_from_geometry_name(shape)
  match inferred {
    Some(kind) =>
      Some({
        kind,
        index: None,
        source: GeometryNameInference,
        confidence: Low,
        reason: "geometry/name inference",
        trace: [shape.source_key],
      })
    None => None
  }
}

///|
fn find_layout_candidates(
  layouts : Array[PptxSourceLayout],
  part_name : String,
) -> Array[PptxPlaceholderCandidate] {
  for layout in layouts {
    if layout.part_name == part_name {
      return layout.placeholders
    }
  }
  []
}

///|
fn find_master_candidates(
  masters : Array[PptxSourceMaster],
  part_name : String,
) -> Array[PptxPlaceholderCandidate] {
  for master in masters {
    if master.part_name == part_name {
      return master.placeholders
    }
  }
  []
}

///|
fn find_placeholder_candidate(
  candidates : Array[PptxPlaceholderCandidate],
  shape : PptxShape,
  allow_type_only : Bool,
) -> PptxPlaceholderCandidate? {
  for c in candidates {
    match shape.direct_placeholder {
      Some(ph) =>
        if c.placeholder.kind == ph.kind && c.placeholder.index == ph.index {
          return Some(c)
        }
      None => ()
    }
  }
  if allow_type_only {
    match infer_placeholder_from_geometry_name(shape) {
      Some(kind) =>
        for c in candidates {
          if c.placeholder.kind == kind {
            return Some(c)
          }
        }
      None => ()
    }
  }
  None
}

///|
fn infer_placeholder_from_geometry_name(
  shape : PptxShape,
) -> PptxPlaceholderKind? {
  let name = shape.name.unwrap_or("").to_lower()
  if name.contains("title") {
    return Some(Title)
  }
  if name.contains("subtitle") {
    return Some(Subtitle)
  }
  if name.contains("footer") {
    return Some(Footer)
  }
  match shape.geometry {
    Some(g) => {
      let y = g.y.unwrap_or(0)
      let h = g.height.unwrap_or(0)
      if y >= 0 && y < 900000 && h > 100000 {
        Some(Title)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn reading_bucket_for_shape(
  shape : PptxShape,
  placeholder : PptxResolvedPlaceholderHint?,
) -> PptxReadingBucket {
  match placeholder {
    Some(ph) =>
      match ph.kind {
        Title | CenterTitle => Title
        Subtitle => Subtitle
        Footer | Date | SlideNumber => Footer
        _ => Body
      }
    None => if shape.text_body is None { Decorative } else { Body }
  }
}

///|
fn reading_confidence_for_shape(
  bucket : PptxReadingBucket,
  placeholder : PptxResolvedPlaceholderHint?,
) -> PptxConfidence {
  match placeholder {
    Some(ph) => ph.confidence
    None => if bucket == Decorative { Low } else { Medium }
  }
}

///|
fn reading_reason_for_shape(
  bucket : PptxReadingBucket,
  placeholder : PptxResolvedPlaceholderHint?,
) -> String {
  match placeholder {
    Some(ph) => "placeholder " + ph.reason
    None =>
      if bucket == Decorative {
        "decorative shape without text"
      } else {
        "shape geometry/source order"
      }
  }
}

///|
fn reading_hint(
  bucket : PptxReadingBucket,
  source_order : Int,
  source_key : PptxSourceKey,
  geometry : PptxGeometry?,
  confidence : PptxConfidence,
  reason : String,
) -> PptxReadingOrderHint {
  let priority = match bucket {
    Title => 10
    Subtitle => 20
    Body => 30
    Table => 40
    Image => 50
    CaptionLike => 60
    NoteLike => 70
    Footer => 80
    Decorative => 90
    Unknown => 100
  }
  let (y, x) = geometry_sort_pair(geometry)
  {
    bucket,
    priority,
    order_key: pad_int(priority, 3) +
    ":" +
    pad_int(y, 10) +
    ":" +
    pad_int(x, 10) +
    ":" +
    pad_int(source_order, 5) +
    ":" +
    source_key.node_key,
    confidence,
    reason,
  }
}

///|
fn geometry_sort_pair(geometry : PptxGeometry?) -> (Int, Int) {
  match geometry {
    Some(g) => (normalize_sort_coord(g.y), normalize_sort_coord(g.x))
    None => (999999999, 999999999)
  }
}

///|
fn normalize_sort_coord(value : Int?) -> Int {
  let v = value.unwrap_or(999999999)
  if v < 0 {
    0
  } else if v > 999999999 {
    999999999
  } else {
    v
  }
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
priv struct PptxSlideLayoutInference {
  layout_regions : Array[PptxLayoutRegionHint]
  image_caption_pairs : Array[PptxImageCaptionPair]
}

///|
priv struct PptxLayoutObjectInfo {
  source_key : PptxSourceKey
  object_index : Int
  kind : PptxObjectKind
  text : String
  name : String?
  shape_id : String?
  geometry : PptxGeometry?
  image_alt_text : String?
  image_title : String?
}

///|
fn infer_slide_layout_regions(
  slide_part : String,
  objects : Array[PptxObject],
  budget : PptxParseBudget,
) -> PptxSlideLayoutInference {
  let infos : Array[PptxLayoutObjectInfo] = []
  let order_ref : Ref[Int] = { val: 0 }
  collect_layout_object_infos(infos, objects, order_ref)
  let pairs = infer_image_caption_pairs(slide_part, infos, budget)
  let regions = layout_regions_from_pairs(pairs)
  append_inferred_shape_regions(regions, infos, pairs, budget)
  { layout_regions: regions, image_caption_pairs: pairs }
}

///|
fn collect_layout_object_infos(
  out : Array[PptxLayoutObjectInfo],
  objects : Array[PptxObject],
  order_ref : Ref[Int],
) -> Unit {
  for obj in objects {
    order_ref.val += 1
    match obj {
      Shape(shape) => {
        let text = shape_plain_text(shape)
        out.push({
          source_key: shape.source_key,
          object_index: order_ref.val,
          kind: Shape,
          text,
          name: shape.name,
          shape_id: shape.shape_id,
          geometry: shape.geometry,
          image_alt_text: None,
          image_title: None,
        })
      }
      Picture(pic) => {
        let (alt, title) = match pic.media {
          Some(media) => (media.alt_text, media.title)
          None => (None, None)
        }
        out.push({
          source_key: pic.source_key,
          object_index: order_ref.val,
          kind: Picture,
          text: "",
          name: pic.name,
          shape_id: pic.shape_id,
          geometry: pic.geometry,
          image_alt_text: alt,
          image_title: title,
        })
      }
      Table(table) =>
        out.push({
          source_key: table.source_key,
          object_index: order_ref.val,
          kind: Table,
          text: table_plain_text(table),
          name: None,
          shape_id: None,
          geometry: table.geometry,
          image_alt_text: None,
          image_title: None,
        })
      Group(group) =>
        collect_layout_object_infos(out, group.children, order_ref)
      _ => ()
    }
  }
}

///|
fn shape_plain_text(shape : PptxShape) -> String {
  match shape.text_body {
    Some(body) => text_body_plain_text(body)
    None => ""
  }
}

///|
fn text_body_plain_text(body : PptxTextBody) -> String {
  let parts : Array[String] = []
  for para in body.paragraphs {
    let text = paragraph_plain_text(para).trim().to_owned()
    if text != "" {
      parts.push(text)
    }
  }
  parts.join("\n")
}

///|
fn paragraph_plain_text(para : PptxParagraph) -> String {
  let mut out = ""
  for run in para.runs {
    for inline in run.inlines {
      match inline {
        Text(text) => out = out + text
        Break => out = out + "\n"
        Field(text) => out = out + text
        Hyperlink(_, text) => out = out + text
        Unsupported(unsupported) =>
          out = out + "[Unsupported PPTX inline: " + unsupported.kind + "]"
      }
    }
  }
  out
}

///|
fn table_plain_text(table : PptxTable) -> String {
  let rows : Array[String] = []
  for row in table.rows {
    let cells : Array[String] = []
    for cell in row.cells {
      let paras : Array[String] = []
      for para in cell.paragraphs {
        let text = paragraph_plain_text(para).trim().to_owned()
        if text != "" {
          paras.push(text)
        }
      }
      cells.push(paras.join(" "))
    }
    rows.push(cells.join(" | "))
  }
  rows.join("\n")
}

///|
fn infer_image_caption_pairs(
  slide_part : String,
  infos : Array[PptxLayoutObjectInfo],
  budget : PptxParseBudget,
) -> Array[PptxImageCaptionPair] {
  let pairs : Array[PptxImageCaptionPair] = []
  let used_captions : Array[PptxSourceKey] = []
  let mut comparisons = 0
  for image in infos {
    if image.kind != Picture {
      continue
    }
    let mut best_score = 0
    let mut best_caption : PptxLayoutObjectInfo? = None
    for candidate in infos {
      if comparisons >= budget.max_geometry_comparisons {
        break
      }
      comparisons += 1
      if candidate.kind != Shape ||
        candidate.text.trim() == "" ||
        source_key_array_contains(used_captions, candidate.source_key) {
        continue
      }
      let score = caption_pair_score(image, candidate)
      if score > best_score {
        best_score = score
        best_caption = Some(candidate)
      }
    }
    match best_caption {
      Some(caption) =>
        if best_score >= 40 &&
          (best_score >= 70 || caption_prefix_score(caption.text) > 0) {
          used_captions.push(caption.source_key)
          pairs.push({
            owning_slide_part: slide_part,
            picture_key: image.source_key,
            caption_key: caption.source_key,
            caption_text: caption.text.trim().to_owned(),
            image_shape_id: image.shape_id,
            image_name: image.name,
            image_alt_text: image.image_alt_text,
            image_title: image.image_title,
            image_geometry: image.geometry,
            confidence: if best_score >= 70 {
              High
            } else if best_score >= 50 {
              Medium
            } else {
              Low
            },
            reason: caption_pair_reason(best_score, caption),
          })
        }
      None => ()
    }
  }
  pairs
}

///|
fn caption_pair_score(
  image : PptxLayoutObjectInfo,
  caption : PptxLayoutObjectInfo,
) -> Int {
  let prefix = caption_prefix_score(caption.text)
  let geom = caption_geometry_score(image.geometry, caption.geometry)
  let order = if caption.object_index >= image.object_index &&
    caption.object_index - image.object_index <= 3 {
    10
  } else {
    0
  }
  if geom == 0 && prefix == 0 {
    0
  } else {
    geom + prefix + order
  }
}

///|
fn caption_prefix_score(text : String) -> Int {
  let lower = text.trim().to_lower()
  if lower.has_prefix("figure") ||
    lower.has_prefix("fig.") ||
    lower.has_prefix("caption") {
    30
  } else {
    0
  }
}

///|
fn caption_geometry_score(
  image_geometry : PptxGeometry?,
  caption_geometry : PptxGeometry?,
) -> Int {
  match (image_geometry, caption_geometry) {
    (Some(img), Some(cap)) => {
      let ix = img.x.unwrap_or(0)
      let iy = img.y.unwrap_or(0)
      let iw = img.width.unwrap_or(0)
      let ih = img.height.unwrap_or(0)
      let cx = cap.x.unwrap_or(0)
      let cy = cap.y.unwrap_or(0)
      let cw = cap.width.unwrap_or(0)
      let ch = cap.height.unwrap_or(0)
      let overlap = int_min(ix + iw, cx + cw) - int_max(ix, cx)
      if overlap <= 0 || overlap * 2 < int_min(iw, cw) {
        return 0
      }
      let below = cy - (iy + ih)
      if below >= 0 && below <= 700000 {
        return 45 + int_max(0, 250000 - below) / 10000
      }
      let above = iy - (cy + ch)
      if above >= 0 && above <= 350000 {
        return 30 + int_max(0, 150000 - above) / 15000
      }
      0
    }
    _ => 0
  }
}

///|
fn caption_pair_reason(score : Int, caption : PptxLayoutObjectInfo) -> String {
  if caption_prefix_score(caption.text) > 0 && score >= 70 {
    "caption-like text near image geometry"
  } else if score >= 70 {
    "nearby text below image geometry"
  } else if score >= 50 {
    "nearby caption candidate"
  } else {
    "low-confidence nearby caption candidate"
  }
}

///|
fn layout_regions_from_pairs(
  pairs : Array[PptxImageCaptionPair],
) -> Array[PptxLayoutRegionHint] {
  let regions : Array[PptxLayoutRegionHint] = []
  for pair in pairs {
    let members = [pair.picture_key, pair.caption_key]
    regions.push({
      kind: CaptionLike,
      members,
      confidence: pair.confidence,
      reason: pair.reason,
      order_key: layout_region_order_key(CaptionLike, members, None),
    })
    regions.push({
      kind: ImageCaptionPair,
      members,
      confidence: pair.confidence,
      reason: pair.reason,
      order_key: layout_region_order_key(ImageCaptionPair, members, None),
    })
  }
  regions
}

///|
fn append_inferred_shape_regions(
  regions : Array[PptxLayoutRegionHint],
  infos : Array[PptxLayoutObjectInfo],
  pairs : Array[PptxImageCaptionPair],
  budget : PptxParseBudget,
) -> Unit {
  let text_infos = non_caption_text_infos(infos, pairs)
  append_two_column_region(regions, text_infos)
  append_table_like_region(regions, text_infos, budget)
  append_grid_like_region(regions, infos, budget)
  append_card_like_region(regions, text_infos)
}

///|
fn non_caption_text_infos(
  infos : Array[PptxLayoutObjectInfo],
  pairs : Array[PptxImageCaptionPair],
) -> Array[PptxLayoutObjectInfo] {
  let out : Array[PptxLayoutObjectInfo] = []
  for info in infos {
    if info.kind == Shape &&
      info.text.trim() != "" &&
      !is_caption_key(info.source_key, pairs) {
      out.push(info)
    }
  }
  out
}

///|
fn append_two_column_region(
  regions : Array[PptxLayoutRegionHint],
  text_infos : Array[PptxLayoutObjectInfo],
) -> Unit {
  if text_infos.length() < 2 {
    return
  }
  let cols = unique_geometry_buckets(text_infos, true)
  if cols.length() == 2 {
    let members = source_keys_from_infos(text_infos)
    regions.push({
      kind: TwoColumn,
      members,
      confidence: Medium,
      reason: "two-column text geometry",
      order_key: layout_region_order_key(
        TwoColumn,
        members,
        first_geometry(text_infos),
      ),
    })
  }
}

///|
fn append_table_like_region(
  regions : Array[PptxLayoutRegionHint],
  text_infos : Array[PptxLayoutObjectInfo],
  budget : PptxParseBudget,
) -> Unit {
  if text_infos.length() < 4 {
    return
  }
  if text_infos.length() * text_infos.length() > budget.max_geometry_comparisons {
    return
  }
  let rows = unique_geometry_buckets(text_infos, false)
  let cols = unique_geometry_buckets(text_infos, true)
  if rows.length() >= 2 && cols.length() >= 2 {
    let members = source_keys_from_infos(text_infos)
    regions.push({
      kind: TableLike,
      members,
      confidence: if text_infos.length() >= rows.length() * cols.length() {
        High
      } else {
        Medium
      },
      reason: "bounded grid of text shapes, not an explicit a:tbl",
      order_key: layout_region_order_key(
        TableLike,
        members,
        first_geometry(text_infos),
      ),
    })
  }
}

///|
fn append_grid_like_region(
  regions : Array[PptxLayoutRegionHint],
  infos : Array[PptxLayoutObjectInfo],
  budget : PptxParseBudget,
) -> Unit {
  let pics : Array[PptxLayoutObjectInfo] = []
  for info in infos {
    if info.kind == Picture {
      pics.push(info)
    }
  }
  if pics.length() < 4 ||
    pics.length() * pics.length() > budget.max_geometry_comparisons {
    return
  }
  let rows = unique_geometry_buckets(pics, false)
  let cols = unique_geometry_buckets(pics, true)
  if rows.length() >= 2 && cols.length() >= 2 {
    let members = source_keys_from_infos(pics)
    regions.push({
      kind: GridLike,
      members,
      confidence: High,
      reason: "bounded grid of picture-like objects",
      order_key: layout_region_order_key(
        GridLike,
        members,
        first_geometry(pics),
      ),
    })
  }
}

///|
fn append_card_like_region(
  regions : Array[PptxLayoutRegionHint],
  text_infos : Array[PptxLayoutObjectInfo],
) -> Unit {
  let cards : Array[PptxLayoutObjectInfo] = []
  for info in text_infos {
    let name = info.name.unwrap_or("").to_lower()
    if name.contains("card") {
      cards.push(info)
    }
  }
  if cards.length() >= 2 {
    let members = source_keys_from_infos(cards)
    regions.push({
      kind: CardLike,
      members,
      confidence: High,
      reason: "repeated card-like text shapes",
      order_key: layout_region_order_key(
        CardLike,
        members,
        first_geometry(cards),
      ),
    })
  }
}

///|
fn unique_geometry_buckets(
  infos : Array[PptxLayoutObjectInfo],
  use_x : Bool,
) -> Array[Int] {
  let buckets : Array[Int] = []
  for info in infos {
    match info.geometry {
      Some(g) => {
        let coord = if use_x { g.x.unwrap_or(0) } else { g.y.unwrap_or(0) }
        let bucket = coord / 250000
        if !int_array_contains(buckets, bucket) {
          buckets.push(bucket)
        }
      }
      None => ()
    }
  }
  buckets.sort()
  buckets
}

///|
fn source_keys_from_infos(
  infos : Array[PptxLayoutObjectInfo],
) -> Array[PptxSourceKey] {
  let out : Array[PptxSourceKey] = []
  for info in infos {
    out.push(info.source_key)
  }
  out
}

///|
fn first_geometry(infos : Array[PptxLayoutObjectInfo]) -> PptxGeometry? {
  for info in infos {
    match info.geometry {
      Some(g) => return Some(g)
      None => ()
    }
  }
  None
}

///|
fn layout_region_order_key(
  kind : PptxLayoutRegionKind,
  members : Array[PptxSourceKey],
  geometry : PptxGeometry?,
) -> String {
  let priority = match kind {
    TitleLike => 10
    BodyLike => 30
    TwoColumn => 35
    TableLike => 45
    GridLike => 55
    CardLike => 58
    CaptionLike => 60
    ImageCaptionPair => 60
    FooterLike => 80
    Decorative => 90
    Unknown => 100
  }
  let first_key = if members.length() == 0 {
    "region"
  } else {
    members[0].node_key
  }
  let (y, x) = geometry_sort_pair(geometry)
  pad_int(priority, 3) +
  ":" +
  pad_int(y, 10) +
  ":" +
  pad_int(x, 10) +
  ":" +
  first_key
}

///|
fn apply_caption_reading_hints(
  objects : Array[PptxObject],
  pairs : Array[PptxImageCaptionPair],
) -> Array[PptxObject] {
  let out : Array[PptxObject] = []
  let mut source_order = 0
  for obj in objects {
    source_order += 1
    out.push(apply_caption_reading_hint(obj, pairs, source_order))
  }
  out
}

///|
fn apply_caption_reading_hint(
  obj : PptxObject,
  pairs : Array[PptxImageCaptionPair],
  source_order : Int,
) -> PptxObject {
  match obj {
    Shape(shape) =>
      match caption_pair_for_key(shape.source_key, pairs) {
        Some(pair) if caption_pair_is_semantic_for_reading(pair) =>
          Shape({
            shape_id: shape.shape_id,
            name: shape.name,
            shape_type: shape.shape_type,
            object_ref: shape.object_ref,
            geometry: shape.geometry,
            direct_placeholder: shape.direct_placeholder,
            placeholder: shape.placeholder,
            text_body: shape.text_body,
            hyperlinks: shape.hyperlinks,
            reading_order: Some(
              reading_hint(
                CaptionLike,
                source_order,
                shape.source_key,
                shape.geometry,
                pair.confidence,
                pair.reason,
              ),
            ),
            source_key: shape.source_key,
          })
        _ => Shape(shape)
      }
    Group(group) =>
      Group({
        shape_id: group.shape_id,
        name: group.name,
        object_ref: group.object_ref,
        geometry: group.geometry,
        children: apply_caption_reading_hints(group.children, pairs),
        reading_order: group.reading_order,
        source_key: group.source_key,
      })
    _ => obj
  }
}

///|
fn caption_pair_is_semantic_for_reading(pair : PptxImageCaptionPair) -> Bool {
  caption_prefix_score(pair.caption_text) > 0
}

///|
fn caption_pair_for_key(
  key : PptxSourceKey,
  pairs : Array[PptxImageCaptionPair],
) -> PptxImageCaptionPair? {
  for pair in pairs {
    if source_keys_equal(pair.caption_key, key) {
      return Some(pair)
    }
  }
  None
}

///|
fn is_caption_key(
  key : PptxSourceKey,
  pairs : Array[PptxImageCaptionPair],
) -> Bool {
  match caption_pair_for_key(key, pairs) {
    Some(_) => true
    None => false
  }
}

///|
fn source_keys_equal(a : PptxSourceKey, b : PptxSourceKey) -> Bool {
  a.part_name == b.part_name && a.node_key == b.node_key
}

///|
fn source_key_array_contains(
  keys : Array[PptxSourceKey],
  key : PptxSourceKey,
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
fn int_min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn int_max(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn collect_reading_order(objects : Array[PptxObject]) -> Array[PptxSourceKey] {
  let keyed : Array[(String, PptxSourceKey)] = []
  let mut fallback_order = 0
  for obj in objects {
    match object_reading_hint(obj) {
      Some(hint) => keyed.push((hint.order_key, object_source_key(obj)))
      None => {
        fallback_order += 1
        keyed.push(
          (
            "100:999999999:999999999:" +
            pad_int(fallback_order, 5) +
            ":" +
            object_source_key(obj).node_key,
            object_source_key(obj),
          ),
        )
      }
    }
  }
  keyed.sort_by(fn(a, b) { a.0.compare(b.0) })
  let out : Array[PptxSourceKey] = []
  for item in keyed {
    out.push(item.1)
  }
  out
}

///|
fn object_reading_hint(obj : PptxObject) -> PptxReadingOrderHint? {
  match obj {
    Shape(shape) => shape.reading_order
    Picture(pic) => pic.reading_order
    Group(group) => group.reading_order
    _ => None
  }
}

///|
fn object_source_key(obj : PptxObject) -> PptxSourceKey {
  match obj {
    Shape(shape) => shape.source_key
    Group(group) => group.source_key
    Picture(pic) => pic.source_key
    Table(table) => table.source_key
    Chart(chart) => chart.source_key
    SmartArt(smart) => smart.source_key
    Ole(ole) => ole.source_key
    Connector(conn) => conn.source_key
    Unsupported(unsupported) => unsupported.source_key
  }
}

///|
fn collect_media_from_objects(
  out : Array[PptxMediaRef],
  objects : Array[PptxObject],
) -> Unit {
  for obj in objects {
    match obj {
      Picture(pic) =>
        match pic.media {
          Some(media) => out.push(media)
          None => ()
        }
      Group(group) => collect_media_from_objects(out, group.children)
      _ => ()
    }
  }
}
