///|
/// Batch v1 orchestration for the product CLI.
///
/// Keep this in `cli_support` so it can reuse the normal one-file conversion
/// path while keeping batch-specific input enumeration and summary writing out
/// of the main CLI conversion flow.
priv struct BatchItemResult {
  index : Int
  input_path : String
  output_md : String?
  format : String
  status : String
  elapsed_ms : Int
  error : String
}

///|
pub struct BatchRunResult {
  total_count : Int
  success_count : Int
  failure_count : Int
  unsupported_count : Int
  skipped_directory_count : Int
  had_error : Bool
  summary_path : String
}

///|
pub fn batch_summary_line(result : BatchRunResult) -> String {
  "batch summary: " +
  result.success_count.to_string() +
  " ok, " +
  result.failure_count.to_string() +
  " failed, " +
  result.unsupported_count.to_string() +
  " unsupported, " +
  result.skipped_directory_count.to_string() +
  " skipped_directory, " +
  result.total_count.to_string() +
  " total -> " +
  result.summary_path
}

///|
pub async fn run_batch(
  input_dir : String,
  output_dir : String,
  with_metadata : Bool,
) -> Result[BatchRunResult, String] {
  let items = collect_batch_inputs(input_dir) catch {
    e => return Err("read batch input dir failed: " + e.to_string())
  }
  ensure_dir_tree(output_dir) catch {
    e => return Err("create batch output dir failed: " + e.to_string())
  }

  let results : Array[BatchItemResult] = []
  let mut success_count = 0
  let mut failure_count = 0
  let mut unsupported_count = 0
  let mut skipped_directory_count = 0

  for i in 0..<items.length() {
    let item = items[i]
    let index = i + 1

    match item.kind {
      BatchInputKind::Directory => {
        skipped_directory_count += 1
        results.push({
          index,
          input_path: item.path,
          output_md: None,
          format: "",
          status: "skipped_directory",
          elapsed_ms: 0,
          error: "",
        })
      }
      BatchInputKind::File => {
        let format = detect_input_format(item.path)
        if format == "unknown" {
          failure_count += 1
          unsupported_count += 1
          results.push({
            index,
            input_path: item.path,
            output_md: None,
            format: @cor.file_ext_lower(item.path),
            status: "unsupported",
            elapsed_ms: 0,
            error: "Unsupported file type: " + @cor.file_ext_lower(item.path),
          })
          continue
        }

        let doc_root = batch_doc_root(output_dir, index, item.path)
        let markdown_path = join_path(doc_root, input_stem(item.path) + ".md")
        let started = now_ms()
        let result = convert_once(
          item.path,
          Some(markdown_path),
          Some(doc_root),
          6,
          None,
          false,
          false,
          false,
          with_metadata,
          OcrPolicy::Auto,
          None,
        )
        let elapsed_ms = elapsed_ms_since(started)

        match result {
          Ok(_) => {
            success_count += 1
            results.push({
              index,
              input_path: item.path,
              output_md: Some(markdown_path),
              format,
              status: "ok",
              elapsed_ms,
              error: "",
            })
          }
          Err(msg) => {
            failure_count += 1
            let status = if msg.contains("Unsupported file type:") {
              unsupported_count += 1
              "unsupported"
            } else {
              "failed"
            }
            results.push({
              index,
              input_path: item.path,
              output_md: Some(markdown_path),
              format,
              status,
              elapsed_ms,
              error: msg,
            })
          }
        }
      }
    }
  }

  let summary_path = join_path(output_dir, "batch-summary.tsv")
  write_batch_summary(summary_path, results) catch {
    e => return Err("write batch summary failed: " + e.to_string())
  }

  Ok({
    total_count: items.length(),
    success_count,
    failure_count,
    unsupported_count,
    skipped_directory_count,
    had_error: failure_count > 0,
    summary_path,
  })
}

///|
priv enum BatchInputKind {
  File
  Directory
}

///|
priv struct BatchInputEntry {
  path : String
  kind : BatchInputKind
}

///|
fn collect_batch_inputs(
  input_dir : String,
) -> Array[BatchInputEntry] raise @fs.IOError {
  let names = @fs.read_dir(input_dir)
  names.sort()

  let out : Array[BatchInputEntry] = []
  for name in names {
    let child = join_path(input_dir, name)
    if @fs.is_dir(child) {
      out.push({ path: child, kind: BatchInputKind::Directory })
    } else if @fs.is_file(child) {
      out.push({ path: child, kind: BatchInputKind::File })
    }
  }
  out
}

///|
fn batch_doc_root(
  output_dir : String,
  index : Int,
  input_path : String,
) -> String {
  join_path(
    output_dir,
    pad_batch_index(index) + "-" + sanitize_batch_stem(input_stem(input_path)),
  )
}

///|
fn pad_batch_index(n : Int) -> String {
  if n < 10 {
    "00" + n.to_string()
  } else if n < 100 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn sanitize_batch_stem(raw : String) -> String {
  let chars = raw.to_array()
  let out : Array[Char] = []
  for ch in chars {
    let keep = (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9')
    if keep {
      out.push(ch)
    } else if ch == '-' || ch == '_' {
      out.push(ch)
    } else {
      out.push('-')
    }
  }

  let text = String::from_array(out).trim().to_owned()
  if text == "" {
    "document"
  } else {
    text
  }
}

///|
fn write_batch_summary(
  path : String,
  results : Array[BatchItemResult],
) -> Unit raise @fs.IOError {
  let lines : Array[String] = [
    "index\tinput_path\toutput_md\tformat\tstatus\telapsed_ms\terror",
  ]
  for item in results {
    let output_md = match item.output_md {
      Some(p) => p
      None => ""
    }
    lines.push(
      item.index.to_string() +
      "\t" +
      summary_escape(item.input_path) +
      "\t" +
      summary_escape(output_md) +
      "\t" +
      summary_escape(item.format) +
      "\t" +
      summary_escape(item.status) +
      "\t" +
      item.elapsed_ms.to_string() +
      "\t" +
      summary_escape(item.error),
    )
  }
  @fs.write_string_to_file(path, lines.join("\n") + "\n", encoding="utf8")
}

///|
fn summary_escape(text : String) -> String {
  text
  .replace(old="\t", new=" ")
  .replace(old="\n", new=" ")
  .replace(old="\r", new=" ")
}

///|
fn elapsed_ms_since(started : Int64) -> Int {
  let now = now_ms()
  if now <= started {
    0
  } else {
    (now - started).to_int()
  }
}
