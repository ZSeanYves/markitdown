///|
/// Compatibility note:
/// - `layout_model_tool` is a legacy umbrella name
/// - the tool can still export `record-kind block|boundary` rows for historical
///   compatibility
/// - `block` rows correspond to convert-layer block-semantic experiments
/// - `boundary` rows correspond to parser/layout boundary experiments
/// - current HGB teacher and distillation work in quality-lab should not treat
///   this mixed export tool as the primary training entrypoint

///|
suberror PdfLayoutToolError {
  Failed(String)
}

///|
impl Show for PdfLayoutToolError with fn to_string(self : PdfLayoutToolError) -> String {
  match self {
    Failed(msg) => msg
  }
}

///|
async fn main {
  run_tool(normalize_cli_args(@sys.get_cli_args())) catch {
    e => {
      println("pdf_layout_classifier failed: " + e.to_string())
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
async fn run_tool(args : Array[String]) -> Unit raise PdfLayoutToolError {
  if args.is_empty() {
    print_usage()
    return
  }

  match args[0] {
    "export" => run_export(slice_args(args, 1))
    "infer" => run_infer(slice_args(args, 1))
    "--help" | "-h" => print_usage()
    other => raise Failed("unknown command: " + other)
  }
}

///|
fn print_usage() -> Unit {
  println(
    "usage: moon run doc_parse/pdf/layout_model_tool -- <export|infer> [args]",
  )
  println(
    "  compatibility surface: use --record-kind to keep block and boundary flows separate",
  )
  println(
    "  export --sample-id ID --input PATH [--output PATH] [--record-kind block|boundary]",
  )
  println("  infer --model PATH --features TSV [--output PATH]")
}

///|
async fn run_export(args : Array[String]) -> Unit raise PdfLayoutToolError {
  let cfg = parse_export_args(args)
  let text = @pdf.export_pdf_layout_features_tsv(
    cfg.input,
    cfg.sample_id,
    cfg.record_kind,
  ) catch {
    e => raise Failed("export failed: " + e.to_string())
  }

  match cfg.output {
    Some(path) => {
      ensure_parent_dir(path)
      @fs.write_string_to_file(path, text, encoding="utf8") catch {
        e => raise Failed("write export output failed: " + e.to_string())
      }
    }
    None => println(text)
  }
}

///|
fn run_infer(args : Array[String]) -> Unit raise PdfLayoutToolError {
  let cfg = parse_infer_args(args)
  let model_text = @fs.read_file_to_string(cfg.model_path, encoding="utf8") catch {
    e => raise Failed("read model failed: " + e.to_string())
  }
  let feature_text = @fs.read_file_to_string(cfg.feature_path, encoding="utf8") catch {
    e => raise Failed("read features failed: " + e.to_string())
  }
  let report = match
    @pdf.infer_pdf_layout_features_tsv(model_text, feature_text) {
    Ok(v) => v
    Err(err) => raise Failed(err.message)
  }

  match cfg.output {
    Some(path) => {
      ensure_parent_dir(path)
      @fs.write_string_to_file(path, report, encoding="utf8") catch {
        e => raise Failed("write infer output failed: " + e.to_string())
      }
    }
    None => println(report)
  }
}

///|
struct ExportArgs {
  sample_id : String
  input : String
  output : String?
  record_kind : String
}

///|
struct InferArgs {
  model_path : String
  feature_path : String
  output : String?
}

///|
fn parse_export_args(
  args : Array[String],
) -> ExportArgs raise PdfLayoutToolError {
  let mut sample_id = ""
  let mut input = ""
  let mut output : String? = None
  let mut record_kind = "block"
  let mut i = 0

  while i < args.length() {
    let arg = args[i]
    if arg == "--sample-id" {
      i = require_value(args, i, arg)
      sample_id = args[i]
    } else if arg == "--input" {
      i = require_value(args, i, arg)
      input = args[i]
    } else if arg == "--output" {
      i = require_value(args, i, arg)
      output = Some(args[i])
    } else if arg == "--record-kind" {
      i = require_value(args, i, arg)
      record_kind = args[i].trim().to_owned().to_lower()
    } else if arg == "-h" || arg == "--help" {
      print_usage()
      @sys.exit(0)
    } else {
      raise Failed("unknown export arg: " + arg)
    }
    i += 1
  }

  if sample_id.trim() == "" {
    raise Failed("--sample-id is required")
  }
  if input.trim() == "" {
    raise Failed("--input is required")
  }
  { sample_id, input, output, record_kind }
}

///|
fn parse_infer_args(args : Array[String]) -> InferArgs raise PdfLayoutToolError {
  let mut model_path = ""
  let mut feature_path = ""
  let mut output : String? = None
  let mut i = 0

  while i < args.length() {
    let arg = args[i]
    if arg == "--model" {
      i = require_value(args, i, arg)
      model_path = args[i]
    } else if arg == "--features" {
      i = require_value(args, i, arg)
      feature_path = args[i]
    } else if arg == "--output" {
      i = require_value(args, i, arg)
      output = Some(args[i])
    } else if arg == "-h" || arg == "--help" {
      print_usage()
      @sys.exit(0)
    } else {
      raise Failed("unknown infer arg: " + arg)
    }
    i += 1
  }

  if model_path.trim() == "" {
    raise Failed("--model is required")
  }
  if feature_path.trim() == "" {
    raise Failed("--features is required")
  }
  { model_path, feature_path, output }
}

///|
fn require_value(
  args : Array[String],
  index : Int,
  flag : String,
) -> Int raise PdfLayoutToolError {
  if index + 1 >= args.length() {
    raise Failed("missing value for " + flag)
  }
  index + 1
}

///|
fn ensure_parent_dir(path : String) -> Unit raise PdfLayoutToolError {
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
  for i = 0; i < chars.length(); i = i + 1 {
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
fn slice_args(args : Array[String], start : Int) -> Array[String] {
  let out : Array[String] = []
  for i = start; i < args.length(); i = i + 1 {
    out.push(args[i])
  }
  out
}

///|
fn ensure_dir_tree(path : String) -> Unit raise PdfLayoutToolError {
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
  ) -> String raise PdfLayoutToolError {
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
