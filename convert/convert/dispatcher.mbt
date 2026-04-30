///|
/// Cross-format dispatcher options.
/// This struct intentionally carries only orchestration toggles shared by CLI.
pub(all) struct ConvertOptions {
  out_dir : String?
  max_heading : Int?
  pdf_enhance_mode : String?
  pdf_extract_debug : Bool
  pdf_dump_selected_raw : Bool
  pdf_pipeline_debug : Bool
}

///|
/// Dispatch by file extension to format-specific parser.
///
/// Why dispatcher is isolated:
/// - keeps extension routing independent from format recovery heuristics
/// - makes new format onboarding explicit (single entry to register)
/// - improves explainability in acceptance reviews: "where does parsing start?"
///
/// Non-goal:
/// - no format fallback / repair strategy here; those belong inside each converter.
pub async fn parse_to_ir(
  input_path : String,
  opts : ConvertOptions,
) -> Result[@cor.Document, @cor.AppError] {
  let ext = file_ext_lower(input_path)

  let out_dir_str = match opts.out_dir {
    None => ""
    Some(dir) => dir
  }
  let max_h = opts.max_heading.unwrap_or(6)

  match ext {
    "docx" => Ok(@doc.parse_docx(input_path, out_dir_str, max_h))
    "pdf" =>
      Ok(
        @pdf.parse_pdf(
          input_path,
          out_dir_str,
          max_h,
          opts.pdf_enhance_mode,
          opts.pdf_extract_debug,
          opts.pdf_dump_selected_raw,
          opts.pdf_pipeline_debug,
        ),
      )
    "xlsx" => Ok(@xlsx.parse_xlsx(input_path, out_dir_str, max_h))
    "pptx" => Ok(@pptx.parse_pptx(input_path, out_dir_str, max_h))
    "html" => Ok(@html.parse_html(input_path, out_dir_str, max_h))
    "htm" => Ok(@html.parse_html(input_path, out_dir_str, max_h))
    "csv" => Ok(@csv.parse_csv(input_path, out_dir_str, max_h))
    "tsv" => Ok(@csv.parse_tsv(input_path, out_dir_str, max_h))
    "json" => Ok(@json.parse_json(input_path, out_dir_str, max_h))
    "md" => Ok(@md.parse_markdown(input_path, out_dir_str, max_h))
    "markdown" => Ok(@md.parse_markdown(input_path, out_dir_str, max_h))
    _ => Err(@cor.AppError("Unsupported file type: " + ext))
  }
}

///|
fn file_ext_lower(path : String) -> String {
  let n = path.length()
  if n == 0 {
    return ""
  }

  let mut i = n - 1
  while i >= 0 {
    if path[i] == '.' {
      if i == n - 1 {
        return ""
      }
      return path[i + 1:].to_owned().to_lower()
    }
    i = i - 1
  }
  ""
}
