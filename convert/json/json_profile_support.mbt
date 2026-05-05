///|
priv struct JsonProfilingCounters {
  value_cell_stringify_calls : Ref[Int]
  scalar_text_stringify_calls : Ref[Int]
  uniform_table_rows_seen : Ref[Int]
  uniform_table_columns_seen : Ref[Int]
  nested_stringify_elapsed_ms : Ref[UInt64]
  uniform_table_detect_elapsed_ms : Ref[UInt64]
}

///|
let json_profile_enabled : Ref[Bool] = { val: false }

///|
pub struct JsonLoweringProfileSummary {
  value_cell_stringify_calls : Int
  scalar_text_stringify_calls : Int
  uniform_table_rows_seen : Int
  uniform_table_columns_seen : Int
  nested_stringify_elapsed_ms : UInt64
  uniform_table_detect_elapsed_ms : UInt64
}

///|
let current_json_profile : Ref[JsonProfilingCounters] = {
  val: {
    value_cell_stringify_calls: { val: 0 },
    scalar_text_stringify_calls: { val: 0 },
    uniform_table_rows_seen: { val: 0 },
    uniform_table_columns_seen: { val: 0 },
    nested_stringify_elapsed_ms: { val: 0 },
    uniform_table_detect_elapsed_ms: { val: 0 },
  },
}

///|
fn reset_json_profile_counters() -> Unit {
  current_json_profile.val = {
    value_cell_stringify_calls: { val: 0 },
    scalar_text_stringify_calls: { val: 0 },
    uniform_table_rows_seen: { val: 0 },
    uniform_table_columns_seen: { val: 0 },
    nested_stringify_elapsed_ms: { val: 0 },
    uniform_table_detect_elapsed_ms: { val: 0 },
  }
}

///|
fn json_profile_begin(enabled : Bool) -> Unit {
  reset_json_profile_counters()
  json_profile_enabled.val = enabled
}

///|
fn json_profile_finish() -> JsonLoweringProfileSummary {
  let summary : JsonLoweringProfileSummary = {
    value_cell_stringify_calls: current_json_profile.val.value_cell_stringify_calls.val,
    scalar_text_stringify_calls: current_json_profile.val.scalar_text_stringify_calls.val,
    uniform_table_rows_seen: current_json_profile.val.uniform_table_rows_seen.val,
    uniform_table_columns_seen: current_json_profile.val.uniform_table_columns_seen.val,
    nested_stringify_elapsed_ms: current_json_profile.val.nested_stringify_elapsed_ms.val,
    uniform_table_detect_elapsed_ms: current_json_profile.val.uniform_table_detect_elapsed_ms.val,
  }
  json_profile_enabled.val = false
  summary
}

///|
fn profile_value_cell_stringify_call() -> Unit {
  if json_profile_enabled.val {
    current_json_profile.val.value_cell_stringify_calls.val += 1
  }
}

///|
fn profile_scalar_text_stringify_call() -> Unit {
  if json_profile_enabled.val {
    current_json_profile.val.scalar_text_stringify_calls.val += 1
  }
}

///|
fn profile_uniform_table_detect_elapsed_ms(
  elapsed_ms : UInt64,
  row_count : Int,
  column_count : Int,
) -> Unit {
  if json_profile_enabled.val {
    current_json_profile.val.uniform_table_detect_elapsed_ms.val += elapsed_ms
    current_json_profile.val.uniform_table_rows_seen.val = row_count
    current_json_profile.val.uniform_table_columns_seen.val = column_count
  }
}

///|
fn profile_nested_stringify_elapsed_ms(elapsed_ms : UInt64) -> Unit {
  if json_profile_enabled.val {
    current_json_profile.val.nested_stringify_elapsed_ms.val += elapsed_ms
  }
}
