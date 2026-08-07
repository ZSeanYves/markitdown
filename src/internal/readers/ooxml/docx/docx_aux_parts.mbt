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
          MissingStylesPart,
          "styles part is missing: ",
          warnings,
        ) {
        Some(xml) => parse_docx_styles_part(part, xml)
        None => { part_name: Some(part), styles: [] }
      }
    None => {
      if docx_source_blocks_have_style_refs(blocks) {
        warnings.push({
          kind: MissingStylesPart,
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
          MissingNumberingPart,
          "numbering part is missing: ",
          warnings,
        ) {
        Some(xml) => parse_docx_numbering_part(part, xml)
        None => { part_name: Some(part), nums: [], levels: [] }
      }
    None => {
      if docx_source_blocks_have_numbering_refs(blocks) {
        warnings.push({
          kind: MissingNumberingPart,
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
    let start = match find_docx_start_tag_from(xml, i, "w:style") {
      Some(value) => value
      None => break
    }
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
            let child_start = match find_docx_char_from(ppr_inner, i, 60) {
              Some(value) => value
              None => break
            }
            if docx_string_has_prefix_at(ppr_inner, child_start, "</") {
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
    let start = match find_docx_start_tag_from(xml, i, "w:num") {
      Some(value) => value
      None => break
    }
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
    let start = match find_docx_start_tag_from(xml, i, "w:lvlOverride") {
      Some(value) => value
      None => break
    }
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
    let start = match find_docx_start_tag_from(xml, i, "w:abstractNum") {
      Some(value) => value
      None => break
    }
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
              let level_start = match
                find_docx_start_tag_from(inner, j, "w:lvl") {
                Some(value) => value
                None => break
              }
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
    Footnote => DocxDiscoveredPartKind::Footnotes
    Endnote => Endnotes
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
  for part in docx_part_graph_parts_by_kind(part_graph, Comments) {
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
  document_xml : String,
  relationships : Array[@ox.OoxmlRelationship],
  kind : DocxPartBodyKind,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourcePartBody] {
  let out : Array[DocxSourcePartBody] = []
  let suffix = match kind {
    Header => "header"
    Footer => "footer"
    Textbox => "textbox"
  }
  let root_tag = match kind {
    Header => "w:hdr"
    Footer => "w:ftr"
    Textbox => "w:txbxContent"
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
                slot_type: docx_part_body_slot_type(document_xml, rel.id, kind),
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
fn docx_part_body_slot_type(
  document_xml : String,
  relationship_id : String,
  kind : DocxPartBodyKind,
) -> String? {
  let tag_name = match kind {
    Header => "w:headerReference"
    Footer => "w:footerReference"
    Textbox => return None
  }
  let mut offset = 0
  while offset < document_xml.length() {
    match find_docx_start_tag_from(document_xml, offset, tag_name) {
      Some(start) =>
        match docx_open_tag_at(document_xml, start) {
          open_tag => {
            if read_docx_attr_value(open_tag, "r:id") == Some(relationship_id) {
              return read_docx_attr_value(open_tag, "w:type")
            }
            offset = start + open_tag.length()
          }
        }
      None => return None
    }
  }
  None
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
    Footnote => "w:footnote"
    Endnote => "w:endnote"
  }
  let mut i = 0
  let mut note_index = 0
  while i < xml.length() {
    let start = match find_docx_start_tag_from(xml, i, tag) {
      Some(value) => value
      None => break
    }
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
    let start = match find_docx_start_tag_from(xml, i, "w:comment") {
      Some(value) => value
      None => break
    }
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
    let start = match find_docx_start_tag_from(xml, i, "w:txbxContent") {
      Some(value) => value
      None => break
    }
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
            shape_id: docx_textbox_anchor_shape_id(anchor_xml),
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
      match docx_textbox_anchor_vml_attr(anchor_xml, "title") {
        Some(value) => Some(value)
        None => docx_textbox_anchor_vml_attr(anchor_xml, "alt")
      }
  }
}

///|
fn docx_textbox_anchor_shape_id(anchor_xml : String) -> String? {
  docx_textbox_anchor_vml_attr(anchor_xml, "id")
}

///|
fn docx_textbox_anchor_vml_attr(anchor_xml : String, attr : String) -> String? {
  match read_docx_non_empty_attr_in_first_tag(anchor_xml, "v:shape", attr) {
    Some(value) => Some(value)
    None => read_docx_non_empty_attr_in_first_tag(anchor_xml, "v:rect", attr)
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
      kind: MissingContainerPart,
      message: "related DOCX part is missing: " + rel.resolved_target,
      source_key: Some(docx_source_key(rel.resolved_target, 0, "missing")),
    })
    return None
  }
  let text = @ox.read_part_text(pkg, rel.resolved_target) catch {
    e => {
      warnings.push({
        kind: MissingContainerPart,
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
      kind: MissingContainerPart,
      message: "discovered DOCX part is missing: " + part.part_name,
      source_key: Some(docx_source_key(part.part_name, 0, "missing")),
    })
    return None
  }
  let text = @ox.read_part_text(pkg, part.part_name) catch {
    e => {
      warnings.push({
        kind: MissingContainerPart,
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
