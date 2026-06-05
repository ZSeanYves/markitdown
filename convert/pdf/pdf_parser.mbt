///|
/// PDF converter orchestration pipeline:
/// event/model extraction -> line staging -> block staging -> classify -> noise filter -> merge -> unified IR.
///
/// Layering intent:
/// - keep each stage locally explainable and testable
/// - allow conservative rollback/downgrade in intermediate stages
/// - keep future OCR intent explicit and fail closed in the current build
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

  let backend_started = pdf_convert_profile_stage_start(profile)
  let ocr_mode = parse_pdf_ocr_mode(enhance_mode)
  match backend_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(
        profile,
        "pdf_backend_select",
        started,
        Some("ocr_mode=" + pdf_ocr_mode_name(ocr_mode)),
      )
    None => ()
  }

  if ocr_mode != PdfOcrMode::Disabled {
    raise @cor.AppError(
      "PDF OCR is not wired in this build. Image OCR is planned for future main-CLI `--ocr` / `--no-ocr` controls; PDF OCR will require an explicit PDF OCR provider.",
    )
  }

  let extract_started = pdf_convert_profile_stage_start(profile)
  let core_doc = extract_pdf_document_model(input_path)
  match extract_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(
        profile,
        "pdf_extract_model",
        started,
        Some(
          "text_pdf_only=true ocr_excluded=true pages=" +
          core_doc.pages.length().to_string(),
        ),
      )
    None => ()
  }

  let lines_started = pdf_convert_profile_stage_start(profile)
  let doc0 = build_convert_lines(core_doc, _out_dir)
  match lines_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(
        profile,
        "pdf_line_build",
        started,
        Some("pages=" + doc0.pages.length().to_string()),
      )
    None => ()
  }
  let blocks_started = pdf_convert_profile_stage_start(profile)
  let doc1 = build_convert_blocks(doc0)
  match blocks_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(
        profile,
        "pdf_block_build",
        started,
        Some("pages=" + doc1.pages.length().to_string()),
      )
    None => ()
  }

  let classify_started = pdf_convert_profile_stage_start(profile)
  let doc2 = classify_convert_blocks(doc1, max_heading)
  match classify_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(
        profile,
        "pdf_block_classify",
        started,
        Some("max_heading=" + max_heading.to_string()),
      )
    None => ()
  }
  let gate_started = pdf_convert_profile_stage_start(profile)
  let gate_cfg = default_pdf_layout_gate_config()
  let doc2g = apply_pdf_layout_gate(doc2, config=gate_cfg)
  match gate_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(
        profile,
        "pdf_layout_gate",
        started,
        Some("enabled=" + gate_cfg.enabled.to_string()),
      )
    None => ()
  }
  let filter_started = pdf_convert_profile_stage_start(profile)
  let doc3 = filter_noise_blocks(doc2g)
  match filter_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(
        profile,
        "pdf_noise_filter",
        started,
        None,
      )
    None => ()
  }
  let merge_started = pdf_convert_profile_stage_start(profile)
  let doc4 = merge_convert_blocks(doc3)
  match merge_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(profile, "pdf_merge", started, None)
    None => ()
  }
  let annotation_started = pdf_convert_profile_stage_start(profile)
  let doc5 = attach_high_confidence_uri_links(doc4)
  match annotation_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(
        profile,
        "pdf_annotation_handling",
        started,
        Some("high_confidence_uri_attach=true"),
      )
    None => ()
  }

  let src = @cor.basename(input_path)
  let ir_started = pdf_convert_profile_stage_start(profile)
  let out = convert_pdf_blocks_to_ir(doc5, max_heading, src)
  append_pdf_outlines_to_ir(out, core_doc.outlines, src)
  match ir_started {
    Some(started) =>
      pdf_convert_profile_add_stage_since(
        profile,
        "pdf_final_block_build",
        started,
        Some("blocks=" + out.blocks.val.length().to_string()),
      )
    None => ()
  }
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
