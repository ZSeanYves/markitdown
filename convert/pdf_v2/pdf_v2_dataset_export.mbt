///|
pub(all) struct PdfV2DatasetExport {
  schema_version : String
  doc_id : String
  text_flow_rows : Array[PdfV2DatasetTextFlowRow]
  boundary_rows : Array[PdfV2DatasetBoundaryRow]
  artifact_rows : Array[PdfV2DatasetArtifactRow]
  adjacency_rows : Array[PdfV2DatasetAdjacencyRow]
}

///|
pub(all) struct PdfV2DatasetTextFlowRow {
  schema_version : String
  doc_id : String
  row_id : String
  task : String
  split : String
  page_index : Int?
  block_index : Int?
  flow_index : Int
  candidate_id : String
  candidate_text : String
  normalized_text : String
  line_count : Int
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
  risk_tags : Array[String]
  current_rule_decision : String
  current_rule_confidence : Double
  weak_label : String
  gold_label : String
  label_source : String
}

///|
pub(all) struct PdfV2DatasetBoundaryRow {
  schema_version : String
  doc_id : String
  row_id : String
  task : String
  split : String
  prev_page_index : Int?
  next_page_index : Int?
  prev_candidate_id : String
  next_candidate_id : String
  prev_text : String
  next_text : String
  same_page : Bool
  cross_page : Bool
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
  risk_tags : Array[String]
  current_rule_decision : String
  current_rule_confidence : Double
  weak_label : String
  gold_label : String
  label_source : String
}

///|
pub(all) struct PdfV2DatasetArtifactRow {
  schema_version : String
  doc_id : String
  row_id : String
  task : String
  split : String
  page_index : Int?
  candidate_id : String
  text : String
  normalized_text : String
  artifact_kind : String
  position_band : String
  page_indices : Array[Int]
  repeat_count : Int
  confidence : Double
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
  risk_tags : Array[String]
  current_rule_decision : String
  current_rule_confidence : Double
  weak_label : String
  gold_label : String
  label_source : String
}

///|
pub(all) struct PdfV2DatasetAdjacencyRow {
  schema_version : String
  doc_id : String
  row_id : String
  task : String
  split : String
  page_index : Int?
  object_kind : String
  object_ref : String
  asset_ref : String
  candidate_id : String
  nearby_text : String
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
  risk_tags : Array[String]
  current_rule_decision : String
  current_rule_confidence : Double
  weak_label : String
  gold_label : String
  label_source : String
  relation : String
  source_order_delta : String
  bbox_distance : String
}

///|
pub(all) struct PdfV2DatasetAuditCounter {
  key : String
  count : Int
}

///|
pub(all) struct PdfV2DatasetExportAudit {
  schema_version : String
  total_rows : Int
  text_flow_row_count : Int
  boundary_row_count : Int
  artifact_row_count : Int
  adjacency_row_count : Int
  empty_gold_label_count : Int
  weak_label_count : Int
  rows_with_unknown_none_or_empty_key_fields : Int
  rows_with_source_refs : Int
  geometry_unknown_row_count : Int
  cross_page_candidate_count : Int
  heading_short_text_count : Int
  image_nearby_text_count : Int
  table_candidate_count : Int
  semantic_fallback_paragraph_count : Int
  rows_by_family : Array[PdfV2DatasetAuditCounter]
  rows_by_task : Array[PdfV2DatasetAuditCounter]
  rows_by_label_source : Array[PdfV2DatasetAuditCounter]
  rows_by_split : Array[PdfV2DatasetAuditCounter]
  risk_tag_distribution : Array[PdfV2DatasetAuditCounter]
}

///|
priv struct PdfV2DatasetFlatRow {
  schema_version : String
  row_family : String
  doc_id : String
  row_id : String
  task : String
  split : String
  page_index : String
  candidate_id : String
  prev_candidate_id : String
  next_candidate_id : String
  object_kind : String
  object_ref : String
  asset_ref : String
  text : String
  normalized_text : String
  nearby_text : String
  current_rule_decision : String
  current_rule_confidence : String
  weak_label : String
  gold_label : String
  label_source : String
  risk_tags : Array[String]
  reason_tags : Array[String]
  source_refs : Array[String]
  extra : String
}

///|
pub fn pdf_v2_dataset_export_schema_version() -> String {
  "pdf_v2_dataset_export_v1"
}

///|
pub fn pdf_v2_export_dataset_from_pipeline_output(
  output : PdfV2ConvertPipelineOutput,
  doc_id : String,
) -> PdfV2DatasetExport {
  pdf_v2_export_dataset_from_fact_arrays(
    doc_id,
    output.text_flow_candidates,
    output.table_candidates,
    output.link_candidates,
    output.image_candidates,
    output.inline_image_candidates,
  )
}

///|
pub fn pdf_v2_export_dataset_from_fact_arrays(
  doc_id : String,
  text_flow_candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  table_candidates : Array[@pdfv2.PdfV2TableCandidate],
  link_candidates : Array[@pdfv2.PdfV2LinkCandidate],
  image_candidates : Array[@pdfv2.PdfV2ImageCandidate],
  inline_image_candidates : Array[@pdfv2.PdfV2InlineImageCandidate],
) -> PdfV2DatasetExport {
  let schema_version = pdf_v2_dataset_export_schema_version()
  let safe_doc_id = pdf_v2_dataset_safe_row_id_part(doc_id)
  let semantic_blocks = pdf_v2_semantic_blocks_from_candidates(
    text_flow_candidates,
    default_pdf_v2_product_bridge_options(),
  )
  let text_flow_rows = pdf_v2_dataset_text_flow_rows(
    schema_version, doc_id, safe_doc_id, text_flow_candidates, semantic_blocks,
  )
  let boundary_rows = pdf_v2_dataset_boundary_rows(
    schema_version, doc_id, safe_doc_id, text_flow_candidates,
  )
  let artifact_rows = pdf_v2_dataset_artifact_rows(
    schema_version, doc_id, safe_doc_id, text_flow_candidates,
  )
  let adjacency_rows = pdf_v2_dataset_adjacency_rows(
    schema_version, doc_id, safe_doc_id, table_candidates, link_candidates, image_candidates,
    inline_image_candidates,
  )
  {
    schema_version,
    doc_id,
    text_flow_rows,
    boundary_rows,
    artifact_rows,
    adjacency_rows,
  }
}

///|
pub fn pdf_v2_dataset_export_to_jsonl(
  dataset_export : PdfV2DatasetExport,
) -> String {
  let rows = pdf_v2_dataset_flat_rows(dataset_export)
  let lines : Array[String] = []
  for row in rows {
    lines.push(pdf_v2_dataset_flat_row_to_json(row))
  }
  if lines.length() == 0 {
    ""
  } else {
    lines.join("\n") + "\n"
  }
}

///|
pub fn pdf_v2_dataset_export_to_tsv(
  dataset_export : PdfV2DatasetExport,
) -> String {
  let rows = pdf_v2_dataset_flat_rows(dataset_export)
  let lines : Array[String] = [pdf_v2_dataset_tsv_header().join("\t")]
  for row in rows {
    lines.push(pdf_v2_dataset_flat_row_to_tsv(row))
  }
  lines.join("\n") + "\n"
}

///|
pub fn pdf_v2_dataset_export_audit(
  dataset_export : PdfV2DatasetExport,
) -> PdfV2DatasetExportAudit {
  let rows = pdf_v2_dataset_flat_rows(dataset_export)
  let rows_by_family : Array[PdfV2DatasetAuditCounter] = []
  let rows_by_task : Array[PdfV2DatasetAuditCounter] = []
  let rows_by_label_source : Array[PdfV2DatasetAuditCounter] = []
  let rows_by_split : Array[PdfV2DatasetAuditCounter] = []
  let risk_tag_distribution : Array[PdfV2DatasetAuditCounter] = []
  let mut empty_gold_label_count = 0
  let mut weak_label_count = 0
  let mut rows_with_unknown_none_or_empty_key_fields = 0
  let mut rows_with_source_refs = 0
  let mut geometry_unknown_row_count = 0
  let mut cross_page_candidate_count = 0
  let mut heading_short_text_count = 0
  let mut image_nearby_text_count = 0
  let mut table_candidate_count = 0
  let mut semantic_fallback_paragraph_count = 0
  for row in rows {
    pdf_v2_dataset_audit_add_counter(rows_by_family, row.row_family)
    pdf_v2_dataset_audit_add_counter(rows_by_task, row.task)
    pdf_v2_dataset_audit_add_counter(rows_by_label_source, row.label_source)
    pdf_v2_dataset_audit_add_counter(rows_by_split, row.split)
    if row.gold_label == "" {
      empty_gold_label_count = empty_gold_label_count + 1
    }
    if row.weak_label != "" {
      weak_label_count = weak_label_count + 1
    }
    if pdf_v2_dataset_flat_row_has_unknown_none_or_empty_key_field(row) {
      rows_with_unknown_none_or_empty_key_fields = rows_with_unknown_none_or_empty_key_fields +
        1
    }
    if row.source_refs.length() > 0 {
      rows_with_source_refs = rows_with_source_refs + 1
    }
    if pdf_v2_dataset_flat_row_has_geometry_unknown(row) {
      geometry_unknown_row_count = geometry_unknown_row_count + 1
    }
    for tag in row.risk_tags {
      pdf_v2_dataset_audit_add_counter(risk_tag_distribution, tag)
      if tag == "cross_page_candidate" {
        cross_page_candidate_count = cross_page_candidate_count + 1
      } else if tag == "heading_short_text" {
        heading_short_text_count = heading_short_text_count + 1
      } else if tag == "image_nearby_text" {
        image_nearby_text_count = image_nearby_text_count + 1
      } else if tag == "table_candidate" {
        table_candidate_count = table_candidate_count + 1
      } else if tag == "semantic_fallback_paragraph" {
        semantic_fallback_paragraph_count = semantic_fallback_paragraph_count +
          1
      }
    }
  }
  {
    schema_version: dataset_export.schema_version,
    total_rows: rows.length(),
    text_flow_row_count: dataset_export.text_flow_rows.length(),
    boundary_row_count: dataset_export.boundary_rows.length(),
    artifact_row_count: dataset_export.artifact_rows.length(),
    adjacency_row_count: dataset_export.adjacency_rows.length(),
    empty_gold_label_count,
    weak_label_count,
    rows_with_unknown_none_or_empty_key_fields,
    rows_with_source_refs,
    geometry_unknown_row_count,
    cross_page_candidate_count,
    heading_short_text_count,
    image_nearby_text_count,
    table_candidate_count,
    semantic_fallback_paragraph_count,
    rows_by_family,
    rows_by_task,
    rows_by_label_source,
    rows_by_split,
    risk_tag_distribution,
  }
}

///|
fn pdf_v2_dataset_text_flow_rows(
  schema_version : String,
  doc_id : String,
  safe_doc_id : String,
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  semantic_blocks : Array[PdfV2SemanticBlock],
) -> Array[PdfV2DatasetTextFlowRow] {
  let rows : Array[PdfV2DatasetTextFlowRow] = []
  for i in 0..<candidates.length() {
    let candidate = candidates[i]
    let semantic_block = if i < semantic_blocks.length() {
      Some(semantic_blocks[i])
    } else {
      None
    }
    let current_rule_decision = match semantic_block {
      Some(block) => pdf_v2_dataset_semantic_kind_name(block.kind)
      None => ""
    }
    let current_rule_confidence = match semantic_block {
      Some(block) => block.decision.confidence
      None => 0.0
    }
    let weak_label = current_rule_decision
    let label_source = if weak_label == "" { "none" } else { "rule_decision" }
    let risk_tags = pdf_v2_dataset_text_flow_risk_tags(
      candidate, semantic_block,
    )
    rows.push({
      schema_version,
      doc_id,
      row_id: pdf_v2_dataset_row_id(
        "text_flow",
        safe_doc_id,
        candidate.page_index,
        "c" + i.to_string(),
      ),
      task: "text_flow",
      split: "unknown",
      page_index: candidate.page_index,
      block_index: candidate.block_index,
      flow_index: candidate.flow_index,
      candidate_id: pdf_v2_dataset_candidate_id(candidate),
      candidate_text: candidate.text,
      normalized_text: candidate.normalized_text,
      line_count: if candidate.line_indices.length() > 0 {
        candidate.line_indices.length()
      } else if candidate.line_signals.length() > 0 {
        candidate.line_signals.length()
      } else {
        candidate.boundary_signal.line_count
      },
      source_refs: candidate.source_refs,
      reason_tags: pdf_v2_dataset_merge_tags(
        candidate.reason_tags,
        candidate.boundary_signal.reason_tags,
      ),
      risk_tags,
      current_rule_decision,
      current_rule_confidence,
      weak_label,
      gold_label: "",
      label_source,
    })
  }
  rows
}

///|
fn pdf_v2_dataset_boundary_rows(
  schema_version : String,
  doc_id : String,
  safe_doc_id : String,
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
) -> Array[PdfV2DatasetBoundaryRow] {
  let rows : Array[PdfV2DatasetBoundaryRow] = []
  if candidates.length() < 2 {
    return rows
  }
  for i in 0..<(candidates.length() - 1) {
    let prev = candidates[i]
    let next = candidates[i + 1]
    let same_page = prev.page_index == next.page_index &&
      prev.page_index is Some(_)
    let cross_page = match (prev.page_index, next.page_index) {
      (Some(left), Some(right)) => left != right
      _ => false
    }
    let risk_tags = if cross_page { ["cross_page_candidate"] } else { [] }
    rows.push({
      schema_version,
      doc_id,
      row_id: pdf_v2_dataset_row_id(
        "boundary",
        safe_doc_id,
        prev.page_index,
        "b" + i.to_string(),
      ),
      task: "boundary",
      split: "unknown",
      prev_page_index: prev.page_index,
      next_page_index: next.page_index,
      prev_candidate_id: pdf_v2_dataset_candidate_id(prev),
      next_candidate_id: pdf_v2_dataset_candidate_id(next),
      prev_text: prev.normalized_text,
      next_text: next.normalized_text,
      same_page,
      cross_page,
      source_refs: pdf_v2_dataset_source_refs_for_pair(
        prev.source_refs,
        next.source_refs,
      ),
      reason_tags: ["adjacent_text_flow_pair"],
      risk_tags,
      current_rule_decision: "",
      current_rule_confidence: 0.0,
      weak_label: "",
      gold_label: "",
      label_source: "none",
    })
  }
  rows
}

///|
fn pdf_v2_dataset_artifact_rows(
  schema_version : String,
  doc_id : String,
  safe_doc_id : String,
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
) -> Array[PdfV2DatasetArtifactRow] {
  let rows : Array[PdfV2DatasetArtifactRow] = []
  let seen_keys : Array[String] = []
  for candidate in candidates {
    for artifact in candidate.artifact_refs {
      let key = pdf_v2_dataset_artifact_key(artifact)
      if seen_keys.contains(key) {
        continue
      }
      seen_keys.push(key)
      let page_index = pdf_v2_dataset_first_page_index(artifact.page_indices)
      let index = rows.length()
      let artifact_kind = pdf_v2_dataset_artifact_kind_name(artifact.kind)
      let risk_tags = if artifact.repeat_count < 2 {
        ["artifact_repeat_low"]
      } else {
        []
      }
      rows.push({
        schema_version,
        doc_id,
        row_id: pdf_v2_dataset_row_id(
          "artifact",
          safe_doc_id,
          page_index,
          "a" + index.to_string(),
        ),
        task: "artifact",
        split: "unknown",
        page_index,
        candidate_id: "artifact:" + index.to_string(),
        text: artifact.normalized_text,
        normalized_text: artifact.normalized_text,
        artifact_kind,
        position_band: pdf_v2_dataset_position_band_name(artifact.position_band),
        page_indices: artifact.page_indices,
        repeat_count: artifact.repeat_count,
        confidence: artifact.confidence,
        source_refs: artifact.source_refs,
        reason_tags: artifact.reason_tags,
        risk_tags,
        current_rule_decision: "",
        current_rule_confidence: 0.0,
        weak_label: "",
        gold_label: "",
        label_source: "none",
      })
    }
  }
  rows
}

///|
fn pdf_v2_dataset_adjacency_rows(
  schema_version : String,
  doc_id : String,
  safe_doc_id : String,
  table_candidates : Array[@pdfv2.PdfV2TableCandidate],
  link_candidates : Array[@pdfv2.PdfV2LinkCandidate],
  image_candidates : Array[@pdfv2.PdfV2ImageCandidate],
  inline_image_candidates : Array[@pdfv2.PdfV2InlineImageCandidate],
) -> Array[PdfV2DatasetAdjacencyRow] {
  let rows : Array[PdfV2DatasetAdjacencyRow] = []
  for table in table_candidates {
    let index = rows.length()
    let nearby_text = if table.rows.length() > 0 {
      table.rows[0].join(" | ")
    } else {
      ""
    }
    rows.push(
      pdf_v2_dataset_adjacency_row(
        schema_version,
        doc_id,
        safe_doc_id,
        table.page_index,
        "adj" + index.to_string(),
        "table",
        "",
        "",
        "",
        nearby_text,
        table.source_refs,
        table.reason_tags,
        ["table_candidate"],
        "table_candidate",
        "",
        "unknown",
        "unknown",
      ),
    )
  }
  for image in image_candidates {
    let index = rows.length()
    let caption_text = match image.caption {
      Some(caption) => caption.caption_text
      None => ""
    }
    let relation = match image.caption {
      Some(caption) =>
        pdf_v2_dataset_image_caption_relation_name(caption.relation)
      None => "unknown"
    }
    let asset_ref = match image.asset {
      Some(asset) =>
        match asset.rel_path {
          Some(path) => path
          None => ""
        }
      None => ""
    }
    let risk_tags = if caption_text == "" { [] } else { ["image_nearby_text"] }
    rows.push(
      pdf_v2_dataset_adjacency_row(
        schema_version,
        doc_id,
        safe_doc_id,
        image.page_index,
        "adj" + index.to_string(),
        "image",
        pdf_v2_dataset_option_string_or_unknown(image.object_ref),
        asset_ref,
        "",
        caption_text,
        [image.source_ref],
        image.reason_tags,
        risk_tags,
        relation,
        "",
        "unknown",
        "unknown",
      ),
    )
  }
  for inline_image in inline_image_candidates {
    let index = rows.length()
    let caption_text = match inline_image.caption {
      Some(caption) => caption.caption_text
      None => ""
    }
    let relation = match inline_image.caption {
      Some(caption) =>
        pdf_v2_dataset_image_caption_relation_name(caption.relation)
      None => "unknown"
    }
    let asset_ref = match inline_image.asset {
      Some(asset) =>
        match asset.rel_path {
          Some(path) => path
          None => ""
        }
      None => ""
    }
    let risk_tags = if caption_text == "" { [] } else { ["image_nearby_text"] }
    rows.push(
      pdf_v2_dataset_adjacency_row(
        schema_version,
        doc_id,
        safe_doc_id,
        inline_image.page_index,
        "adj" + index.to_string(),
        "inline_image",
        "unknown",
        asset_ref,
        "",
        caption_text,
        [inline_image.source_ref],
        inline_image.reason_tags,
        risk_tags,
        relation,
        "",
        "unknown",
        "unknown",
      ),
    )
  }
  for link in link_candidates {
    let index = rows.length()
    let nearby_text = match link.uri {
      Some(uri) => uri
      None =>
        match link.dest {
          Some(dest) => dest
          None => ""
        }
    }
    rows.push(
      pdf_v2_dataset_adjacency_row(
        schema_version,
        doc_id,
        safe_doc_id,
        link.page_index,
        "adj" + index.to_string(),
        "link",
        pdf_v2_dataset_option_string_or_unknown(link.object_ref),
        "",
        "",
        nearby_text,
        [link.source_ref],
        link.reason_tags,
        ["link_annotation_nearby"],
        "link_annotation",
        "",
        "unknown",
        "unknown",
      ),
    )
  }
  rows
}

///|
fn pdf_v2_dataset_adjacency_row(
  schema_version : String,
  doc_id : String,
  safe_doc_id : String,
  page_index : Int?,
  suffix : String,
  object_kind : String,
  object_ref : String,
  asset_ref : String,
  candidate_id : String,
  nearby_text : String,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  reason_tags : Array[String],
  risk_tags : Array[String],
  relation : String,
  weak_label : String,
  source_order_delta : String,
  bbox_distance : String,
) -> PdfV2DatasetAdjacencyRow {
  {
    schema_version,
    doc_id,
    row_id: pdf_v2_dataset_row_id("adjacency", safe_doc_id, page_index, suffix),
    task: "adjacency",
    split: "unknown",
    page_index,
    object_kind,
    object_ref,
    asset_ref,
    candidate_id,
    nearby_text,
    source_refs,
    reason_tags,
    risk_tags,
    current_rule_decision: "",
    current_rule_confidence: 0.0,
    weak_label,
    gold_label: "",
    label_source: if weak_label == "" {
      "none"
    } else {
      "parser_fact"
    },
    relation,
    source_order_delta,
    bbox_distance,
  }
}

///|
fn pdf_v2_dataset_flat_rows(
  dataset_export : PdfV2DatasetExport,
) -> Array[PdfV2DatasetFlatRow] {
  let rows : Array[PdfV2DatasetFlatRow] = []
  for row in dataset_export.text_flow_rows {
    rows.push(pdf_v2_dataset_flat_text_flow_row(row))
  }
  for row in dataset_export.boundary_rows {
    rows.push(pdf_v2_dataset_flat_boundary_row(row))
  }
  for row in dataset_export.artifact_rows {
    rows.push(pdf_v2_dataset_flat_artifact_row(row))
  }
  for row in dataset_export.adjacency_rows {
    rows.push(pdf_v2_dataset_flat_adjacency_row(row))
  }
  rows
}

///|
fn pdf_v2_dataset_flat_text_flow_row(
  row : PdfV2DatasetTextFlowRow,
) -> PdfV2DatasetFlatRow {
  {
    schema_version: row.schema_version,
    row_family: "TextFlowRow",
    doc_id: row.doc_id,
    row_id: row.row_id,
    task: row.task,
    split: row.split,
    page_index: pdf_v2_dataset_optional_int(row.page_index),
    candidate_id: row.candidate_id,
    prev_candidate_id: "",
    next_candidate_id: "",
    object_kind: "",
    object_ref: "",
    asset_ref: "",
    text: row.candidate_text,
    normalized_text: row.normalized_text,
    nearby_text: "",
    current_rule_decision: row.current_rule_decision,
    current_rule_confidence: row.current_rule_confidence.to_string(),
    weak_label: row.weak_label,
    gold_label: row.gold_label,
    label_source: row.label_source,
    risk_tags: row.risk_tags,
    reason_tags: row.reason_tags,
    source_refs: pdf_v2_dataset_source_ref_strings(row.source_refs),
    extra: [
      "block_index=" + pdf_v2_dataset_optional_int(row.block_index),
      "flow_index=" + row.flow_index.to_string(),
      "line_count=" + row.line_count.to_string(),
    ].join(";"),
  }
}

///|
fn pdf_v2_dataset_flat_boundary_row(
  row : PdfV2DatasetBoundaryRow,
) -> PdfV2DatasetFlatRow {
  {
    schema_version: row.schema_version,
    row_family: "BoundaryRow",
    doc_id: row.doc_id,
    row_id: row.row_id,
    task: row.task,
    split: row.split,
    page_index: pdf_v2_dataset_optional_int(row.prev_page_index),
    candidate_id: "",
    prev_candidate_id: row.prev_candidate_id,
    next_candidate_id: row.next_candidate_id,
    object_kind: "",
    object_ref: "",
    asset_ref: "",
    text: row.prev_text,
    normalized_text: row.prev_text,
    nearby_text: row.next_text,
    current_rule_decision: row.current_rule_decision,
    current_rule_confidence: row.current_rule_confidence.to_string(),
    weak_label: row.weak_label,
    gold_label: row.gold_label,
    label_source: row.label_source,
    risk_tags: row.risk_tags,
    reason_tags: row.reason_tags,
    source_refs: pdf_v2_dataset_source_ref_strings(row.source_refs),
    extra: [
      "next_page_index=" + pdf_v2_dataset_optional_int(row.next_page_index),
      "same_page=" + pdf_v2_dataset_bool(row.same_page),
      "cross_page=" + pdf_v2_dataset_bool(row.cross_page),
    ].join(";"),
  }
}

///|
fn pdf_v2_dataset_flat_artifact_row(
  row : PdfV2DatasetArtifactRow,
) -> PdfV2DatasetFlatRow {
  {
    schema_version: row.schema_version,
    row_family: "ArtifactRow",
    doc_id: row.doc_id,
    row_id: row.row_id,
    task: row.task,
    split: row.split,
    page_index: pdf_v2_dataset_optional_int(row.page_index),
    candidate_id: row.candidate_id,
    prev_candidate_id: "",
    next_candidate_id: "",
    object_kind: "page_artifact",
    object_ref: "",
    asset_ref: "",
    text: row.text,
    normalized_text: row.normalized_text,
    nearby_text: "",
    current_rule_decision: row.current_rule_decision,
    current_rule_confidence: row.current_rule_confidence.to_string(),
    weak_label: row.weak_label,
    gold_label: row.gold_label,
    label_source: row.label_source,
    risk_tags: row.risk_tags,
    reason_tags: row.reason_tags,
    source_refs: pdf_v2_dataset_source_ref_strings(row.source_refs),
    extra: [
      "artifact_kind=" + row.artifact_kind,
      "position_band=" + row.position_band,
      "page_indices=" + pdf_v2_dataset_ints(row.page_indices),
      "repeat_count=" + row.repeat_count.to_string(),
      "confidence=" + row.confidence.to_string(),
    ].join(";"),
  }
}

///|
fn pdf_v2_dataset_flat_adjacency_row(
  row : PdfV2DatasetAdjacencyRow,
) -> PdfV2DatasetFlatRow {
  {
    schema_version: row.schema_version,
    row_family: "AdjacencyRow",
    doc_id: row.doc_id,
    row_id: row.row_id,
    task: row.task,
    split: row.split,
    page_index: pdf_v2_dataset_optional_int(row.page_index),
    candidate_id: row.candidate_id,
    prev_candidate_id: "",
    next_candidate_id: "",
    object_kind: row.object_kind,
    object_ref: row.object_ref,
    asset_ref: row.asset_ref,
    text: "",
    normalized_text: "",
    nearby_text: row.nearby_text,
    current_rule_decision: row.current_rule_decision,
    current_rule_confidence: row.current_rule_confidence.to_string(),
    weak_label: row.weak_label,
    gold_label: row.gold_label,
    label_source: row.label_source,
    risk_tags: row.risk_tags,
    reason_tags: row.reason_tags,
    source_refs: pdf_v2_dataset_source_ref_strings(row.source_refs),
    extra: [
      "relation=" + row.relation,
      "source_order_delta=" + row.source_order_delta,
      "bbox_distance=" + row.bbox_distance,
    ].join(";"),
  }
}

///|
fn pdf_v2_dataset_tsv_header() -> Array[String] {
  [
    "schema_version", "row_family", "doc_id", "row_id", "task", "split", "page_index",
    "candidate_id", "prev_candidate_id", "next_candidate_id", "object_kind", "object_ref",
    "asset_ref", "text", "normalized_text", "nearby_text", "current_rule_decision",
    "current_rule_confidence", "weak_label", "gold_label", "label_source", "risk_tags",
    "reason_tags", "source_refs", "extra",
  ]
}

///|
fn pdf_v2_dataset_flat_row_to_tsv(row : PdfV2DatasetFlatRow) -> String {
  [
    row.schema_version,
    row.row_family,
    row.doc_id,
    row.row_id,
    row.task,
    row.split,
    row.page_index,
    row.candidate_id,
    row.prev_candidate_id,
    row.next_candidate_id,
    row.object_kind,
    row.object_ref,
    row.asset_ref,
    row.text,
    row.normalized_text,
    row.nearby_text,
    row.current_rule_decision,
    row.current_rule_confidence,
    row.weak_label,
    row.gold_label,
    row.label_source,
    pdf_v2_dataset_tsv_list(row.risk_tags),
    pdf_v2_dataset_tsv_list(row.reason_tags),
    pdf_v2_dataset_tsv_list(row.source_refs),
    row.extra,
  ]
  .map(pdf_v2_dataset_escape_tsv)
  .join("\t")
}

///|
fn pdf_v2_dataset_flat_row_to_json(row : PdfV2DatasetFlatRow) -> String {
  let fields : Array[String] = [
    pdf_v2_dataset_json_field("schema_version", row.schema_version),
    pdf_v2_dataset_json_field("row_family", row.row_family),
    pdf_v2_dataset_json_field("doc_id", row.doc_id),
    pdf_v2_dataset_json_field("row_id", row.row_id),
    pdf_v2_dataset_json_field("task", row.task),
    pdf_v2_dataset_json_field("split", row.split),
    pdf_v2_dataset_json_field("page_index", row.page_index),
    pdf_v2_dataset_json_field("candidate_id", row.candidate_id),
    pdf_v2_dataset_json_field("prev_candidate_id", row.prev_candidate_id),
    pdf_v2_dataset_json_field("next_candidate_id", row.next_candidate_id),
    pdf_v2_dataset_json_field("object_kind", row.object_kind),
    pdf_v2_dataset_json_field("object_ref", row.object_ref),
    pdf_v2_dataset_json_field("asset_ref", row.asset_ref),
    pdf_v2_dataset_json_field("text", row.text),
    pdf_v2_dataset_json_field("normalized_text", row.normalized_text),
    pdf_v2_dataset_json_field("nearby_text", row.nearby_text),
    pdf_v2_dataset_json_field(
      "current_rule_decision",
      row.current_rule_decision,
    ),
    pdf_v2_dataset_json_field(
      "current_rule_confidence",
      row.current_rule_confidence,
    ),
    pdf_v2_dataset_json_field("weak_label", row.weak_label),
    pdf_v2_dataset_json_field("gold_label", row.gold_label),
    pdf_v2_dataset_json_field("label_source", row.label_source),
    pdf_v2_dataset_json_array_field("risk_tags", row.risk_tags),
    pdf_v2_dataset_json_array_field("reason_tags", row.reason_tags),
    pdf_v2_dataset_json_array_field("source_refs", row.source_refs),
    pdf_v2_dataset_json_field("extra", row.extra),
  ]
  "{" + fields.join(",") + "}"
}

///|
fn pdf_v2_dataset_audit_add_counter(
  counters : Array[PdfV2DatasetAuditCounter],
  key : String,
) -> Unit {
  for i in 0..<counters.length() {
    if counters[i].key == key {
      counters[i] = { ..counters[i], count: counters[i].count + 1 }
      return
    }
  }
  counters.push({ key, count: 1 })
}

///|
fn pdf_v2_dataset_flat_row_has_unknown_none_or_empty_key_field(
  row : PdfV2DatasetFlatRow,
) -> Bool {
  row.doc_id == "" ||
  row.row_id == "" ||
  row.task == "" ||
  row.split == "" ||
  row.split == "unknown" ||
  row.label_source == "none" ||
  row.page_index == "unknown" ||
  (
    row.row_family == "TextFlowRow" &&
    (row.candidate_id == "" || row.text == "")
  ) ||
  (
    row.row_family == "BoundaryRow" &&
    (row.prev_candidate_id == "" || row.next_candidate_id == "")
  ) ||
  (
    row.row_family == "AdjacencyRow" &&
    (row.object_kind == "" || row.object_ref == "unknown")
  )
}

///|
fn pdf_v2_dataset_flat_row_has_geometry_unknown(
  row : PdfV2DatasetFlatRow,
) -> Bool {
  row.page_index == "unknown" ||
  row.object_ref == "unknown" ||
  row.extra.contains("bbox_distance=unknown")
}

///|
fn pdf_v2_dataset_text_flow_risk_tags(
  candidate : @pdfv2.PdfV2TextFlowCandidate,
  semantic_block : PdfV2SemanticBlock?,
) -> Array[String] {
  let tags : Array[String] = []
  match semantic_block {
    Some(block) => {
      tags.append(block.risk_tags)
      if !tags.contains("weak_label_rule_decision") {
        tags.push("weak_label_rule_decision")
      }
      if block.kind == PdfV2SemanticBlockKind::Paragraph &&
        block.decision.rule_id.contains("fallback") {
        tags.push("semantic_fallback_paragraph")
      }
    }
    None => ()
  }
  if candidate.boundary_signal.boundary_confidence > 0.0 &&
    candidate.boundary_signal.boundary_confidence < 0.50 {
    tags.push("low_geometry_confidence")
  }
  if candidate.boundary_signal.heading_candidate_score >= 0.70 &&
    candidate.normalized_text.to_array().length() <= 72 {
    tags.push("heading_short_text")
  }
  if candidate.boundary_signal.list_candidate_score >= 0.70 ||
    candidate.reason_tags.contains("inline_list_split") {
    tags.push("list_marker_weak")
  }
  pdf_v2_dataset_unique_tags(tags)
}

///|
fn pdf_v2_dataset_source_refs_for_pair(
  left : Array[@pdfv2.PdfV2SourceRef],
  right : Array[@pdfv2.PdfV2SourceRef],
) -> Array[@pdfv2.PdfV2SourceRef] {
  let refs : Array[@pdfv2.PdfV2SourceRef] = []
  refs.append(left)
  refs.append(right)
  refs
}

///|
fn pdf_v2_dataset_candidate_id(
  candidate : @pdfv2.PdfV2TextFlowCandidate,
) -> String {
  "p" +
  pdf_v2_dataset_optional_int(candidate.page_index) +
  ":b" +
  pdf_v2_dataset_optional_int(candidate.block_index) +
  ":f" +
  candidate.flow_index.to_string()
}

///|
fn pdf_v2_dataset_row_id(
  task : String,
  safe_doc_id : String,
  page_index : Int?,
  suffix : String,
) -> String {
  "pdfv2:" +
  task +
  ":" +
  safe_doc_id +
  ":p" +
  pdf_v2_dataset_optional_int(page_index) +
  ":" +
  suffix
}

///|
fn pdf_v2_dataset_safe_row_id_part(value : String) -> String {
  let out = StringBuilder::new()
  for ch in value {
    if pdf_v2_dataset_row_id_safe_char(ch) {
      out.write_char(ch)
    } else {
      out.write_char('_')
    }
  }
  let safe = out.to_string()
  if safe == "" {
    "unknown"
  } else {
    safe
  }
}

///|
fn pdf_v2_dataset_row_id_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_' ||
  ch == '-' ||
  ch == '.'
}

///|
fn pdf_v2_dataset_optional_int(value : Int?) -> String {
  match value {
    Some(inner) => inner.to_string()
    None => "unknown"
  }
}

///|
fn pdf_v2_dataset_bool(value : Bool) -> String {
  if value {
    "1"
  } else {
    "0"
  }
}

///|
fn pdf_v2_dataset_ints(values : Array[Int]) -> String {
  let parts : Array[String] = []
  for value in values {
    parts.push(value.to_string())
  }
  parts.join("|")
}

///|
fn pdf_v2_dataset_first_page_index(values : Array[Int]) -> Int? {
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn pdf_v2_dataset_artifact_key(
  artifact : @pdfv2.PdfV2PageArtifactCandidate,
) -> String {
  pdf_v2_dataset_artifact_kind_name(artifact.kind) +
  ":" +
  artifact.normalized_text +
  ":" +
  pdf_v2_dataset_ints(artifact.page_indices)
}

///|
fn pdf_v2_dataset_merge_tags(
  left : Array[String],
  right : Array[String],
) -> Array[String] {
  let tags : Array[String] = []
  tags.append(left)
  tags.append(right)
  pdf_v2_dataset_unique_tags(tags)
}

///|
fn pdf_v2_dataset_unique_tags(tags : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for tag in tags {
    if tag != "" && !out.contains(tag) {
      out.push(tag)
    }
  }
  out
}

///|
fn pdf_v2_dataset_tsv_list(values : Array[String]) -> String {
  values.join("|")
}

///|
fn pdf_v2_dataset_escape_tsv(value : String) -> String {
  let out = StringBuilder::new()
  for ch in value {
    if ch == '\t' || ch == '\n' || ch == '\r' {
      out.write_char(' ')
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn pdf_v2_dataset_json_field(key : String, value : String) -> String {
  "\"" + key + "\":\"" + pdf_v2_dataset_escape_json(value) + "\""
}

///|
fn pdf_v2_dataset_json_array_field(
  key : String,
  values : Array[String],
) -> String {
  let parts : Array[String] = []
  for value in values {
    parts.push("\"" + pdf_v2_dataset_escape_json(value) + "\"")
  }
  "\"" + key + "\":[" + parts.join(",") + "]"
}

///|
fn pdf_v2_dataset_escape_json(value : String) -> String {
  let out = StringBuilder::new()
  for ch in value {
    if ch == '"' {
      out.write_string("\\\"")
    } else if ch == '\\' {
      out.write_string("\\\\")
    } else if ch == '\n' {
      out.write_string("\\n")
    } else if ch == '\r' {
      out.write_string("\\r")
    } else if ch == '\t' {
      out.write_string("\\t")
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn pdf_v2_dataset_source_ref_strings(
  refs : Array[@pdfv2.PdfV2SourceRef],
) -> Array[String] {
  let out : Array[String] = []
  for source_ref in refs {
    out.push(pdf_v2_dataset_source_ref_string(source_ref))
  }
  out
}

///|
fn pdf_v2_dataset_source_ref_string(
  source_ref : @pdfv2.PdfV2SourceRef,
) -> String {
  [
    "page=" + pdf_v2_dataset_optional_int(source_ref.page_index),
    "object=" + pdf_v2_dataset_option_string_or_unknown(source_ref.object_id),
    "stream=" + pdf_v2_dataset_optional_int(source_ref.stream_index),
    "op=" + pdf_v2_dataset_optional_int(source_ref.op_index),
    "order=" + pdf_v2_dataset_optional_int(source_ref.content_order_index),
    "kind=" + pdf_v2_dataset_source_kind_name(source_ref.kind),
  ].join(";")
}

///|
fn pdf_v2_dataset_option_string_or_unknown(value : String?) -> String {
  match value {
    Some(inner) => if inner == "" { "unknown" } else { inner }
    None => "unknown"
  }
}

///|
fn pdf_v2_dataset_semantic_kind_name(kind : PdfV2SemanticBlockKind) -> String {
  match kind {
    PdfV2SemanticBlockKind::Paragraph => "paragraph"
    PdfV2SemanticBlockKind::Heading => "heading"
    PdfV2SemanticBlockKind::OrderedListItem => "ordered_list_item"
    PdfV2SemanticBlockKind::UnorderedListItem => "unordered_list_item"
    PdfV2SemanticBlockKind::Continuation => "continuation"
    PdfV2SemanticBlockKind::PlainText => "plain_text"
    PdfV2SemanticBlockKind::Unknown => "unknown"
  }
}

///|
fn pdf_v2_dataset_artifact_kind_name(
  kind : @pdfv2.PdfV2PageArtifactKind,
) -> String {
  match kind {
    @pdfv2.PdfV2PageArtifactKind::HeaderLike => "header_like"
    @pdfv2.PdfV2PageArtifactKind::FooterLike => "footer_like"
    @pdfv2.PdfV2PageArtifactKind::PageNumberLike => "page_number_like"
    @pdfv2.PdfV2PageArtifactKind::RepeatedLineLike => "repeated_line_like"
    @pdfv2.PdfV2PageArtifactKind::CaptionLike => "caption_like"
    @pdfv2.PdfV2PageArtifactKind::Unknown => "unknown"
  }
}

///|
fn pdf_v2_dataset_position_band_name(
  band : @pdfv2.PdfV2PagePositionBand,
) -> String {
  match band {
    @pdfv2.PdfV2PagePositionBand::Top => "top"
    @pdfv2.PdfV2PagePositionBand::Body => "body"
    @pdfv2.PdfV2PagePositionBand::Bottom => "bottom"
    @pdfv2.PdfV2PagePositionBand::Unknown => "unknown"
  }
}

///|
fn pdf_v2_dataset_image_caption_relation_name(
  relation : @pdfv2.PdfV2ImageCaptionRelation,
) -> String {
  match relation {
    @pdfv2.PdfV2ImageCaptionRelation::Below => "below"
    @pdfv2.PdfV2ImageCaptionRelation::Above => "above"
    @pdfv2.PdfV2ImageCaptionRelation::Nearby => "nearby"
    @pdfv2.PdfV2ImageCaptionRelation::Unknown => "unknown"
  }
}

///|
fn pdf_v2_dataset_source_kind_name(kind : @pdfv2.PdfV2SourceKind) -> String {
  match kind {
    @pdfv2.PdfV2SourceKind::Document => "document"
    @pdfv2.PdfV2SourceKind::Page => "page"
    @pdfv2.PdfV2SourceKind::ContentStream => "content_stream"
    @pdfv2.PdfV2SourceKind::Object => "object"
    @pdfv2.PdfV2SourceKind::TextOp => "text_op"
    @pdfv2.PdfV2SourceKind::Glyph => "glyph"
    @pdfv2.PdfV2SourceKind::Image => "image"
    @pdfv2.PdfV2SourceKind::InlineImage => "inline_image"
    @pdfv2.PdfV2SourceKind::Vector => "vector"
    @pdfv2.PdfV2SourceKind::Annotation => "annotation"
    @pdfv2.PdfV2SourceKind::Form => "form"
    @pdfv2.PdfV2SourceKind::Outline => "outline"
    @pdfv2.PdfV2SourceKind::Destination => "destination"
    @pdfv2.PdfV2SourceKind::Metadata => "metadata"
    @pdfv2.PdfV2SourceKind::Resource => "resource"
    @pdfv2.PdfV2SourceKind::Malformed => "malformed"
    @pdfv2.PdfV2SourceKind::Unsupported => "unsupported"
    @pdfv2.PdfV2SourceKind::Unknown => "unknown"
  }
}
