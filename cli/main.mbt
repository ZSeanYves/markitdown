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
      "hidden benchmark commands moved to cli_bench; run `moon build cli_bench --target native` or `moon run cli_bench -- ...`",
    )
    return true
  }

  false
}

///|
fn report_relocated_command(command : String, package_name : String) -> Unit {
  @clisup.exit_error(
    command +
    " command moved to " +
    package_name +
    "; run `moon build " +
    package_name +
    " --target native` or `moon run " +
    package_name +
    " -- ...`",
  )
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
        "OCR conversion", "cli_ocr", "MARKITDOWN_OCR_CLI", args,
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
  let cli_args : Array[String] = @clicom.normalize_cli_args(@sys.get_cli_args())

  if cli_args.length() == 0 {
    @clisup.print_cli_help()
    @clisup.print_cli_usage()
    return
  }

  if maybe_report_relocated_hidden_command(cli_args) {
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
                "ocr command delegation should have happened before parser dispatch; rebuild cli and cli_ocr together if this persists",
              )
            "debug" => {
              report_relocated_command("debug", "cli_debug")
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
