///|
const PRODUCT_NAME : String = "markitdown-mb"

///|
const PRODUCT_VERSION : String = "0.3.4"

///|
pub fn product_name() -> String {
  PRODUCT_NAME
}

///|
pub fn product_version() -> String {
  PRODUCT_VERSION
}

///|
pub fn print_cli_version() -> Unit {
  println(product_name() + " " + product_version())
}

///|
pub fn new_cli_parser() -> @clap.Parser {
  @clap.Parser::new(
    prog=PRODUCT_NAME,
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
        help="Explicit OCR conversion: ocr [--provider tesseract-cli] [--lang eng+chi_sim] [--with-metadata] <input> [output] (delegates to ocr component)",
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
        help="Moved: build/use debug for debug inspect/providers",
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
  println(parser.gen_help_message([product_name()], {}))
}

///|
pub fn print_cli_usage() -> Unit {
  println("Usage:")
  println(
    "  " + product_name() + " [normal] [--with-metadata] <input> [output]",
  )
  println(
    "  " + product_name() + " batch [--with-metadata] <input_dir> <output_dir>",
  )
  println(
    "  " +
    product_name() +
    " ocr ...    (explicit OCR entry; delegates to bundled ocr or MARKITDOWN_OCR_CLI)",
  )
  println(
    "  " +
    product_name() +
    " debug ...  (moved to debug; build with: moon build debug --target native)",
  )
  println(
    "  hidden bench commands moved to bench; build with: moon build bench --target native",
  )
  println("  " + product_name() + " help | --help | -h")
  println("  " + product_name() + " version | --version")
  println("")
  println(
    "Supported normal formats: docx, pdf, xlsx, pptx, html, csv, tsv, txt, xml, json, yaml, yml, md, markdown, epub, zip",
  )
  println(
    "PDF and ZIP stay on the normal product surface through bundled `pdf` / `zip` components; users do not need to run those components directly.",
  )
  println(
    "OCR stays explicit and isolated from normal conversion; debug and benchmark tooling stay in debug and bench.",
  )
  println(
    "Runtime overrides still supported: MARKITDOWN_OCR_CLI for the OCR component, MARKITDOWN_OCR_PROVIDER_CMD_TESSERACT_CLI for explicit Tesseract provider wiring.",
  )
}
