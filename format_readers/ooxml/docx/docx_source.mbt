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
  let metadata = parse_docx_document_metadata(pkg)
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
    metadata,
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
      xml,
      relationships,
      DocxPartBodyKind::Header,
      warnings,
    ),
    footers: parse_docx_part_bodies_from_relationships(
      pkg,
      xml,
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
    metadata: empty_docx_document_metadata(),
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
