///|
priv struct PptxSourcePartCache {
  bytes : Bytes?
  text : String?
}

///|
priv struct PptxSourceParseContext {
  pkg : @ox.OoxmlPackage
  part_cache : Map[String, PptxSourcePartCache]
  rel_cache : Map[String, Array[PptxRelationship]]
  rel_by_id_cache : Map[String, Map[String, PptxRelationship]]
  warnings : Array[PptxWarning]
  budget : PptxParseBudget
  total_source_nodes : Ref[Int32]
  media_ref_count : Ref[Int32]
  media_bytes_loaded : Ref[Int32]
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
    rel_by_id_cache: Map([]),
    warnings: [],
    budget,
    total_source_nodes: { val: 0, },
    media_ref_count: { val: 0, },
    media_bytes_loaded: { val: 0, },
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
        OverBudget,
        Warning,
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
      OverBudget,
      Warning,
      part_name,
      node_key,
      relationship_id,
      object_ref,
      message,
    ),
  )
}

///|
async fn read_source_part_bytes(
  ctx : PptxSourceParseContext,
  part_name : String,
) -> Bytes? noraise {
  if @dzip.archive_hard_failure(ctx.pkg.archive) is Some(_) {
    return None
  }
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
  ctx.part_cache.set(part_name, { bytes: Some(bytes), text, })
  Some(bytes)
}

///|
async fn read_source_part_text(
  ctx : PptxSourceParseContext,
  part_name : String,
) -> String? noraise {
  if @dzip.archive_hard_failure(ctx.pkg.archive) is Some(_) {
    return None
  }
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
  ctx.part_cache.set(part_name, { bytes, text: Some(text), })
  Some(text)
}

///|
fn to_pptx_target_mode(mode : @ox.OoxmlTargetMode) -> PptxTargetMode {
  match mode {
    Internal => Internal
    External => External
  }
}

///|
fn to_pptx_relationship(
  source_part : String,
  rel : @ox.OoxmlRelationship,
) -> PptxRelationship {
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
async fn read_source_relationships(
  ctx : PptxSourceParseContext,
  source_part : String,
) -> Array[PptxRelationship] noraise {
  if @dzip.archive_hard_failure(ctx.pkg.archive) is Some(_) {
    return []
  }
  match ctx.rel_cache.get(source_part) {
    Some(rels) => return rels
    None => ()
  }
  let raw = @ox.read_part_relationships(ctx.pkg, source_part) catch { _ => [] }
  let out : Array[PptxRelationship] = []
  let by_id : Map[String, PptxRelationship] = Map([])
  let mut count = 0
  for rel in raw {
    count += 1
    if count > ctx.budget.max_relationships_per_part {
      if count == ctx.budget.max_relationships_per_part + 1 {
        ctx.warnings.push(
          pptx_warning(
            OverBudget,
            Warning,
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
    let converted = to_pptx_relationship(source_part, rel)
    out.push(converted)
    if !by_id.contains(converted.id) {
      by_id.set(converted.id, converted)
    }
  }
  ctx.rel_cache.set(source_part, out)
  ctx.rel_by_id_cache.set(source_part, by_id)
  out
}

///|
async fn find_source_relationship_by_id(
  ctx : PptxSourceParseContext,
  source_part : String,
  rel_id : String,
) -> PptxRelationship? noraise {
  match ctx.rel_by_id_cache.get(source_part) {
    Some(by_id) => return by_id.get(rel_id)
    None => ()
  }
  ignore(read_source_relationships(ctx, source_part))
  match ctx.rel_by_id_cache.get(source_part) {
    Some(by_id) => by_id.get(rel_id)
    None => None
  }
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
async fn build_pptx_part_graph(
  ctx : PptxSourceParseContext,
) -> PptxPartGraph noraise {
  let parts : Array[PptxPartInfo] = []
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

  let relationship_sets : Array[PptxRelationshipSet] = []
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
          MissingPresentation,
          Error,
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
async fn parse_pptx_document_metadata(
  ctx : PptxSourceParseContext,
) -> PptxDocumentMetadata {
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
async fn parse_custom_properties(
  ctx : PptxSourceParseContext,
) -> Array[PptxCustomProperty] {
  let projection = @ox.read_custom_properties_projected(
    ctx.pkg,
    max_candidates=ctx.budget.max_custom_properties,
    qualified_value_type=true,
    omit_empty_scalar_values=true,
  )
  if projection.limit_exceeded {
    push_over_budget_warning(
      ctx,
      "docProps/custom.xml",
      "custom-properties",
      None,
      None,
      "pptx custom document property budget exceeded",
    )
  }
  projection.properties.map(property => {
    name: property.name,
    value: property.value,
    value_type: property.value_type,
  })
}

///|
pub async fn open_pptx_document(path : String) -> PptxDocument {
  let session = @input.begin_input_session(@input.input_from_path(path))
  defer @input.end_input_session(session)
  let document = match prepare_pptx_document_from_source(session.source) {
    Ok(prepared) => prepared.document
    Err(message) => raise PptxError::OpenFailed(path + ": " + message)
  }
  if @input.input_session_error(session) is Some(message) {
    raise PptxError::OpenFailed(path + ": " + message)
  }
  document
}

///|
pub async fn parse_pptx_document_from_package(
  pkg : @ox.OoxmlPackage,
) -> PptxDocument {
  let source = parse_pptx_source(pkg)
  let document = normalize_pptx_source(source)
  ensure_pptx_package_integrity(pkg)
  document
}

///|
pub async fn parse_pptx_source(pkg : @ox.OoxmlPackage) -> PptxSourceDocument {
  ensure_pptx_package_integrity(pkg)
  let ctx = new_pptx_source_parse_context(pkg)
  let part_graph0 = build_pptx_part_graph(ctx)
  ensure_pptx_package_integrity(pkg)
  let metadata = parse_pptx_document_metadata(ctx)
  ensure_pptx_package_integrity(pkg)
  let presentation = parse_source_presentation(ctx, part_graph0)
  ensure_pptx_package_integrity(pkg)
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
          OverBudget,
          Warning,
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
  ensure_pptx_package_integrity(pkg)
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

///|
fn ensure_pptx_package_integrity(
  pkg : @ox.OoxmlPackage,
) -> Unit raise PptxError {
  if @dzip.archive_hard_failure(pkg.archive) is Some(message) {
    raise OoxmlFailure(message)
  }
}
