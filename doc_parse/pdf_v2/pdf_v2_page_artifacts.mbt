///|
pub(all) enum PdfV2PageArtifactKind {
  HeaderLike
  FooterLike
  PageNumberLike
  RepeatedLineLike
  CaptionLike
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2PagePositionBand {
  Top
  Body
  Bottom
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2PageArtifactCandidate {
  kind : PdfV2PageArtifactKind
  normalized_text : String
  page_indices : Array[Int]
  repeat_count : Int
  position_band : PdfV2PagePositionBand
  confidence : Double
  reason_tags : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub fn pdf_v2_build_page_artifact_candidates(
  model : PdfV2DocumentModel,
) -> Array[PdfV2PageArtifactCandidate] {
  let candidates : Array[PdfV2PageArtifactCandidate] = []
  let repeated = pdf_v2_page_artifact_repeated_lines(model)
  candidates.append(repeated)
  for page in model.pages {
    for line in page.lines {
      if line.text_signal.starts_with_page_number {
        candidates.push({
          kind: PdfV2PageArtifactKind::PageNumberLike,
          normalized_text: line.text_signal.normalized_text,
          page_indices: match line.page_index {
            Some(index) => [index]
            None => [page.page_index]
          },
          repeat_count: 1,
          position_band: pdf_v2_page_artifact_position_band(line, page),
          confidence: 0.98,
          reason_tags: [
            "page_artifact_candidate", "parser_owned_page_artifact_candidate", "page_number_like",
          ],
          source_refs: line.source_refs,
        })
      } else if line.text_signal.starts_with_caption_marker {
        candidates.push({
          kind: PdfV2PageArtifactKind::CaptionLike,
          normalized_text: line.text_signal.normalized_text,
          page_indices: match line.page_index {
            Some(index) => [index]
            None => [page.page_index]
          },
          repeat_count: 1,
          position_band: pdf_v2_page_artifact_position_band(line, page),
          confidence: 0.72,
          reason_tags: [
            "page_artifact_candidate", "parser_owned_page_artifact_candidate", "caption_like",
          ],
          source_refs: line.source_refs,
        })
      }
    }
  }
  candidates
}

///|
fn pdf_v2_page_artifact_repeated_lines(
  model : PdfV2DocumentModel,
) -> Array[PdfV2PageArtifactCandidate] {
  let texts : Array[String] = []
  let pages_by_text : Array[Array[Int]] = []
  let refs_by_text : Array[Array[PdfV2SourceRef]] = []
  let band_by_text : Array[PdfV2PagePositionBand] = []
  for page in model.pages {
    for line in page.lines {
      let t = line.text_signal.normalized_text
      if !pdf_v2_page_artifact_repetition_eligible(line.text_signal) {
        continue
      }
      let band = pdf_v2_page_artifact_position_band(line, page)
      let mut found = -1
      for i in 0..<texts.length() {
        if texts[i] == t {
          found = i
          break
        }
      }
      if found < 0 {
        texts.push(t)
        pages_by_text.push([page.page_index])
        refs_by_text.push(line.source_refs)
        band_by_text.push(band)
      } else {
        if !pages_by_text[found].contains(page.page_index) {
          pages_by_text[found].push(page.page_index)
        }
        refs_by_text[found].append(line.source_refs)
        if band_by_text[found] == PdfV2PagePositionBand::Unknown &&
          band != PdfV2PagePositionBand::Unknown {
          band_by_text[found] = band
        }
      }
    }
  }
  let out : Array[PdfV2PageArtifactCandidate] = []
  for i in 0..<texts.length() {
    if pages_by_text[i].length() >= 2 {
      let band = band_by_text[i]
      let kind = match band {
        Top => PdfV2PageArtifactKind::HeaderLike
        Bottom => PdfV2PageArtifactKind::FooterLike
        _ => PdfV2PageArtifactKind::RepeatedLineLike
      }
      out.push({
        kind,
        normalized_text: texts[i],
        page_indices: pages_by_text[i],
        repeat_count: pages_by_text[i].length(),
        position_band: band,
        confidence: if band == PdfV2PagePositionBand::Top ||
          band == PdfV2PagePositionBand::Bottom {
          0.88
        } else {
          0.82
        },
        reason_tags: [
          "page_artifact_candidate", "parser_owned_page_artifact_candidate", "repeated_short_line",
        ],
        source_refs: refs_by_text[i],
      })
    }
  }
  out
}

///|
fn pdf_v2_page_artifact_repetition_eligible(
  signal : PdfV2LineTextSignal,
) -> Bool {
  signal.normalized_text != "" &&
  signal.char_count >= 4 &&
  signal.char_count <= 80 &&
  !signal.looks_like_title_line &&
  !signal.starts_with_ordered_marker &&
  !signal.starts_with_unordered_marker &&
  !signal.starts_with_caption_marker &&
  !signal.ends_with_sentence_punctuation
}

///|
fn pdf_v2_page_artifact_position_band(
  line : PdfV2LineCandidate,
  page : PdfV2PageModel,
) -> PdfV2PagePositionBand {
  match line.bbox {
    Some(bbox) => {
      let height = page.media_box.y1 - page.media_box.y0
      if height <= 0.0 {
        return PdfV2PagePositionBand::Unknown
      }
      let top_cut = page.media_box.y1 - height * 0.15
      let bottom_cut = page.media_box.y0 + height * 0.15
      if bbox.y1 >= top_cut {
        PdfV2PagePositionBand::Top
      } else if bbox.y0 <= bottom_cut {
        PdfV2PagePositionBand::Bottom
      } else {
        PdfV2PagePositionBand::Body
      }
    }
    None => PdfV2PagePositionBand::Unknown
  }
}
