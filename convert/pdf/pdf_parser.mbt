///|
/// PDF converter orchestration pipeline:
/// event/model extraction -> line staging -> block staging -> classify -> noise filter -> merge -> unified IR.
///
/// Layering intent:
/// - keep each stage locally explainable and testable
/// - allow conservative rollback/downgrade in intermediate stages
/// - isolate OCR path as an explicit alternative pipeline
pub async fn parse_pdf(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
  enhance_mode : String?,
  _extract_debug : Bool,
  _dump_selected_raw : Bool,
  pipeline_debug : Bool,
) -> @cor.Document {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("pdf: file not found: " + input_path)
  }

  let ocr_mode = parse_pdf_ocr_mode(enhance_mode)

  // Force mode is an explicit user decision: bypass native extraction entirely.
  if ocr_mode == PdfOcrMode::Force {
    return @ocr.parse_pdf_via_ocr(
      input_path, _out_dir, max_heading, pipeline_debug,
    )
  }

  if pipeline_debug {
    let cfg = @api.default_pdf_core_config()
    match @api.extract_document_block_debug(input_path, cfg) {
      Ok(s) => println(s)
      Err(e) => println("pdf_core/debug error: " + e.to_string())
    }
  }

  let core_doc = extract_pdf_core_document(input_path)

  // AutoFallback is conservative degradation: only fallback when native result
  // is effectively empty, to avoid mixing two extraction semantics by default.
  if ocr_mode == PdfOcrMode::AutoFallback &&
    is_effectively_empty_core_doc(core_doc) {
    return @ocr.parse_pdf_via_ocr(
      input_path, _out_dir, max_heading, pipeline_debug,
    )
  }

  let doc0 = build_convert_lines(core_doc, _out_dir)
  let doc1 = build_convert_blocks(doc0)

  if pipeline_debug {
    println(debug_convert_document_summary(doc1))

    for page in doc1.pages {
      debug_print_convert_lines(page)
      debug_print_convert_images(page)
      debug_print_convert_annotations(page)
      debug_print_convert_blocks(page)
    }

    debug_print_page_edge_blocks(doc1)
    debug_print_repeated_edge_texts(doc1)
    debug_print_header_footer_like_blocks(doc1)
  }

  let doc2 = classify_convert_blocks(doc1, max_heading)
  let doc3 = filter_noise_blocks(doc2)
  let doc4 = merge_convert_blocks(doc3)
  let doc5 = attach_high_confidence_uri_links(doc4)

  if pipeline_debug {
    println(debug_convert_document_summary(doc5))
  }

  let src = @cor.basename(input_path)
  convert_pdf_blocks_to_ir(doc5, max_heading, src)
}

///|
priv enum PdfOcrMode {
  Disabled
  AutoFallback
  Force
} derive(Eq)

///|
fn parse_pdf_ocr_mode(mode : String?) -> PdfOcrMode {
  match mode {
    None => PdfOcrMode::Disabled
    Some(raw) => {
      let m = raw.trim().to_lower()
      if m == "ocr" {
        PdfOcrMode::Force
      } else if m == "ocr-auto" || m == "auto-ocr" {
        PdfOcrMode::AutoFallback
      } else {
        PdfOcrMode::Disabled
      }
    }
  }
}

///|
/// 判断 native pdf_core 结果是否几乎没有可用文本。
fn is_effectively_empty_core_doc(doc : @model.PdfDocumentModel) -> Bool {
  let mut signal_chars = 0

  for page in doc.pages {
    for block in page.text_blocks {
      let t = @model.block_text(block).trim().to_owned()
      if t == "" {
        continue
      }

      for ch in t.to_array() {
        if ch != ' ' && ch != '\t' && ch != '\n' && ch != '\r' {
          signal_chars = signal_chars + 1
          if signal_chars >= 24 {
            return false
          }
        }
      }
    }
  }

  true
}
