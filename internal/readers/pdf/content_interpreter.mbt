///|
// Owned by one root page /Contents reference, shared by its Form recursion.
// Captured matrices are scalar values; metadata objects and names are borrowed.
priv struct PdfPendingImageDo {
  xobject_name : String
  object : PdfNativeObject
  reservation : @budget.BudgetLease?
  a : Double
  d : Double
  e : Double
  f : Double
}

///|
priv struct PdfPendingImageQueue {
  context : PdfStreamDecodeContext?
  mut entries : Array[PdfPendingImageDo?]
  mut buffer_reservation : @budget.BudgetLease?
}

///|
fn pdf_pending_image_queue(source : @input.InputSource) -> PdfPendingImageQueue {
  {
    context: pdf_make_stream_decode_context(source),
    entries: [],
    buffer_reservation: None,
  }
}

///|
fn pdf_release_pending_images(queue : PdfPendingImageQueue) -> Unit {
  // Removed Array elements remain in unused Native capacity. Drop every live
  // reference, then the entire backing store, before releasing its reservation.
  for index in 0..<queue.entries.length() {
    let reservation = queue.entries[index].map(entry => entry.reservation)
    queue.entries[index] = None
    if reservation is Some(reservation) {
      pdf_release_decode_scratch(reservation)
    }
  }
  queue.entries = []
  pdf_release_decode_scratch(queue.buffer_reservation)
  queue.buffer_reservation = None
}

///|
fn pdf_pending_image_capacity(
  context : PdfStreamDecodeContext?,
  current : Int32,
  required : Int64,
) -> Int32 raise PdfHardDecodeFailure {
  // Native collection indices are Int32. Check in Int64, never allow the SDK
  // growth helper to receive a wrapped required length and abort.
  if required < 0L || required > 2147483647L || current < 0 {
    let message = "PDF pending image queue exceeds Native array capacity"
    if context is Some(context) {
      @input.record_input_failure(context.source, message)
    }
    raise PdfHardDecodeFailure(ParseFailed(message))
  }
  if current.to_int64() >= required {
    return current
  }
  let doubled = if current == 0 { 8L } else { current.to_int64() * 2L }
  (if doubled > 2147483647L { required } else { doubled.max(required) }).to_int()
}

///|
async fn pdf_enqueue_pending_image(
  queue : PdfPendingImageQueue,
  xobject_name : String,
  object : PdfNativeObject,
  matrix : PdfNativeGraphicsMatrix,
) -> Unit {
  pdf_check_stream_live(queue.context)
  let capacity = pdf_pending_image_capacity(
    queue.context,
    queue.entries.capacity(),
    queue.entries.length().to_int64() + 1L,
  )
  // Native64: three reference fields and four Double fields. Headers,
  // allocator/GC and budget bookkeeping are outside this payload model.
  let reservation = pdf_reserve_decode_scratch(queue.context, 56L)
  let published = Ref(false)
  defer (if !published.val { pdf_release_decode_scratch(reservation) })
  if capacity > queue.entries.capacity() {
    // Hold the full new buffer alongside the old buffer until resizing ends.
    // reserve_capacity uses exactly this capacity on the pinned Native SDK.
    let next_buffer = pdf_reserve_decode_scratch(
      queue.context,
      capacity.to_int64() * 8L,
    )
    queue.entries.reserve_capacity(capacity)
    pdf_release_decode_scratch(queue.buffer_reservation)
    queue.buffer_reservation = next_buffer
  }
  // This is post-lex retention admission. Names can escape into final image
  // SourceRef extras, so their UTF16 payload belongs to the InputSession scope,
  // not to the shorter queue lease. The Int32 length times two fits Int64.
  pdf_retain_decoded_payload(
    queue.context,
    xobject_name.length().to_int64() * 2L,
  )
  queue.entries.push(
    Some({
      xobject_name,
      object,
      reservation,
      a: matrix.a,
      d: matrix.d,
      e: matrix.e,
      f: matrix.f,
    }),
  )
  published.val = true
}

///|
async fn pdf_fulfill_pending_images(
  queue : PdfPendingImageQueue,
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  object_index : Map[Int32, PdfNativeObject],
) -> Array[PdfNativeImageCandidate] {
  let candidates : Array[PdfNativeImageCandidate] = []
  for entry in queue.entries {
    if entry is Some(entry) {
      pdf_check_stream_live(queue.context)
      candidates.push(
        pdf_image_candidate_from_xobject(
          source,
          geometry,
          entry.xobject_name,
          entry.object.object_id,
          entry.object,
          object_index,
          { a: entry.a, d: entry.d, e: entry.e, f: entry.f, },
        ),
      )
    }
  }
  candidates
}

///|
async fn pdf_extract_content_fragments_and_images(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  font_aliases : Map[String, Int32],
  fonts : Map[Int32, PdfNativeFontInfo],
  inline_font_ids : Map[String, Int32],
  content_text : String,
  object_index : Map[Int32, PdfNativeObject],
  resources_text : String?,
) -> Result[
  (Array[PdfNativeTextFragment], Array[PdfNativeImageCandidate]),
  PdfNativeError,
] {
  let pending = pdf_pending_image_queue(source)
  defer pdf_release_pending_images(pending)
  let fragments = match
    pdf_interpret_content_stream(
      source,
      geometry,
      font_aliases,
      fonts,
      inline_font_ids,
      content_text,
      object_index~,
      resources_text~,
      pending_images=Some(pending),
      observe_images=true,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  // Preserve the old text-before-images phase for this /Contents reference.
  // No image payload, colorspace, soft mask or globals are read before here.
  let images = pdf_fulfill_pending_images(
    pending, source, geometry, object_index,
  )
  Ok((fragments, images))
}

///|
async fn pdf_interpret_content_stream(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  font_aliases : Map[String, Int32],
  fonts : Map[Int32, PdfNativeFontInfo],
  inline_font_ids : Map[String, Int32],
  content_text : String,
  object_index~ : Map[Int32, PdfNativeObject] = Map([]),
  resources_text~ : String? = None,
  base_matrix~ : PdfNativeGraphicsMatrix = pdf_identity_matrix(),
  remaining_depth~ : Int32 = 6,
  pending_images~ : PdfPendingImageQueue? = None,
  observe_images~ : Bool = false,
) -> Result[Array[PdfNativeTextFragment], PdfNativeError] {
  if remaining_depth <= 0 {
    return Ok([])
  }
  let tokens = match pdf_scan_content_tokens(content_text) {
    Ok(parsed) => parsed
    Err(err) => return Err(err)
  }
  let fragments : Array[PdfNativeTextFragment] = []
  let operands : Array[PdfNativeContentToken] = []
  let graphics_stack : Array[PdfNativeGraphicsMatrix] = []
  let actual_text_stack : Array[String?] = []
  let mut current_matrix = base_matrix
  let mut text_matrix = pdf_identity_matrix()
  let mut text_line_matrix = pdf_identity_matrix()
  let mut text_leading = 0.0
  let mut char_spacing = 0.0
  let mut word_spacing = 0.0
  let mut horizontal_scaling = 1.0
  let mut text_rise = 0.0
  let mut in_text = false
  let mut current_font_alias : String? = None
  let mut current_font_size : Double? = None
  for token in tokens {
    match token {
      Word(op) =>
        match op {
          "q" => {
            graphics_stack.push(current_matrix)
            operands.clear()
          }
          "Q" => {
            current_matrix = graphics_stack.pop().unwrap_or(base_matrix)
            operands.clear()
          }
          "BT" => {
            in_text = true
            text_matrix = pdf_identity_matrix()
            text_line_matrix = pdf_identity_matrix()
            text_leading = 0.0
            char_spacing = 0.0
            word_spacing = 0.0
            horizontal_scaling = 1.0
            text_rise = 0.0
            operands.clear()
          }
          "ET" => {
            in_text = false
            operands.clear()
          }
          "cm" => {
            if operands.length() >= 6 {
              current_matrix = pdf_concat_graphics_matrix(
                current_matrix,
                pdf_matrix_from_operands(operands),
              )
            }
            operands.clear()
          }
          "Tm" => {
            if operands.length() >= 6 {
              text_matrix = pdf_matrix_from_operands(operands)
              text_line_matrix = text_matrix
            }
            operands.clear()
          }
          "Td" => {
            if operands.length() >= 2 {
              let tx = pdf_token_number(operands[operands.length() - 2]).unwrap_or(
                0.0,
              )
              let ty = pdf_token_number(operands[operands.length() - 1]).unwrap_or(
                0.0,
              )
              text_line_matrix = pdf_text_matrix_translated(
                text_line_matrix, tx, ty,
              )
              text_matrix = text_line_matrix
            }
            operands.clear()
          }
          "TD" => {
            if operands.length() >= 2 {
              let tx = pdf_token_number(operands[operands.length() - 2]).unwrap_or(
                0.0,
              )
              let ty = pdf_token_number(operands[operands.length() - 1]).unwrap_or(
                0.0,
              )
              text_leading = 0.0 - ty
              text_line_matrix = pdf_text_matrix_translated(
                text_line_matrix, tx, ty,
              )
              text_matrix = text_line_matrix
            }
            operands.clear()
          }
          "T*" => {
            if in_text {
              text_line_matrix = pdf_text_matrix_translated(
                text_line_matrix,
                0.0,
                0.0 - text_leading,
              )
              text_matrix = text_line_matrix
            }
            operands.clear()
          }
          "TL" => {
            if operands.length() >= 1 {
              text_leading = pdf_token_number(operands[operands.length() - 1]).unwrap_or(
                text_leading,
              )
            }
            operands.clear()
          }
          "Tc" => {
            if operands.length() >= 1 {
              char_spacing = pdf_token_number(operands[operands.length() - 1]).unwrap_or(
                char_spacing,
              )
            }
            operands.clear()
          }
          "Tw" => {
            if operands.length() >= 1 {
              word_spacing = pdf_token_number(operands[operands.length() - 1]).unwrap_or(
                word_spacing,
              )
            }
            operands.clear()
          }
          "Tz" => {
            if operands.length() >= 1 {
              horizontal_scaling = pdf_token_number(
                  operands[operands.length() - 1],
                ).unwrap_or(horizontal_scaling) /
                100.0
            }
            operands.clear()
          }
          "Ts" => {
            if operands.length() >= 1 {
              text_rise = pdf_token_number(operands[operands.length() - 1]).unwrap_or(
                text_rise,
              )
            }
            operands.clear()
          }
          "Tf" => {
            if operands.length() >= 2 {
              current_font_alias = pdf_token_name(
                operands[operands.length() - 2],
              )
              current_font_size = pdf_token_number(
                operands[operands.length() - 1],
              )
            }
            operands.clear()
          }
          "BDC" => {
            let actual_text = pdf_actual_text_from_operands(operands)
            actual_text_stack.push(actual_text)
            operands.clear()
          }
          "EMC" => {
            ignore(actual_text_stack.pop())
            operands.clear()
          }
          "Tj" => {
            if in_text && operands.length() >= 1 {
              text_matrix = pdf_append_text_operand_fragment(
                fragments,
                source,
                geometry,
                current_matrix,
                text_matrix,
                current_font_alias,
                current_font_size,
                font_aliases,
                fonts,
                operands[operands.length() - 1],
                actual_text_stack.last().unwrap_or(None),
                char_spacing,
                word_spacing,
                horizontal_scaling,
                text_rise,
              )
            }
            operands.clear()
          }
          "TJ" => {
            if in_text && operands.length() >= 1 {
              text_matrix = pdf_append_text_operand_fragment(
                fragments,
                source,
                geometry,
                current_matrix,
                text_matrix,
                current_font_alias,
                current_font_size,
                font_aliases,
                fonts,
                operands[operands.length() - 1],
                actual_text_stack.last().unwrap_or(None),
                char_spacing,
                word_spacing,
                horizontal_scaling,
                text_rise,
              )
            }
            operands.clear()
          }
          "'" => {
            if in_text && operands.length() >= 1 {
              text_line_matrix = pdf_text_matrix_translated(
                text_line_matrix,
                0.0,
                0.0 - text_leading,
              )
              text_matrix = text_line_matrix
              text_matrix = pdf_append_text_operand_fragment(
                fragments,
                source,
                geometry,
                current_matrix,
                text_matrix,
                current_font_alias,
                current_font_size,
                font_aliases,
                fonts,
                operands[operands.length() - 1],
                actual_text_stack.last().unwrap_or(None),
                char_spacing,
                word_spacing,
                horizontal_scaling,
                text_rise,
              )
            }
            operands.clear()
          }
          "\"" => {
            if in_text && operands.length() >= 3 {
              word_spacing = pdf_token_number(operands[operands.length() - 3]).unwrap_or(
                word_spacing,
              )
              char_spacing = pdf_token_number(operands[operands.length() - 2]).unwrap_or(
                char_spacing,
              )
              text_line_matrix = pdf_text_matrix_translated(
                text_line_matrix,
                0.0,
                0.0 - text_leading,
              )
              text_matrix = text_line_matrix
              text_matrix = pdf_append_text_operand_fragment(
                fragments,
                source,
                geometry,
                current_matrix,
                text_matrix,
                current_font_alias,
                current_font_size,
                font_aliases,
                fonts,
                operands[operands.length() - 1],
                actual_text_stack.last().unwrap_or(None),
                char_spacing,
                word_spacing,
                horizontal_scaling,
                text_rise,
              )
            }
            operands.clear()
          }
          "Do" => {
            if operands.length() >= 1 {
              match pdf_token_name(operands[operands.length() - 1]) {
                Some(xobject_name) =>
                  match
                    pdf_interpret_content_xobject(
                      source, geometry, object_index, resources_text, fonts, inline_font_ids,
                      xobject_name, current_matrix, remaining_depth, pending_images,
                      observe_images,
                    ) {
                    Ok(children) => fragments.append(children[:])
                    Err(err) => return Err(err)
                  }
                None => ()
              }
            }
            operands.clear()
          }
          _ => operands.clear()
        }
      _ => operands.push(token)
    }
  }
  Ok(fragments)
}

///|
async fn pdf_interpret_content_xobject(
  source : @input.InputSource,
  geometry : PdfPageGeometry,
  object_index : Map[Int32, PdfNativeObject],
  resources_text : String?,
  fonts : Map[Int32, PdfNativeFontInfo],
  inline_font_ids : Map[String, Int32],
  xobject_name : String,
  current_matrix : PdfNativeGraphicsMatrix,
  remaining_depth : Int32,
  pending_images : PdfPendingImageQueue?,
  observe_images : Bool,
) -> Result[Array[PdfNativeTextFragment], PdfNativeError] {
  if remaining_depth <= 0 {
    return Ok([])
  }
  let resolved = match
    pdf_lookup_xobject_object(resources_text, xobject_name, object_index) {
    Some(value) => value
    None => return Ok([])
  }
  let xobject = resolved.1
  match pdf_extract_name_after(xobject.dict_text, "/Subtype") {
    Some("Image") => {
      if observe_images && pending_images is Some(queue) {
        pdf_enqueue_pending_image(queue, xobject_name, xobject, current_matrix)
      }
      Ok([])
    }
    Some("Form") => {
      let form_text = match
        pdf_decode_stream_text(xobject, "form xobject stream") {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      let local_resources = pdf_extract_resources_text(
        xobject.dict_text,
        object_index,
      )
      let form_resources = match local_resources {
        Some(value) => Some(value)
        None => resources_text
      }
      pdf_interpret_content_stream(
        source,
        geometry,
        pdf_font_aliases_from_resources_text(
          form_resources, object_index, inline_font_ids,
        ),
        fonts,
        inline_font_ids,
        form_text,
        object_index~,
        resources_text=form_resources,
        base_matrix=pdf_concat_graphics_matrix(
          current_matrix,
          pdf_form_graphics_matrix(xobject.dict_text),
        ),
        remaining_depth=remaining_depth - 1,
        pending_images~,
        observe_images=observe_images && local_resources is Some(_),
      )
    }
    _ => Ok([])
  }
}
