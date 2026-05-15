///|
pub fn new_cli_parser() -> @clap.Parser {
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
      "ocr": @clap.SubCommand::new(
        help="Explicit OCR conversion: ocr [--provider tesseract-cli] [--lang eng+chi_sim] [--with-metadata] <input> [output] (delegates to cli_ocr component)",
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
            help="Path to OCR input file (.png/.jpg/.jpeg/.tif/.tiff/.bmp/.webp, or explicit OCR PDF path)",
          ),
        },
      ),
      "debug": @clap.SubCommand::new(
        help="Moved: build/use cli_debug for debug inspect/providers",
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
            help="Debug input, provider listing keyword `providers`, eval keyword `layout-assist-eval`, or legacy PDF debug args: <all|extract|raw|pipeline> <input> [output]",
          ),
        },
      ),
    },
  )
}

///|
pub fn print_cli_help() -> Unit {
  let parser = new_cli_parser()
  println(parser.gen_help_message(["markitdown-mb"], {}))
}

///|
pub fn print_cli_usage() -> Unit {
  println("Usage:")
  println("  markitdown-mb normal [--with-metadata] <input> [output]")
  println("  markitdown-mb batch [--with-metadata] <input_dir> <output_dir>")
  println(
    "  markitdown-mb ocr ...    (product OCR entry; delegates to bundled cli_ocr or MARKITDOWN_OCR_CLI)",
  )
  println(
    "  markitdown-mb debug ...  (moved to cli_debug; build with: moon build cli_debug --target native)",
  )
  println(
    "  hidden bench commands moved to cli_bench; build with: moon build cli_bench --target native",
  )
}
