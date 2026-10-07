///|
pub fn inspect_odt_document(document : OdtDocument) -> OdtInspectReport {
  let mut heading_count = 0
  let mut paragraph_count = 0
  let mut list_item_count = 0
  let mut code_block_count = 0
  let mut raw_block_count = 0
  let mut table_count = 0
  let mut image_count = 0
  let mut note_count = 0
  let mut comment_count = 0
  let mut max_heading_level = 0
  for block in document.blocks {
    if block.note is Some(note) {
      if note.kind == "comment" {
        comment_count += 1
      } else {
        note_count += 1
      }
    }
    for inline in block.inlines {
      match inline.note_kind {
        Some("comment") => comment_count += 1
        Some(_) => note_count += 1
        None => ()
      }
    }
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
    note_count,
    comment_count,
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
  let mut used_cell_count = 0
  let mut hidden_row_count = 0
  let mut covered_cell_count = 0
  let mut max_sheet_rows = 0
  let mut max_sheet_cols = 0
  let mut max_used_cols = 0
  for sheet in document.sheets {
    if sheet.visible {
      visible_sheet_count += 1
    } else {
      hidden_sheet_count += 1
    }
    let mut sheet_row_span = 0
    for row in sheet.rows {
      sheet_row_span += row.repeat_count
      row_count += row.repeat_count
      if row.hidden {
        hidden_row_count += row.repeat_count
      }
      if ods_row_has_visible_content(row) {
        non_empty_row_count += row.repeat_count
      }
      let row_cell_count = ods_row_cell_count(row)
      let row_used_cell_count = ods_row_used_cell_count(row)
      cell_count += row_cell_count * row.repeat_count
      used_cell_count += row_used_cell_count * row.repeat_count
      if row_cell_count > max_sheet_cols {
        max_sheet_cols = row_cell_count
      }
      if row_used_cell_count > max_used_cols {
        max_used_cols = row_used_cell_count
      }
      for cell in row.cells {
        if cell.covered {
          covered_cell_count += cell.repeat_count * row.repeat_count
        }
      }
    }
    if sheet_row_span > max_sheet_rows {
      max_sheet_rows = sheet_row_span
    }
  }
  {
    sheet_count: document.sheets.length(),
    visible_sheet_count,
    hidden_sheet_count,
    row_count,
    non_empty_row_count,
    cell_count,
    used_cell_count,
    hidden_row_count,
    covered_cell_count,
    max_sheet_rows,
    max_sheet_cols,
    max_used_cols,
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
fn ods_row_cell_count(row : OdsRow) -> Int {
  let mut count = 0
  for cell in row.cells {
    count += cell.repeat_count
  }
  count
}

///|
fn ods_row_used_cell_count(row : OdsRow) -> Int {
  let mut width = 0
  for cell in row.cells {
    let cell_width = if cell.covered {
      0
    } else if cell.text != "" || cell.formula is Some(_) {
      max_int(cell.col_span, 1)
    } else {
      0
    }
    if cell_width > 0 {
      width += cell_width
    }
  }
  width
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
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
