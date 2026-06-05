///|
pub fn parse_docx_source_from_package(
  pkg : @ox.OoxmlPackage,
) -> DocxSourceDocument raise DocxError {
  let main_part = locate_docx_main_document_part(pkg)
  let xml = @ox.read_part_text(pkg, main_part) catch {
    e => raise DocxError::OoxmlFailure(e.to_string())
  }
  let relationships = @ox.read_part_relationships(pkg, main_part) catch {
    e => raise DocxError::OoxmlFailure(e.to_string())
  }
  let warnings : Array[DocxSourceWarning] = []
  let part_graph = discover_docx_part_graph(pkg, main_part, relationships)
  let blocks = parse_docx_body_blocks(
    main_part,
    xml,
    relationships,
    Some(pkg),
    warnings,
  )
  let part : DocxSourcePart = { part_name: main_part, blocks, warnings }
  let styles = parse_docx_styles_from_package(
    pkg, main_part, relationships, blocks, warnings,
  )
  let numbering = parse_docx_numbering_from_package(
    pkg, main_part, relationships, blocks, warnings,
  )
  let textboxes = parse_docx_textboxes_in_part(
    main_part,
    None,
    xml,
    relationships,
    Some(pkg),
    warnings,
  )
  let related_textboxes = parse_docx_textboxes_from_relationships(
    pkg, relationships, warnings,
  )
  for textbox in related_textboxes {
    textboxes.push(textbox)
  }
  {
    main_part,
    part_graph,
    parts: [part],
    styles,
    numbering,
    footnotes: parse_docx_notes_from_part_graph(
      pkg,
      part_graph,
      DocxNoteKind::Footnote,
      warnings,
    ),
    endnotes: parse_docx_notes_from_part_graph(
      pkg,
      part_graph,
      DocxNoteKind::Endnote,
      warnings,
    ),
    comments: parse_docx_comments_from_part_graph(pkg, part_graph, warnings),
    headers: parse_docx_part_bodies_from_relationships(
      pkg,
      relationships,
      DocxPartBodyKind::Header,
      warnings,
    ),
    footers: parse_docx_part_bodies_from_relationships(
      pkg,
      relationships,
      DocxPartBodyKind::Footer,
      warnings,
    ),
    textboxes,
    warnings,
  }
}

///|
fn docx_max_table_nesting_depth() -> Int {
  6
}

///|
pub fn parse_docx_source_document_xml(
  part_name : String,
  xml : String,
) -> DocxSourceDocument raise DocxError {
  let relationships : Array[@ox.OoxmlRelationship] = []
  parse_docx_source_document_xml_with_relationships(
    part_name, xml, relationships,
  )
}

///|
fn parse_docx_source_document_xml_with_relationships(
  part_name : String,
  xml : String,
  relationships : Array[@ox.OoxmlRelationship],
) -> DocxSourceDocument raise DocxError {
  let warnings : Array[DocxSourceWarning] = []
  let blocks = parse_docx_body_blocks(
    part_name,
    xml,
    relationships,
    None,
    warnings,
  )
  let part : DocxSourcePart = { part_name, blocks, warnings }
  {
    main_part: part_name,
    part_graph: docx_empty_part_graph(part_name),
    parts: [part],
    styles: { part_name: None, styles: [] },
    numbering: { part_name: None, nums: [], levels: [] },
    footnotes: [],
    endnotes: [],
    comments: [],
    headers: [],
    footers: [],
    textboxes: parse_docx_textboxes_in_part(
      part_name,
      None,
      xml,
      relationships,
      None,
      warnings,
    ),
    warnings,
  }
}

///|
fn locate_docx_main_document_part(
  pkg : @ox.OoxmlPackage,
) -> String raise DocxError {
  let rels = @ox.find_relationships_by_type(pkg, "", "/officeDocument") catch {
    e => raise DocxError::OoxmlFailure(e.to_string())
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
    raise DocxError::MissingMainDocument
  }
}

///|
fn docx_empty_part_graph(main_part : String) -> DocxPartGraph {
  {
    main_part,
    parts: [
      {
        part_name: main_part,
        kind: DocxDiscoveredPartKind::MainDocument,
        source: DocxPartDiscoverySource::ContentType,
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
    if rel.target_mode == @ox.OoxmlTargetMode::External {
      continue
    }
    let kind = docx_discovered_part_kind_from_relationship(rel)
    if kind == DocxDiscoveredPartKind::Unknown {
      continue
    }
    docx_push_discovered_part(graph, {
      part_name: rel.resolved_target,
      kind,
      source: DocxPartDiscoverySource::Relationship,
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
        if kind != DocxDiscoveredPartKind::Unknown {
          docx_push_discovered_part(graph, {
            part_name: part,
            kind,
            source: DocxPartDiscoverySource::ContentType,
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
    source: DocxPartDiscoverySource::ConventionalPath,
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

///|
fn parse_docx_styles_from_package(
  pkg : @ox.OoxmlPackage,
  main_part : String,
  relationships : Array[@ox.OoxmlRelationship],
  blocks : Array[DocxSourceBlock],
  warnings : Array[DocxSourceWarning],
) -> DocxSourceStyles {
  let part_name = match
    find_docx_relationship_by_type(relationships, "styles") {
    Some(rel) => Some(rel.resolved_target)
    None =>
      if @ox.has_part(pkg, "word/styles.xml") {
        Some("word/styles.xml")
      } else {
        None
      }
  }
  match part_name {
    Some(part) =>
      match
        read_docx_service_part_text(
          pkg,
          part,
          DocxSourceWarningKind::MissingStylesPart,
          "styles part is missing: ",
          warnings,
        ) {
        Some(xml) => parse_docx_styles_part(part, xml)
        None => { part_name: Some(part), styles: [] }
      }
    None => {
      if docx_source_blocks_have_style_refs(blocks) {
        warnings.push({
          kind: DocxSourceWarningKind::MissingStylesPart,
          message: "styles part is missing for referenced style",
          source_key: Some(docx_source_key(main_part, 0, "styles")),
        })
      }
      { part_name: None, styles: [] }
    }
  }
}

///|
fn parse_docx_numbering_from_package(
  pkg : @ox.OoxmlPackage,
  main_part : String,
  relationships : Array[@ox.OoxmlRelationship],
  blocks : Array[DocxSourceBlock],
  warnings : Array[DocxSourceWarning],
) -> DocxSourceNumbering {
  let part_name = match
    find_docx_relationship_by_type(relationships, "numbering") {
    Some(rel) => Some(rel.resolved_target)
    None =>
      if @ox.has_part(pkg, "word/numbering.xml") {
        Some("word/numbering.xml")
      } else {
        None
      }
  }
  match part_name {
    Some(part) =>
      match
        read_docx_service_part_text(
          pkg,
          part,
          DocxSourceWarningKind::MissingNumberingPart,
          "numbering part is missing: ",
          warnings,
        ) {
        Some(xml) => parse_docx_numbering_part(part, xml)
        None => { part_name: Some(part), nums: [], levels: [] }
      }
    None => {
      if docx_source_blocks_have_numbering_refs(blocks) {
        warnings.push({
          kind: DocxSourceWarningKind::MissingNumberingPart,
          message: "numbering part is missing for referenced numbering",
          source_key: Some(docx_source_key(main_part, 0, "numbering")),
        })
      }
      { part_name: None, nums: [], levels: [] }
    }
  }
}

///|
fn find_docx_relationship_by_type(
  relationships : Array[@ox.OoxmlRelationship],
  suffix : String,
) -> @ox.OoxmlRelationship? {
  for rel in relationships {
    if docx_relationship_type_matches(rel, suffix) {
      return Some(rel)
    }
  }
  None
}

///|
fn read_docx_service_part_text(
  pkg : @ox.OoxmlPackage,
  part_name : String,
  warning_kind : DocxSourceWarningKind,
  message_prefix : String,
  warnings : Array[DocxSourceWarning],
) -> String? {
  if !@ox.has_part(pkg, part_name) {
    warnings.push({
      kind: warning_kind,
      message: message_prefix + part_name,
      source_key: Some(docx_source_key(part_name, 0, "missing")),
    })
    return None
  }
  let text = @ox.read_part_text(pkg, part_name) catch {
    e => {
      warnings.push({
        kind: warning_kind,
        message: "failed to read service part: " + e.to_string(),
        source_key: Some(docx_source_key(part_name, 0, "missing")),
      })
      return None
    }
  }
  Some(text)
}

///|
fn parse_docx_styles_part(part_name : String, xml : String) -> DocxSourceStyles {
  let styles : Array[DocxSourceStyle] = []
  let mut i = 0
  let mut style_index = 0
  while i < xml.length() {
    let rel = match xml[i:].find("<w:style") {
      Some(value) => value
      None => break
    }
    let start = i + rel
    if is_docx_start_tag_at(xml, start, "w:style") {
      match find_docx_element_end(xml, start, "w:style") {
        Some(end_exclusive) => {
          let open_tag = docx_open_tag_at(xml, start)
          let style_id = read_docx_attr_value(open_tag, "w:styleId").unwrap_or(
            "",
          )
          if style_id != "" {
            let inner = docx_inner_xml_for_element(
              xml, start, end_exclusive, "w:style",
            )
            styles.push({
              style_id,
              style_type: read_docx_attr_value(open_tag, "w:type"),
              name: read_docx_attr_in_first_tag(inner, "w:name", "w:val"),
              based_on: read_docx_attr_in_first_tag(inner, "w:basedOn", "w:val"),
              paragraph_properties: read_docx_style_paragraph_properties(inner),
              source_key: docx_source_key(part_name, style_index, "style"),
            })
            style_index += 1
          }
          i = end_exclusive
        }
        None => break
      }
    } else {
      i = start + 1
    }
  }
  { part_name: Some(part_name), styles }
}

///|
fn read_docx_style_paragraph_properties(style_inner : String) -> Array[String] {
  let out : Array[String] = []
  match find_docx_start_tag_from(style_inner, 0, "w:pPr") {
    Some(start) =>
      match find_docx_element_end(style_inner, start, "w:pPr") {
        Some(end_exclusive) => {
          let ppr_inner = docx_inner_xml_for_element(
            style_inner, start, end_exclusive, "w:pPr",
          )
          let mut i = 0
          while i < ppr_inner.length() {
            let next_lt_rel = match ppr_inner[i:].find("<") {
              Some(rel) => rel
              None => break
            }
            let child_start = i + next_lt_rel
            if ppr_inner[child_start:].has_prefix("</") {
              match find_docx_any_tag_end(ppr_inner, child_start) {
                Some(child_end) => i = child_end
                None => break
              }
            } else {
              let tag = docx_tag_name_at(ppr_inner, child_start)
              if tag != "" && !docx_string_array_contains(out, tag) {
                out.push(tag)
              }
              match skip_docx_element_or_tag(ppr_inner, child_start, tag) {
                Some(child_end) => i = child_end
                None => break
              }
            }
          }
        }
        None => ()
      }
    None => ()
  }
  out
}

///|
fn docx_string_array_contains(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn parse_docx_numbering_part(
  part_name : String,
  xml : String,
) -> DocxSourceNumbering {
  {
    part_name: Some(part_name),
    nums: parse_docx_numbering_nums(part_name, xml),
    levels: parse_docx_numbering_levels(part_name, xml),
  }
}

///|
fn parse_docx_numbering_nums(
  part_name : String,
  xml : String,
) -> Array[DocxSourceNumberingNum] {
  let nums : Array[DocxSourceNumberingNum] = []
  let mut i = 0
  let mut num_index = 0
  while i < xml.length() {
    let rel = match xml[i:].find("<w:num") {
      Some(value) => value
      None => break
    }
    let start = i + rel
    if is_docx_start_tag_at(xml, start, "w:num") {
      match find_docx_element_end(xml, start, "w:num") {
        Some(end_exclusive) => {
          let open_tag = docx_open_tag_at(xml, start)
          let num_id = read_docx_attr_value(open_tag, "w:numId").unwrap_or("")
          if num_id != "" {
            let inner = docx_inner_xml_for_element(
              xml, start, end_exclusive, "w:num",
            )
            nums.push({
              num_id,
              abstract_num_id: read_docx_attr_in_first_tag(
                inner, "w:abstractNumId", "w:val",
              ),
              start_overrides: parse_docx_numbering_start_overrides(inner),
              source_key: docx_source_key(part_name, num_index, "num"),
            })
            num_index += 1
          }
          i = end_exclusive
        }
        None => break
      }
    } else {
      i = start + 1
    }
  }
  nums
}

///|
fn parse_docx_numbering_start_overrides(
  xml : String,
) -> Array[DocxNumberingStartOverride] {
  let overrides : Array[DocxNumberingStartOverride] = []
  let mut i = 0
  while i < xml.length() {
    let rel = match xml[i:].find("<w:lvlOverride") {
      Some(value) => value
      None => break
    }
    let start = i + rel
    if is_docx_start_tag_at(xml, start, "w:lvlOverride") {
      match find_docx_element_end(xml, start, "w:lvlOverride") {
        Some(end_exclusive) => {
          let open_tag = docx_open_tag_at(xml, start)
          let ilvl = read_docx_attr_value(open_tag, "w:ilvl").unwrap_or("")
          if ilvl != "" {
            let inner = docx_inner_xml_for_element(
              xml, start, end_exclusive, "w:lvlOverride",
            )
            overrides.push({
              ilvl,
              start: read_docx_attr_in_first_tag(
                inner, "w:startOverride", "w:val",
              ),
            })
          }
          i = end_exclusive
        }
        None => break
      }
    } else {
      i = start + 1
    }
  }
  overrides
}

///|
fn parse_docx_numbering_levels(
  part_name : String,
  xml : String,
) -> Array[DocxSourceNumberingLevel] {
  let levels : Array[DocxSourceNumberingLevel] = []
  let mut i = 0
  let mut level_index = 0
  while i < xml.length() {
    let rel = match xml[i:].find("<w:abstractNum") {
      Some(value) => value
      None => break
    }
    let start = i + rel
    if is_docx_start_tag_at(xml, start, "w:abstractNum") {
      match find_docx_element_end(xml, start, "w:abstractNum") {
        Some(end_exclusive) => {
          let open_tag = docx_open_tag_at(xml, start)
          let abstract_num_id = read_docx_attr_value(
            open_tag, "w:abstractNumId",
          ).unwrap_or("")
          if abstract_num_id != "" {
            let inner = docx_inner_xml_for_element(
              xml, start, end_exclusive, "w:abstractNum",
            )
            let abstract_style_link = read_docx_attr_in_first_tag(
              inner, "w:styleLink", "w:val",
            )
            let abstract_num_style_link = read_docx_attr_in_first_tag(
              inner, "w:numStyleLink", "w:val",
            )
            let mut level_inner_index = 0
            let mut j = 0
            while j < inner.length() {
              let level_rel = match inner[j:].find("<w:lvl") {
                Some(value) => value
                None => break
              }
              let level_start = j + level_rel
              if is_docx_start_tag_at(inner, level_start, "w:lvl") {
                match find_docx_element_end(inner, level_start, "w:lvl") {
                  Some(level_end) => {
                    let level_open = docx_open_tag_at(inner, level_start)
                    let ilvl = read_docx_attr_value(level_open, "w:ilvl").unwrap_or(
                      "",
                    )
                    if ilvl != "" {
                      let level_xml = docx_inner_xml_for_element(
                        inner, level_start, level_end, "w:lvl",
                      )
                      levels.push({
                        abstract_num_id,
                        ilvl,
                        num_fmt: read_docx_attr_in_first_tag(
                          level_xml, "w:numFmt", "w:val",
                        ),
                        start: read_docx_attr_in_first_tag(
                          level_xml, "w:start", "w:val",
                        ),
                        lvl_text: read_docx_attr_in_first_tag(
                          level_xml, "w:lvlText", "w:val",
                        ),
                        paragraph_style_id: read_docx_attr_in_first_tag(
                          level_xml, "w:pStyle", "w:val",
                        ),
                        style_link: match
                          read_docx_attr_in_first_tag(
                            level_xml, "w:styleLink", "w:val",
                          ) {
                          Some(value) => Some(value)
                          None => abstract_style_link
                        },
                        num_style_link: match
                          read_docx_attr_in_first_tag(
                            level_xml, "w:numStyleLink", "w:val",
                          ) {
                          Some(value) => Some(value)
                          None => abstract_num_style_link
                        },
                        source_key: docx_source_key(
                          part_name,
                          level_index + level_inner_index,
                          "lvl",
                        ),
                      })
                      level_inner_index += 1
                    }
                    j = level_end
                  }
                  None => break
                }
              } else {
                j = level_start + 1
              }
            }
            level_index += level_inner_index
          }
          i = end_exclusive
        }
        None => break
      }
    } else {
      i = start + 1
    }
  }
  levels
}

///|
fn docx_source_blocks_have_style_refs(blocks : Array[DocxSourceBlock]) -> Bool {
  for block in blocks {
    if block.paragraph_style_id is Some(_) {
      return true
    }
    for run in block.runs {
      if run.style_id is Some(_) {
        return true
      }
    }
    match block.table {
      Some(table) =>
        for row in table.rows {
          for cell in row.cells {
            if docx_source_blocks_have_style_refs(cell.blocks) {
              return true
            }
          }
        }
      None => ()
    }
  }
  false
}

///|
fn docx_source_blocks_have_numbering_refs(
  blocks : Array[DocxSourceBlock],
) -> Bool {
  for block in blocks {
    if block.numbering_ref is Some(_) {
      return true
    }
    match block.table {
      Some(table) =>
        for row in table.rows {
          for cell in row.cells {
            if docx_source_blocks_have_numbering_refs(cell.blocks) {
              return true
            }
          }
        }
      None => ()
    }
  }
  false
}

///|
fn parse_docx_notes_from_part_graph(
  pkg : @ox.OoxmlPackage,
  part_graph : DocxPartGraph,
  kind : DocxNoteKind,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceNote] {
  let out : Array[DocxSourceNote] = []
  let part_kind = match kind {
    DocxNoteKind::Footnote => DocxDiscoveredPartKind::Footnotes
    DocxNoteKind::Endnote => DocxDiscoveredPartKind::Endnotes
  }
  for part in docx_part_graph_parts_by_kind(part_graph, part_kind) {
    match read_docx_discovered_part_text(pkg, part, warnings) {
      Some(xml) => {
        let part_relationships = read_docx_part_relationships_or_empty(
          pkg,
          part.part_name,
        )
        for
          note in parse_docx_notes_part(
            part.part_name,
            xml,
            part_relationships,
            kind,
            Some(pkg),
            warnings,
          ) {
          out.push(note)
        }
      }
      None => ()
    }
  }
  out
}

///|
fn parse_docx_comments_from_part_graph(
  pkg : @ox.OoxmlPackage,
  part_graph : DocxPartGraph,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceComment] {
  let out : Array[DocxSourceComment] = []
  for
    part in docx_part_graph_parts_by_kind(
      part_graph,
      DocxDiscoveredPartKind::Comments,
    ) {
    match read_docx_discovered_part_text(pkg, part, warnings) {
      Some(xml) => {
        let part_relationships = read_docx_part_relationships_or_empty(
          pkg,
          part.part_name,
        )
        for
          comment in parse_docx_comments_part(
            part.part_name,
            xml,
            part_relationships,
            Some(pkg),
            warnings,
          ) {
          out.push(comment)
        }
      }
      None => ()
    }
  }
  out
}

///|
fn parse_docx_part_bodies_from_relationships(
  pkg : @ox.OoxmlPackage,
  relationships : Array[@ox.OoxmlRelationship],
  kind : DocxPartBodyKind,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourcePartBody] {
  let out : Array[DocxSourcePartBody] = []
  let suffix = match kind {
    DocxPartBodyKind::Header => "header"
    DocxPartBodyKind::Footer => "footer"
    DocxPartBodyKind::Textbox => "textbox"
  }
  let root_tag = match kind {
    DocxPartBodyKind::Header => "w:hdr"
    DocxPartBodyKind::Footer => "w:ftr"
    DocxPartBodyKind::Textbox => "w:txbxContent"
  }
  let mut body_index = 0
  for rel in relationships {
    if docx_relationship_type_matches(rel, suffix) {
      match read_docx_related_part_text(pkg, rel, warnings) {
        Some(xml) => {
          let part_relationships = read_docx_part_relationships_or_empty(
            pkg,
            rel.resolved_target,
          )
          match docx_first_element_inner(xml, root_tag) {
            Some(inner) => {
              let key = docx_source_key(rel.resolved_target, body_index, suffix)
              out.push({
                kind,
                relationship_id: Some(rel.id),
                part_name: rel.resolved_target,
                blocks: parse_docx_body_inner(
                  rel.resolved_target,
                  inner,
                  part_relationships,
                  Some(pkg),
                  warnings,
                ),
                source_key: key,
              })
              body_index += 1
            }
            None => ()
          }
        }
        None => ()
      }
    }
  }
  out
}

///|
fn parse_docx_textboxes_from_relationships(
  pkg : @ox.OoxmlPackage,
  relationships : Array[@ox.OoxmlRelationship],
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceTextBox] {
  let out : Array[DocxSourceTextBox] = []
  for rel in relationships {
    if docx_relationship_type_matches(rel, "header") ||
      docx_relationship_type_matches(rel, "footer") {
      match read_docx_related_part_text(pkg, rel, warnings) {
        Some(xml) => {
          let part_relationships = read_docx_part_relationships_or_empty(
            pkg,
            rel.resolved_target,
          )
          for
            textbox in parse_docx_textboxes_in_part(
              rel.resolved_target,
              Some(rel.id),
              xml,
              part_relationships,
              Some(pkg),
              warnings,
            ) {
            out.push(textbox)
          }
        }
        None => ()
      }
    }
  }
  out
}

///|
fn parse_docx_notes_part(
  part_name : String,
  xml : String,
  relationships : Array[@ox.OoxmlRelationship],
  kind : DocxNoteKind,
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceNote] {
  let out : Array[DocxSourceNote] = []
  let tag = match kind {
    DocxNoteKind::Footnote => "w:footnote"
    DocxNoteKind::Endnote => "w:endnote"
  }
  let mut i = 0
  let mut note_index = 0
  while i < xml.length() {
    let rel = match xml[i:].find("<" + tag) {
      Some(value) => value
      None => break
    }
    let start = i + rel
    if is_docx_start_tag_at(xml, start, tag) {
      match find_docx_element_end(xml, start, tag) {
        Some(end_exclusive) => {
          let open_tag = docx_open_tag_at(xml, start)
          let note_id = read_docx_attr_value(open_tag, "w:id").unwrap_or("")
          let key = docx_source_key(part_name, note_index, tag)
          out.push({
            kind,
            note_id,
            part_name,
            blocks: parse_docx_body_inner(
              part_name,
              docx_inner_xml_for_element(xml, start, end_exclusive, tag),
              relationships,
              pkg,
              warnings,
            ),
            source_key: key,
          })
          note_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else {
      i = start + 1
    }
  }
  out
}

///|
fn parse_docx_comments_part(
  part_name : String,
  xml : String,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceComment] {
  let out : Array[DocxSourceComment] = []
  let mut i = 0
  let mut comment_index = 0
  while i < xml.length() {
    let rel = match xml[i:].find("<w:comment") {
      Some(value) => value
      None => break
    }
    let start = i + rel
    if is_docx_start_tag_at(xml, start, "w:comment") {
      match find_docx_element_end(xml, start, "w:comment") {
        Some(end_exclusive) => {
          let open_tag = docx_open_tag_at(xml, start)
          let comment_id = read_docx_attr_value(open_tag, "w:id").unwrap_or("")
          let key = docx_source_key(part_name, comment_index, "comment")
          out.push({
            comment_id,
            author: read_docx_attr_value(open_tag, "w:author"),
            date: read_docx_attr_value(open_tag, "w:date"),
            part_name,
            blocks: parse_docx_body_inner(
              part_name,
              docx_inner_xml_for_element(xml, start, end_exclusive, "w:comment"),
              relationships,
              pkg,
              warnings,
            ),
            source_key: key,
          })
          comment_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else {
      i = start + 1
    }
  }
  out
}

///|
fn parse_docx_textboxes_in_part(
  part_name : String,
  relationship_id : String?,
  xml : String,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceTextBox] {
  let out : Array[DocxSourceTextBox] = []
  let mut i = 0
  let mut textbox_index = 0
  while i < xml.length() {
    let rel = match xml[i:].find("<w:txbxContent") {
      Some(value) => value
      None => break
    }
    let start = i + rel
    if is_docx_start_tag_at(xml, start, "w:txbxContent") {
      match find_docx_element_end(xml, start, "w:txbxContent") {
        Some(end_exclusive) => {
          let key = docx_source_key(
            part_name,
            docx_textbox_owner_block_index(xml, start, textbox_index),
            "textbox",
          )
          let anchor_id = docx_textbox_anchor_id(part_name, textbox_index)
          let virtual_part = part_name + "#textbox:" + textbox_index.to_string()
          let anchor_xml = docx_textbox_anchor_xml(xml, start, end_exclusive)
          out.push({
            anchor_id,
            owner_part: part_name,
            relationship_id,
            part_name: virtual_part,
            blocks: parse_docx_body_inner(
              virtual_part,
              docx_inner_xml_for_element(
                xml, start, end_exclusive, "w:txbxContent",
              ),
              relationships,
              pkg,
              warnings,
            ),
            source_key: key,
            shape_id: read_docx_non_empty_attr_in_first_tag(
              anchor_xml, "v:shape", "id",
            ),
            doc_pr_id: read_docx_non_empty_attr_in_first_tag(
              anchor_xml, "wp:docPr", "id",
            ),
            doc_pr_name: read_docx_non_empty_attr_in_first_tag(
              anchor_xml, "wp:docPr", "name",
            ),
            descr: read_docx_non_empty_attr_in_first_tag(
              anchor_xml, "wp:docPr", "descr",
            ),
            title: docx_textbox_anchor_title(anchor_xml),
          })
          textbox_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else {
      i = start + 1
    }
  }
  out
}

///|
fn docx_textbox_anchor_id(part_name : String, index : Int) -> String {
  part_name + "#textbox:" + index.to_string()
}

///|
fn docx_textbox_owner_block_index(
  xml : String,
  start : Int,
  default_index : Int,
) -> Int {
  let paragraph_count = docx_count_start_tags_before(xml, start, "w:p")
  if paragraph_count > 0 {
    paragraph_count - 1
  } else {
    default_index
  }
}

///|
fn docx_count_start_tags_before(xml : String, end : Int, tag : String) -> Int {
  let mut count = 0
  let mut i = 0
  while i < end {
    match find_docx_start_tag_from(xml, i, tag) {
      Some(start) =>
        if start < end {
          count += 1
          i = start + 1
        } else {
          break
        }
      None => break
    }
  }
  count
}

///|
fn docx_textbox_anchor_title(anchor_xml : String) -> String? {
  match read_docx_non_empty_attr_in_first_tag(anchor_xml, "wp:docPr", "title") {
    Some(value) => Some(value)
    None =>
      match
        read_docx_non_empty_attr_in_first_tag(anchor_xml, "v:shape", "title") {
        Some(value) => Some(value)
        None =>
          read_docx_non_empty_attr_in_first_tag(anchor_xml, "v:shape", "alt")
      }
  }
}

///|
fn docx_textbox_anchor_xml(
  xml : String,
  start : Int,
  end_exclusive : Int,
) -> String {
  let mut anchor_start = start
  let mut anchor_end = end_exclusive
  match find_docx_enclosing_element(xml, start, "w:drawing") {
    Some((s, e)) => {
      anchor_start = s
      anchor_end = e
    }
    None => ()
  }
  match find_docx_enclosing_element(xml, start, "w:pict") {
    Some((s, e)) =>
      if anchor_start == start || s >= anchor_start {
        anchor_start = s
        anchor_end = e
      }
    None => ()
  }
  xml[anchor_start:anchor_end].to_owned()
}

///|
fn find_docx_enclosing_element(
  xml : String,
  pos : Int,
  tag : String,
) -> (Int, Int)? {
  let mut i = 0
  let mut out : (Int, Int)? = None
  while i < pos {
    match find_docx_start_tag_from(xml, i, tag) {
      Some(start) => {
        if start > pos {
          break
        }
        match find_docx_element_end(xml, start, tag) {
          Some(end_exclusive) =>
            if end_exclusive >= pos {
              out = Some((start, end_exclusive))
            }
          None => ()
        }
        i = start + 1
      }
      None => break
    }
  }
  out
}

///|
fn docx_relationship_type_matches(
  rel : @ox.OoxmlRelationship,
  suffix : String,
) -> Bool {
  rel.rel_type == suffix || rel.rel_type.has_suffix("/" + suffix)
}

///|
fn read_docx_related_part_text(
  pkg : @ox.OoxmlPackage,
  rel : @ox.OoxmlRelationship,
  warnings : Array[DocxSourceWarning],
) -> String? {
  if !@ox.has_part(pkg, rel.resolved_target) {
    warnings.push({
      kind: DocxSourceWarningKind::MissingContainerPart,
      message: "related DOCX part is missing: " + rel.resolved_target,
      source_key: Some(docx_source_key(rel.resolved_target, 0, "missing")),
    })
    return None
  }
  let text = @ox.read_part_text(pkg, rel.resolved_target) catch {
    e => {
      warnings.push({
        kind: DocxSourceWarningKind::MissingContainerPart,
        message: "failed to read related DOCX part: " + e.to_string(),
        source_key: Some(docx_source_key(rel.resolved_target, 0, "missing")),
      })
      return None
    }
  }
  Some(text)
}

///|
fn read_docx_discovered_part_text(
  pkg : @ox.OoxmlPackage,
  part : DocxDiscoveredPart,
  warnings : Array[DocxSourceWarning],
) -> String? {
  if !@ox.has_part(pkg, part.part_name) {
    warnings.push({
      kind: DocxSourceWarningKind::MissingContainerPart,
      message: "discovered DOCX part is missing: " + part.part_name,
      source_key: Some(docx_source_key(part.part_name, 0, "missing")),
    })
    return None
  }
  let text = @ox.read_part_text(pkg, part.part_name) catch {
    e => {
      warnings.push({
        kind: DocxSourceWarningKind::MissingContainerPart,
        message: "failed to read discovered DOCX part: " + e.to_string(),
        source_key: Some(docx_source_key(part.part_name, 0, "missing")),
      })
      return None
    }
  }
  Some(text)
}

///|
fn read_docx_part_relationships_or_empty(
  pkg : @ox.OoxmlPackage,
  part_name : String,
) -> Array[@ox.OoxmlRelationship] {
  @ox.read_part_relationships(pkg, part_name) catch {
    _ => []
  }
}

///|
fn docx_first_element_inner(xml : String, tag : String) -> String? {
  match find_docx_start_tag_from(xml, 0, tag) {
    Some(start) =>
      match find_docx_element_end(xml, start, tag) {
        Some(end_exclusive) =>
          Some(docx_inner_xml_for_element(xml, start, end_exclusive, tag))
        None => None
      }
    None => None
  }
}

///|
fn parse_docx_body_blocks(
  part_name : String,
  xml : String,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceBlock] raise DocxError {
  let body_start = match xml.find("<w:body") {
    Some(pos) => pos
    None => raise DocxError::MalformedDocument("missing <w:body>")
  }
  let body_open_end = match xml[body_start:].find(">") {
    Some(rel) => rel
    None => raise DocxError::MalformedDocument("invalid <w:body> tag")
  }
  let body_content_start = body_start + body_open_end + 1
  let body_close_rel = match xml[body_content_start:].find("</w:body>") {
    Some(rel) => rel
    None => raise DocxError::MalformedDocument("missing </w:body>")
  }
  let body = xml[body_content_start:body_content_start + body_close_rel].to_owned()
  parse_docx_body_inner(part_name, body, relationships, pkg, warnings)
}

///|
fn parse_docx_body_inner(
  part_name : String,
  body : String,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceBlock] {
  let blocks : Array[DocxSourceBlock] = []
  let mut i = 0
  let mut block_index = 0

  while i < body.length() {
    let next_lt_rel = match body[i:].find("<") {
      Some(rel) => rel
      None => break
    }
    let start = i + next_lt_rel
    if is_docx_start_tag_at(body, start, "w:p") {
      match find_docx_element_end(body, start, "w:p") {
        Some(end_exclusive) => {
          let inner = docx_inner_xml_for_element(
            body, start, end_exclusive, "w:p",
          )
          let key = docx_source_key(part_name, block_index, "p")
          let paragraph_style_id = read_docx_paragraph_style_id(inner)
          let paragraph_alignment = read_docx_paragraph_alignment(inner)
          let numbering_ref = read_docx_numbering_ref(inner)
          let runs = parse_docx_paragraph_runs(
            inner, key, relationships, pkg, warnings,
          )
          let inlines = docx_source_run_inlines(runs)
          blocks.push({
            kind: DocxSourceBlockKind::Paragraph,
            source_key: key,
            paragraph_style_id,
            paragraph_alignment,
            numbering_ref,
            runs,
            table: None,
            content_control: None,
            text: docx_source_inline_text(inlines),
            inlines,
            structural_kind: None,
            raw_tag: Some("w:p"),
          })
          block_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(body, start, "w:tbl") {
      match find_docx_element_end(body, start, "w:tbl") {
        Some(end_exclusive) => {
          let key = docx_source_key(part_name, block_index, "tbl")
          let table_xml = body[start:end_exclusive].to_owned()
          let table = parse_docx_table(
            table_xml, key, 0, relationships, pkg, warnings,
          )
          let table_text = docx_source_table_text(table)
          blocks.push({
            kind: DocxSourceBlockKind::Table,
            source_key: key,
            paragraph_style_id: None,
            paragraph_alignment: None,
            numbering_ref: None,
            runs: [],
            table: Some(table),
            content_control: None,
            text: table_text,
            inlines: [],
            structural_kind: None,
            raw_tag: Some("w:tbl"),
          })
          block_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(body, start, "w:sdt") {
      match find_docx_element_end(body, start, "w:sdt") {
        Some(end_exclusive) => {
          let key = docx_source_key(part_name, block_index, "sdt")
          blocks.push(
            docx_content_control_source_block(
              "w:sdt",
              key,
              docx_content_control_body_xml(
                body[start:end_exclusive].to_owned(),
                "w:sdt",
              ),
              relationships,
              pkg,
              warnings,
            ),
          )
          block_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if docx_structural_block_kind(body, start) is Some(_) {
      match parse_docx_structural_block(part_name, block_index, body, start) {
        Some((block, end_exclusive)) => {
          blocks.push(block)
          block_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(body, start, "w:sectPr") {
      match find_docx_element_end(body, start, "w:sectPr") {
        Some(end_exclusive) => {
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if body[start:].has_prefix("</") {
      match find_docx_any_tag_end(body, start) {
        Some(end_exclusive) => {
          i = end_exclusive
          continue
        }
        None => break
      }
    } else {
      let tag = docx_tag_name_at(body, start)
      let key = docx_source_key(part_name, block_index, "unknown")
      warnings.push({
        kind: DocxSourceWarningKind::UnknownBodyNode,
        message: "unsupported body node: " + tag,
        source_key: Some(key),
      })
      blocks.push({
        kind: DocxSourceBlockKind::Unknown,
        source_key: key,
        paragraph_style_id: None,
        paragraph_alignment: None,
        numbering_ref: None,
        runs: [],
        table: None,
        content_control: None,
        text: "",
        inlines: [],
        structural_kind: None,
        raw_tag: Some(tag),
      })
      block_index += 1
      match find_docx_element_end(body, start, tag) {
        Some(end_exclusive) => i = end_exclusive
        None =>
          match find_docx_any_tag_end(body, start) {
            Some(end_exclusive) => i = end_exclusive
            None => break
          }
      }
    }
  }

  blocks
}

///|
fn parse_docx_table(
  xml : String,
  table_key : DocxSourceKey,
  nesting_depth : Int,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceTable {
  let inner = docx_inner_xml_for_element(xml, 0, xml.length(), "w:tbl")
  let rows : Array[DocxSourceTableRow] = []
  let max_depth_seen : Ref[Int] = { val: nesting_depth }
  let guard_triggered : Ref[Bool] = { val: false }
  let mut i = 0
  let mut row_index = 0
  while i < inner.length() {
    let next_lt_rel = match inner[i:].find("<") {
      Some(rel) => rel
      None => break
    }
    let start = i + next_lt_rel
    if is_docx_start_tag_at(inner, start, "w:tr") {
      match find_docx_element_end(inner, start, "w:tr") {
        Some(end_exclusive) => {
          let row_xml = inner[start:end_exclusive].to_owned()
          let row_key = docx_child_source_key(table_key, "row", row_index)
          rows.push(
            parse_docx_table_row(
              row_xml, row_index, row_key, nesting_depth, max_depth_seen, guard_triggered,
              relationships, pkg, warnings,
            ),
          )
          row_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    }
    match find_docx_any_tag_end(inner, start) {
      Some(end_exclusive) => i = end_exclusive
      None => break
    }
  }
  {
    rows,
    nesting_depth,
    max_nested_depth: max_depth_seen.val,
    deep_table_guard_triggered: guard_triggered.val,
    source_key: table_key,
  }
}

///|
fn docx_structural_block_kind(xml : String, start : Int) -> DocxStructuralKind? {
  if is_docx_start_tag_at(xml, start, "w:sectPr") {
    Some(DocxStructuralKind::SectionProperties)
  } else if is_docx_start_tag_at(xml, start, "w:bookmarkStart") ||
    is_docx_start_tag_at(xml, start, "w:bookmarkEnd") {
    Some(DocxStructuralKind::BookmarkBoundary)
  } else if is_docx_start_tag_at(xml, start, "w:proofErr") {
    Some(DocxStructuralKind::ProofError)
  } else if is_docx_start_tag_at(xml, start, "w:permStart") ||
    is_docx_start_tag_at(xml, start, "w:permEnd") {
    Some(DocxStructuralKind::PermissionBoundary)
  } else if is_docx_start_tag_at(xml, start, "w:commentRangeStart") ||
    is_docx_start_tag_at(xml, start, "w:commentRangeEnd") {
    Some(DocxStructuralKind::CommentRangeBoundary)
  } else if is_docx_start_tag_at(xml, start, "w:moveFromRangeStart") ||
    is_docx_start_tag_at(xml, start, "w:moveFromRangeEnd") ||
    is_docx_start_tag_at(xml, start, "w:moveToRangeStart") ||
    is_docx_start_tag_at(xml, start, "w:moveToRangeEnd") {
    Some(DocxStructuralKind::MoveRangeBoundary)
  } else if is_docx_start_tag_at(xml, start, "w:lastRenderedPageBreak") {
    Some(DocxStructuralKind::LastRenderedPageBreak)
  } else {
    None
  }
}

///|
fn parse_docx_structural_block(
  part_name : String,
  block_index : Int,
  xml : String,
  start : Int,
) -> (DocxSourceBlock, Int)? {
  let tag = docx_tag_name_at(xml, start)
  if tag == "" {
    return None
  }
  let kind = match docx_structural_block_kind(xml, start) {
    Some(value) => value
    None => return None
  }
  let end_exclusive = match docx_structural_end_exclusive(xml, start, tag) {
    Some(value) => value
    None => return None
  }
  let key = docx_source_key(part_name, block_index, "structural")
  Some((docx_structural_source_block(key, kind, tag), end_exclusive))
}

///|
fn parse_docx_structural_child_block(
  parent_key : DocxSourceKey,
  block_index : Int,
  xml : String,
  start : Int,
) -> (DocxSourceBlock, Int)? {
  let tag = docx_tag_name_at(xml, start)
  if tag == "" {
    return None
  }
  let kind = match docx_structural_block_kind(xml, start) {
    Some(value) => value
    None => return None
  }
  let end_exclusive = match docx_structural_end_exclusive(xml, start, tag) {
    Some(value) => value
    None => return None
  }
  let key = docx_child_source_key(parent_key, "structural", block_index)
  Some((docx_structural_source_block(key, kind, tag), end_exclusive))
}

///|
fn docx_structural_end_exclusive(
  xml : String,
  start : Int,
  tag : String,
) -> Int? {
  if tag == "w:sectPr" {
    match find_docx_element_end(xml, start, tag) {
      Some(value) => Some(value)
      None => find_docx_any_tag_end(xml, start)
    }
  } else {
    find_docx_any_tag_end(xml, start)
  }
}

///|
fn docx_structural_source_block(
  key : DocxSourceKey,
  structural_kind : DocxStructuralKind,
  tag : String,
) -> DocxSourceBlock {
  {
    kind: DocxSourceBlockKind::Structural,
    source_key: key,
    paragraph_style_id: None,
    paragraph_alignment: None,
    numbering_ref: None,
    runs: [],
    table: None,
    content_control: None,
    text: "",
    inlines: [],
    structural_kind: Some(structural_kind),
    raw_tag: Some(tag),
  }
}

///|
fn parse_docx_structural_inline(
  xml : String,
  start : Int,
  source_key : DocxSourceKey,
) -> (DocxSourceInline, Int)? {
  let tag = docx_tag_name_at(xml, start)
  if tag == "" {
    return None
  }
  let kind = match docx_structural_block_kind(xml, start) {
    Some(value) => value
    None => return None
  }
  let end_exclusive = match docx_structural_end_exclusive(xml, start, tag) {
    Some(value) => value
    None => return None
  }
  Some(
    (
      DocxSourceInline::StructuralMarker({ kind, tag, source_key }),
      end_exclusive,
    ),
  )
}

///|
fn parse_docx_table_row(
  xml : String,
  row_index : Int,
  row_key : DocxSourceKey,
  nesting_depth : Int,
  max_depth_seen : Ref[Int],
  guard_triggered : Ref[Bool],
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceTableRow {
  let inner = docx_inner_xml_for_element(xml, 0, xml.length(), "w:tr")
  let cells : Array[DocxSourceTableCell] = []
  let mut i = 0
  let mut cell_index = 0
  while i < inner.length() {
    let next_lt_rel = match inner[i:].find("<") {
      Some(rel) => rel
      None => break
    }
    let start = i + next_lt_rel
    if is_docx_start_tag_at(inner, start, "w:tc") {
      match find_docx_element_end(inner, start, "w:tc") {
        Some(end_exclusive) => {
          let cell_xml = inner[start:end_exclusive].to_owned()
          let cell_key = docx_child_source_key(row_key, "cell", cell_index)
          cells.push(
            parse_docx_table_cell(
              cell_xml, row_index, cell_index, cell_key, nesting_depth, max_depth_seen,
              guard_triggered, relationships, pkg, warnings,
            ),
          )
          cell_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    }
    match find_docx_any_tag_end(inner, start) {
      Some(end_exclusive) => i = end_exclusive
      None => break
    }
  }
  {
    row_index,
    is_header: read_docx_table_row_is_header(inner),
    cells,
    source_key: row_key,
  }
}

///|
fn read_docx_table_row_is_header(row_inner : String) -> Bool {
  match row_inner.find("<w:trPr") {
    Some(start) =>
      match find_docx_element_end(row_inner, start, "w:trPr") {
        Some(end_exclusive) =>
          row_inner[start:end_exclusive].contains("<w:tblHeader")
        None => row_inner[start:].contains("<w:tblHeader")
      }
    None => false
  }
}

///|
fn parse_docx_table_cell(
  xml : String,
  row_index : Int,
  cell_index : Int,
  cell_key : DocxSourceKey,
  nesting_depth : Int,
  max_depth_seen : Ref[Int],
  guard_triggered : Ref[Bool],
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceTableCell {
  let inner = docx_inner_xml_for_element(xml, 0, xml.length(), "w:tc")
  let blocks = parse_docx_table_cell_blocks(
    inner, cell_key, nesting_depth, max_depth_seen, guard_triggered, relationships,
    pkg, warnings,
  )
  let text = docx_source_blocks_text(blocks)
  let has_nested_table = docx_source_blocks_have_table(blocks)
  let max_nested_depth = docx_source_blocks_max_table_depth(
    blocks, nesting_depth,
  )
  if max_nested_depth > max_depth_seen.val {
    max_depth_seen.val = max_nested_depth
  }
  {
    row_index,
    cell_index,
    blocks,
    text,
    grid_span: read_docx_cell_grid_span(inner),
    vertical_merge: read_docx_cell_vertical_merge(inner),
    has_nested_table,
    nesting_depth,
    max_nested_depth,
    deep_table_guard_triggered: docx_source_blocks_have_table_guard(blocks),
    source_key: cell_key,
  }
}

///|
fn parse_docx_table_cell_blocks(
  xml : String,
  cell_key : DocxSourceKey,
  nesting_depth : Int,
  max_depth_seen : Ref[Int],
  guard_triggered : Ref[Bool],
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceBlock] {
  let blocks : Array[DocxSourceBlock] = []
  let mut i = 0
  let mut block_index = 0
  while i < xml.length() {
    let next_lt_rel = match xml[i:].find("<") {
      Some(rel) => rel
      None => break
    }
    let start = i + next_lt_rel
    if is_docx_start_tag_at(xml, start, "w:tcPr") {
      match skip_docx_element_or_tag(xml, start, "w:tcPr") {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if docx_structural_block_kind(xml, start) is Some(_) {
      match
        parse_docx_structural_child_block(cell_key, block_index, xml, start) {
        Some((block, end_exclusive)) => {
          blocks.push(block)
          block_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:p") {
      match find_docx_element_end(xml, start, "w:p") {
        Some(end_exclusive) => {
          let inner = docx_inner_xml_for_element(
            xml, start, end_exclusive, "w:p",
          )
          let key = docx_child_source_key(cell_key, "p", block_index)
          let runs = parse_docx_paragraph_runs(
            inner, key, relationships, pkg, warnings,
          )
          let inlines = docx_source_run_inlines(runs)
          blocks.push({
            kind: DocxSourceBlockKind::Paragraph,
            source_key: key,
            paragraph_style_id: read_docx_paragraph_style_id(inner),
            paragraph_alignment: read_docx_paragraph_alignment(inner),
            numbering_ref: read_docx_numbering_ref(inner),
            runs,
            table: None,
            content_control: None,
            text: docx_source_inline_text(inlines),
            inlines,
            structural_kind: None,
            raw_tag: Some("w:p"),
          })
          block_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:tbl") {
      match find_docx_element_end(xml, start, "w:tbl") {
        Some(end_exclusive) => {
          let key = docx_child_source_key(cell_key, "tbl", block_index)
          let next_depth = nesting_depth + 1
          let guard_hit = next_depth > docx_max_table_nesting_depth()
          if next_depth > max_depth_seen.val {
            max_depth_seen.val = next_depth
          }
          if guard_hit {
            guard_triggered.val = true
            warnings.push({
              kind: DocxSourceWarningKind::NestedTable,
              message: "nested table depth guard triggered at depth " +
              next_depth.to_string(),
              source_key: Some(key),
            })
          }
          let table = if guard_hit {
            None
          } else {
            Some(
              parse_docx_table(
                xml[start:end_exclusive].to_owned(),
                key,
                next_depth,
                relationships,
                pkg,
                warnings,
              ),
            )
          }
          match table {
            Some(value) => {
              if value.max_nested_depth > max_depth_seen.val {
                max_depth_seen.val = value.max_nested_depth
              }
              if value.deep_table_guard_triggered {
                guard_triggered.val = true
              }
            }
            None => ()
          }
          blocks.push({
            kind: DocxSourceBlockKind::Table,
            source_key: key,
            paragraph_style_id: None,
            paragraph_alignment: None,
            numbering_ref: None,
            runs: [],
            table,
            content_control: None,
            text: match table {
              Some(value) => docx_source_table_text(value)
              None => ""
            },
            inlines: [],
            structural_kind: None,
            raw_tag: Some("w:tbl"),
          })
          block_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:sdt") {
      match find_docx_element_end(xml, start, "w:sdt") {
        Some(end_exclusive) => {
          let key = docx_child_source_key(cell_key, "sdt", block_index)
          blocks.push(
            docx_content_control_source_block(
              "w:sdt",
              key,
              docx_content_control_body_xml(
                xml[start:end_exclusive].to_owned(),
                "w:sdt",
              ),
              relationships,
              pkg,
              warnings,
            ),
          )
          block_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if xml[start:].has_prefix("</") {
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else {
      let tag = docx_tag_name_at(xml, start)
      let key = docx_child_source_key(cell_key, "unknown", block_index)
      warnings.push({
        kind: DocxSourceWarningKind::UnknownBodyNode,
        message: "unsupported table cell node: " + tag,
        source_key: Some(key),
      })
      blocks.push({
        kind: DocxSourceBlockKind::Unknown,
        source_key: key,
        paragraph_style_id: None,
        paragraph_alignment: None,
        numbering_ref: None,
        runs: [],
        table: None,
        content_control: None,
        text: "",
        inlines: [],
        structural_kind: None,
        raw_tag: Some(tag),
      })
      block_index += 1
      match skip_docx_element_or_tag(xml, start, tag) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    }
  }
  blocks
}

///|
fn parse_docx_paragraph_runs(
  xml : String,
  paragraph_key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceRun] {
  let runs : Array[DocxSourceRun] = []
  let mut i = 0
  let mut run_index = 0
  while i < xml.length() {
    let next_lt_rel = match xml[i:].find("<") {
      Some(rel) => rel
      None => break
    }
    let start = i + next_lt_rel
    if is_docx_start_tag_at(xml, start, "w:pPr") {
      match skip_docx_element_or_tag(xml, start, "w:pPr") {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:r") {
      match find_docx_element_end(xml, start, "w:r") {
        Some(end_exclusive) => {
          let inner = docx_inner_xml_for_element(
            xml, start, end_exclusive, "w:r",
          )
          let run_key = docx_child_source_key(paragraph_key, "r", run_index)
          let run_inlines = parse_docx_run_inlines(
            inner, run_key, relationships, pkg, warnings,
          )
          if run_inlines.length() > 0 {
            runs.push({
              style_id: read_docx_run_style_id(inner),
              bold: read_docx_run_is_bold(inner),
              inlines: run_inlines,
              source_key: run_key,
            })
          }
          run_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:hyperlink") {
      match find_docx_element_end(xml, start, "w:hyperlink") {
        Some(end_exclusive) => {
          let link_key = docx_child_source_key(
            paragraph_key, "hyperlink", run_index,
          )
          let link = parse_docx_hyperlink(
            xml, start, end_exclusive, link_key, relationships, warnings,
          )
          runs.push({
            style_id: None,
            bold: false,
            inlines: [DocxSourceInline::Hyperlink(link)],
            source_key: link_key,
          })
          run_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:fldSimple") {
      match find_docx_element_end(xml, start, "w:fldSimple") {
        Some(end_exclusive) => {
          let field_key = docx_child_source_key(
            paragraph_key, "field", run_index,
          )
          let field = parse_docx_fld_simple(
            xml, start, end_exclusive, field_key, relationships, pkg, warnings,
          )
          runs.push({
            style_id: None,
            bold: false,
            inlines: [field],
            source_key: field_key,
          })
          run_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:sdt") {
      match find_docx_element_end(xml, start, "w:sdt") {
        Some(end_exclusive) => {
          let sdt_key = docx_child_source_key(paragraph_key, "sdt", run_index)
          runs.push({
            style_id: None,
            bold: false,
            inlines: [
              DocxSourceInline::ContentControl(
                parse_docx_inline_content_control(
                  xml, start, end_exclusive, "w:sdt", sdt_key, relationships, pkg,
                  warnings,
                ),
              ),
            ],
            source_key: sdt_key,
          })
          run_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:smartTag") {
      match find_docx_element_end(xml, start, "w:smartTag") {
        Some(end_exclusive) => {
          let smart_key = docx_child_source_key(
            paragraph_key, "smartTag", run_index,
          )
          runs.push({
            style_id: None,
            bold: false,
            inlines: [
              DocxSourceInline::SmartTag(
                parse_docx_smart_tag_inline(
                  xml, start, end_exclusive, smart_key, relationships, pkg, warnings,
                ),
              ),
            ],
            source_key: smart_key,
          })
          run_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_math_start(xml, start) {
      let tag = docx_tag_name_at(xml, start)
      match find_docx_element_end(xml, start, tag) {
        Some(end_exclusive) => {
          let math_key = docx_child_source_key(paragraph_key, "math", run_index)
          runs.push({
            style_id: None,
            bold: false,
            inlines: [
              parse_docx_math_inline(
                xml, start, end_exclusive, tag, math_key, warnings,
              ),
            ],
            source_key: math_key,
          })
          run_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_tracked_change_start(xml, start) {
      let tag = docx_tag_name_at(xml, start)
      match find_docx_element_end(xml, start, tag) {
        Some(end_exclusive) => {
          let tracked_key = docx_child_source_key(
            paragraph_key, "tracked", run_index,
          )
          let tracked = parse_docx_tracked_change(
            xml, start, end_exclusive, tag, tracked_key, relationships, pkg, warnings,
          )
          runs.push({
            style_id: None,
            bold: false,
            inlines: [tracked],
            source_key: tracked_key,
          })
          run_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:bookmarkStart") ||
      is_docx_start_tag_at(xml, start, "w:bookmarkEnd") {
      let bookmark_key = docx_child_source_key(
        paragraph_key, "bookmark", run_index,
      )
      let bookmark = parse_docx_bookmark(xml, start, bookmark_key, warnings)
      runs.push({
        style_id: None,
        bold: false,
        inlines: [bookmark],
        source_key: bookmark_key,
      })
      run_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if docx_structural_block_kind(xml, start) is Some(_) {
      let marker_key = docx_child_source_key(
        paragraph_key, "structural", run_index,
      )
      match parse_docx_structural_inline(xml, start, marker_key) {
        Some((marker, end_exclusive)) => {
          runs.push({
            style_id: None,
            bold: false,
            inlines: [marker],
            source_key: marker_key,
          })
          run_index += 1
          i = end_exclusive
          continue
        }
        None => break
      }
    } else if xml[start:].has_prefix("</") {
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else {
      let tag = docx_tag_name_at(xml, start)
      if tag != "" {
        let unsupported_key = docx_child_source_key(
          paragraph_key, "inline", run_index,
        )
        warnings.push({
          kind: DocxSourceWarningKind::UnsupportedInline,
          message: "unsupported inline node: " + tag,
          source_key: Some(unsupported_key),
        })
        runs.push({
          style_id: None,
          bold: false,
          inlines: [
            DocxSourceInline::UnsupportedInline({
              tag,
              reason: "unsupported paragraph inline node",
              source_key: unsupported_key,
            }),
          ],
          source_key: unsupported_key,
        })
        run_index += 1
      }
      match skip_docx_element_or_tag(xml, start, tag) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    }
  }
  runs
}

///|
fn docx_content_control_body_xml(source_xml : String, tag : String) -> String {
  match find_docx_start_tag_from(source_xml, 0, "w:sdtContent") {
    Some(start) =>
      match find_docx_element_end(source_xml, start, "w:sdtContent") {
        Some(end_exclusive) =>
          docx_inner_xml_for_element(
            source_xml, start, end_exclusive, "w:sdtContent",
          )
        None =>
          docx_inner_xml_for_element(source_xml, 0, source_xml.length(), tag)
      }
    None => docx_inner_xml_for_element(source_xml, 0, source_xml.length(), tag)
  }
}

///|
fn docx_content_control_source_block(
  tag : String,
  key : DocxSourceKey,
  inner : String,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceBlock {
  let blocks = if docx_content_control_has_block_content(inner) {
    parse_docx_body_inner(key.part_name, inner, relationships, pkg, warnings)
  } else {
    []
  }
  let inlines = if blocks.length() == 0 {
    docx_source_run_inlines(
      parse_docx_paragraph_runs(inner, key, relationships, pkg, warnings),
    )
  } else {
    []
  }
  let text = if blocks.length() == 0 {
    docx_source_inline_text(inlines)
  } else {
    docx_source_blocks_text(blocks)
  }
  {
    kind: DocxSourceBlockKind::ContentControl,
    source_key: key,
    paragraph_style_id: None,
    paragraph_alignment: None,
    numbering_ref: None,
    runs: [],
    table: None,
    content_control: Some({ tag, blocks, inlines, text, source_key: key }),
    text,
    inlines,
    structural_kind: None,
    raw_tag: Some(tag),
  }
}

///|
fn parse_docx_inline_content_control(
  xml : String,
  start : Int,
  end_exclusive : Int,
  tag : String,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceContentControl {
  let inner = docx_content_control_body_xml(
    xml[start:end_exclusive].to_owned(),
    tag,
  )
  let blocks = if docx_content_control_has_block_content(inner) {
    parse_docx_body_inner(key.part_name, inner, relationships, pkg, warnings)
  } else {
    []
  }
  let inlines = if blocks.length() == 0 {
    docx_source_run_inlines(
      parse_docx_paragraph_runs(inner, key, relationships, pkg, warnings),
    )
  } else {
    []
  }
  {
    tag,
    blocks,
    inlines,
    text: if blocks.length() == 0 {
      docx_source_inline_text(inlines)
    } else {
      docx_source_blocks_text(blocks)
    },
    source_key: key,
  }
}

///|
fn docx_content_control_has_block_content(xml : String) -> Bool {
  find_docx_start_tag_from(xml, 0, "w:p") is Some(_) ||
  find_docx_start_tag_from(xml, 0, "w:tbl") is Some(_)
}

///|
fn parse_docx_smart_tag_inline(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceSmartTag {
  let inner = docx_inner_xml_for_element(
    xml, start, end_exclusive, "w:smartTag",
  )
  {
    tag: "w:smartTag",
    child_inlines: docx_source_run_inlines(
      parse_docx_paragraph_runs(inner, key, relationships, pkg, warnings),
    ),
    source_key: key,
  }
}

///|
fn parse_docx_run_inlines(
  xml : String,
  run_key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceInline] {
  let inlines : Array[DocxSourceInline] = []
  let mut i = 0
  let mut inline_index = 0
  while i < xml.length() {
    let next_lt_rel = match xml[i:].find("<") {
      Some(rel) => rel
      None => break
    }
    let start = i + next_lt_rel
    if is_docx_start_tag_at(xml, start, "w:rPr") {
      match skip_docx_element_or_tag(xml, start, "w:rPr") {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:tab") {
      inlines.push(DocxSourceInline::Tab)
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:t") {
      let open_end_rel = match xml[start:].find(">") {
        Some(rel) => rel
        None => break
      }
      let text_start = start + open_end_rel + 1
      let close_rel = match xml[text_start:].find("</w:t>") {
        Some(rel) => rel
        None => break
      }
      let text = decode_docx_text(
        xml[text_start:text_start + close_rel].to_owned(),
      )
      if text != "" {
        inlines.push(DocxSourceInline::Text(text))
        inline_index += 1
      }
      i = text_start + close_rel + "</w:t>".length()
    } else if is_docx_start_tag_at(xml, start, "w:br") {
      let break_key = docx_child_source_key(run_key, "break", inline_index)
      inlines.push(parse_docx_break_inline(xml, start, break_key))
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:cr") {
      let break_key = docx_child_source_key(run_key, "break", inline_index)
      inlines.push(
        DocxSourceInline::Break({
          kind: DocxBreakKind::CarriageReturn,
          break_type: Some("cr"),
          source_key: break_key,
        }),
      )
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:drawing") {
      match find_docx_element_end(xml, start, "w:drawing") {
        Some(end_exclusive) => {
          let drawing_key = docx_child_source_key(
            run_key, "drawing", inline_index,
          )
          inlines.push(
            DocxSourceInline::Drawing(
              parse_docx_drawing_anchor(
                xml, start, end_exclusive, drawing_key, relationships, pkg, warnings,
              ),
            ),
          )
          inline_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:pict") {
      match find_docx_element_end(xml, start, "w:pict") {
        Some(end_exclusive) => {
          let shape_key = docx_child_source_key(run_key, "shape", inline_index)
          inlines.push(
            DocxSourceInline::Shape(
              parse_docx_shape_anchor(
                xml, start, end_exclusive, shape_key, relationships, pkg, warnings,
              ),
            ),
          )
          inline_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:txbxContent") {
      match find_docx_element_end(xml, start, "w:txbxContent") {
        Some(end_exclusive) => {
          let textbox_key = docx_child_source_key(
            run_key, "textbox", inline_index,
          )
          inlines.push(
            DocxSourceInline::TextBoxRef({
              anchor_id: None,
              owner_part: textbox_key.part_name,
              source_key: textbox_key,
            }),
          )
          inline_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:hyperlink") {
      match find_docx_element_end(xml, start, "w:hyperlink") {
        Some(end_exclusive) => {
          let link_key = docx_child_source_key(
            run_key, "hyperlink", inline_index,
          )
          let link = parse_docx_hyperlink(
            xml, start, end_exclusive, link_key, relationships, warnings,
          )
          inlines.push(DocxSourceInline::Hyperlink(link))
          inline_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:fldChar") {
      let field_key = docx_child_source_key(run_key, "field", inline_index)
      inlines.push(parse_docx_fld_char(xml, start, field_key, warnings))
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:instrText") {
      let field_key = docx_child_source_key(run_key, "field", inline_index)
      match parse_docx_instr_text(xml, start, field_key, warnings) {
        Some((field, end_exclusive)) => {
          inlines.push(field)
          inline_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:fldSimple") {
      match find_docx_element_end(xml, start, "w:fldSimple") {
        Some(end_exclusive) => {
          let field_key = docx_child_source_key(run_key, "field", inline_index)
          inlines.push(
            parse_docx_fld_simple(
              xml, start, end_exclusive, field_key, relationships, pkg, warnings,
            ),
          )
          inline_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else if is_docx_math_start(xml, start) {
      let tag = docx_tag_name_at(xml, start)
      match find_docx_element_end(xml, start, tag) {
        Some(end_exclusive) => {
          let math_key = docx_child_source_key(run_key, "math", inline_index)
          inlines.push(
            parse_docx_math_inline(
              xml, start, end_exclusive, tag, math_key, warnings,
            ),
          )
          inline_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:bookmarkStart") ||
      is_docx_start_tag_at(xml, start, "w:bookmarkEnd") {
      let bookmark_key = docx_child_source_key(
        run_key, "bookmark", inline_index,
      )
      inlines.push(parse_docx_bookmark(xml, start, bookmark_key, warnings))
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if docx_structural_block_kind(xml, start) is Some(_) {
      let marker_key = docx_child_source_key(
        run_key, "structural", inline_index,
      )
      match parse_docx_structural_inline(xml, start, marker_key) {
        Some((marker, end_exclusive)) => {
          inlines.push(marker)
          inline_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:footnoteReference") {
      inlines.push(
        DocxSourceInline::FootnoteRef(
          read_docx_attr_value(docx_open_tag_at(xml, start), "w:id").unwrap_or(
            "",
          ),
        ),
      )
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:endnoteReference") {
      inlines.push(
        DocxSourceInline::EndnoteRef(
          read_docx_attr_value(docx_open_tag_at(xml, start), "w:id").unwrap_or(
            "",
          ),
        ),
      )
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:commentReference") {
      inlines.push(
        DocxSourceInline::CommentRef(
          read_docx_attr_value(docx_open_tag_at(xml, start), "w:id").unwrap_or(
            "",
          ),
        ),
      )
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:sym") {
      let symbol_key = docx_child_source_key(run_key, "symbol", inline_index)
      inlines.push(parse_docx_symbol_inline(xml, start, symbol_key))
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:softHyphen") {
      let hyphen_key = docx_child_source_key(run_key, "hyphen", inline_index)
      inlines.push(
        DocxSourceInline::Hyphen({
          kind: DocxHyphenKind::Soft,
          source_key: hyphen_key,
        }),
      )
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:noBreakHyphen") {
      let hyphen_key = docx_child_source_key(run_key, "hyphen", inline_index)
      inlines.push(
        DocxSourceInline::Hyphen({
          kind: DocxHyphenKind::NoBreak,
          source_key: hyphen_key,
        }),
      )
      inline_index += 1
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_tracked_change_start(xml, start) {
      let tag = docx_tag_name_at(xml, start)
      match find_docx_element_end(xml, start, tag) {
        Some(end_exclusive) => {
          let tracked_key = docx_child_source_key(
            run_key, "tracked", inline_index,
          )
          inlines.push(
            parse_docx_tracked_change(
              xml, start, end_exclusive, tag, tracked_key, relationships, pkg, warnings,
            ),
          )
          inline_index += 1
          i = end_exclusive
        }
        None => break
      }
    } else if xml[start:].has_prefix("</") {
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else {
      let tag = docx_tag_name_at(xml, start)
      if tag != "" {
        let unsupported_key = docx_child_source_key(
          run_key, "inline", inline_index,
        )
        warnings.push({
          kind: DocxSourceWarningKind::UnsupportedInline,
          message: "unsupported run child: " + tag,
          source_key: Some(unsupported_key),
        })
        inlines.push(
          DocxSourceInline::UnsupportedInline({
            tag,
            reason: "unsupported run child",
            source_key: unsupported_key,
          }),
        )
        inline_index += 1
      }
      match skip_docx_element_or_tag(xml, start, tag) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    }
  }
  inlines
}

///|
fn read_docx_paragraph_style_id(xml : String) -> String? {
  read_docx_attr_in_first_tag(xml, "w:pStyle", "w:val")
}

///|
fn read_docx_paragraph_alignment(xml : String) -> String? {
  read_docx_attr_in_first_tag(xml, "w:jc", "w:val")
}

///|
fn read_docx_cell_grid_span(xml : String) -> String? {
  read_docx_attr_in_first_tag(xml, "w:gridSpan", "w:val")
}

///|
fn read_docx_cell_vertical_merge(xml : String) -> String? {
  match read_docx_attr_in_first_tag(xml, "w:vMerge", "w:val") {
    Some(value) => Some(value)
    None =>
      match find_docx_start_tag_from(xml, 0, "w:vMerge") {
        Some(_) => Some("continue")
        None => None
      }
  }
}

///|
fn docx_source_blocks_have_table(blocks : Array[DocxSourceBlock]) -> Bool {
  for block in blocks {
    if block.kind == DocxSourceBlockKind::Table {
      return true
    }
  }
  false
}

///|
fn docx_source_blocks_max_table_depth(
  blocks : Array[DocxSourceBlock],
  default_depth : Int,
) -> Int {
  let mut out = default_depth
  for block in blocks {
    match block.table {
      Some(table) =>
        if table.max_nested_depth > out {
          out = table.max_nested_depth
        }
      None => ()
    }
  }
  out
}

///|
fn docx_source_blocks_have_table_guard(blocks : Array[DocxSourceBlock]) -> Bool {
  for block in blocks {
    match block.table {
      Some(table) => if table.deep_table_guard_triggered { return true }
      None => if block.kind == DocxSourceBlockKind::Table { return true }
    }
  }
  false
}

///|
fn docx_source_blocks_text(blocks : Array[DocxSourceBlock]) -> String {
  let parts : Array[String] = []
  for block in blocks {
    if block.text.trim() != "" {
      parts.push(block.text)
    }
  }
  parts.join("\n")
}

///|
fn docx_source_table_text(table : DocxSourceTable) -> String {
  let rows : Array[String] = []
  for row in table.rows {
    let cells : Array[String] = []
    for cell in row.cells {
      cells.push(cell.text)
    }
    rows.push(cells.join("\t"))
  }
  rows.join("\n")
}

///|
fn read_docx_run_style_id(xml : String) -> String? {
  read_docx_attr_in_first_tag(xml, "w:rStyle", "w:val")
}

///|
fn read_docx_run_is_bold(xml : String) -> Bool {
  match find_docx_start_tag_from(xml, 0, "w:rPr") {
    Some(start) =>
      match find_docx_element_end(xml, start, "w:rPr") {
        Some(end_exclusive) =>
          docx_inner_xml_for_element(xml, start, end_exclusive, "w:rPr").contains(
            "<w:b",
          )
        None => xml[start:].contains("<w:b")
      }
    None => false
  }
}

///|
fn read_docx_numbering_ref(xml : String) -> DocxNumberingRef? {
  match read_docx_attr_in_first_tag(xml, "w:numId", "w:val") {
    Some(num_id) =>
      Some({ num_id, ilvl: read_docx_attr_in_first_tag(xml, "w:ilvl", "w:val") })
    None => None
  }
}

///|
fn read_docx_attr_in_first_tag(
  xml : String,
  tag : String,
  attr : String,
) -> String? {
  match find_docx_start_tag_from(xml, 0, tag) {
    Some(start) => read_docx_attr_value(docx_open_tag_at(xml, start), attr)
    None => None
  }
}

///|
fn find_docx_start_tag_from(xml : String, from : Int, tag : String) -> Int? {
  let needle = "<" + tag
  let mut i = from
  while i < xml.length() {
    let rel = match xml[i:].find(needle) {
      Some(v) => v
      None => return None
    }
    let pos = i + rel
    if is_docx_start_tag_at(xml, pos, tag) {
      return Some(pos)
    }
    i = pos + 1
  }
  None
}

///|
fn docx_open_tag_at(xml : String, start : Int) -> String {
  match find_docx_any_tag_end(xml, start) {
    Some(end_exclusive) => xml[start:end_exclusive].to_owned()
    None => ""
  }
}

///|
fn read_docx_attr_value(tag_xml : String, attr : String) -> String? {
  match read_docx_attr_value_with_prefix(tag_xml, attr + "=\"", "\"") {
    Some(value) => Some(value)
    None => read_docx_attr_value_with_prefix(tag_xml, attr + "='", "'")
  }
}

///|
fn read_docx_attr_value_with_prefix(
  tag_xml : String,
  prefix : String,
  close_quote : String,
) -> String? {
  match tag_xml.find(prefix) {
    Some(pos) => {
      let value_start = pos + prefix.length()
      match tag_xml[value_start:].find(close_quote) {
        Some(rel) =>
          Some(
            decode_docx_text(tag_xml[value_start:value_start + rel].to_owned()),
          )
        None => None
      }
    }
    None => None
  }
}

///|
priv struct DocxMediaRelationshipRef {
  relationship_id : String?
  relationship_kind : DocxMediaRelationshipKind
}

///|
fn parse_docx_drawing_anchor(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceDrawing {
  let source_xml = xml[start:end_exclusive].to_owned()
  let media = if find_docx_media_relationship_ref(source_xml) is Some(_) {
    Some(
      parse_docx_media_ref(
        xml,
        start,
        end_exclusive,
        "w:drawing",
        DocxMediaContainerKind::Drawing,
        key,
        relationships,
        pkg,
        warnings,
      ),
    )
  } else {
    None
  }
  {
    anchor_id: key.part_name + "#" + key.node_key,
    owner_part: key.part_name,
    source_key: key,
    doc_pr_id: read_docx_non_empty_attr_in_first_tag(
      source_xml, "wp:docPr", "id",
    ),
    doc_pr_name: read_docx_non_empty_attr_in_first_tag(
      source_xml, "wp:docPr", "name",
    ),
    descr: read_docx_media_alt_text(source_xml),
    title: read_docx_media_title(source_xml),
    media,
    text_box_ref: docx_textbox_ref_in_anchor(source_xml, key),
    child_inlines: [],
  }
}

///|
fn parse_docx_shape_anchor(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceShape {
  let source_xml = xml[start:end_exclusive].to_owned()
  let media = if find_docx_media_relationship_ref(source_xml) is Some(_) {
    Some(
      parse_docx_media_ref(
        xml,
        start,
        end_exclusive,
        "w:pict",
        DocxMediaContainerKind::Pict,
        key,
        relationships,
        pkg,
        warnings,
      ),
    )
  } else {
    None
  }
  {
    anchor_id: key.part_name + "#" + key.node_key,
    owner_part: key.part_name,
    source_key: key,
    shape_id: read_docx_non_empty_attr_in_first_tag(source_xml, "v:shape", "id"),
    shape_type: read_docx_non_empty_attr_in_first_tag(
      source_xml, "v:shape", "type",
    ),
    style: read_docx_non_empty_attr_in_first_tag(source_xml, "v:shape", "style"),
    alt_text: read_docx_media_alt_text(source_xml),
    title: read_docx_media_title(source_xml),
    media,
    text_box_ref: docx_textbox_ref_in_anchor(source_xml, key),
    child_inlines: [],
  }
}

///|
fn docx_textbox_ref_in_anchor(
  source_xml : String,
  key : DocxSourceKey,
) -> DocxSourceTextBoxRef? {
  match find_docx_start_tag_from(source_xml, 0, "w:txbxContent") {
    Some(_) =>
      Some({ anchor_id: None, owner_part: key.part_name, source_key: key })
    None => None
  }
}

///|
fn parse_docx_media_ref(
  xml : String,
  start : Int,
  end_exclusive : Int,
  container_tag : String,
  container_kind : DocxMediaContainerKind,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceMediaRef {
  let source_xml = xml[start:end_exclusive].to_owned()
  let media_ref = find_docx_media_relationship_ref(source_xml)
  let mut relationship_id : String? = None
  let mut relationship_kind = DocxMediaRelationshipKind::Unknown
  let mut target : String? = None
  let mut resolved_target : String? = None
  let mut target_mode : DocxTargetMode? = None
  let mut target_part : String? = None
  let mut target_exists : Bool? = None
  let mut content_type : String? = None

  match media_ref {
    Some(ref_info) => {
      relationship_id = ref_info.relationship_id
      relationship_kind = ref_info.relationship_kind
    }
    None =>
      warnings.push({
        kind: DocxSourceWarningKind::MissingMediaTarget,
        message: "media ref has no supported relationship tag: " + container_tag,
        source_key: Some(key),
      })
  }

  match relationship_id {
    Some(rid) =>
      match find_docx_relationship_by_id(relationships, rid) {
        Some(rel) => {
          target = Some(rel.target)
          resolved_target = Some(rel.resolved_target)
          if rel.target_mode == @ox.OoxmlTargetMode::External {
            target_mode = Some(DocxTargetMode::External)
          } else {
            target_mode = Some(DocxTargetMode::Internal)
            target_part = Some(rel.resolved_target)
            target_exists = docx_media_target_exists(pkg, rel.resolved_target)
            content_type = docx_media_content_type(pkg, rel.resolved_target)
            if target_exists == Some(false) {
              warnings.push({
                kind: DocxSourceWarningKind::MissingMediaPart,
                message: "media part is missing: " + rel.resolved_target,
                source_key: Some(key),
              })
            }
            match content_type {
              Some(ct) =>
                if !ct.has_prefix("image/") {
                  warnings.push({
                    kind: DocxSourceWarningKind::UnsupportedMedia,
                    message: "media target content type is not image: " + ct,
                    source_key: Some(key),
                  })
                }
              None => ()
            }
          }
        }
        None =>
          warnings.push({
            kind: DocxSourceWarningKind::MissingMediaTarget,
            message: "media relationship not found: " + rid,
            source_key: Some(key),
          })
      }
    None =>
      if media_ref is Some(_) {
        warnings.push({
          kind: DocxSourceWarningKind::MissingMediaTarget,
          message: "media relationship tag has no relationship id: " +
          container_tag,
          source_key: Some(key),
        })
      }
  }

  {
    relationship_id,
    relationship_kind,
    container_kind,
    target,
    resolved_target,
    target_mode,
    target_part,
    target_exists,
    content_type,
    alt_text: read_docx_media_alt_text(source_xml),
    title: read_docx_media_title(source_xml),
    source_key: key,
  }
}

///|
fn find_docx_media_relationship_ref(
  source_xml : String,
) -> DocxMediaRelationshipRef? {
  let blip_start = find_docx_start_tag_from(source_xml, 0, "a:blip")
  let image_start = find_docx_start_tag_from(source_xml, 0, "v:imagedata")
  match (blip_start, image_start) {
    (Some(a), Some(v)) =>
      if a <= v {
        Some(read_docx_blip_relationship_ref(docx_open_tag_at(source_xml, a)))
      } else {
        Some(
          read_docx_vml_image_relationship_ref(docx_open_tag_at(source_xml, v)),
        )
      }
    (Some(a), None) =>
      Some(read_docx_blip_relationship_ref(docx_open_tag_at(source_xml, a)))
    (None, Some(v)) =>
      Some(
        read_docx_vml_image_relationship_ref(docx_open_tag_at(source_xml, v)),
      )
    (None, None) => None
  }
}

///|
fn read_docx_blip_relationship_ref(tag : String) -> DocxMediaRelationshipRef {
  match read_docx_attr_value(tag, "r:embed") {
    Some(rid) => { relationship_id: Some(rid), relationship_kind: Embed }
    None =>
      match read_docx_attr_value(tag, "r:link") {
        Some(rid) => { relationship_id: Some(rid), relationship_kind: Link }
        None =>
          match read_docx_attr_value(tag, "r:id") {
            Some(rid) =>
              { relationship_id: Some(rid), relationship_kind: Unknown }
            None => { relationship_id: None, relationship_kind: Unknown }
          }
      }
  }
}

///|
fn read_docx_vml_image_relationship_ref(
  tag : String,
) -> DocxMediaRelationshipRef {
  match read_docx_attr_value(tag, "r:id") {
    Some(rid) => { relationship_id: Some(rid), relationship_kind: Embed }
    None =>
      match read_docx_attr_value(tag, "r:embed") {
        Some(rid) => { relationship_id: Some(rid), relationship_kind: Embed }
        None =>
          match read_docx_attr_value(tag, "r:link") {
            Some(rid) => { relationship_id: Some(rid), relationship_kind: Link }
            None => { relationship_id: None, relationship_kind: Unknown }
          }
      }
  }
}

///|
fn docx_media_target_exists(
  pkg : @ox.OoxmlPackage?,
  target_part : String,
) -> Bool? {
  match pkg {
    Some(p) => Some(@ox.has_part(p, target_part))
    None => None
  }
}

///|
fn docx_media_content_type(
  pkg : @ox.OoxmlPackage?,
  target_part : String,
) -> String? {
  match pkg {
    Some(p) => @ox.lookup_content_type(p, target_part) catch { _ => None }
    None => None
  }
}

///|
fn read_docx_media_alt_text(source_xml : String) -> String? {
  match read_docx_non_empty_attr_in_first_tag(source_xml, "wp:docPr", "descr") {
    Some(value) => Some(value)
    None =>
      match
        read_docx_non_empty_attr_in_first_tag(source_xml, "pic:cNvPr", "descr") {
        Some(value) => Some(value)
        None =>
          match
            read_docx_non_empty_attr_in_first_tag(source_xml, "v:shape", "alt") {
            Some(value) => Some(value)
            None =>
              read_docx_non_empty_attr_in_first_tag(
                source_xml, "v:imagedata", "alt",
              )
          }
      }
  }
}

///|
fn read_docx_media_title(source_xml : String) -> String? {
  match read_docx_non_empty_attr_in_first_tag(source_xml, "wp:docPr", "title") {
    Some(value) => Some(value)
    None =>
      match
        read_docx_non_empty_attr_in_first_tag(source_xml, "pic:cNvPr", "title") {
        Some(value) => Some(value)
        None =>
          match
            read_docx_non_empty_attr_in_first_tag(
              source_xml, "v:shape", "title",
            ) {
            Some(value) => Some(value)
            None =>
              match
                read_docx_non_empty_attr_in_first_tag(
                  source_xml, "v:imagedata", "title",
                ) {
                Some(value) => Some(value)
                None =>
                  read_docx_non_empty_attr_in_first_tag(
                    source_xml, "v:imagedata", "o:title",
                  )
              }
          }
      }
  }
}

///|
fn read_docx_non_empty_attr_in_first_tag(
  xml : String,
  tag : String,
  attr : String,
) -> String? {
  match read_docx_attr_in_first_tag(xml, tag, attr) {
    Some(value) => if value.trim() == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn parse_docx_hyperlink(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  warnings : Array[DocxSourceWarning],
) -> DocxSourceHyperlink {
  let open_tag = docx_open_tag_at(xml, start)
  let relationship_id = read_docx_attr_value(open_tag, "r:id")
  let anchor = read_docx_attr_value(open_tag, "w:anchor")
  let text = docx_visible_text_in_scope(
    docx_inner_xml_for_element(xml, start, end_exclusive, "w:hyperlink"),
  )
  let mut target : String? = None
  let mut target_mode : DocxTargetMode? = None
  match relationship_id {
    Some(rid) =>
      match find_docx_relationship_by_id(relationships, rid) {
        Some(rel) => {
          target = Some(rel.resolved_target)
          target_mode = Some(
            if rel.target_mode == @ox.OoxmlTargetMode::External {
              DocxTargetMode::External
            } else {
              DocxTargetMode::Internal
            },
          )
        }
        None =>
          warnings.push({
            kind: DocxSourceWarningKind::MissingHyperlinkTarget,
            message: "hyperlink relationship not found: " + rid,
            source_key: Some(key),
          })
      }
    None => ()
  }
  if target is None {
    match anchor {
      Some(value) => {
        target = Some("#" + value)
        target_mode = Some(DocxTargetMode::Internal)
      }
      None =>
        warnings.push({
          kind: DocxSourceWarningKind::MissingHyperlinkTarget,
          message: "hyperlink has no relationship id or anchor",
          source_key: Some(key),
        })
    }
  }
  { relationship_id, anchor, target, text, target_mode, source_key: key }
}

///|
fn find_docx_relationship_by_id(
  relationships : Array[@ox.OoxmlRelationship],
  relationship_id : String,
) -> @ox.OoxmlRelationship? {
  for rel in relationships {
    if rel.id == relationship_id {
      return Some(rel)
    }
  }
  None
}

///|
fn parse_docx_break_inline(
  xml : String,
  start : Int,
  key : DocxSourceKey,
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  let break_type = read_docx_attr_value(open_tag, "w:type")
  let kind = match break_type {
    Some(value) =>
      if value == "page" {
        DocxBreakKind::Page
      } else if value == "column" {
        DocxBreakKind::Column
      } else if value == "textWrapping" {
        DocxBreakKind::TextWrapping
      } else {
        DocxBreakKind::Unknown
      }
    None => DocxBreakKind::Line
  }
  DocxSourceInline::Break({ kind, break_type, source_key: key })
}

///|
fn is_docx_math_start(xml : String, start : Int) -> Bool {
  is_docx_start_tag_at(xml, start, "m:oMath") ||
  is_docx_start_tag_at(xml, start, "m:oMathPara")
}

///|
fn parse_docx_math_inline(
  xml : String,
  start : Int,
  end_exclusive : Int,
  tag : String,
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  warnings.push({
    kind: DocxSourceWarningKind::UnsupportedMath,
    message: "OMML math preserved without conversion: " + tag,
    source_key: Some(key),
  })
  DocxSourceInline::Math({
    kind: tag,
    text_signature: docx_math_text_signature(
      docx_inner_xml_for_element(xml, start, end_exclusive, tag),
    ),
    child_inlines: [],
    source_key: key,
  })
}

///|
fn parse_docx_symbol_inline(
  xml : String,
  start : Int,
  key : DocxSourceKey,
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  DocxSourceInline::Symbol({
    font: read_docx_attr_value(open_tag, "w:font"),
    char_hex: read_docx_attr_value(open_tag, "w:char"),
    source_key: key,
  })
}

///|
fn parse_docx_fld_simple(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  let inner = docx_inner_xml_for_element(
    xml, start, end_exclusive, "w:fldSimple",
  )
  make_docx_field_inline(
    "fldSimple",
    read_docx_attr_value(open_tag, "w:instr"),
    None,
    docx_non_empty_text(docx_visible_text_in_scope(inner)),
    docx_source_run_inlines(
      parse_docx_paragraph_runs(inner, key, relationships, pkg, warnings),
    ),
    key,
    warnings,
  )
}

///|
fn parse_docx_fld_char(
  xml : String,
  start : Int,
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  make_docx_field_inline(
    "fldChar",
    None,
    read_docx_attr_value(open_tag, "w:fldCharType"),
    None,
    [],
    key,
    warnings,
  )
}

///|
fn parse_docx_instr_text(
  xml : String,
  start : Int,
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> (DocxSourceInline, Int)? {
  let open_end_rel = match xml[start:].find(">") {
    Some(rel) => rel
    None => return None
  }
  let text_start = start + open_end_rel + 1
  let close_rel = match xml[text_start:].find("</w:instrText>") {
    Some(rel) => rel
    None => return None
  }
  let instruction = decode_docx_text(
    xml[text_start:text_start + close_rel].to_owned(),
  )
  Some(
    (
      make_docx_field_inline(
        "instrText",
        Some(instruction),
        None,
        None,
        [],
        key,
        warnings,
      ),
      text_start + close_rel + "</w:instrText>".length(),
    ),
  )
}

///|
fn make_docx_field_inline(
  kind : String,
  instruction : String?,
  field_char_type : String?,
  result_text : String?,
  child_inlines : Array[DocxSourceInline],
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  warnings.push({
    kind: DocxSourceWarningKind::UnsupportedField,
    message: "unsupported field inline: " + kind,
    source_key: Some(key),
  })
  DocxSourceInline::FieldUnsupported({
    kind,
    instruction,
    field_char_type,
    result_text,
    child_inlines,
    source_key: key,
  })
}

///|
fn parse_docx_bookmark(
  xml : String,
  start : Int,
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  let kind = if is_docx_start_tag_at(xml, start, "w:bookmarkStart") {
    DocxBookmarkKind::Start
  } else {
    DocxBookmarkKind::End
  }
  warnings.push({
    kind: DocxSourceWarningKind::UnsupportedBookmark,
    message: "bookmark inline preserved without conversion",
    source_key: Some(key),
  })
  DocxSourceInline::Bookmark({
    kind,
    bookmark_id: read_docx_attr_value(open_tag, "w:id"),
    name: read_docx_attr_value(open_tag, "w:name"),
    source_key: key,
  })
}

///|
fn is_docx_tracked_change_start(xml : String, start : Int) -> Bool {
  is_docx_start_tag_at(xml, start, "w:ins") ||
  is_docx_start_tag_at(xml, start, "w:del") ||
  is_docx_start_tag_at(xml, start, "w:moveFrom") ||
  is_docx_start_tag_at(xml, start, "w:moveTo")
}

///|
fn parse_docx_tracked_change(
  xml : String,
  start : Int,
  end_exclusive : Int,
  tag : String,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  warnings.push({
    kind: DocxSourceWarningKind::TrackedChange,
    message: "tracked change inline preserved without review policy: " + tag,
    source_key: Some(key),
  })
  DocxSourceInline::TrackedChange({
    kind: tag,
    text: docx_visible_text_in_scope(
      docx_inner_xml_for_element(xml, start, end_exclusive, tag),
    ),
    child_inlines: docx_source_run_inlines(
      parse_docx_paragraph_runs(
        docx_inner_xml_for_element(xml, start, end_exclusive, tag),
        key,
        relationships,
        pkg,
        warnings,
      ),
    ),
    source_key: key,
  })
}

///|
fn docx_visible_text_in_scope(xml : String) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < xml.length() {
    let next_lt_rel = match xml[i:].find("<") {
      Some(rel) => rel
      None => break
    }
    let start = i + next_lt_rel
    if is_docx_start_tag_at(xml, start, "w:tab") {
      out.write_string("\t")
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:t") ||
      is_docx_start_tag_at(xml, start, "w:delText") ||
      is_docx_start_tag_at(xml, start, "m:t") {
      let tag = docx_tag_name_at(xml, start)
      let open_end_rel = match xml[start:].find(">") {
        Some(rel) => rel
        None => break
      }
      let text_start = start + open_end_rel + 1
      let close_tag = "</" + tag + ">"
      let close_rel = match xml[text_start:].find(close_tag) {
        Some(rel) => rel
        None => break
      }
      out.write_string(
        decode_docx_text(xml[text_start:text_start + close_rel].to_owned()),
      )
      i = text_start + close_rel + close_tag.length()
    } else if is_docx_start_tag_at(xml, start, "w:br") {
      out.write_string(
        docx_source_break_text_from_open_tag(docx_open_tag_at(xml, start)),
      )
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:cr") {
      out.write_string("\n")
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:sym") {
      out.write_string(
        docx_source_symbol_text_from_tag(docx_open_tag_at(xml, start)),
      )
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:softHyphen") {
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:noBreakHyphen") {
      out.write_string("-")
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else {
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    }
  }
  out.to_string()
}

///|
fn docx_math_text_signature(xml : String) -> String? {
  docx_non_empty_text(docx_visible_text_in_scope(xml))
}

///|
fn docx_non_empty_text(text : String) -> String? {
  if text.trim() == "" {
    None
  } else {
    Some(text)
  }
}

///|
fn docx_inner_xml_for_element(
  xml : String,
  start : Int,
  end_exclusive : Int,
  tag : String,
) -> String {
  let open_end = match find_docx_any_tag_end(xml, start) {
    Some(value) => value
    None => return ""
  }
  let close_len = ("</" + tag + ">").length()
  let inner_end = end_exclusive - close_len
  if is_docx_self_closing_tag(xml[start:open_end].to_owned()) ||
    inner_end <= open_end {
    ""
  } else {
    xml[open_end:inner_end].to_owned()
  }
}

///|
fn docx_child_source_key(
  parent : DocxSourceKey,
  kind : String,
  index : Int,
) -> DocxSourceKey {
  {
    part_name: parent.part_name,
    block_index: parent.block_index,
    node_key: parent.node_key + ":" + kind + ":" + index.to_string(),
  }
}

///|
fn docx_source_run_inlines(
  runs : Array[DocxSourceRun],
) -> Array[DocxSourceInline] {
  let out : Array[DocxSourceInline] = []
  for run in runs {
    for inline in run.inlines {
      out.push(inline)
    }
  }
  out
}

///|
fn docx_source_key(
  part_name : String,
  block_index : Int,
  kind : String,
) -> DocxSourceKey {
  {
    part_name,
    block_index,
    node_key: part_name + ":" + kind + ":" + block_index.to_string(),
  }
}

///|
fn docx_source_inline_text(inlines : Array[DocxSourceInline]) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline {
      DocxSourceInline::Text(text) => out.write_string(text)
      DocxSourceInline::Tab => out.write_string("\t")
      DocxSourceInline::LineBreak => out.write_string("\n")
      DocxSourceInline::Break(value) =>
        out.write_string(docx_source_break_text(value))
      DocxSourceInline::Hyperlink(link) => out.write_string(link.text)
      DocxSourceInline::Media(media) =>
        out.write_string(docx_source_media_text(media))
      DocxSourceInline::TextBoxRef(_) => ()
      DocxSourceInline::Drawing(drawing) =>
        match drawing.media {
          Some(media) => out.write_string(docx_source_media_text(media))
          None => ()
        }
      DocxSourceInline::Shape(shape) =>
        match shape.media {
          Some(media) => out.write_string(docx_source_media_text(media))
          None => out.write_string(docx_source_inline_text(shape.child_inlines))
        }
      DocxSourceInline::ContentControl(control) =>
        out.write_string(control.text)
      DocxSourceInline::FieldUnsupported(field) =>
        out.write_string(docx_source_field_text(field))
      DocxSourceInline::Math(math) =>
        out.write_string(docx_source_math_text(math))
      DocxSourceInline::TrackedChange(change) => out.write_string(change.text)
      DocxSourceInline::SmartTag(smart_tag) =>
        out.write_string(docx_source_inline_text(smart_tag.child_inlines))
      DocxSourceInline::Symbol(symbol) =>
        out.write_string(docx_source_symbol_text(symbol))
      DocxSourceInline::Hyphen(hyphen) =>
        out.write_string(docx_source_hyphen_text(hyphen))
      DocxSourceInline::FootnoteRef(id) =>
        out.write_string("[footnote:" + id + "]")
      DocxSourceInline::EndnoteRef(id) =>
        out.write_string("[endnote:" + id + "]")
      DocxSourceInline::CommentRef(id) =>
        out.write_string("[comment:" + id + "]")
      DocxSourceInline::StructuralMarker(_) => ()
      DocxSourceInline::Bookmark(_) => ()
      DocxSourceInline::UnsupportedInline(_) =>
        out.write_string("[unsupported DOCX inline]")
      DocxSourceInline::Unsupported(_) => ()
    }
  }
  out.to_string()
}

///|
fn docx_source_field_text(field : DocxSourceField) -> String {
  match field.result_text {
    Some(value) => if value.trim() != "" { return value }
    None => ()
  }
  match field.instruction {
    Some(value) =>
      if value.trim() != "" {
        return "[field: " + value.trim().to_owned() + "]"
      }
    None => ()
  }
  match field.field_char_type {
    Some(value) =>
      if value.trim() != "" {
        return "[field: " + field.kind + ":" + value + "]"
      }
    None => ()
  }
  "[field: " + field.kind + "]"
}

///|
fn docx_source_math_text(math : DocxSourceMath) -> String {
  match math.text_signature {
    Some(value) => if value.trim() != "" { return "[math: " + value + "]" }
    None => ()
  }
  "[math]"
}

///|
fn docx_source_break_text(break_value : DocxSourceBreak) -> String {
  match break_value.kind {
    DocxBreakKind::Page => "[break: page]"
    DocxBreakKind::Column => "[break: column]"
    DocxBreakKind::Unknown =>
      match break_value.break_type {
        Some(value) => "[break: " + value + "]"
        None => "[break]"
      }
    DocxBreakKind::Line
    | DocxBreakKind::TextWrapping
    | DocxBreakKind::CarriageReturn => "\n"
  }
}

///|
fn docx_source_break_text_from_open_tag(open_tag : String) -> String {
  let break_type = read_docx_attr_value(open_tag, "w:type")
  let kind = match break_type {
    Some(value) =>
      if value == "page" {
        DocxBreakKind::Page
      } else if value == "column" {
        DocxBreakKind::Column
      } else if value == "textWrapping" {
        DocxBreakKind::TextWrapping
      } else {
        DocxBreakKind::Unknown
      }
    None => DocxBreakKind::Line
  }
  docx_source_break_text({
    kind,
    break_type,
    source_key: docx_source_key("", 0, "break"),
  })
}

///|
fn docx_source_symbol_text(symbol : DocxSourceSymbol) -> String {
  match symbol.char_hex {
    Some(value) => docx_source_symbol_text_from_hex(value)
    None => "[symbol]"
  }
}

///|
fn docx_source_symbol_text_from_tag(open_tag : String) -> String {
  match read_docx_attr_value(open_tag, "w:char") {
    Some(value) => docx_source_symbol_text_from_hex(value)
    None => "[symbol]"
  }
}

///|
fn docx_source_symbol_text_from_hex(value : String) -> String {
  match docx_parse_hex_codepoint(value) {
    Some(codepoint) =>
      if codepoint >= 0x20 && codepoint <= 0x7E {
        String::from_array([Int::unsafe_to_char(codepoint)])
      } else {
        "[symbol: " + value + "]"
      }
    None => "[symbol: " + value + "]"
  }
}

///|
fn docx_parse_hex_codepoint(value : String) -> Int? {
  let chars = value.trim().to_array()
  if chars.length() == 0 {
    return None
  }
  let mut out = 0
  for ch in chars {
    match docx_hex_value(ch) {
      Some(v) => out = (out << 4) + v
      None => return None
    }
  }
  Some(out)
}

///|
fn docx_hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn docx_source_hyphen_text(hyphen : DocxSourceHyphen) -> String {
  match hyphen.kind {
    DocxHyphenKind::Soft => ""
    DocxHyphenKind::NoBreak => "-"
  }
}

///|
fn docx_source_media_text(media : DocxSourceMediaRef) -> String {
  match media.alt_text {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.title {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.target_part {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.resolved_target {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.relationship_id {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  "[image]"
}

///|
fn skip_docx_element_or_tag(xml : String, start : Int, tag : String) -> Int? {
  if tag != "" {
    match find_docx_element_end(xml, start, tag) {
      Some(end_exclusive) => return Some(end_exclusive)
      None => ()
    }
  }
  find_docx_any_tag_end(xml, start)
}

///|
fn find_docx_element_end(xml : String, start : Int, tag : String) -> Int? {
  match find_docx_any_tag_end(xml, start) {
    Some(open_end) =>
      if is_docx_start_tag_at(xml, start, tag) &&
        is_docx_self_closing_tag(xml[start:open_end].to_owned()) {
        return Some(open_end)
      }
    None => return None
  }
  let close_tag = "</" + tag + ">"
  let mut depth = 0
  let mut i = start
  while i < xml.length() {
    let next_lt_rel = match xml[i:].find("<") {
      Some(rel) => rel
      None => return None
    }
    let pos = i + next_lt_rel
    if xml[pos:].has_prefix(close_tag) {
      depth -= 1
      let end_exclusive = pos + close_tag.length()
      if depth == 0 {
        return Some(end_exclusive)
      }
      i = end_exclusive
    } else if is_docx_start_tag_at(xml, pos, tag) {
      match find_docx_any_tag_end(xml, pos) {
        Some(end_exclusive) => {
          depth += 1
          if is_docx_self_closing_tag(xml[pos:end_exclusive].to_owned()) {
            depth -= 1
          }
          i = end_exclusive
        }
        None => return None
      }
    } else {
      match find_docx_any_tag_end(xml, pos) {
        Some(end_exclusive) => i = end_exclusive
        None => return None
      }
    }
  }
  None
}

///|
fn is_docx_start_tag_at(xml : String, start : Int, tag : String) -> Bool {
  if start < 0 || start + tag.length() + 1 > xml.length() {
    return false
  }
  if !xml[start:].has_prefix("<" + tag) {
    return false
  }
  let boundary_index = start + tag.length() + 1
  if boundary_index >= xml.length() {
    return true
  }
  let ch = xml[boundary_index:boundary_index + 1]
  ch == " " || ch == "\t" || ch == "\n" || ch == "\r" || ch == "/" || ch == ">"
}

///|
fn find_docx_any_tag_end(xml : String, start : Int) -> Int? {
  match xml[start:].find(">") {
    Some(rel) => Some(start + rel + 1)
    None => None
  }
}

///|
fn is_docx_self_closing_tag(tag : String) -> Bool {
  let trimmed = tag.trim()
  trimmed.has_suffix("/>")
}

///|
fn docx_tag_name_at(xml : String, start : Int) -> String {
  if start < 0 || start >= xml.length() || !xml[start:].has_prefix("<") {
    return ""
  }
  let mut i = start + 1
  if i < xml.length() && xml[i:i + 1] == "/" {
    i += 1
  }
  let name_start = i
  while i < xml.length() {
    let ch = xml[i:i + 1]
    if ch == " " ||
      ch == "\t" ||
      ch == "\n" ||
      ch == "\r" ||
      ch == "/" ||
      ch == ">" {
      break
    }
    i += 1
  }
  xml[name_start:i].to_owned()
}

///|
fn decode_docx_text(text : String) -> String {
  text
  .replace(old="&lt;", new="<")
  .replace(old="&gt;", new=">")
  .replace(old="&amp;", new="&")
  .replace(old="&quot;", new="\"")
  .replace(old="&apos;", new="'")
}
