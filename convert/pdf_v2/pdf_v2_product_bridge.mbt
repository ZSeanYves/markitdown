///|
pub(all) struct PdfV2ProductBridgeOptions {
  emit_page_breaks : Bool
  emit_low_confidence_notes : Bool
  emit_unsupported_object_notes : Bool
  preserve_empty_pages : Bool
  normalize_plain_text : Bool
  enable_semantic_rules : Bool
  enable_heading_rules : Bool
  enable_list_rules : Bool
  enable_noise_guards : Bool
  enable_uri_link_rules : Bool
  enable_table_rules : Bool
  suppress_page_number_like_noise : Bool
  suppress_repeated_page_artifact_noise : Bool
  max_output_chars : Int?
  source_name : String?
}

///|
priv struct PdfV2ProductBridgePageTextCount {
  page_index : Int?
  count : Int
}

///|
priv struct PdfV2ProductBridgeTableCandidate {
  fragment_index : Int
  rows : Array[Array[String]]
  header_rows : Int
}

///|
pub fn default_pdf_v2_product_bridge_options() -> PdfV2ProductBridgeOptions {
  {
    emit_page_breaks: false,
    emit_low_confidence_notes: false,
    emit_unsupported_object_notes: false,
    preserve_empty_pages: false,
    normalize_plain_text: true,
    enable_semantic_rules: true,
    enable_heading_rules: true,
    enable_list_rules: true,
    enable_noise_guards: true,
    enable_uri_link_rules: true,
    enable_table_rules: true,
    suppress_page_number_like_noise: true,
    suppress_repeated_page_artifact_noise: true,
    max_output_chars: None,
    source_name: Some("pdf_v2"),
  }
}

///|
pub fn pdf_v2_pipeline_result_to_document(
  result : PdfV2ConvertPipelineResult,
  options : PdfV2ProductBridgeOptions,
) -> Result[@cor.Document, @cor.AppError] {
  match result {
    ConvertPipelineOk(output) =>
      Ok(pdf_v2_pipeline_output_to_document(output, options))
    ConvertPipelineErr(failure) =>
      Err(
        @cor.AppError(
          "pdf-v2: pipeline failed at " + failure.stage + ": " + failure.message,
        ),
      )
  }
}

///|
fn pdf_v2_pipeline_output_to_document(
  output : PdfV2ConvertPipelineOutput,
  options : PdfV2ProductBridgeOptions,
) -> @cor.Document {
  let doc = @cor.new_document()
  let mut remaining_chars = options.max_output_chars
  let text_paragraphs = if options.normalize_plain_text &&
    !options.enable_semantic_rules {
    pdf_v2_product_bridge_text_paragraphs(output.fragments, options)
  } else {
    []
  }
  let semantic_blocks = if options.normalize_plain_text &&
    options.enable_semantic_rules {
    pdf_v2_product_bridge_semantic_blocks(
      output.text_flow_candidates,
      output.fragments,
      options,
    )
  } else {
    []
  }
  let table_candidates = pdf_v2_product_bridge_table_candidates(
    output.fragments,
    options,
  )
  let candidate_semantic_mode = options.normalize_plain_text &&
    options.enable_semantic_rules &&
    pdf_v2_product_bridge_has_actionable_text_flow_candidates(
      output.text_flow_candidates,
    )
  let link_page_counts = pdf_v2_product_bridge_link_page_text_counts(
    output, semantic_blocks, text_paragraphs, table_candidates, candidate_semantic_mode,
    options,
  )
  let emitted_table_fragments : Array[Int] = []
  if candidate_semantic_mode {
    for semantic_block in semantic_blocks {
      if semantic_block.fragment_index >= 0 &&
        pdf_v2_product_bridge_push_table_for_fragment(
          doc,
          table_candidates,
          semantic_block.fragment_index,
          emitted_table_fragments,
          output.fragments,
          output.text_flow_candidates,
          candidate_semantic_mode,
          options,
        ) {
        continue
      }
      let text = pdf_v2_product_bridge_take_text(
        semantic_block.text,
        remaining_chars,
      )
      remaining_chars = text.1
      pdf_v2_product_bridge_push_semantic_block(
        doc,
        semantic_block,
        text.0,
        options,
        output.link_candidates,
        link_page_counts,
      )
    }
    for fragment_index in 0..<output.fragments.length() {
      let fragment = output.fragments[fragment_index]
      match fragment.kind {
        PlainText =>
          ignore(
            pdf_v2_product_bridge_push_table_for_fragment(
              doc,
              table_candidates,
              fragment_index,
              emitted_table_fragments,
              output.fragments,
              output.text_flow_candidates,
              candidate_semantic_mode,
              options,
            ),
          )
        PageBreak =>
          if options.emit_page_breaks || options.preserve_empty_pages {
            @cor.push_with_origin(
              doc,
              @cor.Block::BlankLine,
              Some(pdf_v2_product_bridge_origin(doc, fragment, options)),
            )
          }
        LowConfidenceNote =>
          if options.emit_low_confidence_notes {
            let text = pdf_v2_product_bridge_take_text(
              fragment.text,
              remaining_chars,
            )
            remaining_chars = text.1
            pdf_v2_product_bridge_push_plain_text(
              doc,
              text.0,
              fragment,
              options,
              output.link_candidates,
              link_page_counts,
            )
          }
        UnsupportedObjectNote =>
          if options.emit_unsupported_object_notes {
            let text = pdf_v2_product_bridge_take_text(
              fragment.text,
              remaining_chars,
            )
            remaining_chars = text.1
            pdf_v2_product_bridge_push_plain_text(
              doc,
              text.0,
              fragment,
              options,
              output.link_candidates,
              link_page_counts,
            )
          }
      }
    }
    pdf_v2_product_bridge_push_images(
      doc,
      output.image_candidates,
      output.inline_image_candidates,
      options,
    )
    return doc
  }
  let mut shaped_index = 0
  let mut semantic_index = 0
  for fragment_index in 0..<output.fragments.length() {
    let fragment = output.fragments[fragment_index]
    match fragment.kind {
      PlainText =>
        if pdf_v2_product_bridge_push_table_for_fragment(
            doc,
            table_candidates,
            fragment_index,
            emitted_table_fragments,
            output.fragments,
            output.text_flow_candidates,
            candidate_semantic_mode,
            options,
          ) {
          while semantic_index < semantic_blocks.length() &&
                semantic_blocks[semantic_index].fragment_index <= fragment_index {
            semantic_index = semantic_index + 1
          }
          while shaped_index < text_paragraphs.length() &&
                text_paragraphs[shaped_index].fragment_index <= fragment_index {
            shaped_index = shaped_index + 1
          }
          ()
        } else if options.normalize_plain_text && options.enable_semantic_rules {
          while semantic_index < semantic_blocks.length() &&
                semantic_blocks[semantic_index].fragment_index == fragment_index {
            let semantic_block = semantic_blocks[semantic_index]
            let text = pdf_v2_product_bridge_take_text(
              semantic_block.text,
              remaining_chars,
            )
            remaining_chars = text.1
            pdf_v2_product_bridge_push_semantic_block(
              doc,
              semantic_block,
              text.0,
              options,
              output.link_candidates,
              link_page_counts,
            )
            semantic_index = semantic_index + 1
          }
        } else if options.normalize_plain_text {
          while shaped_index < text_paragraphs.length() &&
                text_paragraphs[shaped_index].fragment_index == fragment_index {
            let paragraph = text_paragraphs[shaped_index]
            let text = pdf_v2_product_bridge_take_text(
              paragraph.text,
              remaining_chars,
            )
            remaining_chars = text.1
            pdf_v2_product_bridge_push_plain_text(
              doc,
              text.0,
              fragment,
              options,
              output.link_candidates,
              link_page_counts,
            )
            shaped_index = shaped_index + 1
          }
        } else {
          let text = pdf_v2_product_bridge_take_text(
            fragment.text,
            remaining_chars,
          )
          remaining_chars = text.1
          pdf_v2_product_bridge_push_plain_text(
            doc,
            text.0,
            fragment,
            options,
            output.link_candidates,
            link_page_counts,
          )
        }
      PageBreak =>
        if options.emit_page_breaks || options.preserve_empty_pages {
          @cor.push_with_origin(
            doc,
            @cor.Block::BlankLine,
            Some(pdf_v2_product_bridge_origin(doc, fragment, options)),
          )
        }
      LowConfidenceNote =>
        if options.emit_low_confidence_notes {
          let text = pdf_v2_product_bridge_take_text(
            fragment.text,
            remaining_chars,
          )
          remaining_chars = text.1
          pdf_v2_product_bridge_push_plain_text(
            doc,
            text.0,
            fragment,
            options,
            output.link_candidates,
            link_page_counts,
          )
        }
      UnsupportedObjectNote =>
        if options.emit_unsupported_object_notes {
          let text = pdf_v2_product_bridge_take_text(
            fragment.text,
            remaining_chars,
          )
          remaining_chars = text.1
          pdf_v2_product_bridge_push_plain_text(
            doc,
            text.0,
            fragment,
            options,
            output.link_candidates,
            link_page_counts,
          )
        }
    }
  }
  pdf_v2_product_bridge_push_images(
    doc,
    output.image_candidates,
    output.inline_image_candidates,
    options,
  )
  doc
}

///|
fn pdf_v2_product_bridge_text_paragraphs(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2TextOutputParagraph] {
  pdf_v2_text_output_paragraphs(fragments, options)
}

///|
fn pdf_v2_product_bridge_semantic_blocks(
  text_flow_candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2SemanticBlock] {
  if pdf_v2_product_bridge_has_actionable_text_flow_candidates(
      text_flow_candidates,
    ) {
    pdf_v2_semantic_blocks_from_candidates(text_flow_candidates, options)
  } else {
    pdf_v2_semantic_blocks_from_fragments(fragments, options)
  }
}

///|
fn pdf_v2_product_bridge_has_actionable_text_flow_candidates(
  text_flow_candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
) -> Bool {
  for candidate in text_flow_candidates {
    if candidate.reason_tags.contains("inline_list_split") ||
      candidate.reason_tags.contains("page_artifact_fact_attached") ||
      candidate.boundary_signal.list_candidate_score >= 0.70 {
      return true
    }
  }
  false
}

///|
fn pdf_v2_product_bridge_link_page_text_counts(
  output : PdfV2ConvertPipelineOutput,
  semantic_blocks : Array[PdfV2SemanticBlock],
  text_paragraphs : Array[PdfV2TextOutputParagraph],
  table_candidates : Array[PdfV2ProductBridgeTableCandidate],
  candidate_semantic_mode : Bool,
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2ProductBridgePageTextCount] {
  let counts : Array[PdfV2ProductBridgePageTextCount] = []
  if candidate_semantic_mode {
    for block in semantic_blocks {
      if !block.risk_tags.contains("suppress_output") &&
        !pdf_v2_product_bridge_has_table_for_fragment(
          table_candidates,
          block.fragment_index,
        ) &&
        block.text.trim().to_owned() != "" {
        pdf_v2_product_bridge_increment_page_count(counts, block.page_index)
      }
    }
    for table in table_candidates {
      let fragment = output.fragments[table.fragment_index]
      pdf_v2_product_bridge_increment_page_count(counts, fragment.page_index)
    }
    if options.emit_low_confidence_notes ||
      options.emit_unsupported_object_notes {
      for fragment in output.fragments {
        match fragment.kind {
          LowConfidenceNote =>
            if options.emit_low_confidence_notes &&
              fragment.text.trim().to_owned() != "" {
              pdf_v2_product_bridge_increment_page_count(
                counts,
                fragment.page_index,
              )
            }
          UnsupportedObjectNote =>
            if options.emit_unsupported_object_notes &&
              fragment.text.trim().to_owned() != "" {
              pdf_v2_product_bridge_increment_page_count(
                counts,
                fragment.page_index,
              )
            }
          _ => ()
        }
      }
    }
    return counts
  }
  if options.normalize_plain_text && options.enable_semantic_rules {
    for block in semantic_blocks {
      if !block.risk_tags.contains("suppress_output") &&
        !pdf_v2_product_bridge_has_table_for_fragment(
          table_candidates,
          block.fragment_index,
        ) &&
        block.text.trim().to_owned() != "" {
        pdf_v2_product_bridge_increment_page_count(counts, block.page_index)
      }
    }
    for table in table_candidates {
      let fragment = output.fragments[table.fragment_index]
      pdf_v2_product_bridge_increment_page_count(counts, fragment.page_index)
    }
  } else if options.normalize_plain_text {
    for paragraph in text_paragraphs {
      let fragment = output.fragments[paragraph.fragment_index]
      if paragraph.text.trim().to_owned() != "" {
        pdf_v2_product_bridge_increment_page_count(counts, fragment.page_index)
      }
    }
  } else {
    for fragment in output.fragments {
      if fragment.kind == PdfV2FactFragmentKind::PlainText &&
        fragment.text.trim().to_owned() != "" {
        pdf_v2_product_bridge_increment_page_count(counts, fragment.page_index)
      }
    }
  }
  counts
}

///|
fn pdf_v2_product_bridge_has_table_for_fragment(
  tables : Array[PdfV2ProductBridgeTableCandidate],
  fragment_index : Int,
) -> Bool {
  for table in tables {
    if table.fragment_index == fragment_index {
      return true
    }
  }
  false
}

///|
fn pdf_v2_product_bridge_increment_page_count(
  counts : Array[PdfV2ProductBridgePageTextCount],
  page_index : Int?,
) -> Unit {
  for i in 0..<counts.length() {
    if counts[i].page_index == page_index {
      counts[i] = { ..counts[i], count: counts[i].count + 1 }
      return
    }
  }
  counts.push({ page_index, count: 1 })
}

///|
fn pdf_v2_product_bridge_page_text_count(
  page_index : Int?,
  counts : Array[PdfV2ProductBridgePageTextCount],
) -> Int {
  for item in counts {
    if item.page_index == page_index {
      return item.count
    }
  }
  0
}

///|
fn pdf_v2_product_bridge_table_candidates(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2ProductBridgeTableCandidate] {
  let out : Array[PdfV2ProductBridgeTableCandidate] = []
  if !options.normalize_plain_text ||
    !options.enable_semantic_rules ||
    !options.enable_table_rules {
    return out
  }
  for fragment_index in 0..<fragments.length() {
    let fragment = fragments[fragment_index]
    if fragment.kind != PdfV2FactFragmentKind::PlainText {
      continue
    }
    match pdf_v2_product_bridge_table_from_text(fragment.text) {
      Some(table) =>
        out.push({
          fragment_index,
          rows: table.rows,
          header_rows: table.header_rows,
        })
      None => ()
    }
  }
  out
}

///|
fn pdf_v2_product_bridge_push_table_for_fragment(
  doc : @cor.Document,
  tables : Array[PdfV2ProductBridgeTableCandidate],
  fragment_index : Int,
  emitted : Array[Int],
  fragments : Array[PdfV2FactFragment],
  text_flow_candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  candidate_semantic_mode : Bool,
  options : PdfV2ProductBridgeOptions,
) -> Bool {
  if emitted.contains(fragment_index) {
    return true
  }
  if candidate_semantic_mode &&
    pdf_v2_product_bridge_fragment_has_text_flow_candidate(
      fragments[fragment_index],
      text_flow_candidates,
    ) {
    return false
  }
  for table in tables {
    if table.fragment_index == fragment_index {
      let fragment = fragments[fragment_index]
      @cor.push_with_origin(
        doc,
        @cor.Block::RichTable({
          rows: table.rows,
          header_rows: table.header_rows,
          hints: Some({
            format: Some("pdf_v2_text_table"),
            sheet_state: None,
            merged_ranges: None,
            formula_cells: None,
            semantic_types: None,
            span_cells: None,
          }),
        }),
        Some(pdf_v2_product_bridge_origin(doc, fragment, options)),
      )
      emitted.push(fragment_index)
      return true
    }
  }
  false
}

///|
fn pdf_v2_product_bridge_fragment_has_text_flow_candidate(
  fragment : PdfV2FactFragment,
  text_flow_candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
) -> Bool {
  for candidate in text_flow_candidates {
    if candidate.page_index == fragment.page_index &&
      candidate.block_index == fragment.block_index {
      return true
    }
  }
  false
}

///|
fn pdf_v2_product_bridge_table_from_text(
  text : String,
) -> PdfV2ProductBridgeTableCandidate? {
  match pdf_v2_product_bridge_pipe_table_from_text(text) {
    Some(table) => Some(table)
    None => pdf_v2_product_bridge_aligned_table_from_text(text)
  }
}

///|
fn pdf_v2_product_bridge_pipe_table_from_text(
  text : String,
) -> PdfV2ProductBridgeTableCandidate? {
  let lines = pdf_v2_product_bridge_table_lines(text)
  if lines.length() < 2 {
    return None
  }
  let rows : Array[Array[String]] = []
  let mut separator_seen = false
  let mut width = 0
  for i in 0..<lines.length() {
    let line = lines[i]
    if !line.contains("|") {
      return None
    }
    if pdf_v2_product_bridge_is_pipe_separator_line(line) {
      if i != 1 || separator_seen || rows.length() != 1 {
        return None
      }
      separator_seen = true
      continue
    }
    let row = pdf_v2_product_bridge_parse_pipe_row(line)
    if row.length() < 2 {
      return None
    }
    if width == 0 {
      width = row.length()
    } else if row.length() != width {
      return None
    }
    rows.push(row)
  }
  if rows.length() < 2 {
    return None
  }
  if separator_seen {
    Some({ fragment_index: -1, rows, header_rows: 1 })
  } else if pdf_v2_product_bridge_table_rows_reliable(rows) {
    Some({
      fragment_index: -1,
      rows,
      header_rows: pdf_v2_product_bridge_infer_table_header_rows(rows),
    })
  } else {
    None
  }
}

///|
fn pdf_v2_product_bridge_aligned_table_from_text(
  text : String,
) -> PdfV2ProductBridgeTableCandidate? {
  let lines = pdf_v2_product_bridge_table_lines(text)
  if lines.length() < 2 {
    return None
  }
  let rows : Array[Array[String]] = []
  let mut width = 0
  for line in lines {
    if line.contains("|") {
      return None
    }
    let row = pdf_v2_product_bridge_parse_aligned_row(line)
    if row.length() < 2 {
      return None
    }
    if pdf_v2_product_bridge_table_row_reject(row) {
      return None
    }
    if width == 0 {
      width = row.length()
    } else if row.length() != width {
      return None
    }
    rows.push(row)
  }
  if rows.length() < 2 || !pdf_v2_product_bridge_table_rows_reliable(rows) {
    return None
  }
  Some({
    fragment_index: -1,
    rows,
    header_rows: pdf_v2_product_bridge_infer_table_header_rows(rows),
  })
}

///|
fn pdf_v2_product_bridge_table_lines(text : String) -> Array[String] {
  let out : Array[String] = []
  for
    raw in text
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
    .split("\n") {
    let line = raw.to_owned().trim().to_owned()
    if line != "" {
      out.push(line)
    }
  }
  out
}

///|
fn pdf_v2_product_bridge_parse_pipe_row(line : String) -> Array[String] {
  let trimmed = line.trim().to_owned()
  let inner = pdf_v2_product_bridge_trim_edge_pipes(trimmed)
  let row : Array[String] = []
  for cell in inner.split("|") {
    row.push(cell.to_owned().trim().to_owned())
  }
  row
}

///|
fn pdf_v2_product_bridge_trim_edge_pipes(text : String) -> String {
  let mut out = text
  if out.has_prefix("|") {
    out = out[1:].to_owned()
  }
  if out.has_suffix("|") && out.length() > 0 {
    out = out[:out.length() - 1].to_owned()
  }
  out.trim().to_owned()
}

///|
fn pdf_v2_product_bridge_is_pipe_separator_line(line : String) -> Bool {
  let row = pdf_v2_product_bridge_parse_pipe_row(line)
  if row.length() < 2 {
    return false
  }
  for cell in row {
    if !pdf_v2_product_bridge_is_pipe_separator_cell(cell) {
      return false
    }
  }
  true
}

///|
fn pdf_v2_product_bridge_is_pipe_separator_cell(cell : String) -> Bool {
  let t = cell.trim().to_owned()
  if t.length() < 3 {
    return false
  }
  let chars = t.to_array()
  let mut dash_count = 0
  for i in 0..<chars.length() {
    let ch = chars[i]
    if ch == '-' {
      dash_count = dash_count + 1
    } else if (ch == ':' && (i == 0 || i + 1 == chars.length())) || ch == ' ' {
      ()
    } else {
      return false
    }
  }
  dash_count >= 3
}

///|
fn pdf_v2_product_bridge_parse_aligned_row(line : String) -> Array[String] {
  let row : Array[String] = []
  let chars = line.to_array()
  let mut cell = ""
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == ' ' || ch == '\t' {
      let mut j = i
      while j < chars.length() && (chars[j] == ' ' || chars[j] == '\t') {
        j = j + 1
      }
      if j - i >= 2 {
        let value = cell.to_string().trim().to_owned()
        if value == "" {
          return []
        }
        row.push(value)
        cell = ""
      } else {
        cell = cell + " "
      }
      i = j
    } else {
      cell = cell + ch.to_string()
      i = i + 1
    }
  }
  let value = cell.trim().to_owned()
  if value != "" {
    row.push(value)
  }
  row
}

///|
fn pdf_v2_product_bridge_table_rows_reliable(
  rows : Array[Array[String]],
) -> Bool {
  if rows.length() < 2 {
    return false
  }
  let width = rows[0].length()
  if width < 2 {
    return false
  }
  let mut numeric_count = 0
  let mut short_label_count = 0
  let mut cell_count = 0
  for row in rows {
    if row.length() != width || pdf_v2_product_bridge_table_row_reject(row) {
      return false
    }
    for cell in row {
      cell_count = cell_count + 1
      if pdf_v2_product_bridge_cell_numeric_like(cell) {
        numeric_count = numeric_count + 1
      }
      if pdf_v2_product_bridge_cell_short_label(cell) {
        short_label_count = short_label_count + 1
      }
    }
  }
  numeric_count > 0 || short_label_count * 2 >= cell_count
}

///|
fn pdf_v2_product_bridge_table_row_reject(row : Array[String]) -> Bool {
  for cell in row {
    let t = cell.trim().to_owned()
    if t == "" {
      return true
    }
    let lower = t.to_lower()
    if lower.has_prefix("figure ") ||
      lower.has_prefix("fig. ") ||
      lower.has_prefix("table ") ||
      t.has_prefix("图") ||
      t.has_prefix("表 ") ||
      t.has_prefix("- ") ||
      t.has_prefix("* ") ||
      t.has_prefix("\u{2022} ") ||
      pdf_v2_product_bridge_starts_with_numbered_list_marker(t) {
      return true
    }
    if pdf_v2_product_bridge_sentence_like_table_cell(t) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_product_bridge_infer_table_header_rows(
  rows : Array[Array[String]],
) -> Int {
  if rows.length() < 2 {
    return 0
  }
  let first_numeric = pdf_v2_product_bridge_numeric_cell_count(rows[0])
  let second_numeric = pdf_v2_product_bridge_numeric_cell_count(rows[1])
  if first_numeric == 0 && second_numeric > 0 {
    return 1
  }
  let mut short_labels = 0
  for cell in rows[0] {
    if pdf_v2_product_bridge_cell_short_label(cell) {
      short_labels = short_labels + 1
    }
  }
  if short_labels * 2 >= rows[0].length() {
    1
  } else {
    0
  }
}

///|
fn pdf_v2_product_bridge_numeric_cell_count(row : Array[String]) -> Int {
  let mut out = 0
  for cell in row {
    if pdf_v2_product_bridge_cell_numeric_like(cell) {
      out = out + 1
    }
  }
  out
}

///|
fn pdf_v2_product_bridge_cell_numeric_like(cell : String) -> Bool {
  let t = cell
    .trim()
    .to_owned()
    .replace_all(old=",", new="")
    .replace_all(old="%", new="")
  if t == "" {
    return false
  }
  let chars = t.to_array()
  let mut digit_count = 0
  for i in 0..<chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      digit_count = digit_count + 1
    } else if ch == '.' || (i == 0 && (ch == '-' || ch == '+')) || ch == '$' {
      ()
    } else {
      return false
    }
  }
  digit_count > 0
}

///|
fn pdf_v2_product_bridge_cell_short_label(cell : String) -> Bool {
  let t = cell.trim().to_owned()
  t != "" &&
  t.length() <= 32 &&
  !pdf_v2_product_bridge_cell_numeric_like(t) &&
  !pdf_v2_product_bridge_sentence_like_table_cell(t)
}

///|
fn pdf_v2_product_bridge_sentence_like_table_cell(cell : String) -> Bool {
  let t = cell.trim().to_owned()
  if t.length() < 24 {
    return false
  }
  let words = t.split(" ").length()
  (t.has_suffix(".") || t.has_suffix("!") || t.has_suffix("?")) && words >= 5
}

///|
fn pdf_v2_product_bridge_starts_with_numbered_list_marker(
  text : String,
) -> Bool {
  let chars = text.to_array()
  if chars.length() < 4 {
    return false
  }
  let mut i = 0
  let mut saw_digit = false
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      saw_digit = true
      i = i + 1
      continue
    }
    break
  }
  if !saw_digit || i + 1 >= chars.length() {
    return false
  }
  (chars[i] == '.' || chars[i] == ')' || chars[i] == '\u{3001}') &&
  (chars[i + 1] == ' ' || chars[i + 1] == '\t')
}

///|
fn pdf_v2_product_bridge_push_images(
  doc : @cor.Document,
  images : Array[@pdfv2.PdfV2ImageCandidate],
  inline_images : Array[@pdfv2.PdfV2InlineImageCandidate],
  options : PdfV2ProductBridgeOptions,
) -> Unit {
  let mut index = 0
  for image in images {
    index = index + 1
    let path = pdf_v2_product_bridge_image_path(index, false)
    let origin = pdf_v2_product_bridge_origin_from_parts(
      doc,
      image.page_index,
      [image.source_ref],
      options,
    )
    @cor.push_with_origin(
      doc,
      @cor.Block::ImageBlock({
        path,
        alt_text: Some(pdf_v2_product_bridge_image_alt_text(image)),
        title: pdf_v2_product_bridge_image_title(
          image.width,
          image.height,
          image.filters,
          image.decode_status,
        ),
        caption: None,
        origin: Some(origin),
      }),
      Some(origin),
    )
    @cor.set_asset_origin(doc, path, {
      source_name: options.source_name,
      page: match image.page_index {
        Some(value) => Some(value + 1)
        None => None
      },
      slide: None,
      sheet: None,
      origin_id: Some(pdf_v2_product_bridge_image_origin_id(image, index)),
      nearby_caption: None,
      object_ref: image.object_ref,
      relationship_id: None,
      source_path: None,
      row_index: None,
      column_index: None,
      key_path: Some("pdf_v2.image.metadata"),
    })
  }
  for image in inline_images {
    index = index + 1
    let path = pdf_v2_product_bridge_image_path(index, true)
    let origin = pdf_v2_product_bridge_origin_from_parts(
      doc,
      image.page_index,
      [image.source_ref],
      options,
    )
    @cor.push_with_origin(
      doc,
      @cor.Block::ImageBlock({
        path,
        alt_text: Some(pdf_v2_product_bridge_inline_image_alt_text(image)),
        title: pdf_v2_product_bridge_image_title(
          image.width,
          image.height,
          image.filters,
          image.decode_status,
        ),
        caption: None,
        origin: Some(origin),
      }),
      Some(origin),
    )
    @cor.set_asset_origin(doc, path, {
      source_name: options.source_name,
      page: match image.page_index {
        Some(value) => Some(value + 1)
        None => None
      },
      slide: None,
      sheet: None,
      origin_id: Some("pdf-v2-inline-image-" + index.to_string()),
      nearby_caption: None,
      object_ref: image.source_ref.object_id,
      relationship_id: None,
      source_path: None,
      row_index: None,
      column_index: None,
      key_path: Some("pdf_v2.inline_image.metadata"),
    })
  }
}

///|
fn pdf_v2_product_bridge_image_path(index : Int, inline : Bool) -> String {
  let prefix = if inline {
    "assets/pdf-v2-inline-image-"
  } else {
    "assets/pdf-v2-image-"
  }
  prefix + pdf_v2_product_bridge_pad_asset_index(index) + ".metadata"
}

///|
fn pdf_v2_product_bridge_pad_asset_index(index : Int) -> String {
  let mut out = index.to_string()
  while out.length() < 3 {
    out = "0" + out
  }
  out
}

///|
fn pdf_v2_product_bridge_image_alt_text(
  image : @pdfv2.PdfV2ImageCandidate,
) -> String {
  let kind = if image.inline { "inline image" } else { "image" }
  let size = pdf_v2_product_bridge_image_size_text(image.width, image.height)
  if size == "" {
    "PDF v2 " + kind + " metadata"
  } else {
    "PDF v2 " + kind + " metadata " + size
  }
}

///|
fn pdf_v2_product_bridge_inline_image_alt_text(
  image : @pdfv2.PdfV2InlineImageCandidate,
) -> String {
  let size = pdf_v2_product_bridge_image_size_text(image.width, image.height)
  if size == "" {
    "PDF v2 inline image metadata"
  } else {
    "PDF v2 inline image metadata " + size
  }
}

///|
fn pdf_v2_product_bridge_image_size_text(width : Int?, height : Int?) -> String {
  match (width, height) {
    (Some(w), Some(h)) => "\{w}x\{h}"
    (Some(w), None) => "\{w}x?"
    (None, Some(h)) => "?x\{h}"
    (None, None) => ""
  }
}

///|
fn pdf_v2_product_bridge_image_title(
  width : Int?,
  height : Int?,
  filters : Array[String],
  status : @pdfv2.PdfV2ImageDecodeStatus,
) -> String? {
  let parts : Array[String] = ["metadata-only"]
  let size = pdf_v2_product_bridge_image_size_text(width, height)
  if size != "" {
    parts.push(size)
  }
  if filters.length() > 0 {
    parts.push("filters=" + filters.join(","))
  }
  parts.push("decode=" + pdf_v2_product_bridge_image_decode_status(status))
  Some(parts.join("; "))
}

///|
fn pdf_v2_product_bridge_image_decode_status(
  status : @pdfv2.PdfV2ImageDecodeStatus,
) -> String {
  match status {
    MetadataOnly => "metadata-only"
    DecodeAvailable => "decode-available"
    Unsupported => "unsupported"
    NotAttempted => "not-attempted"
  }
}

///|
fn pdf_v2_product_bridge_image_origin_id(
  image : @pdfv2.PdfV2ImageCandidate,
  index : Int,
) -> String {
  match image.object_ref {
    Some(value) => "pdf-v2-image:" + value
    None => "pdf-v2-image-" + index.to_string()
  }
}

///|
fn pdf_v2_product_bridge_push_plain_text(
  doc : @cor.Document,
  text : String,
  fragment : PdfV2FactFragment,
  options : PdfV2ProductBridgeOptions,
  link_candidates : Array[@pdfv2.PdfV2LinkCandidate],
  link_page_counts : Array[PdfV2ProductBridgePageTextCount],
) -> Unit {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return
  }
  let origin = pdf_v2_product_bridge_origin(doc, fragment, options)
  @cor.push_with_origin(
    doc,
    pdf_v2_product_bridge_plain_core_block(
      trimmed,
      fragment.page_index,
      link_candidates,
      link_page_counts,
      options,
    ),
    Some(origin),
  )
}

///|
fn pdf_v2_product_bridge_push_semantic_block(
  doc : @cor.Document,
  semantic_block : PdfV2SemanticBlock,
  text : String,
  options : PdfV2ProductBridgeOptions,
  link_candidates : Array[@pdfv2.PdfV2LinkCandidate],
  link_page_counts : Array[PdfV2ProductBridgePageTextCount],
) -> Unit {
  if semantic_block.risk_tags.contains("suppress_output") {
    return
  }
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return
  }
  let block = pdf_v2_product_bridge_core_block(
    semantic_block, trimmed, link_candidates, link_page_counts, options,
  )
  @cor.push_with_origin(
    doc,
    block,
    Some(
      pdf_v2_product_bridge_origin_for_semantic(doc, semantic_block, options),
    ),
  )
}

///|
fn pdf_v2_product_bridge_core_block(
  semantic_block : PdfV2SemanticBlock,
  text : String,
  link_candidates : Array[@pdfv2.PdfV2LinkCandidate],
  link_page_counts : Array[PdfV2ProductBridgePageTextCount],
  options : PdfV2ProductBridgeOptions,
) -> @cor.Block {
  let rich_inlines = pdf_v2_product_bridge_link_inlines(
    text,
    semantic_block.page_index,
    link_candidates,
    link_page_counts,
    options,
  )
  match semantic_block.kind {
    PdfV2SemanticBlockKind::Heading =>
      match rich_inlines {
        Some(inlines) =>
          @cor.Block::RichHeading(semantic_block.level.unwrap_or(1), inlines)
        None => @cor.Block::Heading(semantic_block.level.unwrap_or(1), text)
      }
    PdfV2SemanticBlockKind::OrderedListItem =>
      match rich_inlines {
        Some(inlines) =>
          @cor.Block::RichListItem(true, semantic_block.list_level, inlines)
        None => @cor.Block::ListItem(true, semantic_block.list_level, text)
      }
    PdfV2SemanticBlockKind::UnorderedListItem =>
      match rich_inlines {
        Some(inlines) =>
          @cor.Block::RichListItem(false, semantic_block.list_level, inlines)
        None => @cor.Block::ListItem(false, semantic_block.list_level, text)
      }
    PdfV2SemanticBlockKind::Paragraph
    | PdfV2SemanticBlockKind::Continuation
    | PdfV2SemanticBlockKind::PlainText
    | PdfV2SemanticBlockKind::Unknown =>
      match rich_inlines {
        Some(inlines) => @cor.Block::RichParagraph(inlines)
        None => @cor.Block::Paragraph(text)
      }
  }
}

///|
fn pdf_v2_product_bridge_plain_core_block(
  text : String,
  page_index : Int?,
  link_candidates : Array[@pdfv2.PdfV2LinkCandidate],
  link_page_counts : Array[PdfV2ProductBridgePageTextCount],
  options : PdfV2ProductBridgeOptions,
) -> @cor.Block {
  match
    pdf_v2_product_bridge_link_inlines(
      text, page_index, link_candidates, link_page_counts, options,
    ) {
    Some(inlines) => @cor.Block::RichParagraph(inlines)
    None => @cor.Block::Paragraph(text)
  }
}

///|
fn pdf_v2_product_bridge_link_inlines(
  text : String,
  page_index : Int?,
  link_candidates : Array[@pdfv2.PdfV2LinkCandidate],
  link_page_counts : Array[PdfV2ProductBridgePageTextCount],
  options : PdfV2ProductBridgeOptions,
) -> Array[@cor.Inline]? {
  if !options.enable_semantic_rules || !options.enable_uri_link_rules {
    return None
  }
  let association = match
    pdf_v2_product_bridge_link_association(
      text, page_index, link_candidates, link_page_counts,
    ) {
    Some(value) => value
    None => return None
  }
  pdf_v2_product_bridge_unique_inline_link_for_text(
    text,
    association.0,
    association.1,
  )
}

///|
fn pdf_v2_product_bridge_link_association(
  text : String,
  page_index : Int?,
  link_candidates : Array[@pdfv2.PdfV2LinkCandidate],
  link_page_counts : Array[PdfV2ProductBridgePageTextCount],
) -> (String, String)? {
  let page_links : Array[@pdfv2.PdfV2LinkCandidate] = []
  for link in link_candidates {
    if link.page_index == page_index &&
      pdf_v2_product_bridge_safe_uri_link(link) {
      page_links.push(link)
    }
  }
  if page_links.length() == 0 {
    return None
  }
  let text_match : Array[(String, String)] = []
  for link in page_links {
    match link.uri {
      Some(raw_uri) => {
        let uri = raw_uri.trim().to_owned()
        if pdf_v2_product_bridge_unique_substring_range(text, uri) is Some(_) {
          text_match.push((uri, uri))
        }
      }
      None => ()
    }
  }
  if text_match.length() == 1 {
    return Some(text_match[0])
  }
  if page_links.length() == 1 &&
    pdf_v2_product_bridge_page_text_count(page_index, link_page_counts) == 1 {
    match page_links[0].uri {
      Some(uri) => Some((text.trim().to_owned(), uri.trim().to_owned()))
      None => None
    }
  } else {
    None
  }
}

///|
fn pdf_v2_product_bridge_safe_uri_link(
  link : @pdfv2.PdfV2LinkCandidate,
) -> Bool {
  if link.subtype != Some("/Link") {
    return false
  }
  if link.rect is None {
    return false
  }
  match link.uri {
    Some(uri) => pdf_v2_product_bridge_safe_uri(uri)
    None => false
  }
}

///|
fn pdf_v2_product_bridge_safe_uri(uri : String) -> Bool {
  let trimmed = uri.trim().to_owned().to_lower()
  trimmed.has_prefix("http://") ||
  trimmed.has_prefix("https://") ||
  trimmed.has_prefix("mailto:")
}

///|
fn pdf_v2_product_bridge_unique_inline_link_for_text(
  block_text : String,
  label : String,
  uri : String,
) -> Array[@cor.Inline]? {
  let link_label = label.trim().to_owned()
  if link_label == "" {
    return None
  }
  let block = block_text.trim().to_owned()
  if block == "" {
    return None
  }
  match pdf_v2_product_bridge_unique_substring_range(block, link_label) {
    Some((start, end)) => {
      let inlines : Array[@cor.Inline] = []
      let prefix = block[:start].to_owned()
      let matched = block[start:end].to_owned()
      let suffix = block[end:].to_owned()
      if prefix != "" {
        inlines.push(@cor.Inline::Text(prefix))
      }
      inlines.push(@cor.Inline::Link(matched, uri.trim().to_owned()))
      if suffix != "" {
        inlines.push(@cor.Inline::Text(suffix))
      }
      Some(inlines)
    }
    None => None
  }
}

///|
fn pdf_v2_product_bridge_unique_substring_range(
  text : String,
  needle : String,
) -> (Int, Int)? {
  if needle == "" {
    return None
  }
  match text.find(needle) {
    Some(start) => {
      let end = start + needle.length()
      match text[end:].find(needle) {
        Some(_) => None
        None => Some((start, end))
      }
    }
    None => None
  }
}

///|
fn pdf_v2_product_bridge_take_text(
  text : String,
  remaining_chars : Int?,
) -> (String, Int?) {
  match remaining_chars {
    None => (text, None)
    Some(remaining) =>
      if remaining <= 0 {
        ("", Some(0))
      } else if text.length() <= remaining {
        (text, Some(remaining - text.length()))
      } else {
        (text[:remaining].to_owned(), Some(0))
      }
  }
}

///|
fn pdf_v2_product_bridge_origin(
  doc : @cor.Document,
  fragment : PdfV2FactFragment,
  options : PdfV2ProductBridgeOptions,
) -> @cor.Origin {
  pdf_v2_product_bridge_origin_from_parts(
    doc,
    fragment.page_index,
    fragment.source_refs,
    options,
  )
}

///|
fn pdf_v2_product_bridge_origin_for_semantic(
  doc : @cor.Document,
  semantic_block : PdfV2SemanticBlock,
  options : PdfV2ProductBridgeOptions,
) -> @cor.Origin {
  pdf_v2_product_bridge_origin_from_parts(
    doc,
    semantic_block.page_index,
    semantic_block.source_refs,
    options,
  )
}

///|
fn pdf_v2_product_bridge_origin_from_parts(
  doc : @cor.Document,
  page_index : Int?,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  options : PdfV2ProductBridgeOptions,
) -> @cor.Origin {
  {
    source_name: options.source_name,
    page: match page_index {
      Some(index) => Some(index + 1)
      None => None
    },
    slide: None,
    sheet: None,
    block_index: Some(doc.blocks.val.length()),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: pdf_v2_product_bridge_object_ref(source_refs),
    relationship_id: None,
    key_path: None,
  }
}

///|
fn pdf_v2_product_bridge_object_ref(
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> String? {
  for source_ref in source_refs {
    match source_ref.object_id {
      Some(object_id) => return Some(object_id)
      None => ()
    }
  }
  None
}
