///|
pub(all) enum PdfV2ParityVerticalBand {
  Top
  Body
  Bottom
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2ParityTextRelation {
  Before
  After
  SamePage
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2CrossPageBoundaryFact {
  page_from : Int
  page_to : Int
  prev_block_ref : Int?
  next_block_ref : Int?
  prev_line_refs : Array[Int]
  next_line_refs : Array[Int]
  prev_vertical_band : PdfV2ParityVerticalBand
  next_vertical_band : PdfV2ParityVerticalBand
  prev_open_ended : Bool
  next_starts_with_marker : Bool
  repeated_artifact_gap : Bool
  confidence : Double
  reason_tags : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2ImageTextBoundaryFact {
  page_index : Int?
  image_ref : String
  asset_origin_id : String
  nearby_text_refs : Array[Int]
  relation : PdfV2ParityTextRelation
  distance : String
  page_band : PdfV2ParityVerticalBand
  caption_candidate : Bool
  title_nearby : Bool
  confidence : Double
  reason_tags : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2HeaderFooterVariantFact {
  repeated_text_cluster : String
  normalized_key : String
  page_positions : Array[Int]
  page_coverage_ratio : Double
  variant_group_id : String
  position_band : PdfV2ParityVerticalBand
  confidence : Double
  reason_tags : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2HeadingBoundaryFact {
  page_index : Int?
  block_ref : Int?
  line_refs : Array[Int]
  short_text_risk : Bool
  sentence_like_risk : Bool
  font_layout_evidence : String
  numbering_evidence : Bool
  body_continuation_evidence : Bool
  confidence : Double
  reason_tags : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2ColumnLayoutFact {
  page_index : Int
  detected_column_count : String
  block_refs : Array[Int]
  column_assignments : Array[String]
  reading_order_confidence : Double
  ambiguity_flag : Bool
  reason_tags : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2ParityFactSet {
  cross_page_boundaries : Array[PdfV2CrossPageBoundaryFact]
  image_text_boundaries : Array[PdfV2ImageTextBoundaryFact]
  header_footer_variants : Array[PdfV2HeaderFooterVariantFact]
  heading_boundaries : Array[PdfV2HeadingBoundaryFact]
  column_layouts : Array[PdfV2ColumnLayoutFact]
  source_refs : Array[PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub fn pdf_v2_parity_facts_from_model(
  model : PdfV2DocumentModel,
) -> PdfV2ParityFactSet {
  let text_flow_candidates = pdf_v2_build_text_flow_candidates(model)
  let page_artifacts = pdf_v2_build_page_artifact_candidates(model)
  let cross_page_boundaries = pdf_v2_parity_cross_page_boundaries(
    text_flow_candidates,
  )
  let image_text_boundaries = pdf_v2_parity_image_text_boundaries(
    model, text_flow_candidates,
  )
  let header_footer_variants = pdf_v2_parity_header_footer_variants(
    model, page_artifacts,
  )
  let heading_boundaries = pdf_v2_parity_heading_boundaries(
    text_flow_candidates,
  )
  let column_layouts = pdf_v2_parity_column_layouts(model)
  let source_refs : Array[PdfV2SourceRef] = []
  pdf_v2_parity_append_cross_page_refs(source_refs, cross_page_boundaries)
  pdf_v2_parity_append_image_text_refs(source_refs, image_text_boundaries)
  pdf_v2_parity_append_variant_refs(source_refs, header_footer_variants)
  pdf_v2_parity_append_heading_refs(source_refs, heading_boundaries)
  pdf_v2_parity_append_column_refs(source_refs, column_layouts)
  {
    cross_page_boundaries,
    image_text_boundaries,
    header_footer_variants,
    heading_boundaries,
    column_layouts,
    source_refs,
    reason_tags: [
      "pdf_v2_parity_fact_set", "parser_layout_backed", "not_product_behavior",
    ],
  }
}

///|
fn pdf_v2_parity_cross_page_boundaries(
  candidates : Array[PdfV2TextFlowCandidate],
) -> Array[PdfV2CrossPageBoundaryFact] {
  let ordered = pdf_v2_parity_ordered_candidates(candidates)
  let out : Array[PdfV2CrossPageBoundaryFact] = []
  for index = 0; index + 1 < ordered.length(); index = index + 1 {
    let prev = ordered[index]
    let next = ordered[index + 1]
    match (prev.page_index, next.page_index) {
      (Some(page_from), Some(page_to)) if page_to > page_from => {
        let prev_open = !pdf_v2_parity_candidate_ends_sentence(prev)
        let next_marker = pdf_v2_parity_candidate_starts_marker(next)
        let artifact_gap = prev.artifact_refs.length() > 0 ||
          next.artifact_refs.length() > 0
        let reason_tags = [
          "cross_page_boundary_fact", "parser_layout_backed", "source_order_pair",
        ]
        if prev_open {
          reason_tags.push("prev_open_ended")
        }
        if next_marker {
          reason_tags.push("next_starts_with_marker")
        }
        if artifact_gap {
          reason_tags.push("repeated_artifact_gap")
        }
        out.push({
          page_from,
          page_to,
          prev_block_ref: prev.block_index,
          next_block_ref: next.block_index,
          prev_line_refs: prev.line_indices,
          next_line_refs: next.line_indices,
          prev_vertical_band: pdf_v2_parity_candidate_vertical_band(prev),
          next_vertical_band: pdf_v2_parity_candidate_vertical_band(next),
          prev_open_ended: prev_open,
          next_starts_with_marker: next_marker,
          repeated_artifact_gap: artifact_gap,
          confidence: pdf_v2_parity_cross_page_confidence(
            prev_open, next_marker, artifact_gap,
          ),
          reason_tags,
          source_refs: pdf_v2_parity_refs_pair(
            prev.source_refs,
            next.source_refs,
          ),
        })
      }
      _ => ()
    }
  }
  out
}

///|
fn pdf_v2_parity_image_text_boundaries(
  model : PdfV2DocumentModel,
  candidates : Array[PdfV2TextFlowCandidate],
) -> Array[PdfV2ImageTextBoundaryFact] {
  let out : Array[PdfV2ImageTextBoundaryFact] = []
  for page in model.pages {
    let page_candidates = pdf_v2_parity_candidates_for_page(
      candidates,
      page.page_index,
    )
    for image in page.images {
      out.push(
        pdf_v2_parity_image_text_boundary_for_image(
          image.page_index,
          pdf_v2_parity_image_ref(image.object_ref, image.source_ref),
          pdf_v2_parity_image_asset_origin_id(image.asset),
          pdf_v2_parity_image_source_order(image),
          pdf_v2_parity_image_bbox(image.bbox, image.placement),
          page.media_box,
          image.caption,
          [image.source_ref],
          page_candidates,
          "image_text_boundary_fact",
        ),
      )
    }
    for image in page.inline_images {
      out.push(
        pdf_v2_parity_image_text_boundary_for_image(
          image.page_index,
          pdf_v2_parity_inline_image_ref(image.source_ref),
          pdf_v2_parity_image_asset_origin_id(image.asset),
          image.source_ref.content_order_index,
          pdf_v2_parity_image_bbox(image.bbox, image.placement),
          page.media_box,
          image.caption,
          [image.source_ref],
          page_candidates,
          "inline_image_text_boundary_fact",
        ),
      )
    }
  }
  out
}

///|
fn pdf_v2_parity_header_footer_variants(
  model : PdfV2DocumentModel,
  artifacts : Array[PdfV2PageArtifactCandidate],
) -> Array[PdfV2HeaderFooterVariantFact] {
  let out : Array[PdfV2HeaderFooterVariantFact] = []
  let seen_keys : Array[String] = []
  let mut variant_index = 0
  for artifact in artifacts {
    if artifact.kind == PdfV2PageArtifactKind::HeaderLike ||
      artifact.kind == PdfV2PageArtifactKind::FooterLike ||
      artifact.kind == PdfV2PageArtifactKind::RepeatedLineLike {
      let band = pdf_v2_parity_band_from_page_position(artifact.position_band)
      let key = pdf_v2_parity_variant_key(artifact.normalized_text)
      let coverage = if model.page_count <= 0 {
        0.0
      } else {
        artifact.page_indices.length().to_double() /
        model.page_count.to_double()
      }
      let reason_tags = [
        "header_footer_variant_fact", "parser_layout_backed", "page_artifact_cluster",
      ]
      if artifact.kind == PdfV2PageArtifactKind::RepeatedLineLike {
        reason_tags.push("variant_position_unknown")
      }
      seen_keys.push(pdf_v2_parity_variant_group_key(key, band))
      out.push({
        repeated_text_cluster: artifact.normalized_text,
        normalized_key: key,
        page_positions: artifact.page_indices,
        page_coverage_ratio: coverage,
        variant_group_id: "artifact-variant-" + variant_index.to_string(),
        position_band: band,
        confidence: artifact.confidence,
        reason_tags,
        source_refs: artifact.source_refs,
      })
      variant_index = variant_index + 1
    }
  }
  variant_index = pdf_v2_parity_append_edge_variant_facts(
    model, out, seen_keys, variant_index,
  )
  out
}

///|
fn pdf_v2_parity_heading_boundaries(
  candidates : Array[PdfV2TextFlowCandidate],
) -> Array[PdfV2HeadingBoundaryFact] {
  let out : Array[PdfV2HeadingBoundaryFact] = []
  for candidate in candidates {
    let heading_score = candidate.boundary_signal.heading_candidate_score
    let short_text = pdf_v2_parity_candidate_short_text(candidate)
    let sentence_like = pdf_v2_parity_candidate_ends_sentence(candidate)
    let numbering = pdf_v2_parity_candidate_starts_marker(candidate)
    let body_continuation = candidate.boundary_signal.continuation_candidate_score >=
      0.50 ||
      sentence_like
    if heading_score >= 0.50 || short_text || numbering {
      let reason_tags = ["heading_boundary_fact", "parser_layout_backed"]
      if heading_score >= 0.50 {
        reason_tags.push("heading_score_available")
      }
      if short_text {
        reason_tags.push("short_text_risk")
      }
      if sentence_like {
        reason_tags.push("sentence_like_risk")
      }
      if numbering {
        reason_tags.push("numbering_evidence")
      }
      if body_continuation {
        reason_tags.push("body_continuation_evidence")
      }
      out.push({
        page_index: candidate.page_index,
        block_ref: candidate.block_index,
        line_refs: candidate.line_indices,
        short_text_risk: short_text,
        sentence_like_risk: sentence_like,
        font_layout_evidence: pdf_v2_parity_font_layout_evidence(candidate),
        numbering_evidence: numbering,
        body_continuation_evidence: body_continuation,
        confidence: pdf_v2_parity_heading_confidence(
          heading_score, short_text, sentence_like, body_continuation,
        ),
        reason_tags,
        source_refs: candidate.source_refs,
      })
    }
  }
  out
}

///|
fn pdf_v2_parity_append_edge_variant_facts(
  model : PdfV2DocumentModel,
  out : Array[PdfV2HeaderFooterVariantFact],
  seen_keys : Array[String],
  start_index : Int,
) -> Int {
  let keys : Array[String] = []
  let clusters : Array[String] = []
  let pages_by_key : Array[Array[Int]] = []
  let refs_by_key : Array[Array[PdfV2SourceRef]] = []
  let band_by_key : Array[PdfV2ParityVerticalBand] = []
  for page in model.pages {
    for line in page.lines {
      let band = pdf_v2_parity_line_vertical_band(line, page)
      if band != PdfV2ParityVerticalBand::Top &&
        band != PdfV2ParityVerticalBand::Bottom {
        continue
      }
      let text = line.text_signal.normalized_text
      let key = pdf_v2_parity_variant_key(text)
      if key == "" || key == text.to_lower().trim().to_owned() {
        continue
      }
      let group_key = pdf_v2_parity_variant_group_key(key, band)
      if seen_keys.contains(group_key) {
        continue
      }
      let mut found = -1
      for index in 0..<keys.length() {
        if keys[index] == group_key {
          found = index
          break
        }
      }
      if found < 0 {
        keys.push(group_key)
        clusters.push(text)
        pages_by_key.push([page.page_index])
        refs_by_key.push(line.source_refs)
        band_by_key.push(band)
      } else {
        clusters[found] = pdf_v2_parity_variant_cluster_text(
          clusters[found],
          text,
        )
        if !pages_by_key[found].contains(page.page_index) {
          pages_by_key[found].push(page.page_index)
        }
        refs_by_key[found].append(line.source_refs)
      }
    }
  }
  let mut next_index = start_index
  for index in 0..<keys.length() {
    if pages_by_key[index].length() < 2 {
      continue
    }
    let coverage = if model.page_count <= 0 {
      0.0
    } else {
      pages_by_key[index].length().to_double() / model.page_count.to_double()
    }
    out.push({
      repeated_text_cluster: clusters[index],
      normalized_key: pdf_v2_parity_group_key_without_band(keys[index]),
      page_positions: pages_by_key[index],
      page_coverage_ratio: coverage,
      variant_group_id: "edge-variant-" + next_index.to_string(),
      position_band: band_by_key[index],
      confidence: 0.78,
      reason_tags: [
        "header_footer_variant_fact", "parser_layout_backed", "edge_variant_cluster",
      ],
      source_refs: refs_by_key[index],
    })
    next_index = next_index + 1
  }
  next_index
}

///|
fn pdf_v2_parity_column_layouts(
  model : PdfV2DocumentModel,
) -> Array[PdfV2ColumnLayoutFact] {
  let out : Array[PdfV2ColumnLayoutFact] = []
  for page in model.pages {
    let block_refs : Array[Int] = []
    let source_refs : Array[PdfV2SourceRef] = [page.source_ref]
    let mut has_missing_geometry = false
    let mut left_count = 0
    let mut right_count = 0
    let mut body_count = 0
    for block in page.blocks {
      block_refs.push(block.block_index)
      source_refs.append(block.source_refs)
      match pdf_v2_parity_block_column_assignment(block, page.media_box) {
        "left" => left_count = left_count + 1
        "right" => right_count = right_count + 1
        "body" => body_count = body_count + 1
        _ => has_missing_geometry = true
      }
    }
    let detected = if page.blocks.length() == 0 {
      "none"
    } else if has_missing_geometry {
      "unknown"
    } else if left_count > 0 && right_count > 0 {
      "2"
    } else {
      "1"
    }
    let ambiguity = detected == "unknown" || detected == "2"
    let reason_tags = [
      "column_layout_fact", "parser_layout_backed", "source_order_only",
    ]
    if has_missing_geometry {
      reason_tags.push("column_geometry_unknown")
    }
    if detected == "2" {
      reason_tags.push("two_column_candidate")
    }
    if page.blocks.length() == 0 {
      reason_tags.push("no_text_blocks")
    }
    out.push({
      page_index: page.page_index,
      detected_column_count: detected,
      block_refs,
      column_assignments: pdf_v2_parity_column_assignments(page),
      reading_order_confidence: if ambiguity {
        0.25
      } else {
        0.60
      },
      ambiguity_flag: ambiguity,
      reason_tags,
      source_refs,
    })
  }
  out
}

///|
fn pdf_v2_parity_ordered_candidates(
  candidates : Array[PdfV2TextFlowCandidate],
) -> Array[PdfV2TextFlowCandidate] {
  let ordered : Array[PdfV2TextFlowCandidate] = []
  ordered.append(candidates)
  ordered.sort_by(fn(a, b) {
    match (a.page_index, b.page_index) {
      (Some(left), Some(right)) if left != right => left - right
      (Some(_), None) => -1
      (None, Some(_)) => 1
      _ => a.flow_index - b.flow_index
    }
  })
  ordered
}

///|
fn pdf_v2_parity_candidates_for_page(
  candidates : Array[PdfV2TextFlowCandidate],
  page_index : Int,
) -> Array[PdfV2TextFlowCandidate] {
  let out : Array[PdfV2TextFlowCandidate] = []
  for candidate in candidates {
    if candidate.page_index == Some(page_index) {
      out.push(candidate)
    }
  }
  out
}

///|
fn pdf_v2_parity_candidate_ends_sentence(
  candidate : PdfV2TextFlowCandidate,
) -> Bool {
  if candidate.line_signals.length() == 0 {
    return false
  }
  candidate.line_signals[candidate.line_signals.length() - 1].ends_with_sentence_punctuation
}

///|
fn pdf_v2_parity_candidate_starts_marker(
  candidate : PdfV2TextFlowCandidate,
) -> Bool {
  if candidate.line_signals.length() == 0 {
    return false
  }
  let first = candidate.line_signals[0]
  first.starts_with_ordered_marker ||
  first.starts_with_unordered_marker ||
  first.marker_candidate is Some(_)
}

///|
fn pdf_v2_parity_candidate_short_text(
  candidate : PdfV2TextFlowCandidate,
) -> Bool {
  candidate.normalized_text.to_array().length() <= 72 &&
  candidate.line_indices.length() <= 1
}

///|
fn pdf_v2_parity_candidate_vertical_band(
  candidate : PdfV2TextFlowCandidate,
) -> PdfV2ParityVerticalBand {
  if candidate.artifact_refs.length() > 0 {
    pdf_v2_parity_band_from_page_position(
      candidate.artifact_refs[0].position_band,
    )
  } else {
    PdfV2ParityVerticalBand::Unknown
  }
}

///|
fn pdf_v2_parity_band_from_page_position(
  band : PdfV2PagePositionBand,
) -> PdfV2ParityVerticalBand {
  match band {
    Top => PdfV2ParityVerticalBand::Top
    Body => PdfV2ParityVerticalBand::Body
    Bottom => PdfV2ParityVerticalBand::Bottom
    Unknown => PdfV2ParityVerticalBand::Unknown
  }
}

///|
fn pdf_v2_parity_cross_page_confidence(
  prev_open : Bool,
  next_marker : Bool,
  artifact_gap : Bool,
) -> Double {
  let mut confidence = 0.45
  if prev_open {
    confidence = confidence + 0.15
  }
  if next_marker {
    confidence = confidence - 0.10
  }
  if artifact_gap {
    confidence = confidence + 0.10
  }
  pdf_v2_parity_clamp_confidence(confidence)
}

///|
fn pdf_v2_parity_image_text_boundary_for_image(
  page_index : Int?,
  image_ref : String,
  asset_origin_id : String,
  image_order : Int?,
  image_bbox : PdfV2BBox?,
  page_box : PdfV2BBox,
  caption : PdfV2ImageCaptionCandidate?,
  image_source_refs : Array[PdfV2SourceRef],
  candidates : Array[PdfV2TextFlowCandidate],
  base_tag : String,
) -> PdfV2ImageTextBoundaryFact {
  let nearby = pdf_v2_parity_nearby_text(candidates, image_order)
  let caption_candidate = match caption {
    Some(_) => true
    None => nearby.length() > 0 && pdf_v2_parity_text_caption_like(nearby[0])
  }
  let title_nearby = pdf_v2_parity_any_title_nearby(nearby)
  let relation = pdf_v2_parity_text_relation(nearby, image_order)
  let reason_tags = [
    base_tag, "parser_layout_backed", "image_text_nearby_scaffold",
  ]
  if caption_candidate {
    reason_tags.push("caption_candidate")
  }
  if title_nearby {
    reason_tags.push("title_nearby")
  }
  if image_bbox is None {
    reason_tags.push("image_geometry_unknown")
  }
  if nearby.length() == 0 {
    reason_tags.push("nearby_text_unknown")
  }
  let source_refs : Array[PdfV2SourceRef] = []
  source_refs.append(image_source_refs)
  for item in nearby {
    source_refs.append(item.source_refs)
  }
  {
    page_index,
    image_ref,
    asset_origin_id,
    nearby_text_refs: pdf_v2_parity_candidate_refs(nearby),
    relation,
    distance: if image_bbox is Some(_) {
      "bbox_available"
    } else {
      "unknown"
    },
    page_band: pdf_v2_parity_bbox_band(image_bbox, page_box),
    caption_candidate,
    title_nearby,
    confidence: pdf_v2_parity_image_text_confidence(
      caption_candidate,
      title_nearby,
      image_bbox,
      nearby.length(),
    ),
    reason_tags,
    source_refs,
  }
}

///|
fn pdf_v2_parity_nearby_text(
  candidates : Array[PdfV2TextFlowCandidate],
  image_order : Int?,
) -> Array[PdfV2TextFlowCandidate] {
  let out : Array[PdfV2TextFlowCandidate] = []
  match image_order {
    Some(order) => {
      let mut best_delta = 1000000000
      for candidate in candidates {
        match pdf_v2_parity_source_order(candidate.source_refs) {
          Some(candidate_order) => {
            let delta = pdf_v2_parity_abs_int(candidate_order - order)
            if delta < best_delta {
              best_delta = delta
            }
          }
          None => ()
        }
      }
      for candidate in candidates {
        match pdf_v2_parity_source_order(candidate.source_refs) {
          Some(candidate_order) =>
            if pdf_v2_parity_abs_int(candidate_order - order) == best_delta {
              out.push(candidate)
            }
          None => ()
        }
      }
    }
    None => if candidates.length() == 1 { out.push(candidates[0]) }
  }
  out
}

///|
fn pdf_v2_parity_text_caption_like(candidate : PdfV2TextFlowCandidate) -> Bool {
  if candidate.line_signals.length() == 0 {
    false
  } else {
    candidate.line_signals[0].starts_with_caption_marker
  }
}

///|
fn pdf_v2_parity_any_title_nearby(
  candidates : Array[PdfV2TextFlowCandidate],
) -> Bool {
  for candidate in candidates {
    if candidate.line_signals.length() > 0 &&
      candidate.line_signals[0].looks_like_title_line {
      return true
    }
  }
  false
}

///|
fn pdf_v2_parity_text_relation(
  candidates : Array[PdfV2TextFlowCandidate],
  image_order : Int?,
) -> PdfV2ParityTextRelation {
  if candidates.length() == 0 {
    return PdfV2ParityTextRelation::Unknown
  }
  match (image_order, pdf_v2_parity_source_order(candidates[0].source_refs)) {
    (Some(image), Some(text)) if text < image => PdfV2ParityTextRelation::Before
    (Some(image), Some(text)) if text > image => PdfV2ParityTextRelation::After
    (Some(_), Some(_)) => PdfV2ParityTextRelation::SamePage
    _ => PdfV2ParityTextRelation::Unknown
  }
}

///|
fn pdf_v2_parity_image_text_confidence(
  caption_candidate : Bool,
  title_nearby : Bool,
  image_bbox : PdfV2BBox?,
  nearby_count : Int,
) -> Double {
  if nearby_count == 0 {
    return 0.10
  }
  let mut confidence = 0.35
  if caption_candidate {
    confidence = confidence + 0.30
  }
  if title_nearby {
    confidence = confidence + 0.10
  }
  if image_bbox is Some(_) {
    confidence = confidence + 0.15
  }
  pdf_v2_parity_clamp_confidence(confidence)
}

///|
fn pdf_v2_parity_heading_confidence(
  heading_score : Double,
  short_text : Bool,
  sentence_like : Bool,
  body_continuation : Bool,
) -> Double {
  let mut confidence = heading_score
  if confidence < 0.35 {
    confidence = 0.35
  }
  if short_text {
    confidence = confidence + 0.10
  }
  if sentence_like {
    confidence = confidence - 0.20
  }
  if body_continuation {
    confidence = confidence - 0.10
  }
  pdf_v2_parity_clamp_confidence(confidence)
}

///|
fn pdf_v2_parity_font_layout_evidence(
  candidate : PdfV2TextFlowCandidate,
) -> String {
  match candidate.boundary_signal.font_size_relation_to_page {
    Some(_) => "font_relation_available"
    None =>
      if candidate.boundary_signal.boundary_confidence > 0.0 {
        "layout_score_only"
      } else {
        "unknown"
      }
  }
}

///|
fn pdf_v2_parity_column_assignments(page : PdfV2PageModel) -> Array[String] {
  let out : Array[String] = []
  for block in page.blocks {
    out.push(pdf_v2_parity_block_column_assignment(block, page.media_box))
  }
  out
}

///|
fn pdf_v2_parity_line_vertical_band(
  line : PdfV2LineCandidate,
  page : PdfV2PageModel,
) -> PdfV2ParityVerticalBand {
  match line.bbox {
    Some(bbox) => pdf_v2_parity_bbox_band(Some(bbox), page.media_box)
    None => PdfV2ParityVerticalBand::Unknown
  }
}

///|
fn pdf_v2_parity_block_column_assignment(
  block : PdfV2BlockCandidate,
  page_box : PdfV2BBox,
) -> String {
  match block.bbox {
    Some(bbox) => {
      let width = page_box.x1 - page_box.x0
      if width <= 0.0 {
        return "unknown"
      }
      let center = (bbox.x0 + bbox.x1) / 2.0
      let left_cut = page_box.x0 + width * 0.45
      let right_cut = page_box.x0 + width * 0.55
      if center < left_cut {
        "left"
      } else if center > right_cut {
        "right"
      } else {
        "body"
      }
    }
    None => "unknown"
  }
}

///|
fn pdf_v2_parity_image_bbox(
  bbox : PdfV2BBox?,
  placement : PdfV2ImagePlacementFact?,
) -> PdfV2BBox? {
  match bbox {
    Some(_) => bbox
    None =>
      match placement {
        Some(value) => value.bbox
        None => None
      }
  }
}

///|
fn pdf_v2_parity_bbox_band(
  bbox : PdfV2BBox?,
  page_box : PdfV2BBox,
) -> PdfV2ParityVerticalBand {
  match bbox {
    Some(value) => {
      let height = page_box.y1 - page_box.y0
      if height <= 0.0 {
        return PdfV2ParityVerticalBand::Unknown
      }
      let center = (value.y0 + value.y1) / 2.0
      let top_cut = page_box.y1 - height * 0.15
      let bottom_cut = page_box.y0 + height * 0.15
      if center >= top_cut {
        PdfV2ParityVerticalBand::Top
      } else if center <= bottom_cut {
        PdfV2ParityVerticalBand::Bottom
      } else {
        PdfV2ParityVerticalBand::Body
      }
    }
    None => PdfV2ParityVerticalBand::Unknown
  }
}

///|
fn pdf_v2_parity_image_ref(
  object_ref : String?,
  source_ref : PdfV2SourceRef,
) -> String {
  match object_ref {
    Some(value) if value.trim().to_owned() != "" => value
    _ => pdf_v2_parity_source_ref_id(source_ref)
  }
}

///|
fn pdf_v2_parity_inline_image_ref(source_ref : PdfV2SourceRef) -> String {
  "inline:" + pdf_v2_parity_source_ref_id(source_ref)
}

///|
fn pdf_v2_parity_image_asset_origin_id(
  asset : PdfV2ImageAssetCandidate?,
) -> String {
  match asset {
    Some(value) =>
      match value.rel_path {
        Some(path) if path.trim().to_owned() != "" => path
        _ => "asset_present_no_path"
      }
    None => "asset_unknown"
  }
}

///|
fn pdf_v2_parity_image_source_order(image : PdfV2ImageCandidate) -> Int? {
  match image.placement {
    Some(placement) =>
      match placement.source_order {
        Some(_) => placement.source_order
        None => image.source_ref.content_order_index
      }
    None => image.source_ref.content_order_index
  }
}

///|
fn pdf_v2_parity_source_order(refs : Array[PdfV2SourceRef]) -> Int? {
  let mut out : Int? = None
  for source_ref in refs {
    match source_ref.content_order_index {
      Some(order) =>
        match out {
          Some(current) if current <= order => ()
          _ => out = Some(order)
        }
      None => ()
    }
  }
  out
}

///|
fn pdf_v2_parity_source_ref_id(source_ref : PdfV2SourceRef) -> String {
  let page = match source_ref.page_index {
    Some(value) => value.to_string()
    None => "unknown"
  }
  let order = match source_ref.content_order_index {
    Some(value) => value.to_string()
    None => "unknown"
  }
  page + ":" + order
}

///|
fn pdf_v2_parity_candidate_refs(
  candidates : Array[PdfV2TextFlowCandidate],
) -> Array[Int] {
  let out : Array[Int] = []
  for candidate in candidates {
    out.push(candidate.flow_index)
  }
  out
}

///|
fn pdf_v2_parity_refs_pair(
  left : Array[PdfV2SourceRef],
  right : Array[PdfV2SourceRef],
) -> Array[PdfV2SourceRef] {
  let out : Array[PdfV2SourceRef] = []
  out.append(left)
  out.append(right)
  out
}

///|
fn pdf_v2_parity_variant_key(text : String) -> String {
  let out = StringBuilder::new()
  let mut prev_space = false
  let mut prev_digit = false
  for ch in text.to_lower() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if !prev_space {
        out.write_char(' ')
        prev_space = true
      }
      prev_digit = false
    } else if ch >= '0' && ch <= '9' {
      if !prev_digit {
        out.write_char('#')
        prev_digit = true
      }
      prev_space = false
    } else {
      out.write_char(ch)
      prev_space = false
      prev_digit = false
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn pdf_v2_parity_variant_group_key(
  key : String,
  band : PdfV2ParityVerticalBand,
) -> String {
  key + "@" + pdf_v2_parity_band_name(band)
}

///|
fn pdf_v2_parity_band_name(band : PdfV2ParityVerticalBand) -> String {
  match band {
    Top => "top"
    Body => "body"
    Bottom => "bottom"
    Unknown => "unknown"
  }
}

///|
fn pdf_v2_parity_group_key_without_band(group_key : String) -> String {
  let parts = group_key.split("@").to_array()
  if parts.length() == 0 {
    group_key
  } else {
    parts[0].to_owned()
  }
}

///|
fn pdf_v2_parity_variant_cluster_text(left : String, right : String) -> String {
  if left.contains(right) {
    left
  } else if right.contains(left) {
    right
  } else {
    left + " | " + right
  }
}

///|
fn pdf_v2_parity_abs_int(value : Int) -> Int {
  if value < 0 {
    0 - value
  } else {
    value
  }
}

///|
fn pdf_v2_parity_clamp_confidence(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn pdf_v2_parity_append_cross_page_refs(
  out : Array[PdfV2SourceRef],
  facts : Array[PdfV2CrossPageBoundaryFact],
) -> Unit {
  for fact in facts {
    out.append(fact.source_refs)
  }
}

///|
fn pdf_v2_parity_append_image_text_refs(
  out : Array[PdfV2SourceRef],
  facts : Array[PdfV2ImageTextBoundaryFact],
) -> Unit {
  for fact in facts {
    out.append(fact.source_refs)
  }
}

///|
fn pdf_v2_parity_append_variant_refs(
  out : Array[PdfV2SourceRef],
  facts : Array[PdfV2HeaderFooterVariantFact],
) -> Unit {
  for fact in facts {
    out.append(fact.source_refs)
  }
}

///|
fn pdf_v2_parity_append_heading_refs(
  out : Array[PdfV2SourceRef],
  facts : Array[PdfV2HeadingBoundaryFact],
) -> Unit {
  for fact in facts {
    out.append(fact.source_refs)
  }
}

///|
fn pdf_v2_parity_append_column_refs(
  out : Array[PdfV2SourceRef],
  facts : Array[PdfV2ColumnLayoutFact],
) -> Unit {
  for fact in facts {
    out.append(fact.source_refs)
  }
}
