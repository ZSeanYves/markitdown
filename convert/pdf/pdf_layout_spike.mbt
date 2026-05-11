///|
pub async fn export_pdf_layout_features_tsv(
  input_path : String,
  sample_id : String,
  record_kind : String,
) -> String {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("pdf layout export: file not found: " + input_path)
  }

  let export_kind = parse_layout_export_kind(record_kind)
  let core_doc = extract_pdf_document_model(input_path)
  let doc0 = build_convert_lines(core_doc, "")
  let doc1 = build_convert_blocks(doc0)
  let doc2 = classify_convert_blocks(doc1, 6)
  let doc3 = filter_noise_blocks(doc2)

  let features : Array[PdfLayoutFeature] = []
  let feature_names = default_pdf_layout_feature_names()

  if export_kind != PdfLayoutExportKind::BoundaryOnly {
    let repeated_counts = build_repeated_text_counts(doc2)
    for page in doc2.pages {
      for i = 0; i < page.blocks.length(); i = i + 1 {
        let block = page.blocks[i]
        let prev = if i > 0 { Some(page.blocks[i - 1]) } else { None }
        let next = if i + 1 < page.blocks.length() {
          Some(page.blocks[i + 1])
        } else {
          None
        }
        let values = block_layout_feature_values(
          page,
          block,
          prev,
          next,
          repeated_text_score(repeated_counts, block.text, doc2.pages.length()),
          nearest_image_distance(page.images, block._bbox),
        )
        features.push(
          make_pdf_layout_feature(
            sample_id,
            input_path,
            PdfLayoutRecordKind::Block,
            page._page_index,
            block.block_index,
            block.line_start,
            None,
            None,
            None,
            block.text,
            None,
            Some(block_feature_notes(block)),
            values,
          ),
        )
      }
    }
  }

  if export_kind != PdfLayoutExportKind::BlockOnly {
    for i = 1; i < doc3.pages.length(); i = i + 1 {
      let prev_page = doc3.pages[i - 1]
      let cur_page = doc3.pages[i]
      if prev_page.blocks.is_empty() || cur_page.blocks.is_empty() {
        continue
      }

      let left = prev_page.blocks[prev_page.blocks.length() - 1]
      let right = cur_page.blocks[0]
      let merge_decision = decide_page_boundary_merge(prev_page, cur_page)
      features.push(
        make_pdf_layout_feature(
          sample_id,
          input_path,
          PdfLayoutRecordKind::Boundary,
          left._page_index,
          left.block_index,
          left.line_end,
          Some(right._page_index),
          Some(right.block_index),
          Some(right.line_start),
          left.text.trim().to_owned() + " || " + right.text.trim().to_owned(),
          None,
          Some(merge_decision.reason_tags.join(",")),
          boundary_layout_feature_values(prev_page, cur_page),
        ),
      )
    }
  }

  render_pdf_layout_feature_tsv(features, feature_names)
}

///|
pub fn parse_pdf_layout_features_tsv(
  text : String,
) -> Result[Array[PdfLayoutFeature], PdfLayoutModelError] {
  let raw_lines = text.split("\n")
  let lines : Array[String] = []
  for raw in raw_lines {
    let line = raw.replace(old="\r", new="").to_owned()
    if line != "" {
      lines.push(line)
    }
  }

  if lines.is_empty() {
    return Err(model_error(InvalidValue, "feature tsv is empty"))
  }

  let header = split_tsv_line(lines[0])
  let index = header_index(header)
  let required = [
    "sample_id", "source_path", "record_kind", "page_index", "block_index", "line_index",
    "text", "label",
  ]
  for name in required {
    if !index.contains(name) {
      return Err(model_error(MissingField, "missing tsv column: " + name))
    }
  }

  let reserved = reserved_tsv_columns()
  let out : Array[PdfLayoutFeature] = []
  for row_index = 1; row_index < lines.length(); row_index = row_index + 1 {
    let cols = split_tsv_line(lines[row_index])
    if cols.length() != header.length() {
      return Err(
        model_error(
          InvalidValue,
          "row column mismatch at line " + (row_index + 1).to_string(),
        ),
      )
    }

    let feature_values : Map[String, Double] = Map::new()
    for col_index = 0; col_index < header.length(); col_index = col_index + 1 {
      let name = header[col_index]
      if reserved.contains(name) {
        continue
      }
      let raw = cols[col_index].trim().to_owned()
      if raw == "" {
        feature_values.set(name, 0.0)
        continue
      }
      match try_parse_number(raw) {
        Some(v) => feature_values.set(name, v)
        None =>
          return Err(
            model_error(
              InvalidValue,
              "non-numeric feature " +
              name +
              " at line " +
              (row_index + 1).to_string(),
            ),
          )
      }
    }

    let record_kind = match
      parse_record_kind_name(
        cols[index.get("record_kind").unwrap_or(0)].trim().to_owned(),
      ) {
      Some(v) => v
      None =>
        return Err(
          model_error(
            InvalidValue,
            "invalid record_kind at line " + (row_index + 1).to_string(),
          ),
        )
    }

    let page_index = match
      parse_one_based_tsv_int(cols[index.get("page_index").unwrap_or(0)]) {
      Some(v) => v
      None =>
        return Err(
          model_error(
            InvalidValue,
            "invalid page_index at line " + (row_index + 1).to_string(),
          ),
        )
    }
    let block_index = match
      parse_zero_based_tsv_int(cols[index.get("block_index").unwrap_or(0)]) {
      Some(v) => v
      None =>
        return Err(
          model_error(
            InvalidValue,
            "invalid block_index at line " + (row_index + 1).to_string(),
          ),
        )
    }
    let line_index = match
      parse_zero_based_tsv_int(cols[index.get("line_index").unwrap_or(0)]) {
      Some(v) => v
      None =>
        return Err(
          model_error(
            InvalidValue,
            "invalid line_index at line " + (row_index + 1).to_string(),
          ),
        )
    }

    out.push(
      make_pdf_layout_feature(
        cols[index.get("sample_id").unwrap_or(0)],
        cols[index.get("source_path").unwrap_or(0)],
        record_kind,
        page_index,
        block_index,
        line_index,
        parse_optional_one_based_tsv_int(
          cols[index.get("next_page_index").unwrap_or(0)],
        ),
        parse_optional_zero_based_tsv_int(
          cols[index.get("next_block_index").unwrap_or(0)],
        ),
        parse_optional_zero_based_tsv_int(
          cols[index.get("next_line_index").unwrap_or(0)],
        ),
        cols[index.get("text").unwrap_or(0)],
        optional_tsv_text(cols[index.get("label").unwrap_or(0)]),
        optional_tsv_text(
          cols[index.get("notes").unwrap_or(header.length() - 1)],
        ),
        feature_values,
      ),
    )
  }

  Ok(out)
}

///|
pub fn infer_pdf_layout_features_tsv(
  model_text : String,
  feature_tsv : String,
) -> Result[String, PdfLayoutModelError] {
  let model = match parse_pdf_layout_model_json(model_text) {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let features = match parse_pdf_layout_features_tsv(feature_tsv) {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let decisions = match classify_pdf_layout_features(model, features) {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  Ok(render_pdf_layout_decisions_tsv(features, decisions))
}

///|
pub fn render_pdf_layout_decisions_tsv(
  features : Array[PdfLayoutFeature],
  decisions : Array[PdfLayoutModelDecision],
) -> String {
  let lines : Array[String] = [
    [
      "sample_id", "source_path", "record_kind", "page_index", "block_index", "line_index",
      "next_page_index", "next_block_index", "next_line_index", "predicted_label",
      "score", "confidence", "threshold", "accepted", "gold_label", "reasons", "text",
    ].join("\t"),
  ]

  for i = 0; i < decisions.length(); i = i + 1 {
    let feature = features[i]
    let decision = decisions[i]
    lines.push(
      [
        tsv_escape(feature.sample_id),
        tsv_escape(feature.source_path),
        pdf_layout_record_kind_name(feature.record_kind),
        (feature.page_index + 1).to_string(),
        feature.block_index.to_string(),
        feature.line_index.to_string(),
        int_opt_tsv(feature.next_page_index, true),
        int_opt_tsv(feature.next_block_index, false),
        int_opt_tsv(feature.next_line_index, false),
        tsv_escape(decision.label),
        decision.score.to_string(),
        decision.confidence.to_string(),
        decision.threshold.to_string(),
        if decision.accepted {
          "true"
        } else {
          "false"
        },
        tsv_escape(
          match feature.label {
            Some(label) => label
            None => ""
          },
        ),
        tsv_escape(decision.reasons.join(",")),
        tsv_escape(feature.text),
      ].join("\t"),
    )
  }

  lines.join("\n") + "\n"
}

///|
priv enum PdfLayoutExportKind {
  BlockOnly
  BoundaryOnly
  All
} derive(Eq)

///|
fn parse_layout_export_kind(raw : String) -> PdfLayoutExportKind {
  let normalized = raw.trim().to_owned().to_lower()
  if normalized == "boundary" {
    PdfLayoutExportKind::BoundaryOnly
  } else if normalized == "all" {
    PdfLayoutExportKind::All
  } else {
    PdfLayoutExportKind::BlockOnly
  }
}

///|
fn parse_record_kind_name(raw : String) -> PdfLayoutRecordKind? {
  let normalized = raw.trim().to_owned().to_lower()
  if normalized == "line" {
    Some(PdfLayoutRecordKind::Line)
  } else if normalized == "block" {
    Some(PdfLayoutRecordKind::Block)
  } else if normalized == "boundary" {
    Some(PdfLayoutRecordKind::Boundary)
  } else {
    None
  }
}

///|
fn build_repeated_text_counts(doc : PdfConvertDocument) -> Map[String, Int] {
  let counts : Map[String, Int] = Map::new()
  for page in doc.pages {
    for block in page.blocks {
      let key = normalize_noise_key(block.text)
      if key == "" {
        continue
      }
      let prev = counts.get(key).unwrap_or(0)
      counts.set(key, prev + 1)
    }
  }
  counts
}

///|
fn repeated_text_score(
  counts : Map[String, Int],
  text : String,
  page_count : Int,
) -> Double {
  let key = normalize_noise_key(text)
  if key == "" {
    return 0.0
  }
  let count = counts.get(key).unwrap_or(0)
  if count <= 1 || page_count <= 0 {
    return 0.0
  }
  count.to_double() / page_count.to_double()
}

///|
fn nearest_image_distance(
  images : Array[PdfConvertImage],
  block_box : @model.PdfRect,
) -> Double? {
  if images.is_empty() {
    return None
  }

  let mut best : Double? = None
  for image in images {
    let distance = rect_vertical_distance(block_box, image._bbox)
    match best {
      Some(cur) => if distance < cur { best = Some(distance) }
      None => best = Some(distance)
    }
  }
  best
}

///|
fn rect_vertical_distance(a : @model.PdfRect, b : @model.PdfRect) -> Double {
  if a.y1 < b.y0 {
    b.y0 - a.y1
  } else if b.y1 < a.y0 {
    a.y0 - b.y1
  } else {
    0.0
  }
}

///|
fn block_feature_notes(block : PdfConvertBlock) -> String {
  let tags : Array[String] = []
  if block.is_heading_candidate {
    tags.push("heading_candidate")
  }
  if block.is_noise_candidate {
    tags.push("page_number_candidate")
  }
  if block.is_header_footer_candidate {
    tags.push("header_footer_candidate")
  }
  if block.is_artifact_candidate {
    tags.push("artifact_candidate")
  }
  if block.is_caption_candidate {
    tags.push("caption_candidate")
  }
  if block.is_table_cell_candidate {
    tags.push("table_cell_candidate")
  }
  tags.join(",")
}

///|
fn header_index(header : Array[String]) -> Map[String, Int] {
  let out : Map[String, Int] = Map::new()
  for i = 0; i < header.length(); i = i + 1 {
    out.set(header[i], i)
  }
  out
}

///|
fn reserved_tsv_columns() -> Array[String] {
  [
    "sample_id", "source_path", "record_kind", "page_index", "block_index", "line_index",
    "next_page_index", "next_block_index", "next_line_index", "text", "label", "notes",
  ]
}

///|
fn parse_one_based_tsv_int(raw : String) -> Int? {
  match parse_optional_zero_based_tsv_int(raw) {
    Some(v) => Some(v - 1)
    None => None
  }
}

///|
fn parse_zero_based_tsv_int(raw : String) -> Int? {
  try @string.parse_int(raw.trim().to_owned()) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn parse_optional_one_based_tsv_int(raw : String) -> Int? {
  let trimmed = raw.trim().to_owned()
  if trimmed == "" {
    return None
  }
  match parse_zero_based_tsv_int(trimmed) {
    Some(v) => Some(v - 1)
    None => None
  }
}

///|
fn parse_optional_zero_based_tsv_int(raw : String) -> Int? {
  let trimmed = raw.trim().to_owned()
  if trimmed == "" {
    return None
  }
  parse_zero_based_tsv_int(trimmed)
}

///|
fn optional_tsv_text(raw : String) -> String? {
  let trimmed = raw.trim().to_owned()
  if trimmed == "" {
    None
  } else {
    Some(raw)
  }
}

///|
fn split_tsv_line(line : String) -> Array[String] {
  let out : Array[String] = []
  for item in line.split("\t") {
    out.push(item.to_owned())
  }
  out
}
