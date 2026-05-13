///|
/// CLI entrypoint exposing three operational profiles:
/// - normal: default production path
/// - ocr: force OCR-oriented PDF path for scanned/image-heavy PDFs
/// - debug: keep normal parsing but enable scoped PDF debug artifacts/logging
///
/// Keeping these as explicit subcommands improves explainability for acceptance:
/// users can map behavior differences to command intent without reading internals.
async fn main {
  let startup_profile_started = now_us()
  let args = @sys.get_cli_args()
  let args_available_us = elapsed_us_since(startup_profile_started)
  let cli_args : Array[String] = normalize_cli_args(args)
  let cli_args_ready_us = elapsed_us_since(startup_profile_started)

  if cli_args.length() == 0 {
    print_cli_help()
    print_cli_usage()
    return
  }

  if maybe_run_hidden_bench_command(
      cli_args,
      startup_profile_started,
      args.length(),
      args_available_us,
      cli_args_ready_us,
    ) {
    return
  }

  let parser = new_cli_parser()

  let value = @clap.SimpleValue::new("markitdown-mb")
  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      print_cli_help()
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
          let with_metadata = sub.get_flag("with-metadata").unwrap_or(false)

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
                exit_error(
                  "usage: ocr [--provider <name>] [--lang <code>] [--with-metadata] <input> [output]",
                )
                print_cli_usage()
                return
              }
              let input = positional[0]
              let output_opt = if positional.length() >= 2 {
                Some(positional[1])
              } else {
                None
              }
              let provider_name = @clap.SimpleValue::get_option(sub, "provider") catch {
                _ => None
              }
              let lang_arg = @clap.SimpleValue::get_option(sub, "lang") catch {
                _ => None
              }
              cmd_ocr(input, output_opt, provider_name, lang_arg, with_metadata)
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
              if positional.length() == 0 {
                exit_error(
                  "usage: debug [--json] [--with-ir] [--with-metadata-summary] [--with-normalization] <input> | debug [--json] [--probe] providers [--ocr] [--layout-assist]",
                )
                print_cli_usage()
                return
              }

              let first = positional[0].trim().to_owned().to_lower()
              if first == "providers" {
                if positional.length() != 1 {
                  exit_error(
                    "usage: debug [--json] [--probe] providers [--ocr] [--layout-assist]",
                  )
                  print_cli_usage()
                  return
                }

                let output_kind = if sub.get_flag("json").unwrap_or(false) {
                  @cor.DebugOutputKind::Json
                } else {
                  @cor.DebugOutputKind::HumanReadable
                }
                let debug_opts : DebugCliOptions = {
                  output_kind,
                  with_ir: false,
                  with_metadata_summary: false,
                  with_normalization: false,
                }
                let include_ocr = sub.get_flag("ocr").unwrap_or(false)
                let include_layout = sub
                  .get_flag("layout-assist")
                  .unwrap_or(false)
                let probe = sub.get_flag("probe").unwrap_or(false)
                cmd_debug_providers(
                  debug_opts, include_ocr, include_layout, probe,
                )
              } else if first == "all" ||
                first == "extract" ||
                first == "raw" ||
                first == "pipeline" {
                if positional.length() < 2 || positional.length() > 3 {
                  exit_error(
                    "usage: debug [--with-metadata] <all|extract|raw|pipeline> <input> [output]",
                  )
                  print_cli_usage()
                  return
                }

                let scope = first
                let input = positional[1]
                let output_opt = if positional.length() == 3 {
                  Some(positional[2])
                } else {
                  None
                }
                cmd_debug_legacy_pdf(scope, input, output_opt, with_metadata)
              } else {
                if positional.length() != 1 {
                  exit_error(
                    "usage: debug [--json] [--with-ir] [--with-metadata-summary] [--with-normalization] <input>",
                  )
                  print_cli_usage()
                  return
                }

                let output_kind = if sub.get_flag("json").unwrap_or(false) {
                  @cor.DebugOutputKind::Json
                } else {
                  @cor.DebugOutputKind::HumanReadable
                }
                let debug_opts : DebugCliOptions = {
                  output_kind,
                  with_ir: sub.get_flag("with-ir").unwrap_or(false),
                  with_metadata_summary: sub
                  .get_flag("with-metadata-summary")
                  .unwrap_or(false),
                  with_normalization: sub
                  .get_flag("with-normalization")
                  .unwrap_or(false),
                }
                cmd_debug_inspect(positional[0], debug_opts)
              }
            }
            _ => {
              exit_error("unsupported subcommand")
              print_cli_usage()
            }
          }
        }
        None => {
          print_cli_help()
          print_cli_usage()
        }
      }
  }
}

///|
fn new_cli_parser() -> @clap.Parser {
  @clap.Parser::new(
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
        help="Explicit OCR mode: ocr [--provider tesseract-cli] [--lang eng+chi_sim] [--with-metadata] <input> [output]",
        args={
          "provider": @clap.Arg::named(
            nargs=Fixed(1),
            help="Explicit OCR provider name (default: tesseract-cli)",
          ),
          "lang": @clap.Arg::named(
            nargs=Fixed(1),
            help="OCR language code(s), e.g. eng or eng+chi_sim",
          ),
          "with-metadata": @clap.Arg::flag(
            help="Also write <name>.metadata.json next to markdown output",
          ),
          "input": @clap.Arg::positional(
            help="Path to input file (.png/.jpg/.jpeg/.tif/.tiff/.bmp/.webp, or explicit OCR PDF path)",
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
        help="Debug inspect/providers: debug [--json] [--with-ir] [--with-metadata-summary] [--with-normalization] <input> ; debug [--json] [--probe] providers [--ocr] [--layout-assist] ; legacy PDF: debug [--with-metadata] <all|extract|raw|pipeline> <input> [output]",
        args={
          "json": @clap.Arg::flag(help="Emit stable JSON debug report"),
          "with-ir": @clap.Arg::flag(
            help="Include IR block previews in unified debug inspect",
          ),
          "with-metadata-summary": @clap.Arg::flag(
            help="Include block/asset origin summary in unified debug inspect",
          ),
          "with-normalization": @clap.Arg::flag(
            help="Include normalization summary when available",
          ),
          "probe": @clap.Arg::flag(
            help="Debug provider listing only: explicitly probe OCR provider availability",
          ),
          "ocr": @clap.Arg::flag(
            help="Debug provider listing only: include OCR providers",
          ),
          "layout-assist": @clap.Arg::flag(
            help="Debug provider listing only: include layout-assist providers",
          ),
          "with-metadata": @clap.Arg::flag(
            help="Legacy PDF debug: also write <name>.metadata.json next to markdown output",
          ),
          "input": @clap.Arg::positional(
            help="Unified debug inspect input, provider listing keyword `providers`, or legacy PDF debug args: <all|extract|raw|pipeline> <input> [output]",
          ),
        },
      ),
    },
  )
}

///|
fn print_cli_help() -> Unit {
  let parser = new_cli_parser()
  println(parser.gen_help_message(["markitdown-mb"], {}))
}

///|
fn print_cli_usage() -> Unit {
  println("Usage:")
  println("  markitdown-mb normal [--with-metadata] <input> [output]")
  println(
    "  markitdown-mb ocr [--provider <name>] [--lang <code>] [--with-metadata] <input> [output]",
  )
  println("  markitdown-mb batch [--with-metadata] <input_dir> <output_dir>")
  println(
    "  markitdown-mb debug [--json] [--with-ir] [--with-metadata-summary] [--with-normalization] <input>",
  )
  println(
    "  markitdown-mb debug [--json] [--probe] providers [--ocr] [--layout-assist]",
  )
  println(
    "  markitdown-mb debug [--with-metadata] <all|extract|raw|pipeline> <input> [output]",
  )
  println("  dev fallback: moon run cli -- <subcommand> ...")
}
