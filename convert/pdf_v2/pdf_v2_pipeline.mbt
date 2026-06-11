///|
pub(all) struct PdfV2ConvertPipelineOptions {
  parser_options : @pdfv2.PdfV2CoreOpenOptions
  gate_options : PdfV2NoModelGateOptions
  lowering_options : PdfV2FactLoweringOptions
  run_gate : Bool
}

///|
pub(all) struct PdfV2ConvertModelSummary {
  page_count : Int
  source_event_count : Int
  block_count : Int
  line_count : Int
  span_count : Int
  char_count : Int
  unsupported_capability_count : Int
  partial_fact_count : Int
  warning_count : Int
  risk_count : Int
}

///|
pub(all) struct PdfV2ConvertPipelineOutput {
  source_summary : @pdfv2.PdfV2SourceSummary
  model_summary : PdfV2ConvertModelSummary
  layout_summary : @pdfv2.PdfV2LayoutFactSummary
  feature_summary : @pdfv2.PdfV2FeatureSummary
  gate_summary : PdfV2GateSummary?
  lowering_summary : PdfV2FactLoweringSummary
  fragments : Array[PdfV2FactFragment]
  text_flow_candidates : Array[@pdfv2.PdfV2TextFlowCandidate]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  one_pass : Bool
  no_fallback : Bool
}

///|
pub(all) struct PdfV2ConvertPipelineFailure {
  stage : String
  message : String
  fragments : Array[PdfV2FactFragment]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  one_pass : Bool
  no_fallback : Bool
}

///|
pub(all) enum PdfV2ConvertPipelineResult {
  ConvertPipelineOk(PdfV2ConvertPipelineOutput)
  ConvertPipelineErr(PdfV2ConvertPipelineFailure)
}

///|
pub fn default_pdf_v2_convert_pipeline_options() -> PdfV2ConvertPipelineOptions {
  {
    parser_options: @pdfv2.default_pdf_v2_core_open_options(),
    gate_options: default_pdf_v2_no_model_gate_options(),
    lowering_options: {
      ..default_pdf_v2_fact_lowering_options(),
      respect_gate_decisions: true,
    },
    run_gate: true,
  }
}

///|
fn pdf_v2_convert_pipeline_model_summary(
  model : @pdfv2.PdfV2DocumentModel,
) -> PdfV2ConvertModelSummary {
  let mut block_count = 0
  let mut line_count = 0
  let mut span_count = 0
  let mut char_count = 0
  for page in model.pages {
    block_count = block_count + page.blocks.length()
    line_count = line_count + page.lines.length()
    span_count = span_count + page.spans.length()
    char_count = char_count + page.chars.length()
  }
  {
    page_count: model.page_count,
    source_event_count: model.source_events.length(),
    block_count,
    line_count,
    span_count,
    char_count,
    unsupported_capability_count: model.unsupported_capabilities.length(),
    partial_fact_count: model.partial_fact_reports.length(),
    warning_count: model.warnings.length(),
    risk_count: model.risks.length(),
  }
}

///|
fn pdf_v2_convert_pipeline_failure(
  stage : String,
  message : String,
  warnings : Array[@pdfv2.PdfV2Warning],
  risks : Array[@pdfv2.PdfV2Risk],
) -> PdfV2ConvertPipelineResult {
  PdfV2ConvertPipelineResult::ConvertPipelineErr({
    stage,
    message,
    fragments: [],
    warnings,
    risks,
    one_pass: true,
    no_fallback: true,
  })
}

///|
fn pdf_v2_convert_pipeline_gate_result(
  features : @pdfv2.PdfV2FeatureSet,
  options : PdfV2ConvertPipelineOptions,
) -> PdfV2GateResult? {
  if options.run_gate {
    Some(pdf_v2_run_no_model_block_gate(features, options.gate_options))
  } else {
    None
  }
}

///|
pub fn convert_pdf_v2_experimental_from_path(
  path : String,
  options : PdfV2ConvertPipelineOptions,
) -> PdfV2ConvertPipelineResult {
  match @pdfv2.parse_pdf_v2_model_from_path(path, options.parser_options) {
    @pdfv2.ModelAssemblyOk(model) => {
      let model_summary = pdf_v2_convert_pipeline_model_summary(model)
      let layout = @pdfv2.pdf_v2_layout_facts_from_model(model)
      let features = @pdfv2.pdf_v2_features_from_model_and_layout(model, layout)
      let gate_result = pdf_v2_convert_pipeline_gate_result(features, options)
      let lowered = pdf_v2_lower_fact_model(
        pdf_v2_fact_lowering_input_with_gate(
          model,
          Some(features),
          gate_result,
          options.lowering_options,
        ),
      )
      let gate_summary = match gate_result {
        Some(gate) => Some(gate.summary)
        None => None
      }
      PdfV2ConvertPipelineResult::ConvertPipelineOk({
        source_summary: model.source_summary,
        model_summary,
        layout_summary: layout.summary,
        feature_summary: features.summary,
        gate_summary,
        lowering_summary: lowered.summary,
        fragments: lowered.fragments,
        text_flow_candidates: lowered.text_flow_candidates,
        warnings: lowered.warnings,
        risks: lowered.risks,
        one_pass: model.one_pass &&
        layout.one_pass &&
        features.one_pass &&
        lowered.one_pass,
        no_fallback: model.no_fallback &&
        layout.no_fallback &&
        features.no_fallback &&
        lowered.no_fallback,
      })
    }
    @pdfv2.ModelAssemblyErr(warnings, risks, message) =>
      pdf_v2_convert_pipeline_failure(
        "parse_pdf_v2_model_from_path", message, warnings, risks,
      )
  }
}
