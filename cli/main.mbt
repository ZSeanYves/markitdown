///|
fn maybe_report_relocated_hidden_command(args : Array[String]) -> Bool {
  if args.length() == 0 {
    return false
  }

  let command = args[0].trim().to_owned()
  if command == "_bench-noop" ||
    command == "_bench-startup-profile" ||
    command == "_bench-product-path" {
    @clisup.exit_error(
      "hidden benchmark commands moved to bench; run `moon build bench --target native` or `moon run bench -- ...`",
    )
    return true
  }

  false
}

///|
fn is_help_command(arg : String) -> Bool {
  let normalized = arg.trim().to_owned().to_lower()
  normalized == "help" || normalized == "--help" || normalized == "-h"
}

///|
fn is_version_command(arg : String) -> Bool {
  let normalized = arg.trim().to_owned().to_lower()
  normalized == "version" || normalized == "--version"
}

///|
fn is_product_subcommand(arg : String) -> Bool {
  let normalized = arg.trim().to_owned().to_lower()
  normalized == "normal" || normalized == "batch" || normalized == "debug"
}

///|
fn is_relocated_product_command(arg : String) -> Bool {
  let normalized = arg.trim().to_owned().to_lower()
  normalized == "bench"
}

///|
fn is_retired_product_command(arg : String) -> Bool {
  let normalized = arg.trim().to_owned().to_lower()
  normalized == "ocr"
}

///|
fn normalize_product_cli_args(args : Array[String]) -> Array[String] {
  if args.length() == 0 {
    return []
  }

  let first = args[0].trim().to_owned()
  if is_product_subcommand(first) ||
    is_retired_product_command(first) ||
    is_relocated_product_command(first) ||
    is_help_command(first) ||
    is_version_command(first) {
    return args
  }

  let out : Array[String] = ["normal"]
  for arg in args {
    out.push(arg)
  }
  out
}

///|
fn report_retired_product_command(command : String) -> Unit {
  @clisup.exit_error(
    command +
    " product surface has been retired in this build; image OCR now lives on the main CLI with explicit `--ocr` / `--no-ocr` controls, while PDF OCR remains unavailable",
  )
}

///|
fn validate_top_level_ocr_lang_args(args : Array[String]) -> String? {
  for i in 0..<args.length() {
    if args[i].trim() != "--ocr-lang" {
      continue
    }
    if i + 1 >= args.length() {
      return Some("missing value for --ocr-lang")
    }
    let next = args[i + 1].trim().to_owned()
    if next == "" || next.has_prefix("-") {
      return Some("missing value for --ocr-lang")
    }
  }
  None
}

///|
fn report_relocated_command(command : String, package_name : String) -> Unit {
  let scope = if command == "debug" || command == "bench" {
    "developer tool"
  } else {
    "component"
  }
  @clisup.exit_error(
    command +
    " " +
    scope +
    " lives in `" +
    package_name +
    "`; run `moon build " +
    package_name +
    " --target native` or `moon run " +
    package_name +
    " -- ...`",
  )
}

///|
fn maybe_print_top_level_help_or_version(args : Array[String]) -> Bool {
  if args.length() == 0 {
    return false
  }

  let first = args[0]
  if is_help_command(first) {
    @clisup.print_cli_help()
    @clisup.print_cli_usage()
    return true
  }
  if is_version_command(first) {
    @clisup.print_cli_version()
    return true
  }
  false
}

///|
async fn main {
  let cli_args : Array[String] = normalize_product_cli_args(
    @clicom.normalize_cli_args(@sys.get_cli_args()),
  )

  if cli_args.length() == 0 {
    @clisup.print_cli_help()
    @clisup.print_cli_usage()
    return
  }

  if maybe_report_relocated_hidden_command(cli_args) {
    return
  }
  if is_relocated_product_command(cli_args[0]) {
    report_relocated_command("bench", "bench")
    @clisup.print_cli_usage()
    @sys.exit(2)
    return
  }
  if is_retired_product_command(cli_args[0]) {
    report_retired_product_command("ocr")
    @clisup.print_cli_usage()
    @sys.exit(2)
    return
  }
  if maybe_print_top_level_help_or_version(cli_args) {
    return
  }
  match validate_top_level_ocr_lang_args(cli_args) {
    Some(msg) => {
      @clisup.exit_error(msg)
      @clisup.print_cli_usage()
      return
    }
    None => ()
  }

  let parser = @clisup.new_cli_parser()
  let value = @clap.SimpleValue::new("markitdown-mb")
  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      @clisup.print_cli_help()
      @clisup.print_cli_usage()
      return
    }
  }

  match subcmd_help {
    Some(msg) => println(msg)
    None =>
      match value.subcmd {
        Some(sub) => {
          let positional = sub.positional_args
          let with_metadata = sub.get_flag("with-metadata").unwrap_or(false)

          match sub.name {
            "normal" => {
              if positional.length() < 1 || positional.length() > 2 {
                @clisup.exit_error(
                  "usage: normal [--with-metadata] [--ocr|--no-ocr] [--ocr-lang LANG] <input> [output]",
                )
                @clisup.print_cli_usage()
                return
              }
              let force_ocr = sub.get_flag("ocr").unwrap_or(false)
              let disable_ocr = sub.get_flag("no-ocr").unwrap_or(false)
              let ocr_lang : String? = @clap.SimpleValue::get_option(
                sub, "ocr-lang",
              ) catch {
                e => {
                  @clisup.exit_error(e.to_string())
                  @clisup.print_cli_usage()
                  return
                }
              }
              let ocr_policy = match
                @clisup.parse_ocr_policy_flags(force_ocr, disable_ocr) {
                Ok(policy) => policy
                Err(msg) => {
                  @clisup.exit_error(msg)
                  @clisup.print_cli_usage()
                  return
                }
              }
              let input = positional[0]
              let output_opt = if positional.length() >= 2 {
                Some(positional[1])
              } else {
                None
              }
              @clisup.cmd_convert(
                input,
                output_opt,
                None,
                6,
                None,
                false,
                false,
                false,
                with_metadata,
                ocr_policy,
                ocr_lang,
              )
            }
            "batch" => {
              if positional.length() != 2 {
                @clisup.exit_error(
                  "usage: batch [--with-metadata] <input_dir> <output_dir>",
                )
                @clisup.print_cli_usage()
                @sys.exit(2)
                return
              }

              let input_dir = positional[0]
              let output_dir = positional[1]

              if !@fs.path_exists(input_dir) {
                @clisup.exit_error(
                  "batch input_dir must be an existing directory: " + input_dir,
                )
                @sys.exit(2)
                return
              }

              let input_is_dir = @fs.is_dir(input_dir) catch {
                e => {
                  @clisup.exit_error(
                    "batch input_dir check failed: " + e.to_string(),
                  )
                  @sys.exit(2)
                  return
                }
              }
              if !input_is_dir {
                @clisup.exit_error(
                  "batch input_dir must be an existing directory: " + input_dir,
                )
                @sys.exit(2)
                return
              }

              match @clisup.run_batch(input_dir, output_dir, with_metadata) {
                Ok(result) => {
                  println(@clisup.batch_summary_line(result))
                  if result.had_error {
                    @sys.exit(1)
                  }
                }
                Err(msg) => {
                  @clisup.exit_error(msg)
                  @sys.exit(2)
                }
              }
            }
            "debug" => {
              report_relocated_command("debug", "debug")
              @clisup.print_cli_usage()
              @sys.exit(2)
            }
            _ => {
              @clisup.exit_error("unsupported subcommand")
              @clisup.print_cli_usage()
              @sys.exit(2)
            }
          }
        }
        None => {
          @clisup.print_cli_help()
          @clisup.print_cli_usage()
        }
      }
  }
}
