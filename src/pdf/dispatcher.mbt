///|
pub(all) struct ConvertOptions {
  out_dir : String?
  max_heading : Int?
}

///|
pub async fn parse_to_ir(
  input_path : String,
  opts : ConvertOptions,
) -> Result[@cor.Document, @cor.AppError] raise {
  let ext = file_ext_lower(input_path)

  let out_dir_str = match opts.out_dir {
    None => ""
    Some(dir) => dir
  }
  let max_h = opts.max_heading.unwrap_or(6)

  match ext {
    "docx" => Ok(@doc.parse_docx(input_path, out_dir_str, max_h))
    "pdf" => parse_pdf(input_path, PdfParseOptions::{ out_dir: opts.out_dir })
    _ => Err(@cor.AppError("Unsupported file type: " + ext))
  }
}

///|
fn file_ext_lower(path : String) -> String raise {
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
      return path[i + 1:].to_string().to_lower()
    }
    i = i - 1
  }
  ""
}
