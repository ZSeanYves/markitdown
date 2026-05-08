///|
priv struct SheetInfo {
  name : String
  sheet_id : String?
  relationship_id : String
  state : XlsxSheetState
  rel_type : String?
  target : String?
  is_supported_worksheet : Bool
}

///|
/// Open an `.xlsx` file from disk and parse it into a semantic workbook model.
pub fn open_xlsx_workbook(path : String) -> XlsxWorkbook raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise XlsxError::OpenFailed(path + ": " + e.to_string())
  }
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise XlsxError::OoxmlFailure(e.to_string())
  }
  parse_xlsx_workbook_from_package(pkg)
}

///|
/// Parse an already-open OOXML package into an XLSX semantic workbook model.
///
/// RichTable lowering, Markdown output, and sheet-heading product policy stay
/// in `convert/xlsx`.
pub fn parse_xlsx_workbook_from_package(
  pkg : @ox.OoxmlPackage,
) -> XlsxWorkbook raise {
  let workbook_xml = @ox.read_part_text(pkg, "xl/workbook.xml") catch {
    @ox.MissingPart(path) =>
      raise XlsxError::OoxmlFailure("missing workbook part: " + path)
    e => raise XlsxError::OoxmlFailure(e.to_string())
  }

  let shared_strings = if @ox.has_part(pkg, "xl/sharedStrings.xml") {
    let shared_xml = @ox.read_part_text(pkg, "xl/sharedStrings.xml") catch {
      e =>
        raise XlsxError::ParseError(
          "shared strings read failed: " + e.to_string(),
        )
    }
    parse_shared_strings(shared_xml)
  } else {
    []
  }

  let styles = if @ox.has_part(pkg, "xl/styles.xml") {
    let styles_xml = @ox.read_part_text(pkg, "xl/styles.xml") catch {
      e => raise XlsxError::ParseError("styles read failed: " + e.to_string())
    }
    parse_styles_xml(styles_xml)
  } else {
    empty_styles()
  }

  let uses_date_1904 = workbook_uses_date_1904(workbook_xml)
  let sheet_infos = parse_workbook_sheets(pkg, workbook_xml)
  let sheets : Array[XlsxSheet] = []

  for info in sheet_infos {
    let normalized_target = match info.target {
      Some(target) => normalize_sheet_part_target(target)
      None => ""
    }

    if !info.is_supported_worksheet {
      sheets.push(
        empty_sheet_model(
          info.name,
          info.sheet_id,
          Some(info.relationship_id),
          info.rel_type,
          if normalized_target == "" {
            None
          } else {
            Some(normalized_target)
          },
          info.state,
          false,
          false,
          [],
        ),
      )
      continue
    }

    if normalized_target == "" {
      sheets.push(
        empty_sheet_model(
          info.name,
          info.sheet_id,
          Some(info.relationship_id),
          info.rel_type,
          None,
          info.state,
          true,
          false,
          [
            sheet_issue(
              XlsxValidationIssueKind::MissingWorksheetPart,
              XlsxValidationSeverity::Error,
              info.name,
              None,
              None,
              "worksheet relationship target is missing",
            ),
          ],
        ),
      )
      continue
    }

    let sheet_xml = @ox.read_part_text(pkg, normalized_target) catch {
      _ => {
        sheets.push(
          empty_sheet_model(
            info.name,
            info.sheet_id,
            Some(info.relationship_id),
            info.rel_type,
            Some(normalized_target),
            info.state,
            true,
            false,
            [
              sheet_issue(
                XlsxValidationIssueKind::MissingWorksheetPart,
                XlsxValidationSeverity::Error,
                info.name,
                None,
                Some(normalized_target),
                "worksheet part is missing or unreadable",
              ),
            ],
          ),
        )
        continue
      }
    }

    let sheet = parse_sheet_model(
      info.name,
      info.sheet_id,
      Some(info.relationship_id),
      info.rel_type,
      Some(normalized_target),
      info.state,
      sheet_xml,
      shared_strings,
      styles,
      uses_date_1904,
    )
    sheets.push(sheet)
  }

  {
    shared_strings,
    styles,
    uses_date_1904,
    sheets,
    issues: workbook_level_issues(sheets),
  }
}

///|
/// Classify a hard XLSX open or parse failure into a stable error kind.
pub fn classify_xlsx_error(err : XlsxError) -> XlsxErrorInfo {
  let detail = err.to_string()
  let lowered = detail.to_lower()
  let kind = match err {
    XlsxError::OpenFailed(_) => XlsxErrorKind::OpenFailed
    XlsxError::OoxmlFailure(_) =>
      if lowered.contains("missing workbook part") ||
        lowered.contains("xl/workbook.xml") {
        XlsxErrorKind::MissingWorkbook
      } else {
        XlsxErrorKind::OoxmlFailure
      }
    XlsxError::ParseError(_) =>
      if lowered.contains("cell reference") {
        XlsxErrorKind::InvalidCellReference
      } else if lowered.contains("sheet xml") || lowered.contains("worksheet") {
        XlsxErrorKind::MalformedSheetXml
      } else if lowered.contains("workbook") {
        XlsxErrorKind::MalformedWorkbookXml
      } else {
        XlsxErrorKind::Unknown
      }
  }
  { kind, detail }
}

///|
fn workbook_level_issues(
  sheets : Array[XlsxSheet],
) -> Array[XlsxValidationIssue] {
  let issues : Array[XlsxValidationIssue] = []
  let seen : Map[String, Int] = Map::new()

  for sheet in sheets {
    let count = seen.get(sheet.name).unwrap_or(0)
    seen.set(sheet.name, count + 1)
  }

  for sheet in sheets {
    if seen.get(sheet.name).unwrap_or(0) > 1 {
      issues.push({
        kind: XlsxValidationIssueKind::DuplicateSheetName,
        severity: XlsxValidationSeverity::Error,
        sheet_name: Some(sheet.name),
        cell_reference: None,
        part_target: sheet.part_target,
        message: "duplicate sheet name: " + sheet.name,
      })
      ignore(seen.remove(sheet.name))
    }
  }

  issues
}

///|
fn parse_sheet_state(value : String) -> XlsxSheetState {
  if value == "hidden" {
    XlsxSheetState::Hidden
  } else if value == "veryHidden" {
    XlsxSheetState::VeryHidden
  } else {
    XlsxSheetState::Visible
  }
}

///|
fn is_supported_sheet_relationship(rel_type : String?) -> Bool {
  match rel_type {
    Some(v) => v.has_suffix("/worksheet")
    None => false
  }
}

///|
fn parse_workbook_sheets(
  pkg : @ox.OoxmlPackage,
  workbook_xml : String,
) -> Array[SheetInfo] {
  let out : Array[SheetInfo] = []
  let mut pos = 0

  while true {
    let idx = find_sub(workbook_xml, "<sheet", pos)
    match idx {
      None => break
      Some(i0) => {
        let j = find_sub(workbook_xml, ">", i0)
        match j {
          None => break
          Some(i1) => {
            let tag = workbook_xml[i0:i1 + 1].to_owned()
            let name = get_attr(tag, "name").unwrap_or("Sheet")
            let sheet_id = get_attr(tag, "sheetId")
            let rid = get_attr(tag, "r:id").unwrap_or("")
            let state = parse_sheet_state(get_attr(tag, "state").unwrap_or(""))
            if rid != "" {
              let rel = @ox.find_relationship_by_id(pkg, "xl/workbook.xml", rid) catch {
                _ => None
              }
              let (rel_type, target) = match rel {
                Some(info) => (Some(info.rel_type), Some(info.resolved_target))
                None => (None, None)
              }
              out.push({
                name,
                sheet_id,
                relationship_id: rid,
                state,
                rel_type,
                target,
                is_supported_worksheet: is_supported_sheet_relationship(
                  rel_type,
                ),
              })
            }
            pos = i1 + 1
          }
        }
      }
    }
  }

  out
}

///|
fn normalize_sheet_part_target(target : String) -> String {
  let trimmed = target.trim().to_owned()
  if trimmed == "" {
    return ""
  }

  if trimmed.has_prefix("/") {
    trimmed[1:].to_owned()
  } else {
    trimmed
  }
}

///|
fn workbook_uses_date_1904(workbook_xml : String) -> Bool {
  let idx = find_sub(workbook_xml, "<workbookPr", 0)
  match idx {
    None => false
    Some(i0) => {
      let gt0 = find_sub(workbook_xml, ">", i0)
      match gt0 {
        None => false
        Some(i1) => {
          let tag = workbook_xml[i0:i1 + 1].to_owned()
          let raw = get_attr(tag, "date1904").unwrap_or("")
          raw == "1" || raw == "true"
        }
      }
    }
  }
}
