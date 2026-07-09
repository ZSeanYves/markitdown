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
    let start = match find_docx_char_from(xml, i, 60) {
      Some(value) => value
      None => break
    }
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
            xml, start, end_exclusive, link_key, relationships, pkg, warnings,
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
    } else if docx_string_has_prefix_at(xml, start, "</") {
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
    let start = match find_docx_char_from(xml, i, 60) {
      Some(value) => value
      None => break
    }
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
      let open_end = match find_docx_any_tag_end(xml, start) {
        Some(value) => value
        None => break
      }
      let text_start = open_end
      let close_start = match
        find_docx_literal_from(xml, text_start, "</w:t>") {
        Some(value) => value
        None => break
      }
      let text = decode_docx_text(xml[text_start:close_start].to_owned())
      if text != "" {
        inlines.push(DocxSourceInline::Text(text))
        inline_index += 1
      }
      i = close_start + "</w:t>".length()
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
    } else if is_docx_start_tag_at(xml, start, "mc:AlternateContent") {
      match find_docx_element_end(xml, start, "mc:AlternateContent") {
        Some(end_exclusive) => {
          let alt_key = docx_child_source_key(
            run_key, "alternate", inline_index,
          )
          let alt_inlines = parse_docx_alternate_content_inlines(
            xml, start, end_exclusive, alt_key, relationships, pkg, warnings,
          )
          if alt_inlines.length() > 0 {
            inlines.append(alt_inlines[:])
            inline_index += alt_inlines.length()
          }
          i = end_exclusive
        }
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
              doc_pr_id: None,
              shape_id: None,
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
            xml, start, end_exclusive, link_key, relationships, pkg, warnings,
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
    } else if docx_non_visible_run_child(xml, start) {
      match skip_docx_element_or_tag(xml, start, docx_tag_name_at(xml, start)) {
        Some(end_exclusive) => i = end_exclusive
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
    } else if docx_string_has_prefix_at(xml, start, "</") {
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
fn parse_docx_alternate_content_inlines(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceInline] {
  let inner = docx_inner_xml_for_element(
    xml, start, end_exclusive, "mc:AlternateContent",
  )
  let chosen = match find_docx_start_tag_from(inner, 0, "mc:Choice") {
    Some(choice_start) =>
      match find_docx_element_end(inner, choice_start, "mc:Choice") {
        Some(choice_end) =>
          docx_inner_xml_for_element(
            inner, choice_start, choice_end, "mc:Choice",
          )
        None => ""
      }
    None =>
      match find_docx_start_tag_from(inner, 0, "mc:Fallback") {
        Some(fallback_start) =>
          match find_docx_element_end(inner, fallback_start, "mc:Fallback") {
            Some(fallback_end) =>
              docx_inner_xml_for_element(
                inner, fallback_start, fallback_end, "mc:Fallback",
              )
            None => ""
          }
        None => ""
      }
  }
  if chosen == "" {
    []
  } else {
    parse_docx_run_inlines(chosen, key, relationships, pkg, warnings)
  }
}

///|
fn docx_non_visible_run_child_tags() -> Array[String] {
  [
    "w:annotationRef", "w:footnoteRef", "w:endnoteRef", "w:separator", "w:continuationSeparator",
  ]
}

///|
fn docx_non_visible_run_child(xml : String, start : Int) -> Bool {
  for tag in docx_non_visible_run_child_tags() {
    if is_docx_start_tag_at(xml, start, tag) {
      return true
    }
  }
  false
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
  let mut i = if from < 0 { 0 } else { from }
  while i < xml.length() {
    let pos = match find_docx_char_from(xml, i, 60) {
      Some(value) => value
      None => return None
    }
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
