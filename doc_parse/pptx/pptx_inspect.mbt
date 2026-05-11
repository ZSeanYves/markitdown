///|
/// Return PPTX validation issues without treating them as default hard
/// failures.
pub fn collect_pptx_validation_issues(
  pres : PptxPresentation,
) -> Array[PptxValidationIssue] {
  let issues : Array[PptxValidationIssue] = []
  for issue in pres.issues {
    issues.push(issue)
  }
  issues
}

///|
/// Aggregate PPTX validation counts and issues into a deterministic report.
pub fn validate_pptx_presentation(
  pres : PptxPresentation,
) -> PptxValidationReport {
  let issues = collect_pptx_validation_issues(pres)
  let mut warning_count = 0
  let mut error_count = 0
  for issue in issues {
    match issue.severity {
      PptxValidationSeverity::Warning => warning_count += 1
      PptxValidationSeverity::Error => error_count += 1
    }
  }
  { issue_count: issues.length(), warning_count, error_count, issues }
}

///|
fn inspect_shape_tree(
  shapes : Array[PptxShape],
  shape_count : Ref[Int],
  group_shape_count : Ref[Int],
  text_shape_count : Ref[Int],
  paragraph_count : Ref[Int],
  text_run_count : Ref[Int],
  table_count : Ref[Int],
  chart_count : Ref[Int],
) -> Unit {
  for shape in shapes {
    shape_count.val += 1
    if shape.kind == PptxShapeKind::Group {
      group_shape_count.val += 1
    }
    if shape.text_paragraphs.length() > 0 {
      text_shape_count.val += 1
      paragraph_count.val += shape.text_paragraphs.length()
      for para in shape.text_paragraphs {
        text_run_count.val += para.runs.length()
      }
    }
    match shape.table {
      Some(table) => {
        table_count.val += 1
        for row in table.rows {
          for cell in row.cells {
            paragraph_count.val += cell.paragraphs.length()
            for para in cell.paragraphs {
              text_run_count.val += para.runs.length()
            }
          }
        }
      }
      None => ()
    }
    match shape.chart {
      Some(_) => chart_count.val += 1
      None => ()
    }
    inspect_shape_tree(
      shape.children,
      shape_count,
      group_shape_count,
      text_shape_count,
      paragraph_count,
      text_run_count,
      table_count,
      chart_count,
    )
  }
}

///|
/// Summarize structure and raw semantic signals for a parsed PPTX
/// presentation.
pub fn inspect_pptx_presentation(pres : PptxPresentation) -> PptxInspectReport {
  let validation = validate_pptx_presentation(pres)
  let shape_count : Ref[Int] = { val: 0 }
  let group_shape_count : Ref[Int] = { val: 0 }
  let text_shape_count : Ref[Int] = { val: 0 }
  let paragraph_count : Ref[Int] = { val: 0 }
  let text_run_count : Ref[Int] = { val: 0 }
  let table_count : Ref[Int] = { val: 0 }
  let chart_count : Ref[Int] = { val: 0 }
  let mut hidden_slide_count = 0
  let mut image_ref_count = 0
  let mut notes_count = 0
  let mut comment_count = 0

  for slide in pres.slides {
    if slide.hidden {
      hidden_slide_count += 1
    }
    inspect_shape_tree(
      slide.shape_tree,
      shape_count,
      group_shape_count,
      text_shape_count,
      paragraph_count,
      text_run_count,
      table_count,
      chart_count,
    )
    match slide.notes {
      Some(note_doc) => {
        notes_count += 1
        paragraph_count.val += note_doc.paragraphs.length()
        for para in note_doc.paragraphs {
          text_run_count.val += para.runs.length()
        }
      }
      None => ()
    }
    comment_count += slide.comments.length()
    for media in slide.media_refs {
      if media.kind == PptxMediaKind::Image {
        image_ref_count += 1
      }
    }
  }

  {
    slide_count: pres.slides.length(),
    hidden_slide_count,
    shape_count: shape_count.val,
    group_shape_count: group_shape_count.val,
    text_shape_count: text_shape_count.val,
    paragraph_count: paragraph_count.val,
    text_run_count: text_run_count.val,
    table_count: table_count.val,
    chart_count: chart_count.val,
    image_ref_count,
    media_ref_count: pres.media_refs.length(),
    hyperlink_count: pres.hyperlink_refs.length(),
    notes_count,
    comment_count,
    issue_count: validation.issue_count,
    warning_count: validation.warning_count,
    error_count: validation.error_count,
  }
}
