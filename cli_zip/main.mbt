///|
fn zip_cli_args(args : Array[String]) -> Array[String] {
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
  let cli_args = zip_cli_args(@clisup.normalize_cli_args(@sys.get_cli_args()))
  if cli_args.length() == 0 {
    print_zip_help()
    print_zip_usage()
    return
  }

  let parser = new_zip_cli_parser()
  let value = @clap.SimpleValue::new("markitdown-mb-zip")
  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      print_zip_help()
      print_zip_usage()
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
            @clisup.exit_error(
              "usage: [normal] [--with-metadata] <input.zip> [output]",
            )
            print_zip_usage()
            return
          }

          let input = positional[0]
          let output_opt = if positional.length() >= 2 {
            Some(positional[1])
          } else {
            None
          }
          let with_metadata = sub.get_flag("with-metadata").unwrap_or(false)
          cmd_zip_normal(input, output_opt, with_metadata)
        }
        None => {
          print_zip_help()
          print_zip_usage()
        }
      }
  }
}

///|
async fn cmd_zip_normal(
  input : String,
  output : String?,
  with_metadata : Bool,
) -> Unit {
  if @clisup.detect_input_format(input) != "zip" {
    @clisup.exit_error("cli_zip only supports .zip input: " + input)
    return
  }

  let resolved_output = @clisup.resolve_output_path(input, output)
  let output_root_opt = match resolved_output {
    Some(path) => Some(@clisup.dirname_of_path(path))
    None => None
  }
  let parse_out_dir = output_root_opt.unwrap_or("")

  if output_root_opt is Some(out_root) {
    @clisup.ensure_dir_tree(out_root) catch {
      e => {
        @clisup.exit_error("create output dir failed: " + e.to_string())
        return
      }
    }
  }

  let doc = @zipconv.parse_zip(input, parse_out_dir, 6) catch {
    e => {
      @clisup.exit_error("parse failed: " + e.to_string())
      return
    }
  }

  match
    @clisup.write_document_output(input, "zip", doc, output, with_metadata) {
    Ok(_) => ()
    Err(msg) => @clisup.exit_error(msg)
  }
}

///|
fn new_zip_cli_parser() -> @clap.Parser {
  @clap.Parser::new(
    prog="markitdown-mb-zip",
    description="ZIP conversion worker",
    subcmds={
      "normal": @clap.SubCommand::new(
        help="Normal ZIP conversion: [normal] [--with-metadata] <input.zip> [output]",
        args={
          "with-metadata": @clap.Arg::flag(
            help="Also write <name>.metadata.json next to markdown output",
          ),
          "input": @clap.Arg::positional(help="Path to ZIP input file"),
        },
      ),
    },
  )
}

///|
fn print_zip_help() -> Unit {
  let parser = new_zip_cli_parser()
  println(parser.gen_help_message(["markitdown-mb-zip"], {}))
}

///|
fn print_zip_usage() -> Unit {
  println("Usage:")
  println("  markitdown-mb-zip [normal] [--with-metadata] <input.zip> [output]")
}
