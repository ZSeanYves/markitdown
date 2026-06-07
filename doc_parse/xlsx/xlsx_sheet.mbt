///|
priv struct ParsedCellXml {
  reference : String
  cell_type : String
  style_index : Int
  value : String
  formula_text : String?
  inner : String
}

///|
fn parse_sheet_model(
  pkg : @ox.OoxmlPackage,
  sheet_name : String,
  sheet_id : String?,
  relationship_id : String?,
  relationship_type : String?,
  part_target : String?,
  state : XlsxSheetState,
  sheet_xml : String,
  sheet_relationships : Array[@ox.OoxmlRelationship],
  comments : Array[XlsxComment],
  shared : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
  profile : XlsxParseProfileReport?,
) -> XlsxSheetModel {
  let collect_started = xlsx_parse_profile_stage_started(profile)
  let parsed_cells = collect_sheet_cells(sheet_xml)
  xlsx_parse_profile_stage_finished(
    profile,
    "sheet:" + sheet_name + ":collect_cells",
    collect_started,
    Some("parsed_cells=" + parsed_cells.length().to_string()),
  )
  let hidden_rows_started = xlsx_parse_profile_stage_started(profile)
  let hidden_rows = collect_hidden_rows(sheet_xml)
  xlsx_parse_profile_stage_finished(
    profile,
    "sheet:" + sheet_name + ":hidden_rows",
    hidden_rows_started,
    Some("hidden_rows=" + hidden_rows.length().to_string()),
  )
  let merged_started = xlsx_parse_profile_stage_started(profile)
  let (merged_ranges, merged_issues) = parse_merged_ranges(
    sheet_name, part_target, sheet_xml,
  )
  xlsx_parse_profile_stage_finished(
    profile,
    "sheet:" + sheet_name + ":merged_ranges",
    merged_started,
    Some("merged_ranges=" + merged_ranges.length().to_string()),
  )
  let hyperlinks_started = xlsx_parse_profile_stage_started(profile)
  let (hyperlinks, hyperlink_issues) = parse_sheet_hyperlinks(
    sheet_name, part_target, sheet_xml, sheet_relationships,
  )
  xlsx_parse_profile_stage_finished(
    profile,
    "sheet:" + sheet_name + ":hyperlinks",
    hyperlinks_started,
    Some("hyperlinks=" + hyperlinks.length().to_string()),
  )
  let tables_started = xlsx_parse_profile_stage_started(profile)
  let (tables, table_issues) = parse_sheet_tables(
    pkg, sheet_name, sheet_relationships,
  )
  xlsx_parse_profile_stage_finished(
    profile,
    "sheet:" + sheet_name + ":tables",
    tables_started,
    Some("tables=" + tables.length().to_string()),
  )
  let hyperlink_lookup = xlsx_hyperlink_cell_lookup(hyperlinks)
  let resolve_started = xlsx_parse_profile_stage_started(profile)
  let cells : Array[XlsxCellModel] = []

  for parsed in parsed_cells {
    let cell_issues : Array[XlsxValidationIssue] = []
    let trimmed_value = parsed.value.trim()
    let (row, column) = cell_ref_to_rc(parsed.reference)
    if row <= 0 || column <= 0 {
      cell_issues.push(
        cell_issue(
          XlsxValidationIssueKind::InvalidCellReference,
          XlsxValidationSeverity::Error,
          sheet_name,
          parsed.reference,
          part_target,
          "invalid cell reference: " + parsed.reference,
        ),
      )
      cells.push({
        reference: parsed.reference,
        row,
        column,
        raw_type: parsed.cell_type,
        kind: XlsxCellKind::Blank,
        display_text: "",
        source_value: if trimmed_value == "" {
          None
        } else {
          Some(parsed.value)
        },
        formula_text: parsed.formula_text,
        semantic_type: XlsxCellSemanticType::Blank,
        style_index: parsed.style_index,
        num_format_id: style_index_numfmt(styles, parsed.style_index),
        formula_trace: None,
        hyperlink: None,
        issues: cell_issues,
      })
      continue
    }

    if is_unsupported_cell_type(parsed.cell_type) {
      cell_issues.push(
        cell_issue(
          XlsxValidationIssueKind::UnsupportedCellType,
          XlsxValidationSeverity::Warning,
          sheet_name,
          parsed.reference,
          part_target,
          "unsupported cell type: " + parsed.cell_type,
        ),
      )
    }

    if parsed.cell_type == "s" {
      let idx = parse_int(parsed.value)
      if idx < 0 || idx >= shared.length() {
        cell_issues.push(
          cell_issue(
            XlsxValidationIssueKind::MissingSharedString,
            XlsxValidationSeverity::Warning,
            sheet_name,
            parsed.reference,
            part_target,
            "shared string index out of range: " + parsed.value,
          ),
        )
      }
    }

    let num_format_id = style_index_numfmt(styles, parsed.style_index)
    let (kind, semantic_type, text) = resolve_cell_display(
      parsed.cell_type,
      parsed.inner,
      parsed.value,
      parsed.formula_text,
      shared,
      styles,
      num_format_id,
      uses_date_1904,
    )
    let hyperlink = hyperlink_lookup.get(
      row.to_string() + "," + column.to_string(),
    )

    cells.push({
      reference: parsed.reference,
      row,
      column,
      raw_type: parsed.cell_type,
      kind,
      display_text: text,
      source_value: if trimmed_value == "" {
        None
      } else {
        Some(parsed.value)
      },
      formula_text: parsed.formula_text,
      semantic_type,
      style_index: parsed.style_index,
      num_format_id,
      formula_trace: None,
      hyperlink,
      issues: cell_issues,
    })
  }
  xlsx_parse_profile_stage_finished(
    profile,
    "sheet:" + sheet_name + ":resolve_cells",
    resolve_started,
    Some("cells=" + cells.length().to_string()),
  )

  apply_formula_policy(sheet_name, part_target, cells, profile)
  let used_range_started = xlsx_parse_profile_stage_started(profile)
  let (used_min_row, used_min_col, used_max_row, used_max_col) = used_range_from_cells(
    cells,
  )
  let non_empty_cell_count = xlsx_non_empty_cell_count(cells)
  xlsx_parse_profile_stage_finished(
    profile,
    "sheet:" + sheet_name + ":used_range",
    used_range_started,
    Some(
      "used_range=" +
      used_min_row.to_string() +
      "," +
      used_min_col.to_string() +
      "-" +
      used_max_row.to_string() +
      "," +
      used_max_col.to_string(),
    ),
  )

  let issues : Array[XlsxValidationIssue] = []
  issues.append(merged_issues)
  issues.append(hyperlink_issues)
  issues.append(table_issues)
  let unsupported_features = sheet_unsupported_features(
    pkg, sheet_name, part_target, sheet_xml, sheet_relationships,
  )
  issues.append(
    validation_issues_from_unsupported_features(unsupported_features),
  )
  issues.append(
    sheet_guard_issues(
      sheet_name,
      part_target,
      sheet_xml,
      merged_ranges.length(),
      hyperlinks.length(),
      tables.length(),
      cells.length(),
      non_empty_cell_count,
      used_min_row,
      used_min_col,
      used_max_row,
      used_max_col,
    ),
  )
  {
    name: sheet_name,
    sheet_id,
    relationship_id,
    relationship_type,
    part_target,
    state,
    is_supported_worksheet: true,
    has_sheet_xml: true,
    cells,
    merged_ranges,
    comments,
    hyperlinks,
    tables,
    hidden_rows,
    unsupported_features,
    used_min_row,
    used_min_col,
    used_max_row,
    used_max_col,
    issues,
  }
}

///|
fn apply_formula_policy(
  sheet_name : String,
  part_target : String?,
  cells : Array[XlsxCellModel],
  profile : XlsxParseProfileReport?,
) -> Unit {
  let mut formula_context : XlsxFormulaSheetContext? = None
  let mut formula_context_ready = false
  let mut formula_eval_started : UInt64? = None
  let mut formula_cell_count = 0
  let mut missing_cache_formula_count = 0
  let mut evaluated_formula_count = 0
  let mut unsupported_formula_count = 0
  let mut formula_error_count = 0
  let mut i = 0
  while i < cells.length() {
    let cell = cells[i]
    match cell.formula_text {
      Some(text) =>
        if text.trim() != "" {
          formula_cell_count += 1
          if formula_eval_started == None {
            formula_eval_started = Some(
              xlsx_parse_profile_stage_started(profile),
            )
          }
          let trimmed_formula_text = text.trim().to_owned()
          let trace = if cell.source_value != None {
            Some({
              policy: XlsxFormulaPolicy::Cached,
              evaluated_value: None,
              unsupported_reason: None,
              error_reason: None,
              referenced_cells: None,
              referenced_ranges: None,
            })
          } else {
            missing_cache_formula_count += 1
            if !formula_context_ready {
              let formula_context_started = xlsx_parse_profile_stage_started(
                profile,
              )
              formula_context = Some(build_formula_sheet_context(cells))
              formula_context_ready = true
              xlsx_parse_profile_stage_finished(
                profile,
                "sheet:" + sheet_name + ":formula_context",
                formula_context_started,
                Some("cells=" + cells.length().to_string()),
              )
            }
            match formula_context {
              Some(context) =>
                evaluate_missing_cache_formula(
                  cell, trimmed_formula_text, context,
                )
              None => None
            }
          }

          let next_cell = match trace {
            Some(info) => {
              if info.policy == XlsxFormulaPolicy::EvaluatedMissingCache {
                evaluated_formula_count += 1
              } else if info.policy == XlsxFormulaPolicy::UnsupportedFormula {
                unsupported_formula_count += 1
              } else if info.policy == XlsxFormulaPolicy::FormulaError {
                formula_error_count += 1
              }
              let next_issues : Array[XlsxValidationIssue] = []
              for issue in cell.issues {
                next_issues.push(issue)
              }
              if info.policy == XlsxFormulaPolicy::UnsupportedFormula {
                next_issues.push(
                  cell_issue(
                    XlsxValidationIssueKind::UnsupportedFormulaEvaluation,
                    XlsxValidationSeverity::Warning,
                    sheet_name,
                    cell.reference,
                    part_target,
                    info.unsupported_reason.unwrap_or(
                      "formula evaluation is unsupported",
                    ),
                  ),
                )
              }

              if info.policy == XlsxFormulaPolicy::EvaluatedMissingCache {
                {
                  ..cell,
                  display_text: info.evaluated_value.unwrap_or(""),
                  semantic_type: inferred_formula_eval_semantic_type(
                    info.evaluated_value.unwrap_or(""),
                  ),
                  formula_trace: Some(info),
                  issues: next_issues,
                }
              } else {
                { ..cell, formula_trace: Some(info), issues: next_issues }
              }
            }
            None => cell
          }
          cells[i] = next_cell
        }
      None => ()
    }
    i = i + 1
  }

  match formula_eval_started {
    Some(started) =>
      xlsx_parse_profile_stage_finished(
        profile,
        "sheet:" + sheet_name + ":formula_eval",
        started,
        Some(
          "formula_cells=" +
          formula_cell_count.to_string() +
          " missing_cache=" +
          missing_cache_formula_count.to_string() +
          " evaluated=" +
          evaluated_formula_count.to_string() +
          " unsupported=" +
          unsupported_formula_count.to_string() +
          " errors=" +
          formula_error_count.to_string(),
        ),
      )
    None => ()
  }
}

///|
fn inferred_formula_eval_semantic_type(text : String) -> XlsxCellSemanticType {
  let trimmed = text.trim()
  if trimmed == "" {
    XlsxCellSemanticType::FormulaMissingCache
  } else if trimmed == "TRUE" || trimmed == "FALSE" {
    XlsxCellSemanticType::Boolean
  } else {
    try @string.parse_double(trimmed.to_owned()) catch {
      _ => XlsxCellSemanticType::String
    } noraise {
      _ => XlsxCellSemanticType::Number
    }
  }
}

///|
fn used_range_from_cells(cells : Array[XlsxCellModel]) -> (Int, Int, Int, Int) {
  let mut min_r = 0
  let mut min_c = 0
  let mut max_r = 0
  let mut max_c = 0
  for cell in cells {
    if @cor.trim_string(cell.display_text) == "" {
      continue
    }
    if min_r == 0 || cell.row < min_r {
      min_r = cell.row
    }
    if min_c == 0 || cell.column < min_c {
      min_c = cell.column
    }
    if cell.row > max_r {
      max_r = cell.row
    }
    if cell.column > max_c {
      max_c = cell.column
    }
  }
  (min_r, min_c, max_r, max_c)
}

///|
fn xlsx_non_empty_cell_count(cells : Array[XlsxCellModel]) -> Int {
  let mut count = 0
  for cell in cells {
    if @cor.trim_string(cell.display_text) != "" {
      count += 1
    }
  }
  count
}

///|
fn empty_sheet_model(
  sheet_name : String,
  sheet_id : String?,
  relationship_id : String?,
  relationship_type : String?,
  part_target : String?,
  state : XlsxSheetState,
  is_supported_worksheet : Bool,
  has_sheet_xml : Bool,
  issues : Array[XlsxValidationIssue],
) -> XlsxSheetModel {
  {
    name: sheet_name,
    sheet_id,
    relationship_id,
    relationship_type,
    part_target,
    state,
    is_supported_worksheet,
    has_sheet_xml,
    cells: [],
    merged_ranges: [],
    comments: [],
    hyperlinks: [],
    tables: [],
    hidden_rows: [],
    unsupported_features: [],
    used_min_row: 0,
    used_min_col: 0,
    used_max_row: 0,
    used_max_col: 0,
    issues,
  }
}

///|
fn collect_hidden_rows(sheet_xml : String) -> Array[Int] {
  let out : Array[Int] = []
  let mut pos = 0

  while true {
    let row0 = find_sub(sheet_xml, "<row ", pos)
    match row0 {
      None => break
      Some(i0) => {
        let row1 = find_sub(sheet_xml, ">", i0)
        match row1 {
          None => break
          Some(i1) => {
            let tag = sheet_xml[i0:i1 + 1].to_owned()
            let row_ref = parse_int(get_attr(tag, "r").unwrap_or(""))
            let hidden_attr = get_attr(tag, "hidden").unwrap_or("")
            if row_ref > 0 &&
              (
                hidden_attr == "1" ||
                hidden_attr == "true" ||
                hidden_attr == "TRUE"
              ) {
              out.push(row_ref)
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
fn collect_sheet_cells(sheet_xml : String) -> Array[ParsedCellXml] {
  let out : Array[ParsedCellXml] = []
  let mut pos = 0

  while true {
    let c0 = find_sub(sheet_xml, "<c ", pos)
    match c0 {
      None => break
      Some(i0) => {
        let ctag_end0 = find_sub(sheet_xml, ">", i0)
        match ctag_end0 {
          None => break
          Some(i1) => {
            let ctag = sheet_xml[i0:i1 + 1].to_owned()
            let rref = get_attr(ctag, "r").unwrap_or("")
            let cell_type = get_attr(ctag, "t").unwrap_or("")
            let style_idx = parse_int(get_attr(ctag, "s").unwrap_or(""))
            if ctag.has_suffix("/>") {
              out.push({
                reference: rref,
                cell_type,
                style_index: style_idx,
                value: "",
                formula_text: None,
                inner: "",
              })
              pos = i1 + 1
            } else {
              let c_end0 = find_sub(sheet_xml, "</c>", i1 + 1)
              match c_end0 {
                None => break
                Some(c_end) => {
                  let inner = sheet_xml[i1 + 1:c_end].to_owned()
                  let value = tag_text(inner, "v").unwrap_or("")
                  let formula_text = tag_text(inner, "f")
                  out.push({
                    reference: rref,
                    cell_type,
                    style_index: style_idx,
                    value,
                    formula_text,
                    inner,
                  })
                  pos = c_end + 4
                }
              }
            }
          }
        }
      }
    }
  }

  out
}

///|
fn parse_merged_ranges(
  sheet_name : String,
  part_target : String?,
  sheet_xml : String,
) -> (Array[XlsxMergedRange], Array[XlsxValidationIssue]) {
  let ranges : Array[XlsxMergedRange] = []
  let issues : Array[XlsxValidationIssue] = []
  let start0 = find_sub(sheet_xml, "<mergeCells", 0)
  match start0 {
    None => (ranges, issues)
    Some(mc0) => {
      let gt0 = find_sub(sheet_xml, ">", mc0)
      match gt0 {
        None => (ranges, issues)
        Some(mc1) => {
          let end0 = find_sub(sheet_xml, "</mergeCells>", mc1 + 1)
          match end0 {
            None => (ranges, issues)
            Some(mc_end) => {
              let inner = sheet_xml[mc1 + 1:mc_end].to_owned()
              let mut pos = 0
              while true {
                let merge0 = find_sub(inner, "<mergeCell", pos)
                match merge0 {
                  None => break
                  Some(i0) => {
                    let merge1 = find_sub(inner, ">", i0)
                    match merge1 {
                      None => break
                      Some(i1) => {
                        let tag = inner[i0:i1 + 1].to_owned()
                        let range_ref = get_attr(tag, "ref").unwrap_or("")
                        match parse_merge_ref(range_ref) {
                          Some((r1, c1, r2, c2)) =>
                            ranges.push({
                              range_ref,
                              start_row: r1,
                              start_col: c1,
                              end_row: r2,
                              end_col: c2,
                            })
                          None =>
                            issues.push(
                              sheet_issue(
                                XlsxValidationIssueKind::InvalidMergedRange,
                                XlsxValidationSeverity::Warning,
                                sheet_name,
                                None,
                                part_target,
                                "invalid merged range: " + range_ref,
                              ),
                            )
                        }
                        pos = i1 + 1
                      }
                    }
                  }
                }
              }
              (ranges, issues)
            }
          }
        }
      }
    }
  }
}

///|
fn parse_sheet_hyperlinks(
  sheet_name : String,
  part_target : String?,
  sheet_xml : String,
  sheet_relationships : Array[@ox.OoxmlRelationship],
) -> (Array[XlsxHyperlink], Array[XlsxValidationIssue]) {
  let hyperlinks : Array[XlsxHyperlink] = []
  let issues : Array[XlsxValidationIssue] = []
  let mut pos = 0

  while true {
    let link0 = find_exact_start_tag(sheet_xml, "hyperlink", pos)
    match link0 {
      None => break
      Some(i0) => {
        let link1 = find_sub(sheet_xml, ">", i0)
        match link1 {
          None => break
          Some(i1) => {
            let tag = sheet_xml[i0:i1 + 1].to_owned()
            let reference = @cor.trim_string(get_attr(tag, "ref").unwrap_or(""))
            match parse_hyperlink_ref(reference) {
              Some((r1, c1, r2, c2)) => {
                let relationship_id = optional_trimmed_attr(tag, "r:id")
                let location = optional_trimmed_attr(tag, "location")
                let tooltip = optional_trimmed_attr(tag, "tooltip")
                let display = optional_trimmed_attr(tag, "display")
                let (target, kind, warning) = resolve_xlsx_hyperlink_target(
                  relationship_id, location, sheet_relationships,
                )
                match warning {
                  Some(message) =>
                    issues.push(
                      sheet_issue(
                        XlsxValidationIssueKind::MissingRelationshipTarget,
                        XlsxValidationSeverity::Warning,
                        sheet_name,
                        None,
                        part_target,
                        message,
                      ),
                    )
                  None => ()
                }
                hyperlinks.push({
                  reference,
                  start_row: r1,
                  start_col: c1,
                  end_row: r2,
                  end_col: c2,
                  relationship_id,
                  target,
                  location,
                  tooltip,
                  display,
                  kind,
                  warning,
                })
              }
              None =>
                issues.push(
                  sheet_issue(
                    XlsxValidationIssueKind::InvalidCellReference,
                    XlsxValidationSeverity::Warning,
                    sheet_name,
                    None,
                    part_target,
                    "invalid hyperlink reference: " + reference,
                  ),
                )
            }
            pos = i1 + 1
          }
        }
      }
    }
  }

  (hyperlinks, issues)
}

///|
fn parse_sheet_tables(
  pkg : @ox.OoxmlPackage,
  sheet_name : String,
  sheet_relationships : Array[@ox.OoxmlRelationship],
) -> (Array[XlsxTable], Array[XlsxValidationIssue]) {
  let tables : Array[XlsxTable] = []
  let issues : Array[XlsxValidationIssue] = []

  for rel in sheet_relationships {
    if !(rel.rel_type.has_suffix("/table") ||
      rel.rel_type.contains("relationships/table")) {
      continue
    }
    if rel.target_mode != @ox.OoxmlTargetMode::Internal ||
      rel.resolved_target == "" ||
      !@ox.has_part(pkg, rel.resolved_target) {
      issues.push(
        sheet_issue(
          XlsxValidationIssueKind::MissingRelationshipTarget,
          XlsxValidationSeverity::Warning,
          sheet_name,
          None,
          Some(rel.resolved_target),
          "table relationship target is missing: " + rel.id,
        ),
      )
      continue
    }

    let table_xml = @ox.read_part_text(pkg, rel.resolved_target) catch {
      _ => {
        issues.push(
          sheet_issue(
            XlsxValidationIssueKind::MissingRelationshipTarget,
            XlsxValidationSeverity::Warning,
            sheet_name,
            None,
            Some(rel.resolved_target),
            "table relationship target is unreadable: " + rel.id,
          ),
        )
        continue
      }
    }
    match parse_table_part(sheet_name, rel.id, rel.resolved_target, table_xml) {
      Some(table) => tables.push(table)
      None =>
        issues.push(
          sheet_issue(
            XlsxValidationIssueKind::UnknownWorkbookPart,
            XlsxValidationSeverity::Warning,
            sheet_name,
            None,
            Some(rel.resolved_target),
            "table part is malformed or missing ref: " + rel.id,
          ),
        )
    }
  }

  (tables, issues)
}

///|
fn parse_table_part(
  sheet_name : String,
  relationship_id : String,
  source_part : String,
  table_xml : String,
) -> XlsxTable? {
  let table0 = find_exact_start_tag(table_xml, "table", 0)
  match table0 {
    None => None
    Some(i0) => {
      let table1 = find_sub(table_xml, ">", i0)
      match table1 {
        None => None
        Some(i1) => {
          let tag = table_xml[i0:i1 + 1].to_owned()
          let range_ref = normalize_xlsx_range_ref(
            get_attr(tag, "ref").unwrap_or(""),
          )
          match parse_hyperlink_ref(range_ref) {
            None => None
            Some((r1, c1, r2, c2)) => {
              let header_row_count = parse_nonnegative_or_default(
                get_attr(tag, "headerRowCount").unwrap_or("1"),
                1,
              )
              let totals_row_count = parse_nonnegative_or_default(
                get_attr(tag, "totalsRowCount").unwrap_or("0"),
                0,
              )
              let columns = parse_table_columns(table_xml)
              Some({
                table_id: optional_trimmed_attr(tag, "id"),
                name: optional_trimmed_attr(tag, "name"),
                display_name: optional_trimmed_attr(tag, "displayName"),
                style_name: parse_table_style_name(table_xml),
                auto_filter_ref: parse_table_auto_filter_ref(table_xml),
                header_row_visible: header_row_count > 0,
                totals_row_visible: totals_row_count > 0,
                range_ref,
                start_row: r1,
                start_col: c1,
                end_row: r2,
                end_col: c2,
                header_row_count,
                totals_row_count,
                column_names: table_column_names(columns),
                columns,
                sheet_name,
                source_part: Some(source_part),
                relationship_id: Some(relationship_id),
              })
            }
          }
        }
      }
    }
  }
}

///|
fn parse_table_style_name(table_xml : String) -> String? {
  let style0 = find_exact_start_tag(table_xml, "tableStyleInfo", 0)
  match style0 {
    None => None
    Some(i0) => {
      let style1 = find_sub(table_xml, ">", i0)
      match style1 {
        None => None
        Some(i1) => {
          let tag = table_xml[i0:i1 + 1].to_owned()
          optional_trimmed_attr(tag, "name")
        }
      }
    }
  }
}

///|
fn parse_table_auto_filter_ref(table_xml : String) -> String? {
  let filter0 = find_exact_start_tag(table_xml, "autoFilter", 0)
  match filter0 {
    None => None
    Some(i0) => {
      let filter1 = find_sub(table_xml, ">", i0)
      match filter1 {
        None => None
        Some(i1) => {
          let tag = table_xml[i0:i1 + 1].to_owned()
          match optional_trimmed_attr(tag, "ref") {
            Some(ref_text) => Some(normalize_xlsx_range_ref(ref_text))
            None => None
          }
        }
      }
    }
  }
}

///|
fn parse_table_columns(table_xml : String) -> Array[XlsxTableColumn] {
  let columns : Array[XlsxTableColumn] = []
  let mut pos = 0
  while true {
    let col0 = find_exact_start_tag(table_xml, "tableColumn", pos)
    match col0 {
      None => break
      Some(i0) => {
        let col1 = find_sub(table_xml, ">", i0)
        match col1 {
          None => break
          Some(i1) => {
            let tag = table_xml[i0:i1 + 1].to_owned()
            columns.push({
              column_id: optional_trimmed_attr(tag, "id"),
              name: optional_trimmed_attr(tag, "name"),
              totals_row_function: optional_trimmed_attr(
                tag, "totalsRowFunction",
              ),
              totals_row_label: optional_trimmed_attr(tag, "totalsRowLabel"),
            })
            pos = i1 + 1
          }
        }
      }
    }
  }
  columns
}

///|
fn table_column_names(columns : Array[XlsxTableColumn]) -> Array[String] {
  let out : Array[String] = []
  for column in columns {
    match column.name {
      Some(name) => out.push(name)
      None => ()
    }
  }
  out
}

///|
fn parse_nonnegative_or_default(text : String, default : Int) -> Int {
  let value = parse_int(text)
  if value < 0 {
    default
  } else {
    value
  }
}

///|
fn optional_trimmed_attr(tag : String, name : String) -> String? {
  let value = @cor.trim_string(get_attr(tag, name).unwrap_or(""))
  if value == "" {
    None
  } else {
    Some(xml_unescape(value))
  }
}

///|
fn parse_hyperlink_ref(range_ref : String) -> (Int, Int, Int, Int)? {
  let trimmed = @cor.trim_string(range_ref)
  if trimmed == "" {
    return None
  }

  let parts : Array[String] = []
  for part in trimmed.split(":") {
    parts.push(part.to_owned())
  }
  if parts.length() == 1 {
    let (row, col) = cell_ref_to_rc(parts[0])
    if row <= 0 || col <= 0 {
      None
    } else {
      Some((row, col, row, col))
    }
  } else if parts.length() == 2 {
    let (r1, c1) = cell_ref_to_rc(parts[0])
    let (r2, c2) = cell_ref_to_rc(parts[1])
    if r1 <= 0 || c1 <= 0 || r2 <= 0 || c2 <= 0 {
      None
    } else if r1 <= r2 && c1 <= c2 {
      Some((r1, c1, r2, c2))
    } else if r2 <= r1 && c2 <= c1 {
      Some((r2, c2, r1, c1))
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn resolve_xlsx_hyperlink_target(
  relationship_id : String?,
  location : String?,
  sheet_relationships : Array[@ox.OoxmlRelationship],
) -> (String?, XlsxHyperlinkKind, String?) {
  match relationship_id {
    Some(rid) =>
      match find_relationship_by_id_in_list(sheet_relationships, rid) {
        Some(rel) =>
          if rel.target_mode == @ox.OoxmlTargetMode::External {
            (Some(rel.resolved_target), XlsxHyperlinkKind::External, None)
          } else {
            (Some(rel.resolved_target), XlsxHyperlinkKind::Internal, None)
          }
        None =>
          (
            None,
            XlsxHyperlinkKind::Unknown,
            Some("hyperlink relationship target is missing: " + rid),
          )
      }
    None =>
      match location {
        Some(_) => (None, XlsxHyperlinkKind::Internal, None)
        None =>
          (
            None,
            XlsxHyperlinkKind::Unknown,
            Some("hyperlink target is missing"),
          )
      }
  }
}

///|
fn find_relationship_by_id_in_list(
  rels : Array[@ox.OoxmlRelationship],
  rel_id : String,
) -> @ox.OoxmlRelationship? {
  for rel in rels {
    if rel.id == rel_id {
      return Some(rel)
    }
  }
  None
}

///|
fn xlsx_hyperlink_cell_lookup(
  hyperlinks : Array[XlsxHyperlink],
) -> Map[String, XlsxHyperlink] {
  let out : Map[String, XlsxHyperlink] = Map([])
  for link in hyperlinks {
    let rows = link.end_row - link.start_row + 1
    let cols = link.end_col - link.start_col + 1
    if rows <= 0 || cols <= 0 || rows > xlsx_hyperlink_cell_index_cap() / cols {
      continue
    }
    for r in link.start_row..<(link.end_row + 1) {
      for c in link.start_col..<(link.end_col + 1) {
        out.set(r.to_string() + "," + c.to_string(), link)
      }
    }
  }
  out
}

///|
fn xlsx_hyperlink_cell_index_cap() -> Int {
  10_000
}

///|
fn sheet_guard_issues(
  sheet_name : String,
  part_target : String?,
  sheet_xml : String,
  merged_range_count : Int,
  hyperlink_count : Int,
  table_count : Int,
  cell_count : Int,
  non_empty_cell_count : Int,
  used_min_row : Int,
  used_min_col : Int,
  used_max_row : Int,
  used_max_col : Int,
) -> Array[XlsxValidationIssue] {
  let issues : Array[XlsxValidationIssue] = []
  match parse_sheet_dimension_area(sheet_xml) {
    Some(area) =>
      if area > xlsx_large_sheet_dimension_warning_threshold() {
        issues.push(
          sheet_issue(
            XlsxValidationIssueKind::LargeSheetTruncated,
            XlsxValidationSeverity::Warning,
            sheet_name,
            None,
            part_target,
            "large sheet dimension area: " + area.to_string(),
          ),
        )
      }
    None => ()
  }
  if merged_range_count > xlsx_many_merged_ranges_warning_threshold() {
    issues.push(
      sheet_issue(
        XlsxValidationIssueKind::LargeSheetTruncated,
        XlsxValidationSeverity::Warning,
        sheet_name,
        None,
        part_target,
        "many merged ranges: " + merged_range_count.to_string(),
      ),
    )
  }
  if hyperlink_count > xlsx_many_hyperlinks_warning_threshold() {
    issues.push(
      sheet_issue(
        XlsxValidationIssueKind::LargeSheetTruncated,
        XlsxValidationSeverity::Warning,
        sheet_name,
        None,
        part_target,
        "many hyperlinks: " + hyperlink_count.to_string(),
      ),
    )
  }
  if table_count > xlsx_many_tables_warning_threshold() {
    issues.push(
      sheet_issue(
        XlsxValidationIssueKind::LargeSheetTruncated,
        XlsxValidationSeverity::Warning,
        sheet_name,
        None,
        part_target,
        "many structured tables: " + table_count.to_string(),
      ),
    )
  }
  if cell_count > xlsx_many_cells_warning_threshold() {
    issues.push(
      sheet_issue(
        XlsxValidationIssueKind::LargeSheetTruncated,
        XlsxValidationSeverity::Warning,
        sheet_name,
        None,
        part_target,
        "many parsed cells: " + cell_count.to_string(),
      ),
    )
  }
  if non_empty_cell_count > xlsx_many_non_empty_cells_warning_threshold() {
    issues.push(
      sheet_issue(
        XlsxValidationIssueKind::LargeSheetTruncated,
        XlsxValidationSeverity::Warning,
        sheet_name,
        None,
        part_target,
        "many non-empty cells: " + non_empty_cell_count.to_string(),
      ),
    )
  }
  let used_area = xlsx_cell_area(
    used_min_row, used_min_col, used_max_row, used_max_col,
  )
  if used_area > xlsx_large_under_cap_rich_table_warning_threshold() &&
    used_area <= xlsx_large_sheet_dimension_warning_threshold() {
    issues.push(
      sheet_issue(
        XlsxValidationIssueKind::LargeSheetTruncated,
        XlsxValidationSeverity::Warning,
        sheet_name,
        None,
        part_target,
        "large under-cap RichTable area: " + used_area.to_string(),
      ),
    )
  }
  issues
}

///|
fn parse_sheet_dimension_area(sheet_xml : String) -> Int? {
  let dim0 = find_exact_start_tag(sheet_xml, "dimension", 0)
  match dim0 {
    None => None
    Some(i0) => {
      let dim1 = find_sub(sheet_xml, ">", i0)
      match dim1 {
        None => None
        Some(i1) => {
          let tag = sheet_xml[i0:i1 + 1].to_owned()
          let ref_text = normalize_xlsx_range_ref(
            get_attr(tag, "ref").unwrap_or(""),
          )
          match parse_hyperlink_ref(ref_text) {
            Some((r1, c1, r2, c2)) => Some(xlsx_cell_area(r1, c1, r2, c2))
            None => None
          }
        }
      }
    }
  }
}

///|
fn xlsx_cell_area(
  start_row : Int,
  start_col : Int,
  end_row : Int,
  end_col : Int,
) -> Int {
  if start_row <= 0 ||
    start_col <= 0 ||
    end_row < start_row ||
    end_col < start_col {
    0
  } else {
    (end_row - start_row + 1) * (end_col - start_col + 1)
  }
}

///|
fn sheet_unsupported_features(
  pkg : @ox.OoxmlPackage,
  sheet_name : String,
  part_target : String?,
  sheet_xml : String,
  sheet_relationships : Array[@ox.OoxmlRelationship],
) -> Array[XlsxUnsupportedFeature] {
  let features : Array[XlsxUnsupportedFeature] = []
  if find_sub(sheet_xml, "<sheetProtection", 0) != None {
    features.push({
      kind: XlsxUnsupportedFeatureKind::SheetProtection,
      severity: XlsxValidationSeverity::Warning,
      sheet_name: Some(sheet_name),
      relationship_id: None,
      part_target,
      source: part_target.unwrap_or("worksheet"),
      message: "sheet protection is preserved only as an unsupported warning",
    })
  }
  for rel in sheet_relationships {
    match sheet_relationship_feature_kind(rel.rel_type) {
      Some(kind) =>
        features.push({
          kind,
          severity: XlsxValidationSeverity::Warning,
          sheet_name: Some(sheet_name),
          relationship_id: Some(rel.id),
          part_target: Some(rel.resolved_target),
          source: rel.rel_type,
          message: "unsupported sheet relationship " +
          rel.id +
          ": " +
          rel.rel_type,
        })
      None => ()
    }
    if rel.target_mode == @ox.OoxmlTargetMode::Internal &&
      rel.resolved_target != "" &&
      !@ox.has_part(pkg, rel.resolved_target) {
      features.push({
        kind: XlsxUnsupportedFeatureKind::Unknown,
        severity: XlsxValidationSeverity::Warning,
        sheet_name: Some(sheet_name),
        relationship_id: Some(rel.id),
        part_target: Some(rel.resolved_target),
        source: rel.rel_type,
        message: "relationship target is missing: " + rel.id,
      })
    }
  }
  features
}

///|
fn sheet_relationship_feature_kind(
  rel_type : String,
) -> XlsxUnsupportedFeatureKind? {
  if rel_type.has_suffix("/drawing") ||
    rel_type.contains("relationships/drawing") {
    Some(XlsxUnsupportedFeatureKind::Drawing)
  } else if rel_type.has_suffix("/image") ||
    rel_type.contains("relationships/image") {
    Some(XlsxUnsupportedFeatureKind::Image)
  } else if rel_type.has_suffix("/chart") ||
    rel_type.contains("relationships/chart") {
    Some(XlsxUnsupportedFeatureKind::Chart)
  } else if rel_type.contains("pivotTable") || rel_type.contains("pivot") {
    Some(XlsxUnsupportedFeatureKind::PivotTable)
  } else if rel_type.has_suffix("/vbaProject") ||
    rel_type.contains("relationships/vbaProject") {
    Some(XlsxUnsupportedFeatureKind::VbaMacro)
  } else if rel_type.has_suffix("/oleObject") ||
    rel_type.contains("relationships/oleObject") {
    Some(XlsxUnsupportedFeatureKind::OleObject)
  } else if rel_type.has_suffix("/externalLink") ||
    rel_type.contains("relationships/externalLink") {
    Some(XlsxUnsupportedFeatureKind::ExternalLink)
  } else if rel_type.contains("threadedComment") ||
    rel_type.contains("threadedComments") {
    Some(XlsxUnsupportedFeatureKind::ThreadedComment)
  } else {
    None
  }
}

///|
fn validation_issues_from_unsupported_features(
  features : Array[XlsxUnsupportedFeature],
) -> Array[XlsxValidationIssue] {
  let issues : Array[XlsxValidationIssue] = []
  for feature in features {
    issues.push({
      kind: validation_issue_kind_from_unsupported_feature(feature),
      severity: feature.severity,
      sheet_name: feature.sheet_name,
      cell_reference: None,
      part_target: feature.part_target,
      message: feature.message,
    })
  }
  issues
}

///|
fn validation_issue_kind_from_unsupported_feature(
  feature : XlsxUnsupportedFeature,
) -> XlsxValidationIssueKind {
  if feature.message.contains("relationship target is missing") {
    return XlsxValidationIssueKind::MissingRelationshipTarget
  }
  match feature.kind {
    XlsxUnsupportedFeatureKind::Drawing =>
      XlsxValidationIssueKind::UnsupportedDrawing
    XlsxUnsupportedFeatureKind::Chart =>
      XlsxValidationIssueKind::UnsupportedChart
    XlsxUnsupportedFeatureKind::Image =>
      XlsxValidationIssueKind::UnsupportedDrawing
    XlsxUnsupportedFeatureKind::PivotTable =>
      XlsxValidationIssueKind::UnsupportedPivotTable
    XlsxUnsupportedFeatureKind::VbaMacro =>
      XlsxValidationIssueKind::UnsupportedVbaMacro
    XlsxUnsupportedFeatureKind::OleObject =>
      XlsxValidationIssueKind::UnsupportedOleObject
    XlsxUnsupportedFeatureKind::ExternalLink =>
      XlsxValidationIssueKind::UnsupportedExternalLink
    XlsxUnsupportedFeatureKind::ThreadedComment =>
      XlsxValidationIssueKind::UnsupportedThreadedComment
    XlsxUnsupportedFeatureKind::SheetProtection =>
      XlsxValidationIssueKind::UnsupportedSheetProtection
    XlsxUnsupportedFeatureKind::WorkbookProtection =>
      XlsxValidationIssueKind::UnsupportedWorkbookProtection
    XlsxUnsupportedFeatureKind::Unknown =>
      XlsxValidationIssueKind::UnknownWorkbookPart
  }
}

///|
fn parse_merge_ref(range_ref : String) -> (Int, Int, Int, Int)? {
  let parts : Array[String] = []
  for part in range_ref.split(":") {
    parts.push(part.to_owned())
  }
  if parts.length() != 2 {
    return None
  }
  let (r1, c1) = cell_ref_to_rc(parts[0])
  let (r2, c2) = cell_ref_to_rc(parts[1])
  if r1 <= 0 || c1 <= 0 || r2 <= 0 || c2 <= 0 {
    None
  } else {
    Some((r1, c1, r2, c2))
  }
}

///|
fn resolve_cell_display(
  cell_type : String,
  inner : String,
  val : String,
  formula_text : String?,
  shared : Array[String],
  styles : XlsxStyles,
  num_format_id : Int,
  uses_date_1904 : Bool,
) -> (XlsxCellKind, XlsxCellSemanticType, String) {
  let has_formula = match formula_text {
    Some(text) => text.trim() != ""
    None => false
  }
  if cell_type == "s" {
    let idx = parse_int(val)
    if idx >= 0 && idx < shared.length() {
      (XlsxCellKind::SharedString, XlsxCellSemanticType::String, shared[idx])
    } else {
      (XlsxCellKind::SharedString, XlsxCellSemanticType::String, "")
    }
  } else if cell_type == "inlineStr" {
    (
      XlsxCellKind::InlineString,
      XlsxCellSemanticType::String,
      parse_inline_str(inner),
    )
  } else if cell_type == "b" {
    let v = @cor.trim_string(val)
    if v == "1" {
      (
        XlsxCellKind::Boolean,
        if has_formula {
          XlsxCellSemanticType::FormulaCachedValue
        } else {
          XlsxCellSemanticType::Boolean
        },
        "TRUE",
      )
    } else if v == "0" {
      (
        XlsxCellKind::Boolean,
        if has_formula {
          XlsxCellSemanticType::FormulaCachedValue
        } else {
          XlsxCellSemanticType::Boolean
        },
        "FALSE",
      )
    } else {
      (
        XlsxCellKind::Boolean,
        if has_formula {
          XlsxCellSemanticType::FormulaCachedValue
        } else {
          XlsxCellSemanticType::Boolean
        },
        xml_unescape(v),
      )
    }
  } else if cell_type == "str" {
    (
      XlsxCellKind::StringResult,
      if has_formula {
        XlsxCellSemanticType::FormulaCachedValue
      } else {
        XlsxCellSemanticType::String
      },
      xml_unescape(val),
    )
  } else if cell_type == "e" {
    let v = @cor.trim_string(val)
    if v == "" {
      (
        XlsxCellKind::Error,
        if has_formula {
          XlsxCellSemanticType::FormulaCachedValue
        } else {
          XlsxCellSemanticType::Error
        },
        "#ERROR!",
      )
    } else {
      (
        XlsxCellKind::Error,
        if has_formula {
          XlsxCellSemanticType::FormulaCachedValue
        } else {
          XlsxCellSemanticType::Error
        },
        v,
      )
    }
  } else if @cor.trim_string(val) == "" {
    (
      XlsxCellKind::Blank,
      if has_formula {
        XlsxCellSemanticType::FormulaMissingCache
      } else {
        XlsxCellSemanticType::Blank
      },
      "",
    )
  } else {
    let raw = xml_unescape(val)
    let (semantic_type, rendered) = if numfmt_is_builtin_datetime_like(
        num_format_id,
      ) {
      (
        datetime_semantic_type(num_format_id, None, has_formula),
        format_excel_datetime(raw, num_format_id, None, uses_date_1904),
      )
    } else {
      match custom_numfmt_code(styles, num_format_id) {
        Some(code) =>
          if numfmt_code_is_datetime_like(code) {
            (
              datetime_semantic_type(num_format_id, Some(code), has_formula),
              format_excel_datetime(
                raw,
                num_format_id,
                Some(code),
                uses_date_1904,
              ),
            )
          } else {
            (
              if has_formula {
                XlsxCellSemanticType::FormulaCachedValue
              } else {
                XlsxCellSemanticType::Number
              },
              raw,
            )
          }
        None =>
          (
            if has_formula {
              XlsxCellSemanticType::FormulaCachedValue
            } else {
              XlsxCellSemanticType::Number
            },
            raw,
          )
      }
    }
    (XlsxCellKind::Number, semantic_type, rendered)
  }
}

///|
fn datetime_semantic_type(
  num_format_id : Int,
  custom_code : String?,
  has_formula : Bool,
) -> XlsxCellSemanticType {
  if has_formula {
    return XlsxCellSemanticType::FormulaCachedValue
  }

  let is_date_only = match custom_code {
    Some(code) => numfmt_code_is_date_only(code)
    None => numfmt_is_date_only_builtin(num_format_id)
  }
  let is_time_only = match custom_code {
    Some(code) => numfmt_code_is_time_only(code)
    None => numfmt_is_time_only_builtin(num_format_id)
  }
  let is_datetime = match custom_code {
    Some(code) => numfmt_code_is_datetime(code)
    None => numfmt_is_datetime_builtin(num_format_id)
  }

  if is_date_only {
    XlsxCellSemanticType::Date
  } else if is_time_only {
    XlsxCellSemanticType::Time
  } else if is_datetime {
    XlsxCellSemanticType::DateTime
  } else {
    XlsxCellSemanticType::DateTime
  }
}

///|
fn parse_inline_str(inner : String) -> String {
  let mut tpos = 0
  let mut acc = ""

  while true {
    let t0 = find_sub(inner, "<t", tpos)
    match t0 {
      None => break
      Some(t_start) => {
        let ttag_end = find_sub(inner, ">", t_start)
        match ttag_end {
          None => break
          Some(t_end_tag) => {
            let content_start = t_end_tag + 1
            let t1 = find_sub(inner, "</t>", content_start)
            match t1 {
              None => break
              Some(t_end) => {
                let content = inner[content_start:t_end].to_owned()
                acc = acc + xml_unescape(content)
                tpos = t_end + 4
              }
            }
          }
        }
      }
    }
  }

  acc
}

///|
fn parse_sheet_comments_xml(xml : String) -> Array[XlsxComment] {
  let authors = parse_xlsx_comment_authors(xml)
  let out : Array[XlsxComment] = []
  let mut pos = 0

  while true {
    let c0 = find_exact_start_tag(xml, "comment", pos)
    match c0 {
      None => break
      Some(i0) => {
        let ctag_end0 = find_sub(xml, ">", i0)
        match ctag_end0 {
          None => break
          Some(i1) => {
            let tag = xml[i0:i1 + 1].to_owned()
            let c_end0 = find_sub(xml, "</comment>", i1 + 1)
            match c_end0 {
              None => break
              Some(c_end) => {
                let reference = @cor.trim_string(
                  get_attr(tag, "ref").unwrap_or(""),
                )
                let author_name = lookup_xlsx_comment_author_name(
                  authors,
                  parse_int(get_attr(tag, "authorId").unwrap_or("")),
                )
                let inner = xml[i1 + 1:c_end].to_owned()
                let raw_text = parse_inline_str(
                  tag_text(inner, "text").unwrap_or(""),
                )
                let text = normalize_xlsx_comment_text(raw_text, author_name)
                let (row, column) = cell_ref_to_rc(reference)
                if reference != "" && text != "" && row > 0 && column > 0 {
                  out.push({ reference, row, column, author_name, text })
                }
                pos = c_end + 10
              }
            }
          }
        }
      }
    }
  }

  out
}

///|
fn parse_xlsx_comment_authors(xml : String) -> Array[String] {
  let out : Array[String] = []
  let mut pos = 0

  while true {
    let a0 = find_exact_start_tag(xml, "author", pos)
    match a0 {
      None => break
      Some(i0) => {
        let atag_end0 = find_sub(xml, ">", i0)
        match atag_end0 {
          None => break
          Some(i1) => {
            let a_end0 = find_sub(xml, "</author>", i1 + 1)
            match a_end0 {
              None => break
              Some(a_end) => {
                out.push(
                  normalize_xlsx_comment_author_name(
                    xml_unescape(xml[i1 + 1:a_end].to_owned()),
                  ),
                )
                pos = a_end + 9
              }
            }
          }
        }
      }
    }
  }

  out
}

///|
fn find_exact_start_tag(xml : String, name : String, start : Int) -> Int? {
  let pat = "<" + name
  let chars = xml.to_array()
  let mut pos = start
  while true {
    let found = find_sub(xml, pat, pos)
    match found {
      None => return None
      Some(idx) => {
        let end_idx = idx + pat.length()
        if end_idx >= chars.length() {
          return None
        }
        let next = chars[end_idx]
        if next == '>' ||
          next == ' ' ||
          next == '\t' ||
          next == '\n' ||
          next == '\r' {
          return Some(idx)
        }
        pos = idx + 1
      }
    }
  }
  None
}

///|
fn lookup_xlsx_comment_author_name(
  authors : Array[String],
  author_idx : Int,
) -> String? {
  if author_idx < 0 || author_idx >= authors.length() {
    None
  } else {
    let author = authors[author_idx]
    if author == "" {
      None
    } else {
      Some(author)
    }
  }
}

///|
fn normalize_xlsx_comment_author_name(text : String) -> String {
  @cor.trim_string(@cor.collapse_space_like_runs(text))
}

///|
fn normalize_xlsx_comment_text(text : String, author_name : String?) -> String {
  let normalized = @cor.trim_string(@cor.collapse_space_like_runs(text))
  if normalized == "" {
    return ""
  }

  match author_name {
    Some(author) => {
      let trimmed_author = @cor.trim_string(author)
      if trimmed_author == "" {
        normalized
      } else if normalized.has_prefix(trimmed_author + ":") {
        let stripped = @cor.trim_string(
          normalized[(trimmed_author + ":").length():].to_owned(),
        )
        if stripped == "" {
          normalized
        } else {
          stripped
        }
      } else {
        normalized
      }
    }
    None => normalized
  }
}

///|
fn tag_text(xml : String, name : String) -> String? {
  let open = "<" + name
  let t0 = find_sub(xml, open, 0)
  match t0 {
    None => None
    Some(start0) => {
      let gt0 = find_sub(xml, ">", start0)
      match gt0 {
        None => None
        Some(start1) => {
          let end0 = find_sub(xml, "</" + name + ">", start1 + 1)
          match end0 {
            None => None
            Some(end1) => Some(xml[start1 + 1:end1].to_owned())
          }
        }
      }
    }
  }
}

///|
fn cell_ref_to_rc(r : String) -> (Int, Int) {
  if r == "" {
    return (0, 0)
  }
  let chars = r.to_array()
  let mut i = 0
  let mut col = 0

  while i < chars.length() {
    let ch = chars[i]
    if ch >= 'A' && ch <= 'Z' {
      col = col * 26 + (ch.to_int() - 'A'.to_int() + 1)
      i += 1
    } else if ch >= 'a' && ch <= 'z' {
      col = col * 26 + (ch.to_int() - 'a'.to_int() + 1)
      i += 1
    } else {
      break
    }
  }

  let mut row = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      row = row * 10 + (ch.to_int() - '0'.to_int())
      i += 1
    } else {
      break
    }
  }

  (row, col)
}

///|
fn parse_int(s : String) -> Int {
  let t = @cor.trim_string(s)
  if t == "" {
    return -1
  }
  let chars = t.to_array()
  let mut i = 0
  let mut acc = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      acc = acc * 10 + (ch.to_int() - '0'.to_int())
      i += 1
    } else {
      break
    }
  }
  acc
}

///|
fn is_unsupported_cell_type(cell_type : String) -> Bool {
  cell_type != "" &&
  cell_type != "n" &&
  cell_type != "s" &&
  cell_type != "inlineStr" &&
  cell_type != "b" &&
  cell_type != "str" &&
  cell_type != "e"
}

///|
fn sheet_issue(
  kind : XlsxValidationIssueKind,
  severity : XlsxValidationSeverity,
  sheet_name : String,
  cell_reference : String?,
  part_target : String?,
  message : String,
) -> XlsxValidationIssue {
  {
    kind,
    severity,
    sheet_name: Some(sheet_name),
    cell_reference,
    part_target,
    message,
  }
}

///|
fn cell_issue(
  kind : XlsxValidationIssueKind,
  severity : XlsxValidationSeverity,
  sheet_name : String,
  cell_reference : String,
  part_target : String?,
  message : String,
) -> XlsxValidationIssue {
  {
    kind,
    severity,
    sheet_name: Some(sheet_name),
    cell_reference: Some(cell_reference),
    part_target,
    message,
  }
}
