///|
suberror VisionTsvPreviewToolError {
  Failed(String)
}

///|
impl Show for VisionTsvPreviewToolError with fn to_string(
  self : VisionTsvPreviewToolError,
) -> String {
  match self {
    Failed(msg) => msg
  }
}

///|
fn main {
  run_tool(normalize_cli_args(@sys.get_cli_args())) catch {
    e => {
      println("vision_tsv_preview failed: " + e.to_string())
      @sys.exit(1)
    }
  }
}

///|
fn normalize_cli_args(args : Array[String]) -> Array[String] {
  if args.length() == 0 {
    return args
  }
  let first = args[0]
  if first.has_prefix("-") {
    return args
  }
  let out : Array[String] = []
  for i in 1..<args.length() {
    out.push(args[i])
  }
  out
}

///|
fn run_tool(args : Array[String]) -> Unit raise VisionTsvPreviewToolError {
  if args.is_empty() || args[0] == "--help" || args[0] == "-h" {
    print_usage()
    return
  }

  let cfg = parse_args(args)
  let tsv_text = @fs.read_file_to_string(cfg.tsv_path, encoding="utf8") catch {
    e => raise Failed("read TSV failed: " + e.to_string())
  }
  let page = match
    @vision.parse_tesseract_tsv_page_with_provider(tsv_text, cfg.provider) {
    Ok(v) => v
    Err(err) => raise Failed(err.to_string())
  }
  let effective_page = if cfg.resegment_lines {
    @vision.resegment_ocr_page_lines_from_words(page)
  } else {
    page
  }
  let layout = @vision.recover_ocr_layout_page(effective_page)
  let output_text = if cfg.dump_ir_hints {
    let hints = @vision.collect_ocr_layout_page_ir_hints(layout)
    @vision.render_ocr_ir_document_hints_tsv(hints)
  } else if cfg.render_via_ir {
    @vision.render_ocr_layout_page_via_ir_markdown(layout)
  } else {
    @vision.render_ocr_layout_page_markdown(layout)
  }

  match cfg.output {
    Some(path) => {
      ensure_parent_dir(path)
      @fs.write_string_to_file(path, output_text, encoding="utf8") catch {
        e => raise Failed("write output failed: " + e.to_string())
      }
    }
    None => if output_text != "" { println(output_text) }
  }
}

///|
struct PreviewArgs {
  tsv_path : String
  provider : String
  output : String?
  resegment_lines : Bool
  render_via_ir : Bool
  dump_ir_hints : Bool
}

///|
fn parse_args(
  args : Array[String],
) -> PreviewArgs raise VisionTsvPreviewToolError {
  let mut tsv_path = ""
  let mut provider = "tesseract-tsv"
  let mut output : String? = None
  let mut resegment_lines = false
  let mut render_via_ir = false
  let mut dump_ir_hints = false
  let mut i = 0

  while i < args.length() {
    let arg = args[i]
    if arg == "--tsv" {
      i = require_value(args, i, arg)
      tsv_path = args[i]
    } else if arg == "--provider" {
      i = require_value(args, i, arg)
      provider = args[i].trim().to_owned()
    } else if arg == "--output" {
      i = require_value(args, i, arg)
      output = Some(args[i])
    } else if arg == "--resegment-lines" {
      resegment_lines = true
    } else if arg == "--render-via-ir" {
      render_via_ir = true
    } else if arg == "--dump-ir-hints" {
      dump_ir_hints = true
    } else if arg == "--help" || arg == "-h" {
      print_usage()
      @sys.exit(0)
    } else {
      raise Failed("unknown arg: " + arg)
    }
    i += 1
  }

  if tsv_path.trim() == "" {
    raise Failed("--tsv is required")
  }
  if provider.trim() == "" {
    raise Failed("--provider must not be blank")
  }
  { tsv_path, provider, output, resegment_lines, render_via_ir, dump_ir_hints }
}

///|
fn require_value(
  args : Array[String],
  index : Int,
  flag : String,
) -> Int raise VisionTsvPreviewToolError {
  if index + 1 >= args.length() {
    raise Failed("missing value for " + flag)
  }
  index + 1
}

///|
fn print_usage() -> Unit {
  println(
    "usage: moon run convert/vision/tsv_preview_tool -- --tsv PATH [--provider NAME] [--output PATH] [--resegment-lines] [--render-via-ir] [--dump-ir-hints]",
  )
  println(
    "  --resegment-lines  internal/dev-only: resegment line candidates from OCR word geometry before layout recovery",
  )
  println(
    "  --render-via-ir    internal/dev-only: render OCR layout through the shared document IR markdown emitter",
  )
  println(
    "  --dump-ir-hints    internal/dev-only: dump OCR layout -> IR hint side-channel as TSV rows; when present it takes precedence over markdown rendering",
  )
}

///|
fn ensure_parent_dir(path : String) -> Unit raise VisionTsvPreviewToolError {
  let normalized = path.trim().to_owned()
  if normalized == "" {
    return
  }
  let parent = parent_dir(normalized)
  if parent == "" || parent == "." {
    return
  }
  ensure_dir_tree(parent)
}

///|
fn parent_dir(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  let chars = normalized.to_array()
  let mut last_sep = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      last_sep = i
    }
  }
  if last_sep < 0 {
    "."
  } else if last_sep == 0 {
    "/"
  } else {
    normalized[:last_sep].to_owned()
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise VisionTsvPreviewToolError {
  let trimmed = path.trim()
  if trimmed == "" || trimmed == "." {
    return
  }

  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(
    part : Array[Char],
    current : String,
  ) -> String raise VisionTsvPreviewToolError {
    if part.length() == 0 {
      return current
    }

    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    if !@fs.path_exists(next) {
      @fs.create_dir(next) catch {
        e => raise Failed("create dir failed: " + e.to_string())
      }
    }
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }

  ignore(flush(part, current))
}
