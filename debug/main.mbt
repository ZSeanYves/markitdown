///|
fn debug_cli_args(args : Array[String]) -> Array[String] {
  if args.length() == 0 {
    return []
  }

  let first = args[0].trim().to_owned().to_lower()
  if first == "debug" {
    return args
  }

  let out : Array[String] = ["debug"]
  for arg in args {
    out.push(arg)
  }
  out
}

///|
async fn main {
  let cli_args = debug_cli_args(normalize_cli_args(@sys.get_cli_args()))
  if cli_args.length() == 0 {
    print_debug_help()
    print_debug_usage()
    return
  }

  let parser = new_debug_cli_parser()
  let value = @clap.SimpleValue::new("markitdown-mb-debug")
  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      print_debug_help()
      print_debug_usage()
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

          if positional.length() == 0 {
            exit_error(
              "usage: debug [--json] [--with-ir] [--with-metadata-summary] [--with-normalization] <input> | debug [--json] [--probe] providers [--ocr] [--layout-assist] | debug [--json] layout-assist-eval [--split <train|heldout>]",
            )
            print_debug_usage()
            return
          }

          let first = positional[0].trim().to_owned().to_lower()
          if first == "providers" {
            if positional.length() != 1 {
              exit_error(
                "usage: debug [--json] [--probe] providers [--ocr] [--layout-assist]",
              )
              print_debug_usage()
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
            let include_layout = sub.get_flag("layout-assist").unwrap_or(false)
            let probe = sub.get_flag("probe").unwrap_or(false)
            cmd_debug_providers(debug_opts, include_ocr, include_layout, probe)
          } else if first == "layout-assist-eval" {
            if positional.length() != 1 {
              exit_error(
                "usage: debug [--json] layout-assist-eval [--split <train|heldout>]",
              )
              print_debug_usage()
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
            let split = @clap.SimpleValue::get_option(sub, "split") catch {
              _ => None
            }
            cmd_debug_layout_assist_eval(debug_opts, split)
          } else if first == "pdf-v2-trace" {
            if positional.length() != 2 {
              exit_error("usage: debug [--json] pdf-v2-trace <input>")
              print_debug_usage()
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
            cmd_debug_pdf_v2_trace(positional[1], debug_opts)
          } else if first == "all" ||
            first == "extract" ||
            first == "raw" ||
            first == "pipeline" {
            if positional.length() < 2 || positional.length() > 3 {
              exit_error(
                "usage: debug [--with-metadata] <all|extract|raw|pipeline> <input> [output]",
              )
              print_debug_usage()
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
              print_debug_usage()
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
        None => {
          print_debug_help()
          print_debug_usage()
        }
      }
  }
}

///|
fn new_debug_cli_parser() -> @clap.Parser {
  @clap.Parser::new(
    prog="markitdown-mb-debug",
    description="Debug inspect/providers entrypoint",
    subcmds={
      "debug": @clap.SubCommand::new(
        help="Debug inspect/providers: debug [--json] [--with-ir] [--with-metadata-summary] [--with-normalization] <input> ; debug [--json] [--probe] providers [--ocr] [--layout-assist] ; debug [--json] layout-assist-eval [--split train|heldout] ; legacy PDF: debug [--with-metadata] <all|extract|raw|pipeline> <input> [output]",
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
          "split": @clap.Arg::named(
            nargs=AtMost(1),
            help="Debug layout-assist eval only: restrict manifest rows to train or heldout split",
          ),
          "with-metadata": @clap.Arg::flag(
            help="Legacy PDF debug: also write <name>.metadata.json next to markdown output",
          ),
          "input": @clap.Arg::positional(
            help="Unified debug inspect input, provider listing keyword `providers`, eval keyword `layout-assist-eval`, trace keyword `pdf-v2-trace <input>`, or legacy PDF debug args: <all|extract|raw|pipeline> <input> [output]",
          ),
        },
      ),
    },
  )
}

///|
fn print_debug_help() -> Unit {
  let parser = new_debug_cli_parser()
  println(parser.gen_help_message(["markitdown-mb-debug"], {}))
}

///|
fn print_debug_usage() -> Unit {
  println("Usage:")
  println(
    "  markitdown-mb-debug [debug] [--json] [--with-ir] [--with-metadata-summary] [--with-normalization] <input>",
  )
  println(
    "  markitdown-mb-debug [debug] [--json] [--probe] providers [--ocr] [--layout-assist]",
  )
  println(
    "  markitdown-mb-debug [debug] [--json] layout-assist-eval [--split train|heldout]",
  )
  println("  markitdown-mb-debug [debug] [--json] pdf-v2-trace <input>")
  println(
    "  markitdown-mb-debug [debug] [--with-metadata] <all|extract|raw|pipeline> <input> [output]",
  )
}
