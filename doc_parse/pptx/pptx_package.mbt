///|
priv struct PptxSourcePartCache {
  bytes : Bytes?
  text : String?
}

///|
priv struct PptxSourceParseContext {
  pkg : @ox.OoxmlPackage
  part_cache : Map[String, PptxSourcePartCache]
  rel_cache : Map[String, Array[PptxRelationshipV2]]
  warnings : Array[PptxWarning]
  budget : PptxParseBudget
  total_source_nodes : Ref[Int]
  media_ref_count : Ref[Int]
}

///|
fn new_pptx_source_parse_context(
  pkg : @ox.OoxmlPackage,
) -> PptxSourceParseContext {
  let budget = default_pptx_parse_budget()
  touch_pptx_parse_budget(budget)
  {
    pkg,
    part_cache: Map([]),
    rel_cache: Map([]),
    warnings: [],
    budget,
    total_source_nodes: { val: 0 },
    media_ref_count: { val: 0 },
  }
}

///|
fn track_source_node(
  ctx : PptxSourceParseContext,
  part_name : String,
  node_key : String,
) -> Unit {
  ctx.total_source_nodes.val += 1
  if ctx.total_source_nodes.val == ctx.budget.max_total_source_nodes + 1 {
    ctx.warnings.push(
      pptx_warning(
        PptxWarningKind::OverBudget,
        PptxWarningSeverity::Warning,
        part_name,
        node_key,
        None,
        None,
        "pptx source node budget exceeded",
      ),
    )
  }
}

///|
fn push_over_budget_warning(
  ctx : PptxSourceParseContext,
  part_name : String,
  node_key : String,
  relationship_id : String?,
  object_ref : String?,
  message : String,
) -> Unit {
  ctx.warnings.push(
    pptx_warning(
      PptxWarningKind::OverBudget,
      PptxWarningSeverity::Warning,
      part_name,
      node_key,
      relationship_id,
      object_ref,
      message,
    ),
  )
}

///|
fn read_source_part_bytes(
  ctx : PptxSourceParseContext,
  part_name : String,
) -> Bytes? {
  match ctx.part_cache.get(part_name) {
    Some(cached) =>
      match cached.bytes {
        Some(bytes) => return Some(bytes)
        None => ()
      }
    None => ()
  }
  let bytes = @ox.read_part_bytes(ctx.pkg, part_name) catch { _ => return None }
  let text = match ctx.part_cache.get(part_name) {
    Some(cached) => cached.text
    None => None
  }
  ctx.part_cache.set(part_name, { bytes: Some(bytes), text })
  Some(bytes)
}

///|
fn read_source_part_text(
  ctx : PptxSourceParseContext,
  part_name : String,
) -> String? {
  match ctx.part_cache.get(part_name) {
    Some(cached) =>
      match cached.text {
        Some(text) => return Some(text)
        None => ()
      }
    None => ()
  }
  let text = @ox.read_part_text(ctx.pkg, part_name) catch { _ => return None }
  let bytes = match ctx.part_cache.get(part_name) {
    Some(cached) => cached.bytes
    None => None
  }
  ctx.part_cache.set(part_name, { bytes, text: Some(text) })
  Some(text)
}

///|
fn to_pptx_target_mode(mode : @ox.OoxmlTargetMode) -> PptxTargetMode {
  match mode {
    @ox.OoxmlTargetMode::Internal => PptxTargetMode::Internal
    @ox.OoxmlTargetMode::External => PptxTargetMode::External
  }
}

///|
fn to_pptx_relationship(
  source_part : String,
  rel : @ox.OoxmlRelationship,
) -> PptxRelationshipV2 {
  {
    source_part,
    id: rel.id,
    rel_type: rel.rel_type,
    target: rel.target,
    target_mode: to_pptx_target_mode(rel.target_mode),
    resolved_target: rel.resolved_target,
  }
}

///|
fn read_source_relationships(
  ctx : PptxSourceParseContext,
  source_part : String,
) -> Array[PptxRelationshipV2] {
  match ctx.rel_cache.get(source_part) {
    Some(rels) => return rels
    None => ()
  }
  let raw = @ox.read_part_relationships(ctx.pkg, source_part) catch { _ => [] }
  let out : Array[PptxRelationshipV2] = []
  let mut count = 0
  for rel in raw {
    count += 1
    if count > ctx.budget.max_relationships_per_part {
      if count == ctx.budget.max_relationships_per_part + 1 {
        ctx.warnings.push(
          pptx_warning(
            PptxWarningKind::OverBudget,
            PptxWarningSeverity::Warning,
            source_part,
            "rels",
            None,
            None,
            "pptx relationship budget exceeded for part: " + source_part,
          ),
        )
      }
      continue
    }
    out.push(to_pptx_relationship(source_part, rel))
  }
  ctx.rel_cache.set(source_part, out)
  out
}

///|
fn find_source_relationship_by_id(
  ctx : PptxSourceParseContext,
  source_part : String,
  rel_id : String,
) -> PptxRelationshipV2? {
  for rel in read_source_relationships(ctx, source_part) {
    if rel.id == rel_id {
      return Some(rel)
    }
  }
  None
}

///|
fn part_content_type(
  ctx : PptxSourceParseContext,
  part_name : String,
) -> String? {
  @ox.lookup_content_type(ctx.pkg, part_name) catch {
    _ => None
  }
}

///|
fn build_pptx_part_graph(ctx : PptxSourceParseContext) -> PptxPartGraph {
  let parts : Array[PptxPartInfoV2] = []
  for info in @ox.list_part_infos(ctx.pkg) {
    parts.push({
      part_name: info.part_name,
      content_type: info.content_type,
      size: info.size,
      is_relationships_part: info.is_relationships_part,
      has_relationships: info.has_relationships,
    })
  }
  parts.sort_by(fn(a, b) { a.part_name.compare(b.part_name) })

  let relationship_sets : Array[PptxRelationshipSetV2] = []
  for info in parts {
    if info.has_relationships && !info.is_relationships_part {
      relationship_sets.push({
        source_part: info.part_name,
        relationships: read_source_relationships(ctx, info.part_name),
      })
    }
  }

  let root_presentation_part = if @ox.has_part(ctx.pkg, "ppt/presentation.xml") {
    Some("ppt/presentation.xml")
  } else {
    None
  }
  match root_presentation_part {
    None =>
      ctx.warnings.push(
        pptx_warning(
          PptxWarningKind::MissingPresentation,
          PptxWarningSeverity::Error,
          "ppt/presentation.xml",
          "presentation",
          None,
          None,
          "missing ppt/presentation.xml",
        ),
      )
    Some(_) => ()
  }

  {
    parts,
    relationships: relationship_sets,
    root_presentation_part,
    warnings: ctx.warnings.copy(),
  }
}

///|
fn parse_pptx_document_metadata(
  ctx : PptxSourceParseContext,
) -> PptxDocumentMetadata raise {
  let core = @ox.read_core_properties(ctx.pkg)
  let app = @ox.read_app_properties(ctx.pkg)
  {
    title: core.title,
    subject: core.subject,
    creator: core.creator,
    description: core.description,
    keywords: core.keywords,
    created: core.created,
    modified: core.modified,
    application: app.application,
    pages: app.pages,
    words: app.words,
    slides: app.slides,
    sheets: app.sheets,
    custom_properties: parse_custom_properties(ctx),
  }
}

///|
fn parse_custom_properties(
  ctx : PptxSourceParseContext,
) -> Array[PptxCustomProperty] raise {
  let xml = match read_source_part_bytes(ctx, "docProps/custom.xml") {
    Some(bytes) => bytes
    None => return []
  }
  let out : Array[PptxCustomProperty] = []
  let mut pos = 0
  let mut count = 0
  while true {
    let p0 = find_bytes(xml, pat("<property"), pos)
    match p0 {
      None => break
      Some(start) =>
        match slice_full_element(xml, start, "property") {
          Some((block, next_pos)) => {
            count += 1
            if count > ctx.budget.max_custom_properties {
              if count == ctx.budget.max_custom_properties + 1 {
                push_over_budget_warning(
                  ctx,
                  "docProps/custom.xml",
                  "custom-properties",
                  None,
                  None,
                  "pptx custom document property budget exceeded",
                )
              }
              pos = next_pos
              continue
            }
            let name = normalize_optional_attr(
              read_attr_value_in_first_tag_bytes(block, "<property", "name"),
            )
            match name {
              Some(n) => {
                let (value_type, value) = read_custom_property_value(block)
                if value.trim() != "" {
                  out.push({ name: n, value, value_type })
                }
              }
              None => ()
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
fn read_custom_property_value(block : Bytes) -> (String?, String) raise {
  let mut pos = 0
  while pos < block.length() {
    let lt = find_bytes(block, pat("<vt:"), pos)
    match lt {
      None => break
      Some(start) =>
        match read_open_tag_name(block, start) {
          Some(name) => {
            let close_tag = "</" + name + ">"
            let gt = find_bytes(block, pat(">"), start).unwrap_or(-1)
            if gt < 0 {
              return (Some(name), "")
            }
            let end_ = find_bytes(block, pat(close_tag), gt + 1).unwrap_or(-1)
            if end_ < 0 {
              return (Some(name), "")
            }
            return (
              Some(name),
              xml_unescape(bytes_slice_to_string(block, gt + 1, end_))
              .trim()
              .to_owned(),
            )
          }
          None => pos = start + 1
        }
    }
  }
  (None, "")
}

///|
pub fn open_pptx_document(path : String) -> PptxDocument raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise PptxError::OpenFailed(path + ": " + e.to_string())
  }
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise PptxError::OoxmlFailure(e.to_string())
  }
  parse_pptx_document_from_package(pkg)
}

///|
pub fn parse_pptx_document_from_package(
  pkg : @ox.OoxmlPackage,
) -> PptxDocument raise {
  let source = parse_pptx_source(pkg)
  normalize_pptx_source(source)
}

///|
pub fn parse_pptx_source(pkg : @ox.OoxmlPackage) -> PptxSourceDocument raise {
  let ctx = new_pptx_source_parse_context(pkg)
  let part_graph0 = build_pptx_part_graph(ctx)
  let metadata = parse_pptx_document_metadata(ctx)
  let presentation = parse_source_presentation(ctx, part_graph0)
  let layouts = parse_source_layouts(ctx)
  let masters = parse_source_masters(ctx)
  let comment_authors = parse_comment_authors(ctx)
  let slides : Array[PptxSourceSlide] = []
  let mut slide_count = 0
  for slide_ref in presentation.slide_refs {
    slide_count += 1
    if slide_count > ctx.budget.max_slides {
      ctx.warnings.push(
        pptx_warning(
          PptxWarningKind::OverBudget,
          PptxWarningSeverity::Warning,
          slide_ref.part_name,
          slide_ref.source_key.node_key,
          slide_ref.relationship_id,
          None,
          "pptx slide budget exceeded",
        ),
      )
      continue
    }
    slides.push(parse_source_slide(ctx, slide_ref, comment_authors))
  }
  let part_graph : PptxPartGraph = {
    parts: part_graph0.parts,
    relationships: part_graph0.relationships,
    root_presentation_part: part_graph0.root_presentation_part,
    warnings: ctx.warnings.copy(),
  }
  {
    metadata,
    part_graph,
    presentation,
    slides,
    layouts,
    masters,
    comment_authors,
    warnings: ctx.warnings.copy(),
  }
}
