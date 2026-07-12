///|
pub fn pdf_ocr_parser_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  image_ocr_provider? : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ] = @focr.run_ocr_provider,
  rasterizer? : (@input.InputSource) -> Result[
    (PdfRasterResult, String),
    PdfRasterizerError,
  ] = rasterize_pdf_with_pdftoppm_default,
) -> Result[@parser.ParseResult, String] {
  let config = match pdf_ocr_execution_config(source, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let native_document_result = extract_pdf_native_document(source)
  let native_document = match native_document_result {
    Ok(value) => Some(value)
    Err(PdfNativeError::EmptyTextLayer(_)) => None
    Err(error) =>
      return Err(
        pdf_native_enabled_error_diagnostics(source, context, error).errors[0],
      )
  }
  let native_document_ir = match native_document {
    Some(value) =>
      pdf_native_document_to_ir_with_policies(
        value,
        context.pdf_header_footer_filter_policy,
        context.pdf_table_reconstruction_policy,
      )
    None => @core.empty_document_ir()
  }
  let native_page_routes = match native_document {
    Some(value) => pdf_page_routes_from_native_document(value)
    None => []
  }
  let mut needs_raster = match native_document {
    Some(_) => false
    None => true
  }
  if !needs_raster {
    needs_raster = native_page_routes.any(route => {
      pdf_page_route_uses_ocr(route)
    })
  }
  let pdf_raster_wall_ms : Ref[UInt64] = { val: 0 }
  let rasterized = if needs_raster {
    let started = @env.now()
    match rasterizer(source) {
      Ok(value) => {
        pdf_raster_wall_ms.val = @env.now() - started
        Some(value)
      }
      Err(error) => return Err(pdf_raster_provider_error_message(error))
    }
  } else {
    None
  }
  let raster_result = match rasterized {
    Some(value) => value.0
    None =>
      {
        backend_name: "pdftoppm",
        page_count: match native_document {
          Some(value) => value.pages.length()
          None => 0
        },
        pages: [],
        diagnostics: [],
      }
  }
  let temp_dir = match rasterized {
    Some(value) => value.1
    None => ""
  }
  let raster_invoked = needs_raster
  defer (if raster_invoked { cleanup_pdf_ocr_temp_dir(temp_dir) })
  let page_routes = if native_page_routes.length() > 0 {
    native_page_routes
  } else {
    pdf_page_routes_from_raster_result(raster_result)
  }
  let ocr_page_numbers = page_routes
    .filter(pdf_page_route_uses_ocr)
    .map(route => route.page_index)
  let state = pdf_ocr_accumulation_state()
  state.native_text_page_count.val = pdf_page_route_native_output_count(
    page_routes,
  )
  let ocr_image_paths : Array[String] = []
  let page_image_paths : Map[Int, String] = Map([])
  let ocr_blocks_by_page : Map[Int, Array[@core.CoreBlock]] = Map([])
  let ocr_provider_wall_ms : Ref[UInt64] = { val: 0 }
  let ocr_process_invocation_count : Ref[Int] = { val: 0 }
  let ocr_batch_job_count : Ref[Int] = { val: 0 }
  let raster_page_success_count : Ref[Int] = { val: 0 }
  let provider_name : Ref[String?] = { val: None }
  let provider_version : Ref[String?] = { val: None }
  if needs_raster {
    for page in raster_result.pages {
      let page_index = page.page_index + 1
      if !ocr_page_numbers.contains(page_index) {
        continue
      }
      if !page.success {
        pdf_ocr_record_raster_failure(
          state,
          "pdf_raster_page_failed:index=" + page_index.to_string(),
        )
        continue
      }
      let image_path = match page.image_path {
        Some(path) => pdf_runtime_absolute_path(path)
        None => {
          pdf_ocr_record_raster_failure(
            state,
            "pdf_raster_page_missing_image:index=" + page_index.to_string(),
          )
          continue
        }
      }
      page_image_paths.set(page_index, image_path)
      raster_page_success_count.val = raster_page_success_count.val + 1
      ocr_image_paths.push(image_path)
    }
    if ocr_image_paths.length() > 0 {
      ocr_process_invocation_count.val = 1
      ocr_batch_job_count.val = ocr_image_paths.length()
      let request = pdf_ocr_provider_batch_request(
        ocr_image_paths,
        config.provider_kind,
        context.ocr_options.language,
      )
      let started = @env.now()
      match image_ocr_provider(request) {
        Ok(result) => {
          ocr_provider_wall_ms.val = @env.now() - started
          provider_name.val = Some(result.provider_name)
          provider_version.val = result.provider_version
          for job in result.jobs {
            let page_number = match
              pdf_page_number_for_image_path(page_image_paths, job.image_path) {
              Some(value) => value
              None => {
                state.ocr_failure_count.val = state.ocr_failure_count.val + 1
                state.warnings.push(
                  "pdf_ocr_page_failed:index=unknown provider=" +
                  @focr.ocr_provider_kind_name(config.provider_kind) +
                  " reason=unmapped image path",
                )
                continue
              }
            }
            if job.status == "ok" {
              let job_blocks : Array[@core.CoreBlock] = []
              for model in job.pages {
                let model_blocks = @focr.ocr_page_blocks_from_page(
                  source,
                  @input.DetectedFormat::Pdf,
                  page_number,
                  model,
                )
                let scaled_blocks = match
                  pdf_native_page_geometry_for_index(
                    native_document, page_number,
                  ) {
                  Some(geometry) =>
                    pdf_scale_ocr_blocks_to_pdf_geometry(
                      model_blocks, model, geometry,
                    )
                  None => model_blocks
                }
                job_blocks.append(scaled_blocks[:])
              }
              ocr_blocks_by_page.set(page_number, job_blocks)
              state.ocr_success_count.val = state.ocr_success_count.val + 1
            } else if job.status == "empty" {
              pdf_ocr_record_empty_provider_result(state, page_number)
            } else {
              state.ocr_failure_count.val = state.ocr_failure_count.val + 1
              state.warnings.push(
                "pdf_ocr_page_failed:index=" +
                page_number.to_string() +
                " provider=" +
                @focr.ocr_provider_kind_name(config.provider_kind) +
                " reason=" +
                job.error_message.unwrap_or("unknown error"),
              )
            }
          }
        }
        Err(error) =>
          return Err(
            pdf_native_parser_error_message(
              pdf_native_enabled_error_diagnostics(
                source,
                context,
                PdfNativeError::ParseFailed(error.to_string()),
              ),
            ),
          )
      }
    }
  }
  for route in page_routes {
    let native_blocks = pdf_blocks_for_page(
      native_document_ir.blocks,
      route.page_index,
    )
    if route.route_kind == "native_text_page" {
      state.blocks.append(native_blocks[:])
    } else if route.route_kind == "hybrid_region_page" {
      match ocr_blocks_by_page.get(route.page_index) {
        Some(blocks) =>
          state.blocks.append(
            pdf_region_hybrid_page_blocks(native_blocks, blocks, route)[:],
          )
        None => state.blocks.append(native_blocks[:])
      }
    } else {
      match ocr_blocks_by_page.get(route.page_index) {
        Some(blocks) =>
          state.blocks.append(
            pdf_ocr_page_blocks_with_native_facts(native_blocks, blocks)[:],
          )
        None => ()
      }
    }
  }
  let external_process_kinds : Array[String] = []
  if raster_invoked {
    external_process_kinds.push(raster_result.backend_name)
  }
  if ocr_process_invocation_count.val > 0 {
    external_process_kinds.push(
      provider_name.val.unwrap_or(
        @focr.ocr_provider_kind_name(config.provider_kind),
      ),
    )
  }
  let stats : PdfOcrExecutionStats = {
    page_count: page_routes.length(),
    native_page_count: pdf_page_route_native_output_count(page_routes),
    native_detected_page_count: pdf_page_route_native_detected_count(
      page_routes,
    ),
    ocr_page_count: pdf_page_route_ocr_page_count(page_routes),
    hybrid_region_page_count: pdf_page_route_hybrid_region_count(page_routes),
    region_hybrid_candidate_count: pdf_page_route_total_candidate_count(
      page_routes,
    ),
    native_low_confidence_text_count: pdf_page_route_total_low_confidence_count(
      page_routes,
    ),
    raster_invoked,
    rasterized_page_count: if raster_invoked {
      raster_result.pages.length()
    } else {
      0
    },
    raster_page_success_count: raster_page_success_count.val,
    ocr_batch_job_count: ocr_batch_job_count.val,
    ocr_process_invocation_count: ocr_process_invocation_count.val,
    ocr_batch_mode: ocr_process_invocation_count.val > 0,
    page_route_hybrid_used: pdf_page_route_hybrid_used(page_routes),
    page_route_summary: pdf_page_route_summary(page_routes),
    provider_name: provider_name.val,
    provider_version: provider_version.val,
    pdf_raster_wall_ms: pdf_raster_wall_ms.val,
    ocr_provider_wall_ms: ocr_provider_wall_ms.val,
    external_process_invocation_count: (if raster_invoked { 1 } else { 0 }) +
    ocr_process_invocation_count.val,
    external_process_kind: if external_process_kinds.length() == 0 {
      "none"
    } else {
      external_process_kinds.join(",")
    },
    external_process_wall_ms: pdf_raster_wall_ms.val + ocr_provider_wall_ms.val,
  }
  pdf_ocr_finalize_result(
    source, context, config, native_document_ir, raster_result, state, stats,
  )
}

///|
pub async fn pdf_ocr_parser_result_async(
  source : @input.InputSource,
  context : @parser.ParseContext,
  image_ocr_provider? : async (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ] = @focr.run_ocr_provider_async,
  rasterizer? : async (@input.InputSource) -> Result[
    (PdfRasterResult, String),
    PdfRasterizerError,
  ] = rasterize_pdf_with_pdftoppm_default_async,
) -> Result[@parser.ParseResult, String] {
  let config = match pdf_ocr_execution_config(source, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let native_document_result = extract_pdf_native_document(source)
  let native_document = match native_document_result {
    Ok(value) => Some(value)
    Err(PdfNativeError::EmptyTextLayer(_)) => None
    Err(error) =>
      return Err(
        pdf_native_enabled_error_diagnostics(source, context, error).errors[0],
      )
  }
  let native_document_ir = match native_document {
    Some(value) =>
      pdf_native_document_to_ir_with_policies(
        value,
        context.pdf_header_footer_filter_policy,
        context.pdf_table_reconstruction_policy,
      )
    None => @core.empty_document_ir()
  }
  let native_page_routes = match native_document {
    Some(value) => pdf_page_routes_from_native_document(value)
    None => []
  }
  let mut needs_raster = match native_document {
    Some(_) => false
    None => true
  }
  if !needs_raster {
    needs_raster = native_page_routes.any(route => {
      pdf_page_route_uses_ocr(route)
    })
  }
  let pdf_raster_wall_ms : Ref[UInt64] = { val: 0 }
  let rasterized = if needs_raster {
    let started = @env.now()
    match rasterizer(source) {
      Ok(value) => {
        pdf_raster_wall_ms.val = @env.now() - started
        Some(value)
      }
      Err(error) => return Err(pdf_raster_provider_error_message(error))
    }
  } else {
    None
  }
  let raster_result = match rasterized {
    Some(value) => value.0
    None =>
      {
        backend_name: "pdftoppm",
        page_count: match native_document {
          Some(value) => value.pages.length()
          None => 0
        },
        pages: [],
        diagnostics: [],
      }
  }
  let temp_dir = match rasterized {
    Some(value) => value.1
    None => ""
  }
  let raster_invoked = needs_raster
  let page_routes = if native_page_routes.length() > 0 {
    native_page_routes
  } else {
    pdf_page_routes_from_raster_result(raster_result)
  }
  let ocr_page_numbers = page_routes
    .filter(pdf_page_route_uses_ocr)
    .map(route => route.page_index)
  let state = pdf_ocr_accumulation_state()
  state.native_text_page_count.val = pdf_page_route_native_output_count(
    page_routes,
  )
  let ocr_image_paths : Array[String] = []
  let page_image_paths : Map[Int, String] = Map([])
  let ocr_blocks_by_page : Map[Int, Array[@core.CoreBlock]] = Map([])
  let ocr_provider_wall_ms : Ref[UInt64] = { val: 0 }
  let ocr_process_invocation_count : Ref[Int] = { val: 0 }
  let ocr_batch_job_count : Ref[Int] = { val: 0 }
  let raster_page_success_count : Ref[Int] = { val: 0 }
  let provider_name : Ref[String?] = { val: None }
  let provider_version : Ref[String?] = { val: None }
  if needs_raster {
    for page in raster_result.pages {
      let page_index = page.page_index + 1
      if !ocr_page_numbers.contains(page_index) {
        continue
      }
      if !page.success {
        pdf_ocr_record_raster_failure(
          state,
          "pdf_raster_page_failed:index=" + page_index.to_string(),
        )
        continue
      }
      let image_path = match page.image_path {
        Some(path) => pdf_runtime_absolute_path(path)
        None => {
          pdf_ocr_record_raster_failure(
            state,
            "pdf_raster_page_missing_image:index=" + page_index.to_string(),
          )
          continue
        }
      }
      page_image_paths.set(page_index, image_path)
      raster_page_success_count.val = raster_page_success_count.val + 1
      ocr_image_paths.push(image_path)
    }
    if ocr_image_paths.length() > 0 {
      ocr_process_invocation_count.val = 1
      ocr_batch_job_count.val = ocr_image_paths.length()
      let request = pdf_ocr_provider_batch_request(
        ocr_image_paths,
        config.provider_kind,
        context.ocr_options.language,
      )
      let started = @env.now()
      match image_ocr_provider(request) {
        Ok(result) => {
          ocr_provider_wall_ms.val = @env.now() - started
          provider_name.val = Some(result.provider_name)
          provider_version.val = result.provider_version
          for job in result.jobs {
            let page_number = match
              pdf_page_number_for_image_path(page_image_paths, job.image_path) {
              Some(value) => value
              None => {
                state.ocr_failure_count.val = state.ocr_failure_count.val + 1
                state.warnings.push(
                  "pdf_ocr_page_failed:index=unknown provider=" +
                  @focr.ocr_provider_kind_name(config.provider_kind) +
                  " reason=unmapped image path",
                )
                continue
              }
            }
            if job.status == "ok" {
              let job_blocks : Array[@core.CoreBlock] = []
              for model in job.pages {
                let model_blocks = @focr.ocr_page_blocks_from_page(
                  source,
                  @input.DetectedFormat::Pdf,
                  page_number,
                  model,
                )
                let scaled_blocks = match
                  pdf_native_page_geometry_for_index(
                    native_document, page_number,
                  ) {
                  Some(geometry) =>
                    pdf_scale_ocr_blocks_to_pdf_geometry(
                      model_blocks, model, geometry,
                    )
                  None => model_blocks
                }
                job_blocks.append(scaled_blocks[:])
              }
              ocr_blocks_by_page.set(page_number, job_blocks)
              state.ocr_success_count.val = state.ocr_success_count.val + 1
            } else if job.status == "empty" {
              pdf_ocr_record_empty_provider_result(state, page_number)
            } else {
              state.ocr_failure_count.val = state.ocr_failure_count.val + 1
              state.warnings.push(
                "pdf_ocr_page_failed:index=" +
                page_number.to_string() +
                " provider=" +
                @focr.ocr_provider_kind_name(config.provider_kind) +
                " reason=" +
                job.error_message.unwrap_or("unknown error"),
              )
            }
          }
        }
        Err(error) => {
          if raster_invoked {
            pdf_ocr_cleanup_temp_dir_async(temp_dir)
          }
          return Err(
            pdf_native_parser_error_message(
              pdf_native_enabled_error_diagnostics(
                source,
                context,
                PdfNativeError::ParseFailed(error.to_string()),
              ),
            ),
          )
        }
      }
    }
  }
  for route in page_routes {
    let native_blocks = pdf_blocks_for_page(
      native_document_ir.blocks,
      route.page_index,
    )
    if route.route_kind == "native_text_page" {
      state.blocks.append(native_blocks[:])
    } else if route.route_kind == "hybrid_region_page" {
      match ocr_blocks_by_page.get(route.page_index) {
        Some(blocks) =>
          state.blocks.append(
            pdf_region_hybrid_page_blocks(native_blocks, blocks, route)[:],
          )
        None => state.blocks.append(native_blocks[:])
      }
    } else {
      match ocr_blocks_by_page.get(route.page_index) {
        Some(blocks) =>
          state.blocks.append(
            pdf_ocr_page_blocks_with_native_facts(native_blocks, blocks)[:],
          )
        None => ()
      }
    }
  }
  let external_process_kinds : Array[String] = []
  if raster_invoked {
    external_process_kinds.push(raster_result.backend_name)
  }
  if ocr_process_invocation_count.val > 0 {
    external_process_kinds.push(
      provider_name.val.unwrap_or(
        @focr.ocr_provider_kind_name(config.provider_kind),
      ),
    )
  }
  let stats : PdfOcrExecutionStats = {
    page_count: page_routes.length(),
    native_page_count: pdf_page_route_native_output_count(page_routes),
    native_detected_page_count: pdf_page_route_native_detected_count(
      page_routes,
    ),
    ocr_page_count: pdf_page_route_ocr_page_count(page_routes),
    hybrid_region_page_count: pdf_page_route_hybrid_region_count(page_routes),
    region_hybrid_candidate_count: pdf_page_route_total_candidate_count(
      page_routes,
    ),
    native_low_confidence_text_count: pdf_page_route_total_low_confidence_count(
      page_routes,
    ),
    raster_invoked,
    rasterized_page_count: if raster_invoked {
      raster_result.pages.length()
    } else {
      0
    },
    raster_page_success_count: raster_page_success_count.val,
    ocr_batch_job_count: ocr_batch_job_count.val,
    ocr_process_invocation_count: ocr_process_invocation_count.val,
    ocr_batch_mode: ocr_process_invocation_count.val > 0,
    page_route_hybrid_used: pdf_page_route_hybrid_used(page_routes),
    page_route_summary: pdf_page_route_summary(page_routes),
    provider_name: provider_name.val,
    provider_version: provider_version.val,
    pdf_raster_wall_ms: pdf_raster_wall_ms.val,
    ocr_provider_wall_ms: ocr_provider_wall_ms.val,
    external_process_invocation_count: (if raster_invoked { 1 } else { 0 }) +
    ocr_process_invocation_count.val,
    external_process_kind: if external_process_kinds.length() == 0 {
      "none"
    } else {
      external_process_kinds.join(",")
    },
    external_process_wall_ms: pdf_raster_wall_ms.val + ocr_provider_wall_ms.val,
  }
  let result = pdf_ocr_finalize_result(
    source, context, config, native_document_ir, raster_result, state, stats,
  )
  if raster_invoked {
    pdf_ocr_cleanup_temp_dir_async(temp_dir)
  }
  result
}

///|
pub fn pdf_ocr_parser() -> @parser.Parser {
  @parser.make_parser(
    pdf_ocr_parser_name(),
    @parser.ParserMode::LayoutTwoStage,
    pdf_ocr_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      pdf_ocr_parser_result(source, context)
    },
  )
}
