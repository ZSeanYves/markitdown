///|
fn locate_docx_main_document_part(
  pkg : @ox.OoxmlPackage,
) -> String raise DocxError {
  let rels = @ox.find_relationships_by_type(pkg, "", "/officeDocument") catch {
    e => raise OoxmlFailure(e.to_string())
  }
  if rels.length() > 0 {
    return rels[0].resolved_target
  }

  if @ox.has_part(pkg, "word/document.xml") {
    return "word/document.xml"
  }

  let candidates = @ox.list_parts_by_content_type(
    pkg, "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  ) catch {
    _ => []
  }
  if candidates.length() > 0 {
    candidates[0]
  } else {
    raise MissingMainDocument
  }
}

///|
fn parse_docx_document_metadata(pkg : @ox.OoxmlPackage) -> DocxDocumentMetadata {
  let core = @ox.read_core_properties(pkg)
  let app = @ox.read_app_properties(pkg)
  {
    core: {
      title: core.title,
      subject: core.subject,
      creator: core.creator,
      last_modified_by: core.last_modified_by,
      created: core.created,
      modified: core.modified,
      keywords: core.keywords,
      description: core.description,
      category: core.category,
    },
    app: {
      company: app.company,
      manager: app.manager,
      application: app.application,
      pages: app.pages,
      words: app.words,
      slides: app.slides,
      sheets: app.sheets,
    },
    custom_properties: docx_custom_properties_from_ooxml(
      @ox.read_custom_properties(pkg),
    ),
  }
}

///|
fn empty_docx_document_metadata() -> DocxDocumentMetadata {
  {
    core: {
      title: None,
      subject: None,
      creator: None,
      last_modified_by: None,
      created: None,
      modified: None,
      keywords: None,
      description: None,
      category: None,
    },
    app: {
      company: None,
      manager: None,
      application: None,
      pages: None,
      words: None,
      slides: None,
      sheets: None,
    },
    custom_properties: [],
  }
}

///|
fn docx_custom_properties_from_ooxml(
  props : Array[@ox.OoxmlCustomProperty],
) -> Array[DocxCustomProperty] {
  let out : Array[DocxCustomProperty] = []
  for prop in props {
    out.push({ name: prop.name, value: prop.value, value_type: prop.value_type })
  }
  out
}

///|
fn docx_empty_part_graph(main_part : String) -> DocxPartGraph {
  {
    main_part,
    parts: [
      {
        part_name: main_part,
        kind: MainDocument,
        source: ContentType,
        relationship_id: None,
        source_part: None,
        content_type: None,
      },
    ],
  }
}

///|
fn discover_docx_part_graph(
  pkg : @ox.OoxmlPackage,
  main_part : String,
  relationships : Array[@ox.OoxmlRelationship],
) -> DocxPartGraph {
  let graph = docx_empty_part_graph(main_part)
  docx_discover_relationship_parts(pkg, graph, main_part, relationships)
  docx_discover_content_type_parts(pkg, graph, main_part)
  docx_discover_conventional_parts(pkg, graph, main_part)
  graph
}

///|
fn docx_discover_relationship_parts(
  pkg : @ox.OoxmlPackage,
  graph : DocxPartGraph,
  source_part : String,
  relationships : Array[@ox.OoxmlRelationship],
) -> Unit {
  for rel in relationships {
    if rel.target_mode == External {
      continue
    }
    let kind = docx_discovered_part_kind_from_relationship(rel)
    if kind == Unknown {
      continue
    }
    docx_push_discovered_part(graph, {
      part_name: rel.resolved_target,
      kind,
      source: Relationship,
      relationship_id: Some(rel.id),
      source_part: Some(source_part),
      content_type: docx_lookup_part_content_type(pkg, rel.resolved_target),
    })
  }
}

///|
fn docx_discovered_part_kind_from_relationship(
  rel : @ox.OoxmlRelationship,
) -> DocxDiscoveredPartKind {
  if docx_relationship_type_matches(rel, "footnotes") {
    Footnotes
  } else if docx_relationship_type_matches(rel, "endnotes") {
    Endnotes
  } else if docx_relationship_type_matches(rel, "comments") {
    Comments
  } else if docx_relationship_type_matches(rel, "header") {
    Header
  } else if docx_relationship_type_matches(rel, "footer") {
    Footer
  } else if docx_relationship_type_matches(rel, "numbering") {
    Numbering
  } else if docx_relationship_type_matches(rel, "styles") {
    Styles
  } else if docx_relationship_type_matches(rel, "image") {
    Media
  } else {
    Unknown
  }
}

///|
fn docx_discover_content_type_parts(
  pkg : @ox.OoxmlPackage,
  graph : DocxPartGraph,
  main_part : String,
) -> Unit {
  for part in @ox.list_parts(pkg) {
    match docx_lookup_part_content_type(pkg, part) {
      Some(content_type) => {
        let kind = docx_discovered_part_kind_from_content_type(content_type)
        if kind != Unknown {
          docx_push_discovered_part(graph, {
            part_name: part,
            kind,
            source: ContentType,
            relationship_id: None,
            source_part: if part == main_part {
              None
            } else {
              Some(main_part)
            },
            content_type: Some(content_type),
          })
        }
      }
      None => ()
    }
  }
}

///|
fn docx_discovered_part_kind_from_content_type(
  content_type : String,
) -> DocxDiscoveredPartKind {
  if content_type ==
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml" {
    MainDocument
  } else if content_type ==
    "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml" {
    Footnotes
  } else if content_type ==
    "application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml" {
    Endnotes
  } else if content_type ==
    "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml" {
    Comments
  } else if content_type ==
    "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml" {
    Header
  } else if content_type ==
    "application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml" {
    Footer
  } else if content_type ==
    "application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml" {
    Numbering
  } else if content_type ==
    "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml" {
    Styles
  } else if content_type.has_prefix("image/") {
    Media
  } else {
    Unknown
  }
}

///|
fn docx_discover_conventional_parts(
  pkg : @ox.OoxmlPackage,
  graph : DocxPartGraph,
  main_part : String,
) -> Unit {
  docx_discover_conventional_part(
    pkg,
    graph,
    main_part,
    "word/footnotes.xml",
    Footnotes,
  )
  docx_discover_conventional_part(
    pkg,
    graph,
    main_part,
    "word/endnotes.xml",
    Endnotes,
  )
  docx_discover_conventional_part(
    pkg,
    graph,
    main_part,
    "word/comments.xml",
    Comments,
  )
  docx_discover_conventional_part(
    pkg,
    graph,
    main_part,
    "word/styles.xml",
    Styles,
  )
  docx_discover_conventional_part(
    pkg,
    graph,
    main_part,
    "word/numbering.xml",
    Numbering,
  )
}

///|
fn docx_discover_conventional_part(
  pkg : @ox.OoxmlPackage,
  graph : DocxPartGraph,
  main_part : String,
  part_name : String,
  kind : DocxDiscoveredPartKind,
) -> Unit {
  if !@ox.has_part(pkg, part_name) {
    return
  }
  docx_push_discovered_part(graph, {
    part_name,
    kind,
    source: ConventionalPath,
    relationship_id: None,
    source_part: Some(main_part),
    content_type: docx_lookup_part_content_type(pkg, part_name),
  })
}

///|
fn docx_push_discovered_part(
  graph : DocxPartGraph,
  part : DocxDiscoveredPart,
) -> Unit {
  for existing in graph.parts {
    if existing.part_name == part.part_name && existing.kind == part.kind {
      return
    }
  }
  graph.parts.push(part)
}

///|
fn docx_lookup_part_content_type(
  pkg : @ox.OoxmlPackage,
  part_name : String,
) -> String? {
  @ox.lookup_content_type(pkg, part_name) catch {
    _ => None
  }
}

///|
fn docx_part_graph_parts_by_kind(
  graph : DocxPartGraph,
  kind : DocxDiscoveredPartKind,
) -> Array[DocxDiscoveredPart] {
  let out : Array[DocxDiscoveredPart] = []
  for part in graph.parts {
    if part.kind == kind {
      out.push(part)
    }
  }
  out
}
