///|
async fn main {
  let args = @sys.get_cli_args()

  let parser = @clap.Parser::new(
    prog="markitdown-mb",
    description="Convert documents (docx/pdf/xlsx/pptx/html) to Markdown (MoonBit, markitdown-like)",
    subcmds={
      "convert": @clap.SubCommand::new(
        help="Convert a .docx/.pdf/.xlsx/.pptx/.html file to Markdown",
        args={
          "input": @clap.Arg::positional(
            help="Path to input file (.docx/.pdf/.xlsx/.pptx/.html)",
          ),
          "output": @clap.Arg::named(
            short='o',
            nargs=@clap.Nargs::AtMost(1),
            help="Output markdown file (default: stdout)",
          ),
          "out-dir": @clap.Arg::named(
            nargs=@clap.Nargs::AtMost(1),
            help="Output directory for assets (default: ./out)",
          ),
          "max-heading": @clap.Arg::named(
            nargs=@clap.Nargs::AtMost(1),
            help="Max heading level to emit (default: 3)",
          ),
          "ocr": @clap.Arg::named(
            nargs=@clap.Nargs::AtMost(1),
            help="Enable OCR enhancement for PDF (default: off). Accepts: 1/true/on/yes",
          ),
          "pdf-backend": @clap.Arg::named(
            nargs=@clap.Nargs::AtMost(1),
            help="PDF backend: external|pdf-native (default: external)",
          ),
          "pdf-backend-policy": @clap.Arg::named(
            nargs=@clap.Nargs::AtMost(1),
            help="PDF backend policy: external|native-strict|native-gated (default: external)",
          ),
          "debug": @clap.Arg::named(
            nargs=@clap.Nargs::AtMost(1),
            help="Debug modes: extract|dump-raw|pipeline|all (comma-separated supported)",
          ),
        },
      ),
      "help": @clap.SubCommand::new(help="Display help message"),
    },
  )

  let help_msg = parser.gen_help_message(["markitdown-mb"], {})

  let cli_args : Array[String] = normalize_cli_args(args)
  if cli_args.length() == 0 {
    println(help_msg)
    return
  }

  let value = @clap.SimpleValue::new("markitdown-mb")
  //println("raw args  = \{args}")
  let cli_args : Array[String] = normalize_cli_args(args)
  //println("norm args = \{cli_args}")

  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      println(help_msg)
      return
    }
  }

  match subcmd_help {
    Some(msg) => println(msg)
    None =>
      match value.subcmd {
        Some(sub) => {
          let positional = sub.positional_args
          match sub.name {
            "convert" => {
              if positional.length() == 0 {
                exit_error("missing input argument")
                println(help_msg)
                return
              }

              let input = positional[0]

              let output_opt : String? = match sub.args.get("output") {
                Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
                None => None
              }

              let out_dir_opt : String? = match sub.args.get("out-dir") {
                Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
                None => None
              }

              let max_heading_opt : String? = match
                sub.args.get("max-heading") {
                Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
                None => None
              }

              let ocr_enabled = parse_bool_flag(sub.args.get("ocr"))
              let pdf_mode_opt = if ocr_enabled {
                Some("ocr")
              } else {
                None
              }
              let pdf_backend_opt : String? = match
                sub.args.get("pdf-backend") {
                Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
                None => None
              }
              let pdf_backend_policy_opt : String? = match
                sub.args.get("pdf-backend-policy") {
                Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
                None => None
              }

              let mh0 = parse_int_or_default(max_heading_opt, 3)
              let max_heading = if mh0 < 1 {
                1
              } else if mh0 > 6 {
                6
              } else {
                mh0
              }

              let (pdf_extract_debug, pdf_dump_selected_raw, pdf_pipeline_debug) =
                parse_debug_modes(sub.args.get("debug"))
              cmd_convert(
                input, output_opt, out_dir_opt, max_heading, pdf_mode_opt, pdf_backend_opt,
                pdf_backend_policy_opt, pdf_extract_debug, pdf_dump_selected_raw,
                pdf_pipeline_debug,
              )
            }
            "help" => println(help_msg)
            _ => println(help_msg)
          }
        }
        None => println(help_msg)
      }
  }
}

///|
fn parse_bool_flag(raw : Array[String]?) -> Bool {
  match raw {
    None => false
    Some(arr) =>
      if arr.length() == 0 {
        true
      } else {
        let v = arr[0].trim().to_string().to_lower()
        v == "1" || v == "true" || v == "on" || v == "yes"
      }
  }
}

///|
fn parse_debug_modes(raw : Array[String]?) -> (Bool, Bool, Bool) {
  let mut extract = false
  let mut dump_raw = false
  let mut pipeline = false

  let arg = match raw {
    None => ""
    Some(arr) =>
      if arr.length() == 0 {
        "all"
      } else {
        arr[0].trim().to_string().to_lower()
      }
  }

  if arg == "" {
    return (false, false, false)
  }

  let parts = arg.split(",")
  for p in parts {
    let mode = p.trim().to_string()
    if mode == "all" {
      extract = true
      dump_raw = true
      pipeline = true
      continue
    }
    if mode == "extract" {
      extract = true
      continue
    }
    if mode == "dump-raw" || mode == "dump_raw" || mode == "dumpraw" {
      dump_raw = true
      continue
    }
    if mode == "pipeline" {
      pipeline = true
      continue
    }
  }

  (extract, dump_raw, pipeline)
}
