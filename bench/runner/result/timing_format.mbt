///|
pub fn rounded_wall_us_to_ms(wall_us : Int64) -> Int64 {
  if wall_us >= 0L {
    (wall_us + 500L) / 1000L
  } else {
    -((0L - wall_us + 500L) / 1000L)
  }
}

///|
pub fn format_optional_int(value : Int?) -> String {
  value.map(value => value.to_string()).unwrap_or("null")
}

///|
pub fn format_optional_int64(value : Int64?) -> String {
  value.map(value => value.to_string()).unwrap_or("null")
}

///|
pub fn format_wall_pair(wall_ms : Int64?, wall_us : Int64?) -> String {
  match wall_ms {
    Some(ms) =>
      match wall_us {
        Some(us) => format_ms_from_us(us) + " (" + us.to_string() + " us)"
        None => ms.to_string() + " ms"
      }
    None =>
      match wall_us {
        Some(us) => format_ms_from_us(us) + " (" + us.to_string() + " us)"
        None => "null"
      }
  }
}

///|
pub fn format_wall_ms_from_us(value : Int64?) -> String {
  match value {
    Some(us) => format_ms_from_us(us)
    None => "null"
  }
}

///|
pub fn format_optional_speedup(value : Double?) -> String {
  value.map(value => value.to_string() + "x").unwrap_or("null")
}

///|
pub fn format_optional_percent(value : Double?) -> String {
  value.map(value => (value * 100.0).to_string() + "%").unwrap_or("null")
}

///|
pub fn format_ms_from_us(us : Int64) -> String {
  let negative = us < 0L
  let abs_us = if negative { 0L - us } else { us }
  let whole_ms = abs_us / 1000L
  let fractional_us = abs_us % 1000L
  let prefix = if negative { "-" } else { "" }
  prefix + whole_ms.to_string() + "." + zero_pad_3(fractional_us) + " ms"
}

///|
fn zero_pad_3(value : Int64) -> String {
  if value < 10L {
    "00" + value.to_string()
  } else if value < 100L {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
pub fn canonical_runner_warnings(
  runner_mode : String,
  canonical_performance : Bool,
  has_inprocess_engine? : Bool = false,
) -> Array[String] {
  let warnings : Array[String] = []
  if !canonical_performance {
    warnings.push(
      "WARNING: this run is not marked as release runner mode. Use a prebuilt release runner for formal performance numbers: `moon build bench/runner --target native --release` then `_build/native/release/build/bench/runner/runner.exe ...`.",
    )
    if has_inprocess_engine {
      warnings.push(
        "In-process engine timing under moon run/dev mode can be distorted and should not be used for formal engine speedup or fixed-overhead conclusions.",
      )
    }
  }
  if runner_mode == "unknown" {
    warnings.push(
      "Runner mode could not be determined automatically. Set `MARKITDOWN_BENCH_RUNNER_MODE=release|dev_moon_run|unknown` to override detection when needed.",
    )
  }
  warnings
}
