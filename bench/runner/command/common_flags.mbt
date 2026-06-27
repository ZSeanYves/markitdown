///|
fn parse_run_compare_common_flag(
  args : Array[String],
  index : Int,
  tier : Ref[String],
  exact_tiers : Ref[Array[String]],
  bench_ids : Ref[Array[String]],
  format_filters : Ref[Array[String]],
  limit : Ref[Int?],
  repeat_count : Ref[Int],
  warmup_count : Ref[Int],
  timeout_sec : Ref[Int?],
  timeout_ms : Ref[Int?],
  markitdown_path : Ref[String?],
  cli_output_mode : Ref[CliOutputMode],
  engine_output_mode : Ref[EngineOutputMode],
) -> Int? raise {
  match parse_tier_flag(args, index, tier) {
    Some(next) => Some(next)
    None =>
      match parse_exact_tiers_flag(args, index, exact_tiers) {
        Some(next) => Some(next)
        None =>
          match parse_bench_id_flag(args, index, bench_ids) {
            Some(next) => Some(next)
            None =>
              match parse_format_flag(args, index, format_filters) {
                Some(next) => Some(next)
                None =>
                  match parse_limit_flag(args, index, limit) {
                    Some(next) => Some(next)
                    None =>
                      match
                        parse_repeat_timeout_common_flag(
                          args, index, repeat_count, warmup_count, timeout_sec, timeout_ms,
                        ) {
                        Some(next) => Some(next)
                        None =>
                          match
                            parse_markitdown_path_flag(
                              args, index, markitdown_path,
                            ) {
                            Some(next) => Some(next)
                            None =>
                              match
                                parse_cli_output_mode_flag(
                                  args, index, cli_output_mode,
                                ) {
                                Some(next) => Some(next)
                                None =>
                                  parse_engine_output_mode_flag(
                                    args, index, engine_output_mode,
                                  )
                              }
                          }
                      }
                  }
              }
          }
      }
  }
}

///|
fn parse_profile_common_flag(
  args : Array[String],
  index : Int,
  exact_tiers : Ref[Array[String]],
  bench_ids : Ref[Array[String]],
  formats : Ref[Array[String]],
) -> Int? raise {
  match parse_exact_tiers_flag(args, index, exact_tiers) {
    Some(next) => Some(next)
    None =>
      match parse_bench_id_flag(args, index, bench_ids) {
        Some(next) => Some(next)
        None => parse_profile_formats_flag(args, index, formats)
      }
  }
}

///|
fn parse_repeat_timeout_common_flag(
  args : Array[String],
  index : Int,
  repeat_count : Ref[Int],
  warmup_count : Ref[Int],
  timeout_sec : Ref[Int?],
  timeout_ms : Ref[Int?],
) -> Int? raise {
  match parse_repeat_flag(args, index, repeat_count) {
    Some(next) => Some(next)
    None =>
      match parse_warmup_flag(args, index, warmup_count) {
        Some(next) => Some(next)
        None => parse_timeout_flag(args, index, timeout_sec, timeout_ms)
      }
  }
}

///|
fn parse_tier_flag(
  args : Array[String],
  index : Int,
  tier : Ref[String],
) -> Int? raise {
  if args[index] != "--tier" {
    return None
  }
  ensure_next_arg(args, index, "--tier")
  tier.val = args[index + 1]
  Some(index + 2)
}

///|
fn parse_format_flag(
  args : Array[String],
  index : Int,
  format_filters : Ref[Array[String]],
) -> Int? raise {
  if args[index] != "--format" {
    return None
  }
  ensure_next_arg(args, index, "--format")
  format_filters.val = parse_csv_non_empty(args[index + 1], "--format")
  Some(index + 2)
}

///|
fn parse_exact_tiers_flag(
  args : Array[String],
  index : Int,
  exact_tiers : Ref[Array[String]],
) -> Int? raise {
  if args[index] != "--tiers" {
    return None
  }
  ensure_next_arg(args, index, "--tiers")
  exact_tiers.val = @manifest.parse_tier_list(args[index + 1], "--tiers")
  Some(index + 2)
}

///|
fn parse_bench_id_flag(
  args : Array[String],
  index : Int,
  bench_ids : Ref[Array[String]],
) -> Int? raise {
  if args[index] != "--bench-id" {
    return None
  }
  ensure_next_arg(args, index, "--bench-id")
  bench_ids.val = parse_csv_non_empty(args[index + 1], "--bench-id")
  Some(index + 2)
}

///|
fn parse_profile_formats_flag(
  args : Array[String],
  index : Int,
  formats : Ref[Array[String]],
) -> Int? raise {
  if args[index] != "--format" {
    return None
  }
  ensure_next_arg(args, index, "--format")
  formats.val = parse_csv_non_empty(args[index + 1], "--format")
  Some(index + 2)
}

///|
fn parse_limit_flag(
  args : Array[String],
  index : Int,
  limit : Ref[Int?],
) -> Int? raise {
  if args[index] != "--limit" {
    return None
  }
  ensure_next_arg(args, index, "--limit")
  limit.val = Some(parse_non_negative_int(args[index + 1], "--limit"))
  Some(index + 2)
}

///|
fn parse_csv_non_empty(text : String, flag : String) -> Array[String] raise {
  let out = text
    .split(",")
    .to_array()
    .map(part => parse_non_empty_string(part.to_owned(), flag))
  if out.length() == 0 {
    raise @manifest.InvalidArgument("empty value is not allowed for " + flag)
  }
  out
}

///|
fn parse_repeat_flag(
  args : Array[String],
  index : Int,
  repeat_count : Ref[Int],
) -> Int? raise {
  if args[index] != "--repeat" {
    return None
  }
  ensure_next_arg(args, index, "--repeat")
  repeat_count.val = parse_positive_int(args[index + 1], "--repeat")
  Some(index + 2)
}

///|
fn parse_warmup_flag(
  args : Array[String],
  index : Int,
  warmup_count : Ref[Int],
) -> Int? raise {
  if args[index] != "--warmup" {
    return None
  }
  ensure_next_arg(args, index, "--warmup")
  warmup_count.val = parse_non_negative_int(args[index + 1], "--warmup")
  Some(index + 2)
}

///|
fn parse_timeout_flag(
  args : Array[String],
  index : Int,
  timeout_sec : Ref[Int?],
  timeout_ms : Ref[Int?],
) -> Int? raise {
  match args[index] {
    "--timeout-sec" => {
      ensure_next_arg(args, index, "--timeout-sec")
      ensure_timeout_mode(timeout_sec.val, timeout_ms.val)
      timeout_sec.val = Some(
        parse_positive_int(args[index + 1], "--timeout-sec"),
      )
      Some(index + 2)
    }
    "--timeout-ms" => {
      ensure_next_arg(args, index, "--timeout-ms")
      ensure_timeout_mode(timeout_sec.val, timeout_ms.val)
      timeout_ms.val = Some(parse_positive_int(args[index + 1], "--timeout-ms"))
      Some(index + 2)
    }
    _ => None
  }
}

///|
fn parse_markitdown_path_flag(
  args : Array[String],
  index : Int,
  markitdown_path : Ref[String?],
) -> Int? raise {
  if args[index] != "--markitdown-path" {
    return None
  }
  ensure_next_arg(args, index, "--markitdown-path")
  markitdown_path.val = Some(
    parse_non_empty_string(args[index + 1], "--markitdown-path"),
  )
  Some(index + 2)
}

///|
fn parse_cli_output_mode_flag(
  args : Array[String],
  index : Int,
  cli_output_mode : Ref[CliOutputMode],
) -> Int? raise {
  if args[index] != "--cli-output-mode" {
    return None
  }
  ensure_next_arg(args, index, "--cli-output-mode")
  cli_output_mode.val = parse_cli_output_mode(args[index + 1])
  Some(index + 2)
}

///|
fn parse_engine_output_mode_flag(
  args : Array[String],
  index : Int,
  engine_output_mode : Ref[EngineOutputMode],
) -> Int? raise {
  if args[index] != "--engine-output-mode" {
    return None
  }
  ensure_next_arg(args, index, "--engine-output-mode")
  engine_output_mode.val = parse_engine_output_mode(args[index + 1])
  Some(index + 2)
}
