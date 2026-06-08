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
/// Benchmark-oriented profiled parse helper used for internal hotspot
/// attribution.
///
/// This does not change the semantic workbook model or conversion behavior.
pub fn profile_xlsx_workbook_from_package(
  pkg : @ox.OoxmlPackage,
) -> XlsxProfiledWorkbook raise {
  let report = new_xlsx_parse_profile_report()
  let workbook = parse_xlsx_workbook_from_package_with_profile(
    pkg,
    Some(report),
  )
  { workbook, report }
}

///|
/// Parse an already-open OOXML package into an XLSX semantic workbook model.
///
/// RichTable lowering, Markdown output, and sheet-heading product policy stay
/// in `convert/xlsx`.
pub fn parse_xlsx_workbook_from_package(
  pkg : @ox.OoxmlPackage,
) -> XlsxWorkbook raise {
  parse_xlsx_workbook_from_package_with_profile(pkg, None)
}

///|
fn parse_xlsx_workbook_from_package_with_profile(
  pkg : @ox.OoxmlPackage,
  profile : XlsxParseProfileReport?,
) -> XlsxWorkbook raise {
  let workbook_started = xlsx_parse_profile_stage_started(profile)
  let workbook_xml = @ox.read_part_text(pkg, "xl/workbook.xml") catch {
    @ox.MissingPart(path) =>
      raise XlsxError::OoxmlFailure("missing workbook part: " + path)
    e => raise XlsxError::OoxmlFailure(e.to_string())
  }
  xlsx_parse_profile_stage_finished(
    profile,
    "workbook_xml",
    workbook_started,
    Some("bytes=" + workbook_xml.length().to_string()),
  )

  let shared_strings_started = xlsx_parse_profile_stage_started(profile)
  let shared_string_issues : Array[XlsxValidationIssue] = []
  let shared_strings = if @ox.has_part(pkg, "xl/sharedStrings.xml") {
    let shared_xml = @ox.read_part_text(pkg, "xl/sharedStrings.xml") catch {
      e =>
        raise XlsxError::ParseError(
          "shared strings read failed: " + e.to_string(),
        )
    }
    let (parsed, issues) = parse_shared_strings(shared_xml)
    shared_string_issues.append(issues)
    parsed
  } else {
    []
  }
  xlsx_parse_profile_stage_finished(
    profile,
    "shared_strings",
    shared_strings_started,
    Some("count=" + shared_strings.length().to_string()),
  )

  let styles_started = xlsx_parse_profile_stage_started(profile)
  let styles = if @ox.has_part(pkg, "xl/styles.xml") {
    let styles_xml = @ox.read_part_text(pkg, "xl/styles.xml") catch {
      e => raise XlsxError::ParseError("styles read failed: " + e.to_string())
    }
    parse_styles_xml(styles_xml)
  } else {
    empty_styles()
  }
  xlsx_parse_profile_stage_finished(
    profile,
    "styles",
    styles_started,
    Some(
      "xf_numfmts=" +
      styles.xf_numfmts.length().to_string() +
      " custom_numfmts=" +
      styles.custom_numfmts.length().to_string(),
    ),
  )

  let metadata_started = xlsx_parse_profile_stage_started(profile)
  let metadata = parse_xlsx_workbook_metadata(pkg)
  xlsx_parse_profile_stage_finished(
    profile,
    "document_properties",
    metadata_started,
    Some(
      "custom_properties=" +
      metadata.custom_properties.length().to_string(),
    ),
  )

  let workbook_flags_started = xlsx_parse_profile_stage_started(profile)
  let uses_date_1904 = workbook_uses_date_1904(workbook_xml)
  xlsx_parse_profile_stage_finished(
    profile,
    "workbook_flags",
    workbook_flags_started,
    Some("uses_date_1904=" + uses_date_1904.to_string()),
  )
  let sheet_infos_started = xlsx_parse_profile_stage_started(profile)
  let (sheet_infos, sheet_info_issues) = parse_workbook_sheets(
    pkg, workbook_xml,
  )
  xlsx_parse_profile_stage_finished(
    profile,
    "sheet_infos",
    sheet_infos_started,
    Some("count=" + sheet_infos.length().to_string()),
  )
  let defined_names_started = xlsx_parse_profile_stage_started(profile)
  let (defined_names, defined_name_issues) = parse_workbook_defined_names(
    workbook_xml, sheet_infos,
  )
  xlsx_parse_profile_stage_finished(
    profile,
    "defined_names",
    defined_names_started,
    Some("count=" + defined_names.length().to_string()),
  )
  let sheets : Array[XlsxSheet] = []
  let total_cell_budget_remaining : Ref[Int] = {
    val: xlsx_max_total_cells(),
  }

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

    let sheet_xml_started = xlsx_parse_profile_stage_started(profile)
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
    xlsx_parse_profile_stage_finished(
      profile,
      "sheet:" + info.name + ":read_xml",
      sheet_xml_started,
      Some("bytes=" + sheet_xml.length().to_string()),
    )

    let sheet_relationships_started = xlsx_parse_profile_stage_started(profile)
    let (sheet_relationships, sheet_relationship_issues) = read_sheet_relationships(
      pkg,
      normalized_target,
    )
    xlsx_parse_profile_stage_finished(
      profile,
      "sheet:" + info.name + ":relationships",
      sheet_relationships_started,
      Some("relationships=" + sheet_relationships.length().to_string()),
    )

    let comments_started = xlsx_parse_profile_stage_started(profile)
    let (comments, comment_issues) = read_sheet_comments_from_relationships(
      pkg, info.name, Some(normalized_target), sheet_relationships,
    )
    xlsx_parse_profile_stage_finished(
      profile,
      "sheet:" + info.name + ":comments",
      comments_started,
      Some("comments=" + comments.length().to_string()),
    )

    let sheet = parse_sheet_model(
      pkg,
      info.name,
      info.sheet_id,
      Some(info.relationship_id),
      info.rel_type,
      Some(normalized_target),
      info.state,
      sheet_xml,
      sheet_relationships,
      comments,
      shared_strings,
      styles,
      uses_date_1904,
      profile,
      total_cell_budget_remaining,
      sheet_relationship_issues,
      comment_issues,
    )
    sheets.push(sheet)
  }

  let issues_started = xlsx_parse_profile_stage_started(profile)
  let (workbook_relationships, workbook_relationship_issues) = read_workbook_relationships(
    pkg,
  )
  let unsupported_features = workbook_unsupported_features(
    pkg, workbook_xml, workbook_relationships,
  )
  let issues = workbook_level_issues(
    pkg,
    workbook_relationships,
    unsupported_features,
    shared_strings,
    defined_names.length(),
    sheet_infos.length(),
    sheets,
  )
  issues.append(shared_string_issues)
  issues.append(sheet_info_issues)
  issues.append(defined_name_issues)
  issues.append(workbook_relationship_issues)
  xlsx_parse_profile_stage_finished(
    profile,
    "workbook_issues",
    issues_started,
    Some("count=" + issues.length().to_string()),
  )

  {
    metadata,
    shared_strings,
    styles,
    uses_date_1904,
    defined_names,
    sheets,
    unsupported_features,
    issues,
  }
}

///|
fn parse_xlsx_workbook_metadata(pkg : @ox.OoxmlPackage) -> XlsxWorkbookMetadata {
  let core = @ox.read_core_properties(pkg)
  let app = @ox.read_app_properties(pkg)
  {
    core: {
      title: core.title,
      subject: core.subject,
      creator: core.creator,
      last_modified_by: core.last_modified_by,
      created: core.created,
      modified: core.modified,
      keywords: core.keywords,
      description: core.description,
      category: core.category,
    },
    app: {
      company: app.company,
      manager: app.manager,
      application: app.application,
      pages: app.pages,
      words: app.words,
      slides: app.slides,
      sheets: app.sheets,
    },
    custom_properties: parse_xlsx_custom_properties(pkg),
  }
}

///|
fn parse_xlsx_custom_properties(
  pkg : @ox.OoxmlPackage,
) -> Array[XlsxCustomProperty] {
  let out : Array[XlsxCustomProperty] = []
  for prop in @ox.read_custom_properties(pkg) {
    out.push({
      name: prop.name,
      value: prop.value,
      value_type: prop.value_type,
    })
  }
  out
}

///|
fn read_workbook_relationships(
  pkg : @ox.OoxmlPackage,
) -> (Array[@ox.OoxmlRelationship], Array[XlsxValidationIssue]) {
  let rels = @ox.read_part_relationships(pkg, "xl/workbook.xml") catch {
    _ => []
  }
  truncate_workbook_relationships(rels, "xl/workbook.xml")
}

///|
fn read_sheet_relationships(
  pkg : @ox.OoxmlPackage,
  sheet_part : String,
) -> (Array[@ox.OoxmlRelationship], Array[XlsxValidationIssue]) {
  let rels = @ox.read_part_relationships(pkg, sheet_part) catch {
    _ => []
  }
  truncate_sheet_relationships(rels, sheet_part)
}

///|
fn truncate_workbook_relationships(
  rels : Array[@ox.OoxmlRelationship],
  part_target : String,
) -> (Array[@ox.OoxmlRelationship], Array[XlsxValidationIssue]) {
  let out : Array[@ox.OoxmlRelationship] = []
  let issues : Array[XlsxValidationIssue] = []
  for rel in rels {
    if out.length() >= xlsx_max_relationships_per_part() {
      issues.push(
        workbook_issue(
          XlsxValidationIssueKind::LargeSheetTruncated,
          XlsxValidationSeverity::Warning,
          Some(part_target),
          "relationships truncated at hard cap: " +
          xlsx_max_relationships_per_part().to_string(),
        ),
      )
      break
    }
    out.push(rel)
  }
  (out, issues)
}

///|
fn truncate_sheet_relationships(
  rels : Array[@ox.OoxmlRelationship],
  part_target : String,
) -> (Array[@ox.OoxmlRelationship], Array[XlsxValidationIssue]) {
  let out : Array[@ox.OoxmlRelationship] = []
  let issues : Array[XlsxValidationIssue] = []
  for rel in rels {
    if out.length() >= xlsx_max_relationships_per_part() {
      issues.push(
        workbook_issue(
          XlsxValidationIssueKind::LargeSheetTruncated,
          XlsxValidationSeverity::Warning,
          Some(part_target),
          "relationships truncated at hard cap: " +
          xlsx_max_relationships_per_part().to_string(),
        ),
      )
      break
    }
    out.push(rel)
  }
  (out, issues)
}

///|
fn read_sheet_comments_from_relationships(
  pkg : @ox.OoxmlPackage,
  sheet_name : String,
  part_target : String?,
  rels : Array[@ox.OoxmlRelationship],
) -> (Array[XlsxComment], Array[XlsxValidationIssue]) {
  for rel in rels {
    if rel.target_mode == @ox.OoxmlTargetMode::Internal &&
      (
        rel.rel_type.has_suffix("/comments") ||
        rel.rel_type.contains("relationships/comments")
      ) &&
      rel.resolved_target.has_prefix("xl/") &&
      rel.resolved_target.has_suffix(".xml") &&
      @ox.has_part(pkg, rel.resolved_target) {
      let comments_xml = @ox.read_part_text(pkg, rel.resolved_target) catch {
        _ => return ([], [])
      }
      let (comments, truncated) = parse_sheet_comments_xml(comments_xml)
      let issues = if truncated {
        truncated_comments_issues(sheet_name, part_target, xlsx_max_comments() + 1)
      } else {
        []
      }
      return (comments, issues)
    }
  }

  ([], [])
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
  pkg : @ox.OoxmlPackage,
  workbook_relationships : Array[@ox.OoxmlRelationship],
  unsupported_features : Array[XlsxUnsupportedFeature],
  shared_strings : Array[String],
  defined_name_count : Int,
  sheet_count : Int,
  sheets : Array[XlsxSheet],
) -> Array[XlsxValidationIssue] {
  let issues : Array[XlsxValidationIssue] = []
  let seen : Map[String, Int] = Map([])

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

  issues.append(
    validation_issues_from_unsupported_features(unsupported_features),
  )

  for rel in workbook_relationships {
    if workbook_relationship_feature_kind(rel.rel_type) == None &&
      !is_supported_sheet_relationship(Some(rel.rel_type)) &&
      rel.target_mode == @ox.OoxmlTargetMode::Internal &&
      rel.resolved_target != "" &&
      !@ox.has_part(pkg, rel.resolved_target) {
      issues.push(
        workbook_issue(
          XlsxValidationIssueKind::MissingRelationshipTarget,
          XlsxValidationSeverity::Warning,
          Some(rel.resolved_target),
          "relationship target is missing: " + rel.id,
        ),
      )
    }
  }

  if shared_strings.length() > xlsx_large_shared_strings_warning_threshold() {
    issues.push(
      workbook_issue(
        XlsxValidationIssueKind::LargeSharedStrings,
        XlsxValidationSeverity::Warning,
        Some("xl/sharedStrings.xml"),
        "large sharedStrings count: " + shared_strings.length().to_string(),
      ),
    )
  }

  let (shared_string_bytes, longest_shared_string) = shared_string_size_stats(
    shared_strings,
  )
  if shared_string_bytes > xlsx_large_shared_string_bytes_warning_threshold() {
    issues.push(
      workbook_issue(
        XlsxValidationIssueKind::LargeSharedStrings,
        XlsxValidationSeverity::Warning,
        Some("xl/sharedStrings.xml"),
        "large sharedStrings text bytes: " + shared_string_bytes.to_string(),
      ),
    )
  }
  if longest_shared_string > xlsx_long_shared_string_warning_threshold() {
    issues.push(
      workbook_issue(
        XlsxValidationIssueKind::LargeSharedStrings,
        XlsxValidationSeverity::Warning,
        Some("xl/sharedStrings.xml"),
        "long shared string length: " + longest_shared_string.to_string(),
      ),
    )
  }

  if sheet_count > xlsx_many_sheets_warning_threshold() {
    issues.push(
      workbook_issue(
        XlsxValidationIssueKind::LargeSheetTruncated,
        XlsxValidationSeverity::Warning,
        Some("xl/workbook.xml"),
        "large workbook sheet count: " + sheet_count.to_string(),
      ),
    )
  }

  if defined_name_count > xlsx_many_defined_names_warning_threshold() {
    issues.push(
      workbook_issue(
        XlsxValidationIssueKind::LargeSheetTruncated,
        XlsxValidationSeverity::Warning,
        Some("xl/workbook.xml"),
        "large defined name count: " + defined_name_count.to_string(),
      ),
    )
  }

  issues
}

///|
fn shared_string_size_stats(shared_strings : Array[String]) -> (Int, Int) {
  let mut total = 0
  let mut longest = 0
  for text in shared_strings {
    total += text.length()
    if text.length() > longest {
      longest = text.length()
    }
  }
  (total, longest)
}

///|
fn workbook_unsupported_features(
  pkg : @ox.OoxmlPackage,
  workbook_xml : String,
  workbook_relationships : Array[@ox.OoxmlRelationship],
) -> Array[XlsxUnsupportedFeature] {
  let features : Array[XlsxUnsupportedFeature] = []
  if find_sub(workbook_xml, "<workbookProtection", 0) != None {
    features.push({
      kind: XlsxUnsupportedFeatureKind::WorkbookProtection,
      severity: XlsxValidationSeverity::Warning,
      sheet_name: None,
      relationship_id: None,
      part_target: Some("xl/workbook.xml"),
      source: "xl/workbook.xml",
      message: "workbook protection is preserved only as an unsupported warning",
    })
  }
  for rel in workbook_relationships {
    match workbook_relationship_feature_kind(rel.rel_type) {
      Some(kind) => {
        features.push({
          kind,
          severity: XlsxValidationSeverity::Warning,
          sheet_name: None,
          relationship_id: Some(rel.id),
          part_target: Some(rel.resolved_target),
          source: rel.rel_type,
          message: "unsupported workbook relationship " +
          rel.id +
          ": " +
          rel.rel_type,
        })
        if rel.target_mode == @ox.OoxmlTargetMode::Internal &&
          rel.resolved_target != "" &&
          !@ox.has_part(pkg, rel.resolved_target) {
          features.push({
            kind: XlsxUnsupportedFeatureKind::Unknown,
            severity: XlsxValidationSeverity::Warning,
            sheet_name: None,
            relationship_id: Some(rel.id),
            part_target: Some(rel.resolved_target),
            source: rel.rel_type,
            message: "relationship target is missing: " + rel.id,
          })
        }
      }
      None => ()
    }
  }
  features
}

///|
fn workbook_relationship_feature_kind(
  rel_type : String,
) -> XlsxUnsupportedFeatureKind? {
  if rel_type.has_suffix("/externalLink") ||
    rel_type.contains("relationships/externalLink") {
    Some(XlsxUnsupportedFeatureKind::ExternalLink)
  } else if rel_type.has_suffix("/vbaProject") ||
    rel_type.contains("relationships/vbaProject") {
    Some(XlsxUnsupportedFeatureKind::VbaMacro)
  } else if rel_type.has_suffix("/oleObject") ||
    rel_type.contains("relationships/oleObject") {
    Some(XlsxUnsupportedFeatureKind::OleObject)
  } else {
    None
  }
}

///|
fn workbook_issue(
  kind : XlsxValidationIssueKind,
  severity : XlsxValidationSeverity,
  part_target : String?,
  message : String,
) -> XlsxValidationIssue {
  {
    kind,
    severity,
    sheet_name: None,
    cell_reference: None,
    part_target,
    message,
  }
}

///|
fn parse_workbook_defined_names(
  workbook_xml : String,
  sheet_infos : Array[SheetInfo],
) -> (Array[XlsxDefinedName], Array[XlsxValidationIssue]) {
  let out : Array[XlsxDefinedName] = []
  let issues : Array[XlsxValidationIssue] = []
  let mut pos = 0

  while true {
    let dn0 = find_exact_start_tag(workbook_xml, "definedName", pos)
    match dn0 {
      None => break
      Some(i0) => {
        let dn1 = find_sub(workbook_xml, ">", i0)
        match dn1 {
          None => break
          Some(i1) => {
            let tag = workbook_xml[i0:i1 + 1].to_owned()
            let end0 = find_sub(workbook_xml, "</definedName>", i1 + 1)
            match end0 {
              None => break
              Some(end1) => {
                if out.length() >= xlsx_max_defined_names() {
                  issues.push(
                    workbook_issue(
                      XlsxValidationIssueKind::LargeSheetTruncated,
                      XlsxValidationSeverity::Warning,
                      Some("xl/workbook.xml"),
                      "defined names truncated at hard cap: " +
                      xlsx_max_defined_names().to_string(),
                    ),
                  )
                  break
                }
                let name = xml_unescape(get_attr(tag, "name").unwrap_or(""))
                let text = xml_unescape(workbook_xml[i1 + 1:end1].to_owned())
                let local_idx_raw = get_attr(tag, "localSheetId").unwrap_or("")
                let local_idx = parse_int(local_idx_raw)
                let sheet_scope_index = if local_idx >= 0 {
                  Some(local_idx)
                } else {
                  None
                }
                let sheet_scope = match sheet_scope_index {
                  Some(idx) =>
                    if idx >= 0 && idx < sheet_infos.length() {
                      Some(sheet_infos[idx].name)
                    } else {
                      None
                    }
                  None => None
                }
                let hidden_raw = get_attr(tag, "hidden").unwrap_or("")
                let hidden = hidden_raw == "1" ||
                  hidden_raw == "true" ||
                  hidden_raw == "TRUE"
                let (target_sheet, target_range) = parse_defined_name_target(
                  text,
                )
                out.push({
                  name,
                  text,
                  sheet_scope,
                  sheet_scope_index,
                  kind: defined_name_kind(
                    name, text, target_sheet, target_range,
                  ),
                  target_sheet,
                  target_range,
                  hidden,
                  source: "xl/workbook.xml",
                })
                pos = end1 + 14
              }
            }
          }
        }
      }
    }
  }

  (out, issues)
}

///|
fn defined_name_kind(
  name : String,
  text : String,
  target_sheet : String?,
  target_range : String?,
) -> XlsxDefinedNameKind {
  if name == "_xlnm.Print_Area" || name.has_suffix(".Print_Area") {
    XlsxDefinedNameKind::PrintArea
  } else if name == "_xlnm._FilterDatabase" ||
    name.has_suffix("._FilterDatabase") {
    XlsxDefinedNameKind::AutoFilter
  } else if target_sheet != None && target_range != None {
    XlsxDefinedNameKind::NamedRange
  } else if defined_name_text_is_formula_like(text) {
    XlsxDefinedNameKind::FormulaLike
  } else {
    XlsxDefinedNameKind::Unknown
  }
}

///|
fn defined_name_text_is_formula_like(text : String) -> Bool {
  let t = text.trim()
  t.contains("(") ||
  t.contains("+") ||
  t.contains("-") ||
  t.contains("*") ||
  t.contains("/") ||
  t.contains(",")
}

///|
fn parse_defined_name_target(text : String) -> (String?, String?) {
  let t = text.trim().to_owned()
  if t == "" || t.contains(",") || t.contains("[") || t.contains("]") {
    return (None, None)
  }
  let bang = find_last_char(t, '!')
  match bang {
    None => (None, None)
    Some(idx) => {
      let raw_sheet = t[:idx].to_owned()
      let raw_range = t[idx + 1:].to_owned()
      let range_ref = normalize_xlsx_range_ref(raw_range)
      if xlsx_range_ref_is_simple(range_ref) {
        (Some(normalize_defined_name_sheet(raw_sheet)), Some(range_ref))
      } else {
        (None, None)
      }
    }
  }
}

///|
fn xlsx_range_ref_is_simple(range_ref : String) -> Bool {
  let parts : Array[String] = []
  for part in range_ref.split(":") {
    parts.push(part.to_owned())
  }
  if parts.length() == 1 {
    xlsx_cell_ref_is_simple(parts[0])
  } else if parts.length() == 2 {
    xlsx_cell_ref_is_simple(parts[0]) && xlsx_cell_ref_is_simple(parts[1])
  } else {
    false
  }
}

///|
fn xlsx_cell_ref_is_simple(ref_text : String) -> Bool {
  let text = ref_text.trim()
  if text == "" {
    return false
  }
  let chars = text.to_array()
  let mut i = 0
  let mut saw_col = false
  while i < chars.length() {
    let ch = chars[i]
    if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
      saw_col = true
      i += 1
    } else {
      break
    }
  }
  if !saw_col {
    return false
  }
  let mut saw_row = false
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      saw_row = true
      i += 1
    } else {
      return false
    }
  }
  saw_row
}

///|
fn normalize_defined_name_sheet(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.length() >= 2 && trimmed.has_prefix("'") && trimmed.has_suffix("'") {
    trimmed[1:trimmed.length() - 1].to_owned().replace(old="''", new="'")
  } else {
    trimmed
  }
}

///|
fn normalize_xlsx_range_ref(text : String) -> String {
  let chars = text.trim().to_array()
  let out : Array[Char] = []
  for ch in chars {
    if ch != '$' {
      out.push(ch)
    }
  }
  String::from_array(out)
}

///|
fn find_last_char(text : String, needle : Char) -> Int? {
  let chars = text.to_array()
  let mut found = -1
  for i in 0..<chars.length() {
    if chars[i] == needle {
      found = i
    }
  }
  if found < 0 {
    None
  } else {
    Some(found)
  }
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
) -> (Array[SheetInfo], Array[XlsxValidationIssue]) {
  let out : Array[SheetInfo] = []
  let issues : Array[XlsxValidationIssue] = []
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
              if out.length() >= xlsx_max_sheets() {
                issues.push(
                  workbook_issue(
                    XlsxValidationIssueKind::LargeSheetTruncated,
                    XlsxValidationSeverity::Warning,
                    Some("xl/workbook.xml"),
                    "sheets truncated at hard cap: " +
                    xlsx_max_sheets().to_string(),
                  ),
                )
                break
              }
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

  (out, issues)
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
