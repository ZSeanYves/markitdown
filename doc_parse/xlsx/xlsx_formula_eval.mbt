///|
fn evaluate_missing_cache_formula(
  cell : XlsxCellModel,
  formula_text : String,
  context : XlsxFormulaSheetContext,
) -> XlsxFormulaTrace? {
  if formula_text.length() > context.max_formula_text_length {
    return Some({
      policy: XlsxFormulaPolicy::UnsupportedFormula,
      evaluated_value: None,
      unsupported_reason: Some("formula text too long"),
      error_reason: None,
      referenced_cells: None,
      referenced_ranges: None,
    })
  }

  let ast = match parse_xlsx_formula_text(formula_text) {
    Ok(v) => v
    Err(reason) =>
      return Some({
        policy: XlsxFormulaPolicy::UnsupportedFormula,
        evaluated_value: None,
        unsupported_reason: Some(reason),
        error_reason: None,
        referenced_cells: None,
        referenced_ranges: None,
      })
  }

  let state = { visited: Map([]) }
  state.visited.set(cell.reference, true)
  match eval_formula_ast(context, ast, cell.reference, 0, state) {
    XlsxFormulaEvalResult::Evaluated(value, _semantic_type, refs, ranges) =>
      Some({
        policy: XlsxFormulaPolicy::EvaluatedMissingCache,
        evaluated_value: Some(value),
        unsupported_reason: None,
        error_reason: None,
        referenced_cells: array_or_none(refs),
        referenced_ranges: array_or_none(ranges),
      })
    XlsxFormulaEvalResult::Unsupported(reason, refs, ranges) =>
      Some({
        policy: XlsxFormulaPolicy::UnsupportedFormula,
        evaluated_value: None,
        unsupported_reason: Some(reason),
        error_reason: None,
        referenced_cells: array_or_none(refs),
        referenced_ranges: array_or_none(ranges),
      })
    XlsxFormulaEvalResult::Error(reason, refs, ranges) =>
      Some({
        policy: XlsxFormulaPolicy::FormulaError,
        evaluated_value: None,
        unsupported_reason: None,
        error_reason: Some(reason),
        referenced_cells: array_or_none(refs),
        referenced_ranges: array_or_none(ranges),
      })
  }
}

///|
fn build_formula_sheet_context(
  cells : Array[XlsxCellModel],
) -> XlsxFormulaSheetContext {
  let map : Map[String, XlsxFormulaCellRecord] = Map([])
  for cell in cells {
    map.set(cell.reference, {
      display_text: cell.display_text,
      semantic_type: cell.semantic_type,
      formula_text: cell.formula_text,
      source_value: cell.source_value,
    })
  }
  {
    cells: map,
    max_recursion_depth: 16,
    max_range_cell_count: 1000,
    max_formula_text_length: 512,
  }
}

///|
fn eval_formula_ast(
  context : XlsxFormulaSheetContext,
  ast : XlsxFormulaAst,
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  if depth > context.max_recursion_depth {
    return XlsxFormulaEvalResult::Error(
      "formula recursion depth exceeded",
      [],
      [],
    )
  }

  match ast {
    XlsxFormulaAst::Number(v) =>
      XlsxFormulaEvalResult::Evaluated(
        format_formula_number(v),
        XlsxCellSemanticType::Number,
        [],
        [],
      )
    XlsxFormulaAst::String(v) =>
      XlsxFormulaEvalResult::Evaluated(v, XlsxCellSemanticType::String, [], [])
    XlsxFormulaAst::Bool(v) =>
      XlsxFormulaEvalResult::Evaluated(
        if v {
          "TRUE"
        } else {
          "FALSE"
        },
        XlsxCellSemanticType::Boolean,
        [],
        [],
      )
    XlsxFormulaAst::CellRef(label, row, col) =>
      eval_cell_ref(context, label, row, col, current_ref, depth, state)
    XlsxFormulaAst::RangeRef(
      start_label,
      end_label,
      start_row,
      start_col,
      end_row,
      end_col
    ) =>
      eval_range_ref(
        context, start_label, end_label, start_row, start_col, end_row, end_col,
        current_ref, depth, state,
      )
    XlsxFormulaAst::Unary(op, inner) =>
      eval_unary(context, op, inner, current_ref, depth, state)
    XlsxFormulaAst::Binary(op, left, right) =>
      eval_binary(context, op, left, right, current_ref, depth, state)
    XlsxFormulaAst::FunctionCall(name, args) =>
      eval_function_call(context, name, args, current_ref, depth, state)
  }
}

///|
fn eval_cell_ref(
  context : XlsxFormulaSheetContext,
  label : String,
  _row : Int,
  _col : Int,
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  let refs = [label]
  match context.cells.get(label) {
    None =>
      return XlsxFormulaEvalResult::Error(
        "missing cell reference: " + label,
        refs,
        [],
      )
    Some(record) =>
      match record.formula_text {
        Some(inner_formula) => {
          let trimmed_inner_formula = inner_formula.trim()
          if trimmed_inner_formula == "" {
            return scalar_result_from_record(record, refs)
          } else if state.visited.get(label) == Some(true) {
            return XlsxFormulaEvalResult::Error(
              "circular reference: " + current_ref + " -> " + label,
              refs,
              [],
            )
          } else if record.source_value != None {
            return scalar_result_from_record(record, refs)
          } else {
            let ast = match
              parse_xlsx_formula_text(trimmed_inner_formula.to_owned()) {
              Ok(v) => v
              Err(reason) =>
                return XlsxFormulaEvalResult::Unsupported(
                  "unsupported referenced formula in " + label + ": " + reason,
                  refs,
                  [],
                )
            }
            state.visited.set(label, true)
            let nested = eval_formula_ast(context, ast, label, depth + 1, state)
            ignore(state.visited.remove(label))
            return prepend_formula_ref(nested, label)
          }
        }
        None => return scalar_result_from_record(record, refs)
      }
  }
}

///|
fn eval_range_ref(
  context : XlsxFormulaSheetContext,
  start_label : String,
  end_label : String,
  start_row : Int,
  start_col : Int,
  end_row : Int,
  end_col : Int,
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  let row0 = if start_row <= end_row { start_row } else { end_row }
  let row1 = if start_row <= end_row { end_row } else { start_row }
  let col0 = if start_col <= end_col { start_col } else { end_col }
  let col1 = if start_col <= end_col { end_col } else { start_col }
  let count = (row1 - row0 + 1) * (col1 - col0 + 1)
  let range_label = start_label + ":" + end_label
  if count <= 0 {
    return XlsxFormulaEvalResult::Error("invalid range: " + range_label, [], [
      range_label,
    ])
  }
  if count > context.max_range_cell_count {
    return XlsxFormulaEvalResult::Unsupported(
      "range too large: " + range_label,
      [],
      [range_label],
    )
  }

  let values : Array[XlsxFormulaScalar] = []
  let refs : Array[String] = []
  for row in row0..<(row1 + 1) {
    for col in col0..<(col1 + 1) {
      let cell_ref = formula_rc_to_ref(row, col)
      refs.push(cell_ref)
      let scalar = match
        eval_cell_ref(
          context,
          cell_ref,
          row,
          col,
          current_ref,
          depth + 1,
          state,
        ) {
        XlsxFormulaEvalResult::Evaluated(text, semantic_type, _, _) =>
          scalar_from_text_and_semantic(text, semantic_type)
        XlsxFormulaEvalResult::Unsupported(reason, _, _) =>
          return XlsxFormulaEvalResult::Unsupported(reason, refs, [range_label])
        XlsxFormulaEvalResult::Error(reason, _, _) =>
          return XlsxFormulaEvalResult::Error(reason, refs, [range_label])
      }
      values.push(scalar)
    }
  }

  let (_, text, semantic_type) = collapse_range_scalar(values, refs, [
    range_label,
  ])
  XlsxFormulaEvalResult::Evaluated(text, semantic_type, refs, [range_label])
}

///|
fn eval_unary(
  context : XlsxFormulaSheetContext,
  op : String,
  inner : XlsxFormulaAst,
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  let value = match eval_value(context, inner, current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let (scalar, refs, ranges) = match
    flatten_value_to_scalar(
      value,
      XlsxFormulaScalarMode::ScalarOnly,
      "unary operator " + op,
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  match op {
    "+" =>
      match scalar_to_number(scalar) {
        Ok(v) =>
          XlsxFormulaEvalResult::Evaluated(
            format_formula_number(v),
            XlsxCellSemanticType::Number,
            refs,
            ranges,
          )
        Err(reason) => XlsxFormulaEvalResult::Unsupported(reason, refs, ranges)
      }
    "-" =>
      match scalar_to_number(scalar) {
        Ok(v) =>
          XlsxFormulaEvalResult::Evaluated(
            format_formula_number(-v),
            XlsxCellSemanticType::Number,
            refs,
            ranges,
          )
        Err(reason) => XlsxFormulaEvalResult::Unsupported(reason, refs, ranges)
      }
    _ =>
      XlsxFormulaEvalResult::Unsupported(
        "unsupported unary operator: " + op,
        refs,
        ranges,
      )
  }
}

///|
fn eval_binary(
  context : XlsxFormulaSheetContext,
  op : String,
  left : XlsxFormulaAst,
  right : XlsxFormulaAst,
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  let left_value = match
    eval_value(context, left, current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let right_value = match
    eval_value(context, right, current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }

  let (left_scalar, left_refs, left_ranges) = match
    flatten_value_to_scalar(
      left_value,
      XlsxFormulaScalarMode::ScalarOnly,
      "binary operator " + op,
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  let (right_scalar, right_refs, right_ranges) = match
    flatten_value_to_scalar(
      right_value,
      XlsxFormulaScalarMode::ScalarOnly,
      "binary operator " + op,
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  let refs = concat_unique_strings(left_refs, right_refs)
  let ranges = concat_unique_strings(left_ranges, right_ranges)

  match op {
    "+" | "-" | "*" | "/" | "^" => {
      let lv = match scalar_to_number(left_scalar) {
        Ok(v) => v
        Err(reason) =>
          return XlsxFormulaEvalResult::Unsupported(reason, refs, ranges)
      }
      let rv = match scalar_to_number(right_scalar) {
        Ok(v) => v
        Err(reason) =>
          return XlsxFormulaEvalResult::Unsupported(reason, refs, ranges)
      }
      if op == "/" && is_zeroish(rv) {
        return XlsxFormulaEvalResult::Error("division by zero", refs, ranges)
      }
      let value = match op {
        "+" => lv + rv
        "-" => lv - rv
        "*" => lv * rv
        "/" => lv / rv
        "^" => @math.pow(lv, rv)
        _ => 0.0
      }
      XlsxFormulaEvalResult::Evaluated(
        format_formula_number(value),
        XlsxCellSemanticType::Number,
        refs,
        ranges,
      )
    }
    "&" =>
      XlsxFormulaEvalResult::Evaluated(
        scalar_to_text(left_scalar) + scalar_to_text(right_scalar),
        XlsxCellSemanticType::String,
        refs,
        ranges,
      )
    "=" | "<>" | "<" | "<=" | ">" | ">=" => {
      let cmp = compare_formula_scalars(left_scalar, right_scalar)
      match cmp {
        Ok(ordering) => {
          let result = match op {
            "=" => ordering == 0
            "<>" => ordering != 0
            "<" => ordering < 0
            "<=" => ordering <= 0
            ">" => ordering > 0
            ">=" => ordering >= 0
            _ => false
          }
          XlsxFormulaEvalResult::Evaluated(
            if result {
              "TRUE"
            } else {
              "FALSE"
            },
            XlsxCellSemanticType::Boolean,
            refs,
            ranges,
          )
        }
        Err(reason) => XlsxFormulaEvalResult::Unsupported(reason, refs, ranges)
      }
    }
    _ =>
      XlsxFormulaEvalResult::Unsupported(
        "unsupported binary operator: " + op,
        refs,
        ranges,
      )
  }
}

///|
fn eval_function_call(
  context : XlsxFormulaSheetContext,
  name : String,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  match name {
    "SUM" =>
      eval_aggregate_numbers(context, args, current_ref, depth, state, "SUM")
    "AVERAGE" =>
      eval_aggregate_numbers(
        context, args, current_ref, depth, state, "AVERAGE",
      )
    "MIN" =>
      eval_aggregate_numbers(context, args, current_ref, depth, state, "MIN")
    "MAX" =>
      eval_aggregate_numbers(context, args, current_ref, depth, state, "MAX")
    "COUNT" =>
      eval_count_function(context, args, current_ref, depth, state, false)
    "COUNTA" =>
      eval_count_function(context, args, current_ref, depth, state, true)
    "IF" => eval_if_function(context, args, current_ref, depth, state)
    "ROUND" => eval_round_function(context, args, current_ref, depth, state)
    "ABS" => eval_abs_function(context, args, current_ref, depth, state)
    "CONCAT" | "CONCATENATE" =>
      eval_concat_function(context, args, current_ref, depth, state)
    "LEFT" => eval_left_function(context, args, current_ref, depth, state)
    "RIGHT" => eval_right_function(context, args, current_ref, depth, state)
    "LEN" => eval_len_function(context, args, current_ref, depth, state)
    "LOWER" =>
      eval_lower_upper_function(context, args, current_ref, depth, state, false)
    "UPPER" =>
      eval_lower_upper_function(context, args, current_ref, depth, state, true)
    "TRIM" => eval_trim_function(context, args, current_ref, depth, state)
    "TODAY" | "NOW" | "RAND" | "RANDBETWEEN" =>
      XlsxFormulaEvalResult::Unsupported(
        "volatile function unsupported: " + name,
        [],
        [],
      )
    _ =>
      XlsxFormulaEvalResult::Unsupported("unsupported function: " + name, [], [])
  }
}

///|
fn eval_aggregate_numbers(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
  fn_name : String,
) -> XlsxFormulaEvalResult {
  if args.length() == 0 {
    return XlsxFormulaEvalResult::Unsupported(
      fn_name + " requires at least one argument",
      [],
      [],
    )
  }
  let scalars = match
    eval_argument_scalars(context, args, current_ref, depth, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let refs = scalars.1
  let ranges = scalars.2
  let numbers : Array[Double] = []
  for scalar in scalars.0 {
    match scalar {
      XlsxFormulaScalar::Number(v) => numbers.push(v)
      XlsxFormulaScalar::Blank => ()
      XlsxFormulaScalar::String(_) | XlsxFormulaScalar::Bool(_) => ()
      XlsxFormulaScalar::Error(code) =>
        return XlsxFormulaEvalResult::Error(code, refs, ranges)
    }
  }
  if fn_name == "COUNT" {
    return XlsxFormulaEvalResult::Evaluated(
      numbers.length().to_string(),
      XlsxCellSemanticType::Number,
      refs,
      ranges,
    )
  }
  if numbers.length() == 0 {
    return XlsxFormulaEvalResult::Evaluated(
      "0",
      XlsxCellSemanticType::Number,
      refs,
      ranges,
    )
  }

  let mut acc = numbers[0]
  let mut sum = 0.0
  let mut min_v = numbers[0]
  let mut max_v = numbers[0]
  for value in numbers {
    sum = sum + value
    if value < min_v {
      min_v = value
    }
    if value > max_v {
      max_v = value
    }
    acc = value
  }
  let result = match fn_name {
    "SUM" => sum
    "AVERAGE" => sum / numbers.length().to_double()
    "MIN" => min_v
    "MAX" => max_v
    _ => acc
  }
  XlsxFormulaEvalResult::Evaluated(
    format_formula_number(result),
    XlsxCellSemanticType::Number,
    refs,
    ranges,
  )
}

///|
fn eval_count_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
  count_non_blank : Bool,
) -> XlsxFormulaEvalResult {
  if args.length() == 0 {
    return XlsxFormulaEvalResult::Unsupported(
      "COUNT/COUNTA requires at least one argument",
      [],
      [],
    )
  }
  let scalars = match
    eval_argument_scalars(context, args, current_ref, depth, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let mut count = 0
  for scalar in scalars.0 {
    match scalar {
      XlsxFormulaScalar::Number(_) => count = count + 1
      XlsxFormulaScalar::Bool(_) => if count_non_blank { count = count + 1 }
      XlsxFormulaScalar::String(text) =>
        if count_non_blank && text != "" {
          count = count + 1
        }
      XlsxFormulaScalar::Blank => ()
      XlsxFormulaScalar::Error(code) =>
        return XlsxFormulaEvalResult::Error(code, scalars.1, scalars.2)
    }
  }
  XlsxFormulaEvalResult::Evaluated(
    count.to_string(),
    XlsxCellSemanticType::Number,
    scalars.1,
    scalars.2,
  )
}

///|
fn eval_if_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  if args.length() < 2 || args.length() > 3 {
    return XlsxFormulaEvalResult::Unsupported(
      "IF requires two or three arguments",
      [],
      [],
    )
  }
  let cond_value = match
    eval_value(context, args[0], current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let (cond_scalar, cond_refs, cond_ranges) = match
    flatten_value_to_scalar(
      cond_value,
      XlsxFormulaScalarMode::ScalarOnly,
      "IF condition",
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  let cond = match scalar_to_bool(cond_scalar) {
    Ok(v) => v
    Err(reason) =>
      return XlsxFormulaEvalResult::Unsupported(reason, cond_refs, cond_ranges)
  }
  let branch = if cond {
    args[1]
  } else if args.length() == 3 {
    args[2]
  } else {
    XlsxFormulaAst::Bool(false)
  }
  let branch_value = match
    eval_value(context, branch, current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let (branch_scalar, branch_refs, branch_ranges) = match
    flatten_value_to_scalar(
      branch_value,
      XlsxFormulaScalarMode::ScalarOnly,
      "IF branch",
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  let refs = concat_unique_strings(cond_refs, branch_refs)
  let ranges = concat_unique_strings(cond_ranges, branch_ranges)
  formula_scalar_to_result(branch_scalar, refs, ranges)
}

///|
fn eval_round_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  if args.length() != 2 {
    return XlsxFormulaEvalResult::Unsupported(
      "ROUND requires exactly two arguments",
      [],
      [],
    )
  }
  let (value, digits, refs, ranges) = match
    eval_numeric_pair(context, args, current_ref, depth, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let scale = @math.pow(10.0, digits)
  let rounded = (value * scale).round() / scale
  XlsxFormulaEvalResult::Evaluated(
    format_formula_number(rounded),
    XlsxCellSemanticType::Number,
    refs,
    ranges,
  )
}

///|
fn eval_abs_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  if args.length() != 1 {
    return XlsxFormulaEvalResult::Unsupported(
      "ABS requires exactly one argument",
      [],
      [],
    )
  }
  let value = match
    eval_value(context, args[0], current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let (scalar, refs, ranges) = match
    flatten_value_to_scalar(
      value,
      XlsxFormulaScalarMode::ScalarOnly,
      "ABS argument",
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  match scalar_to_number(scalar) {
    Ok(v) =>
      XlsxFormulaEvalResult::Evaluated(
        format_formula_number(v.abs()),
        XlsxCellSemanticType::Number,
        refs,
        ranges,
      )
    Err(reason) => XlsxFormulaEvalResult::Unsupported(reason, refs, ranges)
  }
}

///|
fn eval_concat_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  let scalars = match
    eval_argument_scalars(context, args, current_ref, depth, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let out = StringBuilder::new()
  for scalar in scalars.0 {
    out.write_string(scalar_to_text(scalar))
  }
  XlsxFormulaEvalResult::Evaluated(
    out.to_string(),
    XlsxCellSemanticType::String,
    scalars.1,
    scalars.2,
  )
}

///|
fn eval_left_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  if args.length() == 0 || args.length() > 2 {
    return XlsxFormulaEvalResult::Unsupported(
      "LEFT requires one or two arguments",
      [],
      [],
    )
  }
  let text_value = match
    eval_value(context, args[0], current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let (scalar, refs, ranges) = match
    flatten_value_to_scalar(
      text_value,
      XlsxFormulaScalarMode::ScalarOnly,
      "LEFT argument",
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  let text = scalar_to_text(scalar)
  let count = if args.length() == 2 {
    match eval_integer_arg(context, args[1], current_ref, depth + 1, state) {
      Ok((value, more_refs, more_ranges)) => {
        let refs2 = concat_unique_strings(refs, more_refs)
        let ranges2 = concat_unique_strings(ranges, more_ranges)
        let taken = take_left_chars(text, value)
        return XlsxFormulaEvalResult::Evaluated(
          taken,
          XlsxCellSemanticType::String,
          refs2,
          ranges2,
        )
      }
      Err(res) => return res
    }
  } else {
    1
  }
  XlsxFormulaEvalResult::Evaluated(
    take_left_chars(text, count),
    XlsxCellSemanticType::String,
    refs,
    ranges,
  )
}

///|
fn eval_right_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  if args.length() == 0 || args.length() > 2 {
    return XlsxFormulaEvalResult::Unsupported(
      "RIGHT requires one or two arguments",
      [],
      [],
    )
  }
  let text_value = match
    eval_value(context, args[0], current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let (scalar, refs, ranges) = match
    flatten_value_to_scalar(
      text_value,
      XlsxFormulaScalarMode::ScalarOnly,
      "RIGHT argument",
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  let text = scalar_to_text(scalar)
  if args.length() == 2 {
    match eval_integer_arg(context, args[1], current_ref, depth + 1, state) {
      Ok((value, more_refs, more_ranges)) => {
        let refs2 = concat_unique_strings(refs, more_refs)
        let ranges2 = concat_unique_strings(ranges, more_ranges)
        return XlsxFormulaEvalResult::Evaluated(
          take_right_chars(text, value),
          XlsxCellSemanticType::String,
          refs2,
          ranges2,
        )
      }
      Err(res) => return res
    }
  }
  XlsxFormulaEvalResult::Evaluated(
    take_right_chars(text, 1),
    XlsxCellSemanticType::String,
    refs,
    ranges,
  )
}

///|
fn eval_len_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  if args.length() != 1 {
    return XlsxFormulaEvalResult::Unsupported(
      "LEN requires exactly one argument",
      [],
      [],
    )
  }
  let value = match
    eval_value(context, args[0], current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let (scalar, refs, ranges) = match
    flatten_value_to_scalar(
      value,
      XlsxFormulaScalarMode::ScalarOnly,
      "LEN argument",
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  XlsxFormulaEvalResult::Evaluated(
    scalar_to_text(scalar).to_array().length().to_string(),
    XlsxCellSemanticType::Number,
    refs,
    ranges,
  )
}

///|
fn eval_lower_upper_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
  upper : Bool,
) -> XlsxFormulaEvalResult {
  if args.length() != 1 {
    return XlsxFormulaEvalResult::Unsupported(
      "LOWER/UPPER requires exactly one argument",
      [],
      [],
    )
  }
  let value = match
    eval_value(context, args[0], current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let (scalar, refs, ranges) = match
    flatten_value_to_scalar(
      value,
      XlsxFormulaScalarMode::ScalarOnly,
      if upper {
        "UPPER argument"
      } else {
        "LOWER argument"
      },
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  let text = scalar_to_text(scalar)
  XlsxFormulaEvalResult::Evaluated(
    if upper {
      text.to_upper()
    } else {
      text.to_lower()
    },
    XlsxCellSemanticType::String,
    refs,
    ranges,
  )
}

///|
fn eval_trim_function(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> XlsxFormulaEvalResult {
  if args.length() != 1 {
    return XlsxFormulaEvalResult::Unsupported(
      "TRIM requires exactly one argument",
      [],
      [],
    )
  }
  let value = match
    eval_value(context, args[0], current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return res
  }
  let (scalar, refs, ranges) = match
    flatten_value_to_scalar(
      value,
      XlsxFormulaScalarMode::ScalarOnly,
      "TRIM argument",
    ) {
    Ok(v) => v
    Err(res) => return res
  }
  XlsxFormulaEvalResult::Evaluated(
    collapse_internal_ws(scalar_to_text(scalar)),
    XlsxCellSemanticType::String,
    refs,
    ranges,
  )
}

///|
fn eval_argument_scalars(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> Result[
  (Array[XlsxFormulaScalar], Array[String], Array[String]),
  XlsxFormulaEvalResult,
] {
  let scalars : Array[XlsxFormulaScalar] = []
  let refs : Array[String] = []
  let ranges : Array[String] = []
  for arg in args {
    let value = match eval_value(context, arg, current_ref, depth + 1, state) {
      Ok(v) => v
      Err(res) => return Err(res)
    }
    match value {
      XlsxFormulaValue::Scalar(scalar, _, _) => scalars.push(scalar)
      XlsxFormulaValue::Range(items, item_refs, item_ranges) => {
        for scalar in items {
          scalars.push(scalar)
        }
        merge_unique_strings(refs, item_refs)
        merge_unique_strings(ranges, item_ranges)
      }
    }
    let (value_refs, value_ranges) = value_refs_and_ranges(value)
    merge_unique_strings(refs, value_refs)
    merge_unique_strings(ranges, value_ranges)
  }
  Ok((scalars, refs, ranges))
}

///|
fn eval_numeric_pair(
  context : XlsxFormulaSheetContext,
  args : Array[XlsxFormulaAst],
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> Result[
  (Double, Double, Array[String], Array[String]),
  XlsxFormulaEvalResult,
] {
  let left = match eval_value(context, args[0], current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return Err(res)
  }
  let right = match
    eval_value(context, args[1], current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return Err(res)
  }
  let (left_scalar, left_refs, left_ranges) = match
    flatten_value_to_scalar(
      left,
      XlsxFormulaScalarMode::ScalarOnly,
      "numeric argument",
    ) {
    Ok(v) => v
    Err(res) => return Err(res)
  }
  let (right_scalar, right_refs, right_ranges) = match
    flatten_value_to_scalar(
      right,
      XlsxFormulaScalarMode::ScalarOnly,
      "numeric argument",
    ) {
    Ok(v) => v
    Err(res) => return Err(res)
  }
  let lv = match scalar_to_number(left_scalar) {
    Ok(v) => v
    Err(reason) =>
      return Err(
        XlsxFormulaEvalResult::Unsupported(reason, left_refs, left_ranges),
      )
  }
  let rv = match scalar_to_number(right_scalar) {
    Ok(v) => v
    Err(reason) =>
      return Err(
        XlsxFormulaEvalResult::Unsupported(
          reason,
          concat_unique_strings(left_refs, right_refs),
          concat_unique_strings(left_ranges, right_ranges),
        ),
      )
  }
  Ok(
    (
      lv,
      rv,
      concat_unique_strings(left_refs, right_refs),
      concat_unique_strings(left_ranges, right_ranges),
    ),
  )
}

///|
fn eval_integer_arg(
  context : XlsxFormulaSheetContext,
  arg : XlsxFormulaAst,
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> Result[(Int, Array[String], Array[String]), XlsxFormulaEvalResult] {
  let value = match eval_value(context, arg, current_ref, depth + 1, state) {
    Ok(v) => v
    Err(res) => return Err(res)
  }
  let (scalar, refs, ranges) = match
    flatten_value_to_scalar(
      value,
      XlsxFormulaScalarMode::ScalarOnly,
      "integer argument",
    ) {
    Ok(v) => v
    Err(res) => return Err(res)
  }
  let number = match scalar_to_number(scalar) {
    Ok(v) => v
    Err(reason) =>
      return Err(XlsxFormulaEvalResult::Unsupported(reason, refs, ranges))
  }
  Ok((number.round().to_int(), refs, ranges))
}

///|
fn eval_value(
  context : XlsxFormulaSheetContext,
  ast : XlsxFormulaAst,
  current_ref : String,
  depth : Int,
  state : XlsxFormulaEvalState,
) -> Result[XlsxFormulaValue, XlsxFormulaEvalResult] {
  match ast {
    XlsxFormulaAst::RangeRef(
      start_label,
      end_label,
      start_row,
      start_col,
      end_row,
      end_col
    ) => {
      let row0 = if start_row <= end_row { start_row } else { end_row }
      let row1 = if start_row <= end_row { end_row } else { start_row }
      let col0 = if start_col <= end_col { start_col } else { end_col }
      let col1 = if start_col <= end_col { end_col } else { start_col }
      let count = (row1 - row0 + 1) * (col1 - col0 + 1)
      let range_label = start_label + ":" + end_label
      if count <= 0 {
        return Err(
          XlsxFormulaEvalResult::Error("invalid range: " + range_label, [], [
            range_label,
          ]),
        )
      }
      if count > context.max_range_cell_count {
        return Err(
          XlsxFormulaEvalResult::Unsupported(
            "range too large: " + range_label,
            [],
            [range_label],
          ),
        )
      }
      let scalars : Array[XlsxFormulaScalar] = []
      let refs : Array[String] = []
      for row in row0..<(row1 + 1) {
        for col in col0..<(col1 + 1) {
          let cell_ref = formula_rc_to_ref(row, col)
          refs.push(cell_ref)
          let scalar = match
            eval_cell_ref(
              context,
              cell_ref,
              row,
              col,
              current_ref,
              depth + 1,
              state,
            ) {
            XlsxFormulaEvalResult::Evaluated(text, semantic_type, _, _) =>
              scalar_from_text_and_semantic(text, semantic_type)
            XlsxFormulaEvalResult::Unsupported(reason, _, _) =>
              return Err(
                XlsxFormulaEvalResult::Unsupported(reason, refs, [range_label]),
              )
            XlsxFormulaEvalResult::Error(reason, _, _) =>
              return Err(
                XlsxFormulaEvalResult::Error(reason, refs, [range_label]),
              )
          }
          scalars.push(scalar)
        }
      }
      Ok(XlsxFormulaValue::Range(scalars, refs, [range_label]))
    }
    _ =>
      match eval_formula_ast(context, ast, current_ref, depth, state) {
        XlsxFormulaEvalResult::Evaluated(text, semantic_type, refs, ranges) =>
          Ok(
            XlsxFormulaValue::Scalar(
              scalar_from_text_and_semantic(text, semantic_type),
              refs,
              ranges,
            ),
          )
        XlsxFormulaEvalResult::Unsupported(reason, refs, ranges) =>
          Err(XlsxFormulaEvalResult::Unsupported(reason, refs, ranges))
        XlsxFormulaEvalResult::Error(reason, refs, ranges) =>
          Err(XlsxFormulaEvalResult::Error(reason, refs, ranges))
      }
  }
}

///|
fn scalar_result_from_record(
  record : XlsxFormulaCellRecord,
  refs : Array[String],
) -> XlsxFormulaEvalResult {
  match record.semantic_type {
    XlsxCellSemanticType::Error =>
      XlsxFormulaEvalResult::Error(record.display_text, refs, [])
    _ =>
      XlsxFormulaEvalResult::Evaluated(
        record.display_text,
        record.semantic_type,
        refs,
        [],
      )
  }
}

///|
fn scalar_from_text_and_semantic(
  text : String,
  semantic_type : XlsxCellSemanticType,
) -> XlsxFormulaScalar {
  let trimmed = text.trim().to_owned()
  match semantic_type {
    XlsxCellSemanticType::Boolean =>
      if trimmed.to_upper() == "TRUE" {
        XlsxFormulaScalar::Bool(true)
      } else if trimmed.to_upper() == "FALSE" {
        XlsxFormulaScalar::Bool(false)
      } else {
        XlsxFormulaScalar::String(text)
      }
    XlsxCellSemanticType::Number | XlsxCellSemanticType::FormulaCachedValue =>
      match parse_formula_double(trimmed) {
        Ok(v) => XlsxFormulaScalar::Number(v)
        Err(_) => XlsxFormulaScalar::String(text)
      }
    XlsxCellSemanticType::Blank | XlsxCellSemanticType::FormulaMissingCache =>
      if trimmed == "" {
        XlsxFormulaScalar::Blank
      } else {
        XlsxFormulaScalar::String(text)
      }
    XlsxCellSemanticType::Error => XlsxFormulaScalar::Error(text)
    _ =>
      match parse_formula_double(trimmed) {
        Ok(v) =>
          if semantic_type == XlsxCellSemanticType::Date ||
            semantic_type == XlsxCellSemanticType::DateTime ||
            semantic_type == XlsxCellSemanticType::Time {
            XlsxFormulaScalar::String(text)
          } else {
            XlsxFormulaScalar::Number(v)
          }
        Err(_) => XlsxFormulaScalar::String(text)
      }
  }
}

///|
fn flatten_value_to_scalar(
  value : XlsxFormulaValue,
  mode : XlsxFormulaScalarMode,
  context : String,
) -> Result[
  (XlsxFormulaScalar, Array[String], Array[String]),
  XlsxFormulaEvalResult,
] {
  match value {
    XlsxFormulaValue::Scalar(scalar, refs, ranges) => Ok((scalar, refs, ranges))
    XlsxFormulaValue::Range(_, refs, ranges) =>
      match mode {
        XlsxFormulaScalarMode::ScalarOnly =>
          Err(
            XlsxFormulaEvalResult::Unsupported(
              "range scalar coercion unsupported in " + context,
              refs,
              ranges,
            ),
          )
      }
  }
}

///|
fn value_refs_and_ranges(
  value : XlsxFormulaValue,
) -> (Array[String], Array[String]) {
  match value {
    XlsxFormulaValue::Scalar(_, refs, ranges) => (refs, ranges)
    XlsxFormulaValue::Range(_, refs, ranges) => (refs, ranges)
  }
}

///|
fn collapse_range_scalar(
  values : Array[XlsxFormulaScalar],
  _refs : Array[String],
  _ranges : Array[String],
) -> (XlsxFormulaScalar, String, XlsxCellSemanticType) {
  if values.length() == 0 {
    return (XlsxFormulaScalar::Blank, "", XlsxCellSemanticType::Blank)
  }
  let scalar = values[0]
  match scalar {
    XlsxFormulaScalar::Number(v) =>
      (scalar, format_formula_number(v), XlsxCellSemanticType::Number)
    XlsxFormulaScalar::Bool(v) =>
      (scalar, if v { "TRUE" } else { "FALSE" }, XlsxCellSemanticType::Boolean)
    XlsxFormulaScalar::Blank => (scalar, "", XlsxCellSemanticType::Blank)
    XlsxFormulaScalar::Error(code) =>
      (scalar, code, XlsxCellSemanticType::Error)
    XlsxFormulaScalar::String(text) =>
      (scalar, text, XlsxCellSemanticType::String)
  }
}

///|
fn formula_scalar_to_result(
  scalar : XlsxFormulaScalar,
  refs : Array[String],
  ranges : Array[String],
) -> XlsxFormulaEvalResult {
  match scalar {
    XlsxFormulaScalar::Number(v) =>
      XlsxFormulaEvalResult::Evaluated(
        format_formula_number(v),
        XlsxCellSemanticType::Number,
        refs,
        ranges,
      )
    XlsxFormulaScalar::String(text) =>
      XlsxFormulaEvalResult::Evaluated(
        text,
        XlsxCellSemanticType::String,
        refs,
        ranges,
      )
    XlsxFormulaScalar::Bool(v) =>
      XlsxFormulaEvalResult::Evaluated(
        if v {
          "TRUE"
        } else {
          "FALSE"
        },
        XlsxCellSemanticType::Boolean,
        refs,
        ranges,
      )
    XlsxFormulaScalar::Blank =>
      XlsxFormulaEvalResult::Evaluated(
        "",
        XlsxCellSemanticType::Blank,
        refs,
        ranges,
      )
    XlsxFormulaScalar::Error(code) =>
      XlsxFormulaEvalResult::Error(code, refs, ranges)
  }
}

///|
fn scalar_to_number(scalar : XlsxFormulaScalar) -> Result[Double, String] {
  match scalar {
    XlsxFormulaScalar::Number(v) => Ok(v)
    XlsxFormulaScalar::Bool(v) => Ok(if v { 1.0 } else { 0.0 })
    XlsxFormulaScalar::Blank => Ok(0.0)
    XlsxFormulaScalar::String(text) =>
      match parse_formula_double(text.trim().to_owned()) {
        Ok(v) => Ok(v)
        Err(_) => Err("numeric coercion unsupported for text: " + text)
      }
    XlsxFormulaScalar::Error(code) => Err(code)
  }
}

///|
fn scalar_to_bool(scalar : XlsxFormulaScalar) -> Result[Bool, String] {
  match scalar {
    XlsxFormulaScalar::Bool(v) => Ok(v)
    XlsxFormulaScalar::Number(v) => Ok(!is_zeroish(v))
    XlsxFormulaScalar::Blank => Ok(false)
    XlsxFormulaScalar::String(text) => {
      let trimmed = text.trim().to_owned().to_upper()
      if trimmed == "TRUE" {
        Ok(true)
      } else if trimmed == "FALSE" || trimmed == "" {
        Ok(false)
      } else {
        match parse_formula_double(trimmed) {
          Ok(v) => Ok(!is_zeroish(v))
          Err(_) => Err("boolean coercion unsupported for text: " + text)
        }
      }
    }
    XlsxFormulaScalar::Error(code) => Err(code)
  }
}

///|
fn scalar_to_text(scalar : XlsxFormulaScalar) -> String {
  match scalar {
    XlsxFormulaScalar::Number(v) => format_formula_number(v)
    XlsxFormulaScalar::String(text) => text
    XlsxFormulaScalar::Bool(v) => if v { "TRUE" } else { "FALSE" }
    XlsxFormulaScalar::Blank => ""
    XlsxFormulaScalar::Error(code) => code
  }
}

///|
fn compare_formula_scalars(
  left : XlsxFormulaScalar,
  right : XlsxFormulaScalar,
) -> Result[Int, String] {
  match (left, right) {
    (XlsxFormulaScalar::Number(a), XlsxFormulaScalar::Number(b)) =>
      Ok(if a < b { -1 } else if a > b { 1 } else { 0 })
    (XlsxFormulaScalar::Bool(a), XlsxFormulaScalar::Bool(b)) =>
      Ok(if a == b { 0 } else if !a && b { -1 } else { 1 })
    (XlsxFormulaScalar::String(a), XlsxFormulaScalar::String(b)) =>
      Ok(if a < b { -1 } else if a > b { 1 } else { 0 })
    (XlsxFormulaScalar::Blank, XlsxFormulaScalar::Blank) => Ok(0)
    _ => {
      let a = scalar_to_number(left)
      let b = scalar_to_number(right)
      match (a, b) {
        (Ok(av), Ok(bv)) =>
          Ok(if av < bv { -1 } else if av > bv { 1 } else { 0 })
        _ => Err("comparison coercion unsupported")
      }
    }
  }
}

///|
fn prepend_formula_ref(
  result : XlsxFormulaEvalResult,
  reference : String,
) -> XlsxFormulaEvalResult {
  match result {
    XlsxFormulaEvalResult::Evaluated(text, semantic_type, refs, ranges) =>
      XlsxFormulaEvalResult::Evaluated(
        text,
        semantic_type,
        concat_unique_strings([reference], refs),
        ranges,
      )
    XlsxFormulaEvalResult::Unsupported(reason, refs, ranges) =>
      XlsxFormulaEvalResult::Unsupported(
        reason,
        concat_unique_strings([reference], refs),
        ranges,
      )
    XlsxFormulaEvalResult::Error(reason, refs, ranges) =>
      XlsxFormulaEvalResult::Error(
        reason,
        concat_unique_strings([reference], refs),
        ranges,
      )
  }
}

///|
fn format_formula_number(value : Double) -> String {
  let rounded = if is_zeroish(value) { 0.0 } else { value }
  let raw = rounded.to_string()
  if raw.contains("e") || raw.contains("E") {
    return raw
  }
  if !raw.contains(".") {
    return raw
  }
  let chars = raw.to_array()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == '0' {
    end = end - 1
  }
  if end > 0 && chars[end - 1] == '.' {
    end = end - 1
  }
  String::from_array(chars[:end].to_owned())
}

///|
fn is_zeroish(value : Double) -> Bool {
  value.abs() < 0.0000000001
}

///|
fn formula_rc_to_ref(row : Int, col : Int) -> String {
  if row <= 0 || col <= 0 {
    return ""
  }
  let parts : Array[String] = []
  let mut n = col
  while n > 0 {
    let rem = (n - 1) % 26
    let ch = match ('A'.to_int() + rem).to_char() {
      Some(v) => v
      None => return ""
    }
    parts.push(ch.to_string())
    n = (n - 1) / 26
  }
  let out = StringBuilder::new()
  let mut i = parts.length()
  while i > 0 {
    out.write_string(parts[i - 1])
    i = i - 1
  }
  out.write_string(row.to_string())
  out.to_string()
}

///|
fn concat_unique_strings(
  left : Array[String],
  right : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  merge_unique_strings(out, left)
  merge_unique_strings(out, right)
  out
}

///|
fn merge_unique_strings(out : Array[String], values : Array[String]) -> Unit {
  for value in values {
    let mut seen = false
    for existing in out {
      if existing == value {
        seen = true
        break
      }
    }
    if !seen {
      out.push(value)
    }
  }
}

///|
fn array_or_none(values : Array[String]) -> Array[String]? {
  if values.length() == 0 {
    None
  } else {
    Some(values)
  }
}

///|
fn take_left_chars(text : String, count : Int) -> String {
  if count <= 0 {
    return ""
  }
  let chars = text.to_array()
  let end_ = if count < chars.length() { count } else { chars.length() }
  String::from_array(chars[:end_].to_owned())
}

///|
fn take_right_chars(text : String, count : Int) -> String {
  if count <= 0 {
    return ""
  }
  let chars = text.to_array()
  let start = if count < chars.length() { chars.length() - count } else { 0 }
  String::from_array(chars[start:].to_owned())
}

///|
fn collapse_internal_ws(text : String) -> String {
  let chars = text.trim().to_array()
  let out : Array[Char] = []
  let mut prev_space = false
  for ch in chars {
    let is_space = ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
    if is_space {
      if !prev_space {
        out.push(' ')
      }
      prev_space = true
    } else {
      out.push(ch)
      prev_space = false
    }
  }
  String::from_array(out)
}

///|
fn parse_formula_double(text : String) -> Result[Double, String] {
  try @string.parse_double(text) catch {
    _ => Err("invalid floating point literal")
  } noraise {
    value => Ok(value)
  }
}
