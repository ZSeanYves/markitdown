///|
pub fn inspect_odt_document(document : OdtDocument) -> OdtInspectReport {
  let mut heading_count = 0
  let mut paragraph_count = 0
  let mut list_item_count = 0
  let mut code_block_count = 0
  let mut raw_block_count = 0
  let mut table_count = 0
  let mut image_count = 0
  let mut max_heading_level = 0
  for block in document.blocks {
    match block.kind {
      Heading => {
        heading_count += 1
        match block.level {
          Some(level) =>
            if level > max_heading_level {
              max_heading_level = level
            }
          None => ()
        }
      }
      Paragraph => paragraph_count += 1
      ListItem => list_item_count += 1
      Code => code_block_count += 1
      NoteDefinition => paragraph_count += 1
      Raw => raw_block_count += 1
      Table => table_count += 1
      Image => image_count += 1
    }
  }
  {
    block_count: document.blocks.length(),
    heading_count,
    paragraph_count,
    list_item_count,
    code_block_count,
    raw_block_count,
    table_count,
    image_count,
    max_heading_level,
  }
}

///|
pub fn inspect_ods_document(document : OdsDocument) -> OdsInspectReport {
  let mut visible_sheet_count = 0
  let mut hidden_sheet_count = 0
  let mut row_count = 0
  let mut non_empty_row_count = 0
  let mut cell_count = 0
  let mut max_sheet_rows = 0
  let mut max_sheet_cols = 0
  for sheet in document.sheets {
    if sheet.visible {
      visible_sheet_count += 1
    } else {
      hidden_sheet_count += 1
    }
    if sheet.rows.length() > max_sheet_rows {
      max_sheet_rows = sheet.rows.length()
    }
    for row in sheet.rows {
      row_count += 1
      if ods_row_has_visible_content(row) {
        non_empty_row_count += 1
      }
      cell_count += row.cells.length()
      if row.cells.length() > max_sheet_cols {
        max_sheet_cols = row.cells.length()
      }
    }
  }
  {
    sheet_count: document.sheets.length(),
    visible_sheet_count,
    hidden_sheet_count,
    row_count,
    non_empty_row_count,
    cell_count,
    max_sheet_rows,
    max_sheet_cols,
  }
}

///|
fn ods_row_has_visible_content(row : OdsRow) -> Bool {
  for cell in row.cells {
    if cell.text != "" || cell.formula is Some(_) {
      return true
    }
  }
  false
}

///|
pub fn inspect_odp_document(document : OdpDocument) -> OdpInspectReport {
  let mut block_count = 0
  let mut heading_count = 0
  let mut paragraph_count = 0
  let mut list_item_count = 0
  let mut table_count = 0
  let mut image_count = 0
  let mut notes_count = 0
  let mut raw_block_count = 0
  for slide in document.slides {
    for block in slide.blocks {
      block_count += 1
      match block.kind {
        Heading => heading_count += 1
        Paragraph => paragraph_count += 1
        ListItem => list_item_count += 1
        Table => table_count += 1
        Image => image_count += 1
        Notes => notes_count += 1
        Raw => raw_block_count += 1
      }
    }
  }
  {
    slide_count: document.slides.length(),
    block_count,
    heading_count,
    paragraph_count,
    list_item_count,
    table_count,
    image_count,
    notes_count,
    raw_block_count,
  }
}
