///|
/// CLI entrypoint exposing three operational profiles:
/// - normal: default production path
/// - ocr: force OCR-oriented PDF path for scanned/image-heavy PDFs
/// - debug: keep normal parsing but enable scoped PDF debug artifacts/logging
///
/// Keeping these as explicit subcommands improves explainability for acceptance:
/// users can map behavior differences to command intent without reading internals.
async fn main {
  let args = @sys.get_cli_args()

  let parser = @clap.Parser::new(
    prog="markitdown-mb",
    description="Convert documents to Markdown",
    subcmds={
      "normal": @clap.SubCommand::new(
        help="Normal conversion: normal [--with-metadata] <input> [output]",
        args={
          "with-metadata": @clap.Arg::flag(
            help="Also write <name>.metadata.json next to markdown output",
          ),
          "input": @clap.Arg::positional(
            help="Path to input file (.docx/.pdf/.xlsx/.pptx/.html/.csv/.tsv/.txt/.xml/.json/.zip/.epub)",
          ),
        },
      ),
      "ocr": @clap.SubCommand::new(
        help="OCR conversion for scanned/image PDFs: ocr [--with-metadata] <input> [output]",
        args={
          "with-metadata": @clap.Arg::flag(
            help="Also write <name>.metadata.json next to markdown output",
          ),
          "input": @clap.Arg::positional(
            help="Path to input file (.pdf preferred)",
          ),
        },
      ),
      "batch": @clap.SubCommand::new(
        help="Batch conversion: batch [--with-metadata] <input_dir> <output_dir>",
        args={
          "with-metadata": @clap.Arg::flag(
            help="Also write <name>.metadata.json inside each document output root",
          ),
          "input": @clap.Arg::positional(
            help="Path to input directory (non-recursive file scan)",
          ),
        },
      ),
      "debug": @clap.SubCommand::new(
        help="Debug conversion: debug [--with-metadata] <all|extract|raw|pipeline> <input> [output]",
        args={
          "with-metadata": @clap.Arg::flag(
            help="Also write <name>.metadata.json next to markdown output",
          ),
          "input": @clap.Arg::positional(
            help="Arguments: <all|extract|raw|pipeline> <input> [output]",
          ),
        },
      ),
    },
  )

  let help_msg = parser.gen_help_message(["markitdown-mb"], {})

  let cli_args : Array[String] = normalize_cli_args(args)
  if cli_args.length() == 0 {
    println(help_msg)
    print_cli_usage()
    return
  }

  let value = @clap.SimpleValue::new("markitdown-mb")
  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      println(help_msg)
      print_cli_usage()
      return
    }
  }

  match subcmd_help {
    Some(msg) => println(msg)
    None =>
      match value.subcmd {
        Some(sub) => {
          let positional = sub.positional_args
          let with_metadata = sub.flags.contains("with-metadata")

          match sub.name {
            "normal" => {
              if positional.length() < 1 || positional.length() > 2 {
                exit_error("usage: normal [--with-metadata] <input> [output]")
                print_cli_usage()
                return
              }
              let input = positional[0]
              let output_opt = if positional.length() >= 2 {
                Some(positional[1])
              } else {
                None
              }
              cmd_convert(
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
            "ocr" => {
              if positional.length() < 1 || positional.length() > 2 {
                exit_error("usage: ocr [--with-metadata] <input> [output]")
                print_cli_usage()
                return
              }
              let input = positional[0]
              let output_opt = if positional.length() >= 2 {
                Some(positional[1])
              } else {
                None
              }
              cmd_convert(
                input,
                output_opt,
                None,
                6,
                Some("ocr"),
                false,
                false,
                false,
                with_metadata,
              )
            }
            "batch" => {
              if positional.length() != 2 {
                exit_error(
                  "usage: batch [--with-metadata] <input_dir> <output_dir>",
                )
                print_cli_usage()
                @sys.exit(2)
                return
              }

              let input_dir = positional[0]
              let output_dir = positional[1]

              if !@fs.path_exists(input_dir) {
                exit_error(
                  "batch input_dir must be an existing directory: " + input_dir,
                )
                @sys.exit(2)
                return
              }

              let input_is_dir = @fs.is_dir(input_dir) catch {
                e => {
                  exit_error("batch input_dir check failed: " + e.to_string())
                  @sys.exit(2)
                  return
                }
              }
              if !input_is_dir {
                exit_error(
                  "batch input_dir must be an existing directory: " + input_dir,
                )
                @sys.exit(2)
                return
              }

              match run_batch(input_dir, output_dir, with_metadata) {
                Ok(result) => {
                  println(batch_summary_line(result))
                  if result.had_error {
                    @sys.exit(1)
                  }
                }
                Err(msg) => {
                  exit_error(msg)
                  @sys.exit(2)
                }
              }
            }
            "debug" => {
              if positional.length() < 2 || positional.length() > 3 {
                exit_error(
                  "usage: debug [--with-metadata] <all|extract|raw|pipeline> <input> [output]",
                )
                print_cli_usage()
                return
              }

              let scope = positional[0].trim().to_owned().to_lower()
              let input = positional[1]
              let output_opt = if positional.length() == 3 {
                Some(positional[2])
              } else {
                None
              }

              let (pdf_extract_debug, pdf_dump_selected_raw, pdf_pipeline_debug) = match
                scope {
                "all" => (true, true, true)
                "extract" => (true, false, false)
                "raw" => (false, true, false)
                "pipeline" => (false, false, true)
                _ => {
                  exit_error(
                    "invalid debug scope: " +
                    scope +
                    " (expected: all|extract|raw|pipeline)",
                  )
                  print_cli_usage()
                  return
                }
              }

              cmd_convert(
                input,
                output_opt,
                None,
                6,
                None,
                pdf_extract_debug,
                pdf_dump_selected_raw,
                pdf_pipeline_debug,
                with_metadata,
              )
            }
            _ => {
              exit_error("unsupported subcommand")
              print_cli_usage()
            }
          }
        }
        None => {
          println(help_msg)
          print_cli_usage()
        }
      }
  }
}

///|
fn print_cli_usage() -> Unit {
  println("Usage:")
  println("  moon run cli -- normal [--with-metadata] <input> [output]")
  println("  moon run cli -- ocr [--with-metadata] <input> [output]")
  println("  moon run cli -- batch [--with-metadata] <input_dir> <output_dir>")
  println(
    "  moon run cli -- debug [--with-metadata] <all|extract|raw|pipeline> <input> [output]",
  )
}
