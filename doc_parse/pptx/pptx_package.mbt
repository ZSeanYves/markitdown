///|
/// Open a `.pptx` file from disk and parse it into a semantic presentation
/// model.
pub fn open_pptx_presentation(path : String) -> PptxPresentation raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise PptxError::OpenFailed(path + ": " + e.to_string())
  }
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise PptxError::OoxmlFailure(e.to_string())
  }
  parse_pptx_presentation_from_package(pkg)
}

///|
/// Parse an already-open OOXML package into a source-native PPTX semantic
/// model.
///
/// Reading order, layout recovery, grouping, caption policy, asset export, and
/// final Markdown/IR lowering remain in `convert/pptx`.
pub fn parse_pptx_presentation_from_package(
  pkg : @ox.OoxmlPackage,
) -> PptxPresentation raise {
  let pres_xml = @ox.read_part_text(pkg, "ppt/presentation.xml") catch {
    @ox.MissingPart(path) =>
      raise PptxError::OoxmlFailure("missing presentation part: " + path)
    e => raise PptxError::OoxmlFailure(e.to_string())
  }
  if !pres_xml.contains("<p:presentation") {
    raise PptxError::ParseError(
      "malformed presentation xml: missing <p:presentation>",
    )
  }

  let issues : Array[PptxValidationIssue] = []
  let relationships = read_pptx_relationship_index(pkg, "ppt/presentation.xml")
  let raw_entries = parse_presentation_slide_entries(pres_xml)
  let slide_entries : Array[PptxSlideEntry] = []

  if raw_entries.length() > 0 {
    for raw in raw_entries {
      match raw.rel_id {
        Some(rid) =>
          match find_pptx_relationship_by_id(relationships, rid) {
            Some(rel) =>
              if rel.rel_type.has_suffix("/slide") &&
                rel.resolved_target.has_prefix("ppt/slides/") &&
                rel.resolved_target.has_suffix(".xml") {
                slide_entries.push({
                  slide_id: raw.slide_id,
                  part_name: rel.resolved_target,
                  rel_id: Some(rid),
                  hidden: raw.hidden,
                })
              } else {
                issues.push(
                  pptx_issue(
                    PptxValidationIssueKind::MissingRelationshipTarget,
                    PptxValidationSeverity::Warning,
                    Some("ppt/presentation.xml"),
                    Some(rid),
                    None,
                    "missing slide relationship target: " + rid,
                  ),
                )
              }
            None =>
              issues.push(
                pptx_issue(
                  PptxValidationIssueKind::MissingRelationshipTarget,
                  PptxValidationSeverity::Warning,
                  Some("ppt/presentation.xml"),
                  Some(rid),
                  None,
                  "missing slide relationship target: " + rid,
                ),
              )
          }
        None => ()
      }
    }
  } else {
    for part_name in list_slide_part_names(pkg) {
      slide_entries.push({
        slide_id: None,
        part_name,
        rel_id: None,
        hidden: false,
      })
    }
  }

  let slides : Array[PptxSlide] = []
  let media_refs : Array[PptxMediaRef] = []
  let hyperlink_refs : Array[PptxHyperlink] = []

  let mut index = 1
  for entry in slide_entries {
    if !@ox.has_part(pkg, entry.part_name) {
      issues.push(
        pptx_issue(
          PptxValidationIssueKind::MissingSlidePart,
          PptxValidationSeverity::Warning,
          Some(entry.part_name),
          entry.rel_id,
          None,
          "missing slide part: " + entry.part_name,
        ),
      )
      index += 1
      continue
    }
    let slide = parse_pptx_slide(pkg, entry, index)
    for issue in slide.issues {
      issues.push(issue)
    }
    for media in slide.media_refs {
      media_refs.push(media)
    }
    for link in slide.hyperlink_refs {
      hyperlink_refs.push(link)
    }
    slides.push(slide)
    index += 1
  }

  { slides, relationships, media_refs, hyperlink_refs, issues }
}

///|
/// Classify a hard PPTX open or parse failure into a stable error kind.
pub fn classify_pptx_error(err : PptxError) -> PptxErrorInfo {
  let detail = err.to_string()
  let lowered = detail.to_lower()
  let kind = match err {
    PptxError::OpenFailed(_) => PptxErrorKind::OpenFailed
    PptxError::OoxmlFailure(_) =>
      if lowered.contains("missing presentation part") ||
        lowered.contains("ppt/presentation.xml") {
        PptxErrorKind::MissingPresentation
      } else {
        PptxErrorKind::OoxmlFailure
      }
    PptxError::ParseError(_) =>
      if lowered.contains("presentation xml") {
        PptxErrorKind::MalformedPresentationXml
      } else if lowered.contains("slide xml") {
        PptxErrorKind::MalformedSlideXml
      } else {
        PptxErrorKind::Unknown
      }
  }
  { kind, detail }
}
