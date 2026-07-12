///|
pub fn parse_select_request(args : Array[String]) -> SelectRequest raise {
  let tier = Ref("smoke")
  let exact_tiers : Ref[Array[String]] = Ref([])
  let bench_ids : Ref[Array[String]] = Ref([])
  let format_filters : Ref[Array[String]] = Ref([])
  let comparison_classes : Ref[Array[String]] = Ref([])
  let limit : Ref[Int?] = Ref(None)
  let output = Ref(SelectOutput::Jsonl)
  let stats_only = Ref(false)
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    match arg {
      "--tier" => {
        ensure_next_arg(args, i.val, "--tier")
        tier.val = args[i.val + 1]
        i.val += 2
      }
      "--tiers" => {
        ensure_next_arg(args, i.val, "--tiers")
        exact_tiers.val = parse_tier_list(args[i.val + 1], "--tiers")
        i.val += 2
      }
      "--bench-id" => {
        ensure_next_arg(args, i.val, "--bench-id")
        bench_ids.val = parse_non_empty_csv(args[i.val + 1], "--bench-id")
        i.val += 2
      }
      "--format" => {
        ensure_next_arg(args, i.val, "--format")
        format_filters.val = parse_non_empty_csv(args[i.val + 1], "--format")
        i.val += 2
      }
      "--comparison-class" => {
        ensure_next_arg(args, i.val, "--comparison-class")
        comparison_classes.val = parse_non_empty_csv(
          args[i.val + 1],
          "--comparison-class",
        )
        i.val += 2
      }
      "--limit" => {
        ensure_next_arg(args, i.val, "--limit")
        limit.val = Some(parse_positive_int_arg(args[i.val + 1], "--limit"))
        i.val += 2
      }
      "--output" => {
        ensure_next_arg(args, i.val, "--output")
        output.val = parse_select_output(args[i.val + 1])
        i.val += 2
      }
      "--stats" => {
        stats_only.val = true
        i.val += 1
      }
      _ => raise InvalidArgument("unsupported select argument: " + arg)
    }
  }
  validate_tier(tier.val)
  validate_tiers(exact_tiers.val)
  make_select_request(
    tier.val,
    exact_tiers.val,
    bench_ids.val,
    format_filters.val,
    limit.val,
    output.val,
    stats_only.val,
    comparison_classes=comparison_classes.val,
  )
}

///|
pub fn make_select_request(
  tier : String,
  exact_tiers : Array[String],
  bench_ids : Array[String],
  format_filters : Array[String],
  limit : Int?,
  output : SelectOutput,
  stats_only : Bool,
  comparison_classes? : Array[String] = [],
) -> SelectRequest {
  {
    tier,
    exact_tiers,
    bench_ids,
    format_filters,
    comparison_classes,
    limit,
    output,
    stats_only,
  }
}

///|
fn parse_select_output(text : String) -> SelectOutput raise {
  match text.trim().to_lower() {
    "jsonl" => SelectOutput::Jsonl
    "tsv" => SelectOutput::Tsv
    _ => raise InvalidArgument("unsupported --output value: " + text)
  }
}

///|
fn ensure_next_arg(
  args : Array[String],
  index : Int,
  flag : String,
) -> Unit raise {
  if index + 1 >= args.length() {
    raise InvalidArgument("missing value for " + flag)
  }
}

///|
fn parse_positive_int_arg(text : String, flag : String) -> Int raise {
  let value = @string.parse_int(text.trim()) catch {
    _ => raise InvalidArgument("invalid integer for " + flag + ": " + text)
  }
  if value < 0 {
    raise InvalidArgument(
      "negative integer is not allowed for " + flag + ": " + text,
    )
  }
  value
}

///|
pub fn validate_tier(tier : String) -> Unit raise {
  match tier.trim().to_lower() {
    "smoke" | "regular" | "release" | "stress" => ()
    _ => raise InvalidArgument("unsupported tier: " + tier)
  }
}

///|
pub fn validate_tiers(tiers : Array[String]) -> Unit raise {
  for tier in tiers {
    validate_tier(tier)
  }
}

///|
pub fn parse_tier_list(text : String, flag : String) -> Array[String] raise {
  let tiers = parse_non_empty_csv(text, flag).map(tier => {
    tier.trim().to_lower().to_owned()
  })
  if tiers.length() == 0 {
    raise InvalidArgument("empty value is not allowed for " + flag)
  }
  tiers
}

///|
fn parse_non_empty_csv(text : String, flag : String) -> Array[String] raise {
  let out = text
    .split(",")
    .to_array()
    .map(part => part.trim().to_owned())
    .filter(part => part != "")
  if out.length() == 0 {
    raise InvalidArgument("empty value is not allowed for " + flag)
  }
  out
}
