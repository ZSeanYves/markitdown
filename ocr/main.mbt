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
fn main {
  let cli_args = ocr_cli_args(@clicom.normalize_cli_args(@sys.get_cli_args()))
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
            @clicom.exit_error("usage: ocr <input> [output]")
            print_ocr_usage()
            return
          }

          let input = positional[0]
          let output_opt = if positional.length() >= 2 {
            Some(positional[1])
          } else {
            None
          }
          cmd_ocr(input, output_opt)
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
    description="OCR rebuild entrypoint; provider execution is not wired in this build",
    subcmds={
      "ocr": @clap.SubCommand::new(
        help="OCR rebuild entrypoint; current provider execution is retired while OCRPageModel and layout recovery are rebuilt",
        args={
          "input": @clap.Arg::positional(
            help="Path to OCR candidate input; current build returns a rebuild notice instead of executing providers",
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
  println("  markitdown-mb-ocr [ocr] <input> [output]")
  println("")
  println("Current OCR boundary:")
  println(
    "  * explicit-only: normal conversion does not auto OCR or probe providers",
  )
  println("  * OCR is being rebuilt around provider-independent OCRPageModel")
  println("  * previous text-only OCR prototype has been retired")
  println("  * current OCR provider execution is not wired in this build")
  println(
    "  * PDF OCR remains fail closed and will require an explicit provider",
  )
  println("  * no bundled tessdata and no automatic model downloads")
}
