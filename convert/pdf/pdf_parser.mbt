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
  _pipeline_debug : Bool,
) -> @cor.Document {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("pdf: file not found: " + input_path)
  }

  let profile = if pdf_convert_profile_enabled() {
    Some(new_pdf_convert_profile_report(input_path))
  } else {
    None
  }
  pdf_convert_profile_set_active(profile)
  defer {
    maybe_write_pdf_convert_profile_log(profile)
    pdf_convert_profile_set_active(None)
  }

  let backend_started = @env.now()
  let ocr_mode = parse_pdf_ocr_mode(enhance_mode)
  pdf_convert_profile_add_stage(
    profile,
    "pdf_backend_select",
    @env.now() - backend_started,
    Some("ocr_mode=" + pdf_ocr_mode_name(ocr_mode)),
  )

  if ocr_mode != PdfOcrMode::Disabled {
    raise @cor.AppError(
      "pdf OCR mode moved to ocr; use the explicit OCR runner instead of the normal cli binary",
    )
  }

  let extract_started = @env.now()
  let core_doc = extract_pdf_document_model(input_path)
  pdf_convert_profile_add_stage(
    profile,
    "pdf_extract_model",
    @env.now() - extract_started,
    Some(
      "text_pdf_only=true ocr_excluded=true pages=" +
      core_doc.pages.length().to_string(),
    ),
  )

  let lines_started = @env.now()
  let doc0 = build_convert_lines(core_doc, _out_dir)
  pdf_convert_profile_add_stage(
    profile,
    "pdf_line_build",
    @env.now() - lines_started,
    Some("pages=" + doc0.pages.length().to_string()),
  )
  let blocks_started = @env.now()
  let doc1 = build_convert_blocks(doc0)
  pdf_convert_profile_add_stage(
    profile,
    "pdf_block_build",
    @env.now() - blocks_started,
    Some("pages=" + doc1.pages.length().to_string()),
  )

  let classify_started = @env.now()
  let doc2 = classify_convert_blocks(doc1, max_heading)
  pdf_convert_profile_add_stage(
    profile,
    "pdf_block_classify",
    @env.now() - classify_started,
    Some("max_heading=" + max_heading.to_string()),
  )
  let filter_started = @env.now()
  let doc3 = filter_noise_blocks(doc2)
  pdf_convert_profile_add_stage(
    profile,
    "pdf_noise_filter",
    @env.now() - filter_started,
    None,
  )
  let merge_started = @env.now()
  let doc4 = merge_convert_blocks(doc3)
  pdf_convert_profile_add_stage(
    profile,
    "pdf_merge",
    @env.now() - merge_started,
    None,
  )
  let annotation_started = @env.now()
  let doc5 = attach_high_confidence_uri_links(doc4)
  pdf_convert_profile_add_stage(
    profile,
    "pdf_annotation_handling",
    @env.now() - annotation_started,
    Some("high_confidence_uri_attach=true"),
  )

  let src = @cor.basename(input_path)
  let ir_started = @env.now()
  let out = convert_pdf_blocks_to_ir(doc5, max_heading, src)
  append_pdf_outlines_to_ir(out, core_doc.outlines, src)
  pdf_convert_profile_add_stage(
    profile,
    "pdf_final_block_build",
    @env.now() - ir_started,
    Some("blocks=" + out.blocks.val.length().to_string()),
  )
  out
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
fn pdf_ocr_mode_name(mode : PdfOcrMode) -> String {
  match mode {
    PdfOcrMode::Disabled => "disabled"
    PdfOcrMode::AutoFallback => "auto_fallback"
    PdfOcrMode::Force => "force"
  }
}
