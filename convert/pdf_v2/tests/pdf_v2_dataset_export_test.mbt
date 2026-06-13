///|
fn dataset_export_ref(page_index : Int, order : Int) -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(page_index),
    object_id: Some("4 0 R"),
    stream_index: Some(0),
    op_index: Some(order),
    content_order_index: Some(order),
    kind: @pdfv2.PdfV2SourceKind::TextOp,
  }
}

///|
fn dataset_export_text_candidate(
  page_index : Int,
  block_index : Int,
  flow_index : Int,
  line_index : Int,
  text : String,
  heading_score : Double,
  list_score : Double,
  artifacts : Array[@pdfv2.PdfV2PageArtifactCandidate],
) -> @pdfv2.PdfV2TextFlowCandidate {
  let refs = [dataset_export_ref(page_index, line_index)]
  let signal = @pdfv2.pdf_v2_build_line_text_signal(
    text,
    @pdfv2.PdfV2TextDecodeConfidence::High,
    refs,
    ["dataset_export_test"],
  )
  {
    page_index: Some(page_index),
    block_index: Some(block_index),
    flow_index,
    line_indices: [line_index],
    text,
    normalized_text: signal.normalized_text,
    original_lines: [text],
    normalized_lines: [signal.normalized_text],
    line_signals: [signal],
    boundary_signal: {
      ..@pdfv2.pdf_v2_empty_block_boundary_signal(),
      line_count: 1,
      first_line_text: signal.normalized_text,
      last_line_text: signal.normalized_text,
      heading_candidate_score: heading_score,
      list_candidate_score: list_score,
      boundary_confidence: 0.45,
      reason_tags: ["dataset_export_boundary_signal"],
    },
    artifact_refs: artifacts,
    source_refs: refs,
    reason_tags: ["dataset_export_test"],
  }
}

///|
fn dataset_export_artifact() -> @pdfv2.PdfV2PageArtifactCandidate {
  {
    kind: @pdfv2.PdfV2PageArtifactKind::PageNumberLike,
    normalized_text: "Page 1",
    normalized_key: "page #",
    raw_text_variants: ["Page 1"],
    page_indices: [0],
    repeat_count: 1,
    position_band: @pdfv2.PdfV2PagePositionBand::Bottom,
    page_coverage_ratio: 1.0,
    first_page_index: Some(0),
    last_page_index: Some(0),
    page_number_like: true,
    numbered_variant: true,
    real_heading_risk: false,
    table_header_body_risk: false,
    confidence: 0.98,
    reason_tags: ["page_artifact_candidate", "page_number_like"],
    blockers: [],
    source_refs: [dataset_export_ref(0, 9)],
  }
}

///|
fn dataset_export_table() -> @pdfv2.PdfV2TableCandidate {
  {
    page_index: Some(0),
    block_indices: [2],
    line_indices: [2, 3],
    rows: [["Name", "Value"], ["A", "1"]],
    columns: 2,
    cells: [],
    source_refs: [dataset_export_ref(0, 2)],
    confidence: 0.91,
    reason_tags: ["table_candidate", "dataset_export_test"],
    table_kind: @pdfv2.PdfV2TableKind::CoordinateGrid,
    has_header: true,
    header_row_index: Some(0),
  }
}

///|
fn dataset_export_link() -> @pdfv2.PdfV2LinkCandidate {
  {
    page_index: Some(0),
    object_ref: Some("6 0 R"),
    subtype: Some("/Link"),
    rect: None,
    uri: Some("https://example.test"),
    dest: None,
    source_ref: dataset_export_ref(0, 4),
    warnings: [],
    risks: [],
    reason_tags: ["link_annotation"],
  }
}

///|
fn dataset_export_image() -> @pdfv2.PdfV2ImageCandidate {
  {
    page_index: Some(0),
    object_ref: Some("8 0 R"),
    width: Some(640),
    height: Some(360),
    color_space: Some("/DeviceRGB"),
    bits_per_component: Some(8),
    filters: ["/DCTDecode"],
    image_mask: None,
    mask_present: false,
    smask_present: false,
    inline: false,
    bbox: None,
    nesting: None,
    placement: None,
    caption: Some({
      image_object_ref: Some("8 0 R"),
      asset_ref: None,
      caption_text: "Figure 1. Exported image",
      page_index: Some(0),
      line_source_refs: [dataset_export_ref(0, 5)],
      relation: @pdfv2.PdfV2ImageCaptionRelation::Below,
      confidence: 0.82,
      reason_tags: ["image_caption_candidate"],
    }),
    source_ref: dataset_export_ref(0, 6),
    warnings: [],
    risks: [],
    reason_tags: ["image_candidate"],
    decode_status: @pdfv2.PdfV2ImageDecodeStatus::MetadataOnly,
    asset: None,
  }
}

///|
fn dataset_export_small_fixture(
  doc_id : String,
) -> @pdfv2conv.PdfV2DatasetExport {
  let page_artifact = dataset_export_artifact()
  @pdfv2conv.pdf_v2_export_dataset_from_fact_arrays(
    doc_id,
    [
      dataset_export_text_candidate(0, 0, 0, 0, "Overview", 0.80, 0.0, [
        page_artifact,
      ]),
      dataset_export_text_candidate(1, 1, 1, 1, "Body sentence.", 0.0, 0.0, []),
    ],
    [dataset_export_table()],
    [dataset_export_link()],
    [dataset_export_image()],
    [],
  )
}

///|
fn dataset_export_parity_fixture(
  doc_id : String,
) -> @pdfv2conv.PdfV2DatasetExport {
  @pdfv2conv.pdf_v2_export_dataset_from_fact_arrays_with_parity(
    doc_id,
    [
      dataset_export_text_candidate(0, 0, 0, 0, "Overview", 0.80, 0.0, [
        dataset_export_artifact(),
      ]),
      dataset_export_text_candidate(1, 1, 1, 1, "Body sentence.", 0.0, 0.0, []),
    ],
    [dataset_export_table()],
    [dataset_export_link()],
    [dataset_export_image()],
    [],
    {
      cross_page_boundaries: [
        {
          page_from: 0,
          page_to: 1,
          prev_block_ref: Some(0),
          next_block_ref: Some(1),
          prev_line_refs: [0],
          next_line_refs: [1],
          prev_vertical_band: @pdfv2.PdfV2ParityVerticalBand::Body,
          next_vertical_band: @pdfv2.PdfV2ParityVerticalBand::Body,
          prev_open_ended: true,
          next_starts_with_marker: false,
          repeated_artifact_gap: false,
          confidence: 0.72,
          reason_tags: ["cross_page_boundary_fact", "dataset_export_test"],
          source_refs: [dataset_export_ref(0, 10), dataset_export_ref(1, 11)],
        },
      ],
      image_text_boundaries: [
        {
          page_index: Some(0),
          image_ref: "8 0 R",
          asset_origin_id: "xobj-image-8",
          nearby_text_refs: [5],
          relation: @pdfv2.PdfV2ParityTextRelation::After,
          distance: "unknown",
          page_band: @pdfv2.PdfV2ParityVerticalBand::Unknown,
          caption_candidate: true,
          title_nearby: false,
          confidence: 0.67,
          reason_tags: [
            "image_text_boundary_fact", "parser_layout_backed", "image_geometry_unknown",
          ],
          source_refs: [dataset_export_ref(0, 6), dataset_export_ref(0, 5)],
        },
      ],
      header_footer_variants: [
        {
          repeated_text_cluster: "Confidential Footer 1 / Confidential Footer 2",
          normalized_key: "confidential footer #",
          raw_text_variants: ["Confidential Footer 1", "Confidential Footer 2"],
          page_positions: [0, 1],
          page_coverage_ratio: 1.0,
          first_page_index: Some(0),
          last_page_index: Some(1),
          variant_group_id: "edge-variant-0",
          position_band: @pdfv2.PdfV2ParityVerticalBand::Bottom,
          page_number_like: false,
          numbered_variant: true,
          real_heading_risk: false,
          confidence: 0.78,
          reason_tags: [
            "header_footer_variant_fact", "parser_layout_backed", "repeated_edge_evidence",
          ],
          blockers: [],
          source_refs: [dataset_export_ref(0, 12), dataset_export_ref(1, 13)],
        },
      ],
      heading_boundaries: [
        {
          page_index: Some(0),
          block_ref: Some(0),
          line_refs: [0],
          short_text_risk: true,
          sentence_like_risk: false,
          font_layout_evidence: "font_relation_available",
          numbering_evidence: false,
          body_continuation_evidence: false,
          confidence: 0.61,
          reason_tags: ["heading_boundary_fact", "short_text_risk"],
          source_refs: [dataset_export_ref(0, 0)],
        },
      ],
      column_layouts: [
        {
          page_index: 1,
          detected_column_count: "2",
          block_refs: [0, 1],
          column_assignments: ["left", "right"],
          reading_order_confidence: 0.74,
          ambiguity_flag: false,
          reason_tags: ["two_column_candidate"],
          source_refs: [dataset_export_ref(1, 20)],
        },
      ],
      source_refs: [],
      reason_tags: ["dataset_export_test"],
    },
  )
}

///|
fn dataset_export_counter_count(
  counters : Array[@pdfv2conv.PdfV2DatasetAuditCounter],
  key : String,
) -> Int {
  for counter in counters {
    if counter.key == key {
      return counter.count
    }
  }
  0
}

///|
test "pdf v2 dataset exporter uses stable row ids and doc scoped ids" {
  let first = dataset_export_small_fixture("doc/A")
  let second = dataset_export_small_fixture("doc/A")
  let different = dataset_export_small_fixture("doc/B")

  assert_true(first.schema_version == "pdf_v2_dataset_export_v1")
  assert_true(first.text_flow_rows.length() == 2)
  assert_true(first.boundary_rows.length() == 1)
  assert_true(first.artifact_rows.length() == 1)
  assert_true(first.adjacency_rows.length() == 3)
  assert_true(first.evidence_rows.length() == 0)
  assert_true(first.text_flow_rows[0].row_id == second.text_flow_rows[0].row_id)
  assert_true(first.boundary_rows[0].row_id == second.boundary_rows[0].row_id)
  assert_true(first.artifact_rows[0].row_id == second.artifact_rows[0].row_id)
  assert_true(first.adjacency_rows[0].row_id == second.adjacency_rows[0].row_id)
  assert_true(
    first.text_flow_rows[0].row_id != different.text_flow_rows[0].row_id,
  )
  assert_true(first.text_flow_rows[0].row_id.contains("doc_A"))
  assert_true(!first.text_flow_rows[0].row_id.contains("/"))
}

///|
test "pdf v2 dataset exporter emits text flow weak labels and source refs" {
  let dataset = dataset_export_small_fixture("doc-text-flow")
  let row = dataset.text_flow_rows[0]
  let tsv = @pdfv2conv.pdf_v2_dataset_export_to_tsv(dataset)
  let jsonl = @pdfv2conv.pdf_v2_dataset_export_to_jsonl(dataset)

  assert_true(row.schema_version == "pdf_v2_dataset_export_v1")
  assert_true(row.doc_id == "doc-text-flow")
  assert_true(row.task == "text_flow")
  assert_true(row.split == "unknown")
  assert_true(row.gold_label == "")
  assert_true(row.label_source == "rule_decision")
  assert_true(row.weak_label != "")
  assert_true(row.risk_tags.contains("weak_label_rule_decision"))
  assert_true(row.risk_tags.contains("low_geometry_confidence"))
  assert_true(row.risk_tags.contains("heading_short_text"))
  assert_true(row.source_refs.length() == 1)
  assert_true(tsv.contains("kind=text_op"))
  assert_true(jsonl.contains("\"source_refs\":[\"page=0;object=4 0 R"))
}

///|
test "pdf v2 dataset exporter emits boundary artifact and adjacency rows" {
  let dataset = dataset_export_small_fixture("doc-families")
  let boundary = dataset.boundary_rows[0]
  let artifact = dataset.artifact_rows[0]
  let table = dataset.adjacency_rows[0]
  let image = dataset.adjacency_rows[1]
  let link = dataset.adjacency_rows[2]

  assert_true(boundary.task == "boundary")
  assert_true(boundary.cross_page)
  assert_true(!boundary.same_page)
  assert_true(boundary.risk_tags.contains("cross_page_candidate"))
  assert_true(boundary.label_source == "none")
  assert_true(artifact.task == "artifact")
  assert_true(artifact.artifact_kind == "page_number_like")
  assert_true(artifact.position_band == "bottom")
  assert_true(artifact.repeat_count == 1)
  assert_true(artifact.risk_tags.contains("artifact_repeat_low"))
  assert_true(artifact.weak_label == "")
  assert_true(artifact.label_source == "none")
  assert_true(table.object_kind == "table")
  assert_true(table.risk_tags.contains("table_candidate"))
  assert_true(table.current_rule_decision == "")
  assert_true(table.relation == "table_candidate")
  assert_true(table.weak_label == "")
  assert_true(table.label_source == "none")
  assert_true(image.object_kind == "image")
  assert_true(image.risk_tags.contains("image_nearby_text"))
  assert_true(image.relation == "below")
  assert_true(link.object_kind == "link")
  assert_true(link.risk_tags.contains("link_annotation_nearby"))
  assert_true(link.object_ref == "6 0 R")
}

///|
test "pdf v2 dataset exporter serializes deterministic JSONL and TSV" {
  let dataset = @pdfv2conv.pdf_v2_export_dataset_from_fact_arrays(
    "doc weird",
    [
      dataset_export_text_candidate(
        0,
        0,
        0,
        0,
        "Hello\tWorld\nAgain \"quoted\"",
        0.0,
        0.0,
        [],
      ),
    ],
    [],
    [],
    [],
    [],
  )
  let first_jsonl = @pdfv2conv.pdf_v2_dataset_export_to_jsonl(dataset)
  let second_jsonl = @pdfv2conv.pdf_v2_dataset_export_to_jsonl(dataset)
  let tsv = @pdfv2conv.pdf_v2_dataset_export_to_tsv(dataset)

  assert_true(first_jsonl == second_jsonl)
  assert_true(
    tsv.has_prefix(
      "schema_version\trow_family\tdoc_id\trow_id\ttask\tsplit\tpage_index\tcandidate_id",
    ),
  )
  assert_true(tsv.contains("pdfv2:text_flow:doc_weird:p0:c0"))
  assert_true(tsv.contains("evidence_kind"))
  assert_true(tsv.contains("blockers"))
  assert_true(tsv.contains("Hello World Again \"quoted\""))
  assert_true(first_jsonl.contains("Hello\\tWorld\\nAgain \\\"quoted\\\""))
  assert_true(first_jsonl.contains("\"risk_tags\":["))
  assert_true(first_jsonl.contains("\"gold_label\":\"\""))
}

///|
test "pdf v2 dataset exporter stays out of runtime product path" {
  let pipeline_text = @fs.read_file_to_string(
    "convert/pdf_v2/pdf_v2_pipeline.mbt",
    encoding="utf8",
  ) catch {
    err => fail("read pipeline source failed: " + err.to_string())
  }
  let bridge_text = @fs.read_file_to_string(
    "convert/pdf_v2/pdf_v2_product_bridge.mbt",
    encoding="utf8",
  ) catch {
    err => fail("read product bridge source failed: " + err.to_string())
  }

  assert_true(
    !pipeline_text.contains("pdf_v2_export_dataset_from_pipeline_output"),
  )
  assert_true(
    !bridge_text.contains("pdf_v2_export_dataset_from_pipeline_output"),
  )
  assert_true(!pipeline_text.contains("pdf_v2_dataset_export_to_jsonl"))
  assert_true(!bridge_text.contains("pdf_v2_dataset_export_to_jsonl"))
}

///|
test "pdf v2 dataset export audit counts row quality in memory" {
  let dataset = dataset_export_small_fixture("doc-audit")
  let audit = @pdfv2conv.pdf_v2_dataset_export_audit(dataset)

  assert_true(audit.schema_version == "pdf_v2_dataset_export_v1")
  assert_true(audit.total_rows == 7)
  assert_true(audit.text_flow_row_count == 2)
  assert_true(audit.boundary_row_count == 1)
  assert_true(audit.artifact_row_count == 1)
  assert_true(audit.adjacency_row_count == 3)
  assert_true(audit.evidence_row_count == 0)
  assert_true(audit.empty_gold_label_count == audit.total_rows)
  assert_true(audit.weak_label_count == 2)
  assert_true(audit.rows_with_source_refs == audit.total_rows)
  assert_true(audit.rows_with_unknown_none_or_empty_key_fields > 0)
  assert_true(audit.geometry_unknown_row_count > 0)
  assert_true(audit.cross_page_candidate_count == 1)
  assert_true(audit.heading_short_text_count == 1)
  assert_true(audit.image_nearby_text_count == 1)
  assert_true(audit.table_candidate_count == 1)
  assert_true(audit.semantic_fallback_paragraph_count == 0)
  assert_true(
    dataset_export_counter_count(audit.rows_by_family, "TextFlowRow") == 2,
  )
  assert_true(
    dataset_export_counter_count(audit.rows_by_task, "text_flow") == 2,
  )
  assert_true(dataset_export_counter_count(audit.rows_by_task, "boundary") == 1)
  assert_true(dataset_export_counter_count(audit.rows_by_task, "artifact") == 1)
  assert_true(
    dataset_export_counter_count(audit.rows_by_task, "adjacency") == 3,
  )
  assert_true(
    dataset_export_counter_count(audit.rows_by_label_source, "rule_decision") ==
    2,
  )
  assert_true(
    dataset_export_counter_count(audit.rows_by_label_source, "none") == 5,
  )
  assert_true(dataset_export_counter_count(audit.rows_by_split, "unknown") == 7)
  assert_true(
    dataset_export_counter_count(
      audit.risk_tag_distribution,
      "weak_label_rule_decision",
    ) ==
    2,
  )
}

///|
test "pdf v2 dataset exporter emits parity evidence rows for training readiness" {
  let dataset = dataset_export_parity_fixture("doc-parity")
  let audit = @pdfv2conv.pdf_v2_dataset_export_audit(dataset)
  let tsv = @pdfv2conv.pdf_v2_dataset_export_to_tsv(dataset)
  let jsonl = @pdfv2conv.pdf_v2_dataset_export_to_jsonl(dataset)

  assert_true(dataset.evidence_rows.length() == 5)
  assert_true(audit.total_rows == 12)
  assert_true(audit.evidence_row_count == 5)
  assert_true(audit.image_evidence_row_count == 1)
  assert_true(audit.heading_evidence_row_count == 1)
  assert_true(audit.column_evidence_row_count == 1)
  assert_true(audit.artifact_evidence_row_count == 1)
  assert_true(dataset.evidence_rows[0].gold_label == "")
  assert_true(dataset.evidence_rows[0].label_source == "none")
  assert_true(
    dataset_export_counter_count(audit.rows_by_family, "EvidenceRow") == 5,
  )
  assert_true(
    dataset_export_counter_count(audit.rows_by_task, "semantic_arbitration") ==
    3,
  )
  assert_true(
    dataset_export_counter_count(audit.rows_by_task, "layout_recovery") == 2,
  )
  assert_true(tsv.contains("cross_page_boundary"))
  assert_true(tsv.contains("image_text_boundary"))
  assert_true(tsv.contains("header_footer_variant"))
  assert_true(tsv.contains("heading_boundary"))
  assert_true(tsv.contains("column_layout"))
  assert_true(tsv.contains("caption_candidate"))
  assert_true(tsv.contains("column_assignments=left|right"))
  assert_true(jsonl.contains("\"evidence_kind\":\"image_text_boundary\""))
  assert_true(jsonl.contains("\"blockers\":[]"))
}
