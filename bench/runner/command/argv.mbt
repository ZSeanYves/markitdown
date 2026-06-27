///|
pub fn parse_run_request(args : Array[String]) -> RunRequest raise {
  parse_run_request_with_context(args, default_runner_context())
}

///|
pub fn parse_run_request_with_context(
  args : Array[String],
  runner : RunnerContext,
) -> RunRequest raise {
  let tool_name : Ref[String?] = Ref(None)
  let tier = Ref("smoke")
  let exact_tiers : Ref[Array[String]] = Ref([])
  let bench_ids : Ref[Array[String]] = Ref([])
  let format_filters : Ref[Array[String]] = Ref([])
  let limit : Ref[Int?] = Ref(None)
  let repeat_count = Ref(1)
  let warmup_count = Ref(1)
  let timeout_sec : Ref[Int?] = Ref(None)
  let timeout_ms : Ref[Int?] = Ref(None)
  let markitdown_path : Ref[String?] = Ref(None)
  let cli_output_mode = Ref(default_cli_output_mode())
  let engine_output_mode = Ref(default_engine_output_mode())
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    match arg {
      "--tool" => {
        ensure_next_arg(args, i.val, "--tool")
        tool_name.val = Some(args[i.val + 1])
        i.val += 2
      }
      _ =>
        match
          parse_run_compare_common_flag(
            args,
            i.val,
            tier,
            exact_tiers,
            bench_ids,
            format_filters,
            limit,
            repeat_count,
            warmup_count,
            timeout_sec,
            timeout_ms,
            markitdown_path,
            cli_output_mode,
            engine_output_mode,
          ) {
          Some(next) => i.val = next
          None =>
            raise @manifest.InvalidArgument("unsupported run argument: " + arg)
        }
    }
  }
  @manifest.validate_tier(tier.val)
  @manifest.validate_tiers(exact_tiers.val)
  let tool = match tool_name.val {
    Some(value) => value
    None => raise @manifest.InvalidArgument("missing --tool")
  }
  make_run_request(
    tool,
    tier.val,
    exact_tiers.val,
    bench_ids.val,
    format_filters.val,
    limit.val,
    repeat_count.val,
    warmup_count.val,
    resolve_timeout_ms(timeout_sec.val, timeout_ms.val),
    markitdown_path.val,
    cli_output_mode.val,
    engine_output_mode.val,
    default_run_id(args),
    default_git_commit(),
    runner,
  )
}

///|
pub fn parse_compare_request(args : Array[String]) -> CompareRequest raise {
  parse_compare_request_with_context(args, default_runner_context())
}

///|
pub fn parse_profile_request(args : Array[String]) -> ProfileRequest raise {
  parse_profile_request_with_context(args, default_runner_context())
}

///|
pub fn parse_compare_request_with_context(
  args : Array[String],
  runner : RunnerContext,
) -> CompareRequest raise {
  let tier = Ref("smoke")
  let exact_tiers : Ref[Array[String]] = Ref([])
  let bench_ids : Ref[Array[String]] = Ref([])
  let format_filters : Ref[Array[String]] = Ref([])
  let limit : Ref[Int?] = Ref(None)
  let repeat_count = Ref(1)
  let warmup_count = Ref(1)
  let timeout_sec : Ref[Int?] = Ref(None)
  let timeout_ms : Ref[Int?] = Ref(None)
  let markitdown_path : Ref[String?] = Ref(None)
  let cli_output_mode = Ref(default_cli_output_mode())
  let engine_output_mode = Ref(default_engine_output_mode())
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    match
      parse_run_compare_common_flag(
        args,
        i.val,
        tier,
        exact_tiers,
        bench_ids,
        format_filters,
        limit,
        repeat_count,
        warmup_count,
        timeout_sec,
        timeout_ms,
        markitdown_path,
        cli_output_mode,
        engine_output_mode,
      ) {
      Some(next) => i.val = next
      None =>
        raise @manifest.InvalidArgument("unsupported compare argument: " + arg)
    }
  }
  @manifest.validate_tier(tier.val)
  @manifest.validate_tiers(exact_tiers.val)
  make_compare_request(
    tier.val,
    exact_tiers.val,
    bench_ids.val,
    format_filters.val,
    limit.val,
    repeat_count.val,
    warmup_count.val,
    resolve_timeout_ms(timeout_sec.val, timeout_ms.val),
    markitdown_path.val,
    cli_output_mode.val,
    engine_output_mode.val,
    default_run_id(args),
    default_git_commit(),
    runner,
  )
}

///|
pub fn parse_profile_request_with_context(
  args : Array[String],
  runner : RunnerContext,
) -> ProfileRequest raise {
  let profile_kind : Ref[String?] = Ref(None)
  let exact_tiers : Ref[Array[String]] = Ref([])
  let bench_ids : Ref[Array[String]] = Ref([])
  let formats : Ref[Array[String]] = Ref([])
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    match arg {
      "--kind" => {
        ensure_next_arg(args, i.val, "--kind")
        profile_kind.val = Some(
          parse_non_empty_string(args[i.val + 1], "--kind"),
        )
        i.val += 2
      }
      _ =>
        match
          parse_profile_common_flag(
            args,
            i.val,
            exact_tiers,
            bench_ids,
            formats,
          ) {
          Some(next) => i.val = next
          None =>
            raise @manifest.InvalidArgument(
              "unsupported profile argument: " + arg,
            )
        }
    }
  }
  let kind = match profile_kind.val {
    Some(value) => value.trim().to_lower().to_owned()
    None => "official-gate"
  }
  if kind != "official-gate" && kind != "single" {
    raise @manifest.InvalidArgument(
      "unsupported --kind value: " + kind + " (expected official-gate|single)",
    )
  }
  @manifest.validate_tiers(exact_tiers.val)
  if kind == "single" && bench_ids.val.length() == 0 {
    raise @manifest.InvalidArgument(
      "--kind single requires at least one --bench-id",
    )
  }
  let effective_tiers = if exact_tiers.val.length() == 0 {
    ["regular", "release", "stress"]
  } else {
    exact_tiers.val
  }
  make_profile_request(
    kind,
    effective_tiers,
    bench_ids.val,
    formats.val,
    default_run_id(args),
    default_git_commit(),
    runner,
  )
}

///|
pub fn parse_diagnose_request(args : Array[String]) -> DiagnoseRequest raise {
  parse_diagnose_request_with_context(args, default_runner_context())
}

///|
pub fn parse_diagnose_request_with_context(
  args : Array[String],
  runner : RunnerContext,
) -> DiagnoseRequest raise {
  let repeat_count = Ref(20)
  let warmup_count = Ref(5)
  let timeout_sec : Ref[Int?] = Ref(None)
  let timeout_ms : Ref[Int?] = Ref(None)
  let cli_output_mode = Ref(default_cli_output_mode())
  let engine_output_mode = Ref(default_engine_output_mode())
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    match
      parse_repeat_timeout_common_flag(
        args,
        i.val,
        repeat_count,
        warmup_count,
        timeout_sec,
        timeout_ms,
      ) {
      Some(next) => i.val = next
      None =>
        match parse_cli_output_mode_flag(args, i.val, cli_output_mode) {
          Some(next) => i.val = next
          None =>
            match
              parse_engine_output_mode_flag(args, i.val, engine_output_mode) {
              Some(next) => i.val = next
              None =>
                raise @manifest.InvalidArgument(
                  "unsupported diagnose-overhead argument: " + arg,
                )
            }
        }
    }
  }
  make_diagnose_request(
    repeat_count.val,
    warmup_count.val,
    resolve_timeout_ms(timeout_sec.val, timeout_ms.val),
    cli_output_mode.val,
    engine_output_mode.val,
    default_run_id(args),
    default_git_commit(),
    runner,
  )
}

///|
fn ensure_next_arg(
  args : Array[String],
  index : Int,
  flag : String,
) -> Unit raise {
  if index + 1 >= args.length() {
    raise @manifest.InvalidArgument("missing value for " + flag)
  }
}

///|
fn parse_non_negative_int(text : String, flag : String) -> Int raise {
  let value = @string.parse_int(text.trim()) catch {
    _ =>
      raise @manifest.InvalidArgument(
        "invalid integer for " + flag + ": " + text,
      )
  }
  if value < 0 {
    raise @manifest.InvalidArgument(
      "negative integer is not allowed for " + flag + ": " + text,
    )
  }
  value
}

///|
fn parse_positive_int(text : String, flag : String) -> Int raise {
  let value = parse_non_negative_int(text, flag)
  if value <= 0 {
    raise @manifest.InvalidArgument(
      "non-positive integer is not allowed for " + flag + ": " + text,
    )
  }
  value
}

///|
fn parse_non_empty_string(text : String, flag : String) -> String raise {
  let value = text.trim().to_owned()
  if value == "" {
    raise @manifest.InvalidArgument("empty value is not allowed for " + flag)
  }
  value
}

///|
fn ensure_timeout_mode(timeout_sec : Int?, timeout_ms : Int?) -> Unit raise {
  if timeout_sec is Some(_) || timeout_ms is Some(_) {
    raise @manifest.InvalidArgument(
      "cannot use --timeout-sec and --timeout-ms together",
    )
  }
}

///|
fn resolve_timeout_ms(timeout_sec : Int?, timeout_ms : Int?) -> Int {
  match timeout_ms {
    Some(value) => value
    None =>
      match timeout_sec {
        Some(value) => value * 1000
        None => 60000
      }
  }
}

///|
fn default_run_id(args : Array[String]) -> String {
  match @env.get_env_var("MARKITDOWN_BENCH_RUN_ID") {
    Some(run_id) if run_id != "" => run_id
    _ => {
      let fingerprint = args.join("\u{1f}").hash()
      let fingerprint_text = if fingerprint < 0 {
        "n" + (-fingerprint).to_string(radix=16)
      } else {
        fingerprint.to_string(radix=16)
      }
      "run-" + @env.now().to_string() + "-" + fingerprint_text
    }
  }
}

///|
fn default_git_commit() -> String {
  match @env.get_env_var("MARKITDOWN_BENCH_GIT_COMMIT") {
    Some(commit) if commit != "" => commit
    _ => "unknown"
  }
}
