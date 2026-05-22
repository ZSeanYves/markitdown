///|
suberror VisionTsvSummaryToolError {
  Failed(String)
}

///|
impl Show for VisionTsvSummaryToolError with to_string(
  self : VisionTsvSummaryToolError,
) -> String {
  match self {
    Failed(msg) => msg
  }
}

///|
fn main {
  run_tool(normalize_cli_args(@sys.get_cli_args())) catch {
    e => {
      println("vision_tsv_summary failed: " + e.to_string())
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
fn run_tool(args : Array[String]) -> Unit raise VisionTsvSummaryToolError {
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

  let summary_lines = [
    "provider=" + page.provider,
    "source_kind=" + page.source_kind,
    "lines=" + @vision.ocr_page_line_count(page).to_string(),
    "words=" + @vision.ocr_page_word_count(page).to_string(),
    "warnings=" + @vision.ocr_page_warning_count(page).to_string(),
    "text=" + @vision.ocr_page_text(page),
  ]

  match cfg.output {
    Some(path) => {
      ensure_parent_dir(path)
      @fs.write_string_to_file(
        path,
        summary_lines.join("\n") + "\n",
        encoding="utf8",
      ) catch {
        e => raise Failed("write summary failed: " + e.to_string())
      }
    }
    None => println(summary_lines.join("\n"))
  }
}

///|
struct SummaryArgs {
  tsv_path : String
  provider : String
  output : String?
}

///|
fn parse_args(
  args : Array[String],
) -> SummaryArgs raise VisionTsvSummaryToolError {
  let mut tsv_path = ""
  let mut provider = "tesseract-tsv"
  let mut output : String? = None
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
  { tsv_path, provider, output }
}

///|
fn require_value(
  args : Array[String],
  index : Int,
  flag : String,
) -> Int raise VisionTsvSummaryToolError {
  if index + 1 >= args.length() {
    raise Failed("missing value for " + flag)
  }
  index + 1
}

///|
fn print_usage() -> Unit {
  println(
    "usage: moon run convert/vision/tsv_summary_tool -- --tsv PATH [--provider NAME] [--output PATH]",
  )
}

///|
fn ensure_parent_dir(path : String) -> Unit raise VisionTsvSummaryToolError {
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
fn ensure_dir_tree(path : String) -> Unit raise VisionTsvSummaryToolError {
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
  ) -> String raise VisionTsvSummaryToolError {
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
