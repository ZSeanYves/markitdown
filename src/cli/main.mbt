///|
async fn main {
  let args = @sys.get_cli_args()

  let parser = @clap.Parser::new(
    prog="markitdown-mb",
    description="Convert documents (docx/pdf/xlsx/pptx/html) to Markdown (MoonBit, markitdown-like)",
    subcmds={
      "demo": @clap.SubCommand::new(
        help="Print a demo Markdown document (tests core/ir + emitter)",
        args={},
      ),
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
          "pdf-mode": @clap.Arg::named(
            nargs=@clap.Nargs::AtMost(1),
            help="PDF enhancement mode: text|experimental (default: text)",
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
            "demo" => cmd_demo()
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

              let pdf_mode_opt : String? = match sub.args.get("pdf-mode") {
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
              cmd_convert(input, output_opt, out_dir_opt, max_heading, pdf_mode_opt)
            }
            "help" => println(help_msg)
            _ => println(help_msg)
          }
        }
        None => println(help_msg)
      }
  }
}
