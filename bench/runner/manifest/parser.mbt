///|
pub fn parse_select_request(args : Array[String]) -> SelectRequest raise {
  let tier = Ref("smoke")
  let format_filter : Ref[String?] = Ref(None)
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
      "--format" => {
        ensure_next_arg(args, i.val, "--format")
        format_filter.val = Some(args[i.val + 1])
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
  make_select_request(
    tier.val,
    format_filter.val,
    limit.val,
    output.val,
    stats_only.val,
  )
}

///|
pub fn make_select_request(
  tier : String,
  format_filter : String?,
  limit : Int?,
  output : SelectOutput,
  stats_only : Bool,
) -> SelectRequest {
  { tier, format_filter, limit, output, stats_only }
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
