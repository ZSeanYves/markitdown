///|
fn pdf_cli_args(args : Array[String]) -> Array[String] {
  if args.length() == 0 {
    return []
  }

  let first = args[0].trim().to_owned().to_lower()
  if first == "normal" {
    return args
  }

  let out : Array[String] = ["normal"]
  for arg in args {
    out.push(arg)
  }
  out
}

///|
async fn main {
  let cli_args = pdf_cli_args(@clicom.normalize_cli_args(@sys.get_cli_args()))
  if cli_args.length() == 0 {
    print_pdf_help()
    print_pdf_usage()
    return
  }

  let parser = new_pdf_cli_parser()
  let value = @clap.SimpleValue::new("markitdown-mb-pdf")
  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      print_pdf_help()
      print_pdf_usage()
      return
    }
  }

  match subcmd_help {
    Some(msg) => println(msg)
    None =>
      match value.subcmd {
        Some(sub) => {
          let positional = sub.positional_args
          if positional.length() < 1 || positional.length() > 2 {
            @clicom.exit_error(
              "usage: [normal] [--with-metadata] <input.pdf> [output]",
            )
            print_pdf_usage()
            return
          }

          let input = positional[0]
          let output_opt = if positional.length() >= 2 {
            Some(positional[1])
          } else {
            None
          }
          let with_metadata = sub.get_flag("with-metadata").unwrap_or(false)
          cmd_pdf_normal(input, output_opt, with_metadata)
        }
        None => {
          print_pdf_help()
          print_pdf_usage()
        }
      }
  }
}

///|
async fn cmd_pdf_normal(
  input : String,
  output : String?,
  with_metadata : Bool,
) -> Unit {
  if @clicom.detect_input_format(input) != "pdf" {
    @clicom.exit_error("cli_pdf only supports .pdf input: " + input)
    return
  }

  let resolved_output = @clicom.resolve_output_path(input, output)
  let output_root_opt = match resolved_output {
    Some(path) => Some(@clicom.dirname_of_path(path))
    None => None
  }
  let parse_out_dir = output_root_opt.unwrap_or("")

  if output_root_opt is Some(out_root) {
    @clicom.ensure_dir_tree(out_root) catch {
      e => {
        @clicom.exit_error("create output dir failed: " + e.to_string())
        return
      }
    }
  }

  let doc = @pdf.parse_pdf(input, parse_out_dir, 6, None, false, false, false) catch {
    e => {
      @clicom.exit_error("parse failed: " + e.to_string())
      return
    }
  }

  match
    @clicom.write_document_output(input, "pdf", doc, output, with_metadata) {
    Ok(_) => ()
    Err(msg) => @clicom.exit_error(msg)
  }
}

///|
fn new_pdf_cli_parser() -> @clap.Parser {
  @clap.Parser::new(
    prog="markitdown-mb-pdf",
    description="Normal PDF conversion worker",
    subcmds={
      "normal": @clap.SubCommand::new(
        help="Normal PDF conversion: [normal] [--with-metadata] <input.pdf> [output]",
        args={
          "with-metadata": @clap.Arg::flag(
            help="Also write <name>.metadata.json next to markdown output",
          ),
          "input": @clap.Arg::positional(help="Path to PDF input file"),
        },
      ),
    },
  )
}

///|
fn print_pdf_help() -> Unit {
  let parser = new_pdf_cli_parser()
  println(parser.gen_help_message(["markitdown-mb-pdf"], {}))
}

///|
fn print_pdf_usage() -> Unit {
  println("Usage:")
  println("  markitdown-mb-pdf [normal] [--with-metadata] <input.pdf> [output]")
}
