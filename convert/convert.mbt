///|
/// Convert one input through the canonical product path and return only the
/// end-user result payload.
pub fn convert_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[ConvertResult, ConvertError] {
  match convert_input_with_provenance(source, options) {
    Ok(execution) => Ok(execution.result)
    Err(err) => Err(err)
  }
}

///|
/// Resolve routing without fully executing conversion.
pub fn plan_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[RoutePlan, ConvertError] {
  match detect_and_resolve_execution_plan(source, options) {
    Ok((_effective_source, _detected, execution_plan)) =>
      Ok(route_plan_from_execution_plan(execution_plan))
    Err(err) => Err(err)
  }
}

///|
/// Convert one input and return both the result payload and execution
/// provenance.
pub fn convert_input_with_provenance(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[ConvertExecution, ConvertError] {
  convert_input_with_provenance_and_image_ocr_provider(
    source, options, @focr.run_ocr_provider,
  )
}

///|
/// Convert one input with an injected image OCR provider while preserving full
/// provenance.
pub fn convert_input_with_provenance_and_image_ocr_provider(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertExecution, ConvertError] {
  convert_input_with_image_ocr_provider_and_provenance(
    source, options, image_ocr_provider,
  )
}

///|
/// Convert one input with injected image OCR and PDF rasterizer boundaries
/// while preserving full provenance.
pub fn convert_input_with_provenance_and_image_ocr_provider_and_pdf_rasterizer(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
  pdf_rasterizer : (@input.InputSource) -> Result[
    (@fpdf.PdfRasterResult, String),
    @fpdf.PdfRasterizerError,
  ],
) -> Result[ConvertExecution, ConvertError] {
  convert_input_with_image_ocr_provider_and_pdf_rasterizer_and_provenance(
    source, options, image_ocr_provider, pdf_rasterizer,
  )
}

///|
/// Convert one input with an injected image OCR provider and return only the
/// end-user result payload.
pub fn convert_input_with_image_ocr_provider(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertResult, ConvertError] {
  match
    convert_input_with_provenance_and_image_ocr_provider(
      source, options, image_ocr_provider,
    ) {
    Ok(execution) => Ok(execution.result)
    Err(err) => Err(err)
  }
}
