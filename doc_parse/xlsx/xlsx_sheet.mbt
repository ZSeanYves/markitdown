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
  sheet_name : String,
  sheet_id : String?,
  relationship_id : String?,
  relationship_type : String?,
  part_target : String?,
  state : XlsxSheetState,
  sheet_xml : String,
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
    hidden_rows,
    used_min_row,
    used_min_col,
    used_max_row,
    used_max_col,
    issues: merged_issues,
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
    hidden_rows: [],
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
