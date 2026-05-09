///|
fn parse_pptx_notes(
  pkg : @ox.OoxmlPackage,
  rels : PptxRelationshipIndex,
  issues : Array[PptxValidationIssue],
) -> PptxNotes? raise {
  let part_path = match rels.notes_part {
    Some(part) => part
    None => return None
  }

  if !@ox.has_part(pkg, part_path) {
    issues.push(
      pptx_issue(
        PptxValidationIssueKind::MissingRelationshipTarget,
        PptxValidationSeverity::Warning,
        Some(part_path),
        rels.notes_relationship_id,
        None,
        "missing notes part: " + part_path,
      ),
    )
    return None
  }

  let xml = @ox.read_part_bytes(pkg, part_path) catch { _ => return None }
  let note_rels = read_pptx_relationship_index(pkg, part_path)
  let note_issues : Array[PptxValidationIssue] = []
  let ctx : PptxShapeParseContext = {
    pkg,
    rels: note_rels,
    source_part: part_path,
    issues: note_issues,
  }
  let shapes = parse_pptx_shape_tree(xml, ctx)
  for issue in note_issues {
    issues.push(issue)
  }
  Some({ part_path, paragraphs: collect_shape_paragraphs(shapes) })
}
