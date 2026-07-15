///|
fn parse_docx_body_blocks(
  part_name : String,
  xml : String,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceBlock] raise DocxError {
  let body_start = match find_docx_start_tag_from(xml, 0, "w:body") {
    Some(pos) => pos
    None => raise DocxError::MalformedDocument("missing <w:body>")
  }
  let body_open_end = match find_docx_any_tag_end(xml, body_start) {
    Some(pos) => pos
    None => raise DocxError::MalformedDocument("invalid <w:body> tag")
  }
  let body_content_start = body_open_end
  let body_close = match
    find_docx_literal_from(xml, body_content_start, "</w:body>") {
    Some(pos) => pos
    None => raise DocxError::MalformedDocument("missing </w:body>")
  }
  let body = xml[body_content_start:body_close].to_owned()
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
    let start = match find_docx_char_from(body, i, 60) {
      Some(value) => value
      None => break
    }
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
    } else if docx_string_has_prefix_at(body, start, "</") {
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
    let start = match find_docx_char_from(inner, i, 60) {
      Some(value) => value
      None => break
    }
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
    let start = match find_docx_char_from(inner, i, 60) {
      Some(value) => value
      None => break
    }
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
    let start = match find_docx_char_from(xml, i, 60) {
      Some(value) => value
      None => break
    }
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
        blocks.push({
          kind: DocxSourceBlockKind::Table,
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
          raw_tag: Some("w:tbl"),
        })
        block_index += 1
        break
      }
      match find_docx_element_end(xml, start, "w:tbl") {
        Some(end_exclusive) => {
          let table = Some(
            parse_docx_table(
              xml[start:end_exclusive].to_owned(),
              key,
              next_depth,
              relationships,
              pkg,
              warnings,
            ),
          )
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
    } else if docx_string_has_prefix_at(xml, start, "</") {
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
