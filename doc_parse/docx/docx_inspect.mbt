///|
/// Return DOCX validation issues without treating them as default hard
/// failures.
pub fn collect_docx_validation_issues(
  doc : DocxDocument,
) -> Array[DocxValidationIssue] {
  let issues : Array[DocxValidationIssue] = []
  for issue in doc.issues {
    issues.push(issue)
  }
  issues
}

///|
/// Aggregate DOCX validation counts and issues into a deterministic report.
pub fn validate_docx_document(doc : DocxDocument) -> DocxValidationReport {
  let issues = collect_docx_validation_issues(doc)
  let mut warning_count = 0
  let mut error_count = 0

  for issue in issues {
    match issue.severity {
      DocxValidationSeverity::Warning => warning_count += 1
      DocxValidationSeverity::Error => error_count += 1
    }
  }

  { issue_count: issues.length(), warning_count, error_count, issues }
}

///|
fn inspect_docx_blocks(
  blocks : Array[DocxBodyBlock],
  paragraph_count : Ref[Int],
  run_count : Ref[Int],
  text_run_count : Ref[Int],
  table_count : Ref[Int],
  table_row_count : Ref[Int],
  table_cell_count : Ref[Int],
  hyperlink_count : Ref[Int],
  media_ref_count : Ref[Int],
  image_ref_count : Ref[Int],
  numbering_ref_count : Ref[Int],
) -> Unit {
  for block in blocks {
    match block {
      DocxBodyBlock::Paragraph(paragraph) => {
        paragraph_count.val += 1
        if paragraph.numbering_ref is Some(_) {
          numbering_ref_count.val += 1
        }
        hyperlink_count.val += paragraph.hyperlink_refs.length()
        media_ref_count.val += paragraph.media_refs.length()
        for media in paragraph.media_refs {
          match media.content_type {
            Some(t) => if t.has_prefix("image/") { image_ref_count.val += 1 }
            None =>
              match media.target_part {
                Some(target) =>
                  if target.has_prefix("word/media/") {
                    image_ref_count.val += 1
                  }
                None => ()
              }
          }
        }

        for run in paragraph.runs {
          run_count.val += 1
          let mut has_text = false
          for inline in run.inlines {
            match inline {
              DocxInline::Text(text) => if text != "" { has_text = true }
              DocxInline::Hyperlink(link) =>
                if link.text != "" {
                  has_text = true
                }
              _ => ()
            }
          }
          if has_text {
            text_run_count.val += 1
          }
        }
      }
      DocxBodyBlock::Table(table) => {
        table_count.val += 1
        table_row_count.val += table.rows.length()
        for row in table.rows {
          table_cell_count.val += row.cells.length()
          for cell in row.cells {
            inspect_docx_blocks(
              cell.body_blocks,
              paragraph_count,
              run_count,
              text_run_count,
              table_count,
              table_row_count,
              table_cell_count,
              hyperlink_count,
              media_ref_count,
              image_ref_count,
              numbering_ref_count,
            )
          }
        }
      }
    }
  }
}

///|
/// Summarize structure and raw semantic signals for a parsed DOCX document.
pub fn inspect_docx_document(doc : DocxDocument) -> DocxInspectReport {
  let validation = validate_docx_document(doc)
  let paragraph_count : Ref[Int] = { val: 0 }
  let run_count : Ref[Int] = { val: 0 }
  let text_run_count : Ref[Int] = { val: 0 }
  let table_count : Ref[Int] = { val: 0 }
  let table_row_count : Ref[Int] = { val: 0 }
  let table_cell_count : Ref[Int] = { val: 0 }
  let hyperlink_count : Ref[Int] = { val: 0 }
  let media_ref_count : Ref[Int] = { val: 0 }
  let image_ref_count : Ref[Int] = { val: 0 }
  let numbering_ref_count : Ref[Int] = { val: 0 }

  inspect_docx_blocks(
    doc.body_blocks,
    paragraph_count,
    run_count,
    text_run_count,
    table_count,
    table_row_count,
    table_cell_count,
    hyperlink_count,
    media_ref_count,
    image_ref_count,
    numbering_ref_count,
  )
  for note in doc.notes.footnotes {
    inspect_docx_blocks(
      note.body_blocks,
      paragraph_count,
      run_count,
      text_run_count,
      table_count,
      table_row_count,
      table_cell_count,
      hyperlink_count,
      media_ref_count,
      image_ref_count,
      numbering_ref_count,
    )
  }
  for note in doc.notes.endnotes {
    inspect_docx_blocks(
      note.body_blocks,
      paragraph_count,
      run_count,
      text_run_count,
      table_count,
      table_row_count,
      table_cell_count,
      hyperlink_count,
      media_ref_count,
      image_ref_count,
      numbering_ref_count,
    )
  }
  for comment in doc.notes.comments {
    inspect_docx_blocks(
      comment.body_blocks,
      paragraph_count,
      run_count,
      text_run_count,
      table_count,
      table_row_count,
      table_cell_count,
      hyperlink_count,
      media_ref_count,
      image_ref_count,
      numbering_ref_count,
    )
  }
  for header in doc.headers {
    inspect_docx_blocks(
      header.body_blocks,
      paragraph_count,
      run_count,
      text_run_count,
      table_count,
      table_row_count,
      table_cell_count,
      hyperlink_count,
      media_ref_count,
      image_ref_count,
      numbering_ref_count,
    )
  }
  for footer in doc.footers {
    inspect_docx_blocks(
      footer.body_blocks,
      paragraph_count,
      run_count,
      text_run_count,
      table_count,
      table_row_count,
      table_cell_count,
      hyperlink_count,
      media_ref_count,
      image_ref_count,
      numbering_ref_count,
    )
  }
  for box in doc.text_boxes {
    inspect_docx_blocks(
      box.body_blocks,
      paragraph_count,
      run_count,
      text_run_count,
      table_count,
      table_row_count,
      table_cell_count,
      hyperlink_count,
      media_ref_count,
      image_ref_count,
      numbering_ref_count,
    )
  }

  {
    paragraph_count: paragraph_count.val,
    run_count: run_count.val,
    text_run_count: text_run_count.val,
    table_count: table_count.val,
    table_row_count: table_row_count.val,
    table_cell_count: table_cell_count.val,
    hyperlink_count: hyperlink_count.val,
    media_ref_count: media_ref_count.val,
    image_ref_count: image_ref_count.val,
    numbering_ref_count: numbering_ref_count.val,
    style_count: doc.styles.styles.length(),
    note_count: doc.notes.footnotes.length() +
    doc.notes.endnotes.length() +
    doc.notes.comments.length(),
    header_count: doc.headers.length(),
    footer_count: doc.footers.length(),
    text_box_count: doc.text_boxes.length(),
    issue_count: validation.issue_count,
    warning_count: validation.warning_count,
    error_count: validation.error_count,
  }
}
