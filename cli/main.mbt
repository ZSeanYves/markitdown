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
  normalized == "normal" ||
  normalized == "batch" ||
  normalized == "ocr" ||
  normalized == "debug"
}

///|
fn is_relocated_product_command(arg : String) -> Bool {
  let normalized = arg.trim().to_owned().to_lower()
  normalized == "bench"
}

///|
fn normalize_product_cli_args(args : Array[String]) -> Array[String] {
  if args.length() == 0 {
    return []
  }

  let first = args[0].trim().to_owned()
  if is_product_subcommand(first) ||
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
async fn maybe_delegate_product_worker_command(args : Array[String]) -> Bool {
  if args.length() == 0 {
    return false
  }

  let command = args[0].trim().to_owned().to_lower()
  if command == "ocr" {
    match
      @clicom.delegate_external_command(
        "OCR conversion", "ocr", "MARKITDOWN_OCR_CLI", args,
      ) {
      Ok(_) => ()
      Err(msg) => @clicom.exit_error(msg)
    }
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
  if maybe_print_top_level_help_or_version(cli_args) {
    return
  }
  if maybe_delegate_product_worker_command(cli_args) {
    return
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
                  "usage: normal [--with-metadata] <input> [output]",
                )
                @clisup.print_cli_usage()
                return
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
            "ocr" =>
              @clicom.exit_error(
                "ocr command delegation should have happened before parser dispatch; rebuild cli and ocr together if this persists",
              )
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
