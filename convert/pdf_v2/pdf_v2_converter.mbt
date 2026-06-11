///|
fn pdf_v2_dispatcher_pipeline_options() -> PdfV2ConvertPipelineOptions {
  {
    ..default_pdf_v2_convert_pipeline_options(),
    run_gate: false,
    lowering_options: {
      ..default_pdf_v2_fact_lowering_options(),
      respect_gate_decisions: false,
    },
  }
}

///|
pub fn parse_pdf_v2(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> Result[@cor.Document, @cor.AppError] {
  let pipeline_result = convert_pdf_v2_experimental_from_path(
    input_path,
    pdf_v2_dispatcher_pipeline_options(),
  )
  pdf_v2_pipeline_result_to_document(pipeline_result, {
    ..default_pdf_v2_product_bridge_options(),
    source_name: Some(@cor.basename(input_path)),
  })
}
