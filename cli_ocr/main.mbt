///|
fn ocr_cli_args(args : Array[String]) -> Array[String] {
  if args.length() == 0 {
    return []
  }

  let first = args[0].trim().to_owned().to_lower()
  if first == "ocr" {
    return args
  }

  let out : Array[String] = ["ocr"]
  for arg in args {
    out.push(arg)
  }
  out
}

///|
async fn main {
  let cli_args = ocr_cli_args(@clisup.normalize_cli_args(@sys.get_cli_args()))
  if cli_args.length() == 0 {
    print_ocr_help()
    print_ocr_usage()
    return
  }

  let parser = new_ocr_cli_parser()
  let value = @clap.SimpleValue::new("markitdown-mb-ocr")
  let subcmd_help = parser.parse(value, cli_args[:]) catch {
    e => {
      println(e)
      print_ocr_help()
      print_ocr_usage()
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
              "usage: ocr [--provider <name>] [--lang <code>] [--with-metadata] <input> [output]",
            )
            print_ocr_usage()
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
          let with_metadata = sub.get_flag("with-metadata").unwrap_or(false)
          cmd_ocr(input, output_opt, provider_name, lang_arg, with_metadata)
        }
        None => {
          print_ocr_help()
          print_ocr_usage()
        }
      }
  }
}

///|
fn new_ocr_cli_parser() -> @clap.Parser {
  @clap.Parser::new(
    prog="markitdown-mb-ocr",
    description="Explicit OCR conversion entrypoint",
    subcmds={
      "ocr": @clap.SubCommand::new(
        help="Explicit OCR mode: ocr [--provider tesseract-cli] [--lang eng+chi_sim] [--with-metadata] <input> [output]",
        args={
          "provider": @clap.Arg::named(
            nargs=AtMost(1),
            help="Explicit OCR provider name (default: tesseract-cli)",
          ),
          "lang": @clap.Arg::named(
            nargs=AtMost(1),
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
    },
  )
}

///|
fn print_ocr_help() -> Unit {
  let parser = new_ocr_cli_parser()
  println(parser.gen_help_message(["markitdown-mb-ocr"], {}))
}

///|
fn print_ocr_usage() -> Unit {
  println("Usage:")
  println(
    "  markitdown-mb-ocr [ocr] [--provider <name>] [--lang <code>] [--with-metadata] <input> [output]",
  )
}
