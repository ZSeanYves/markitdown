///|
pub(all) enum PdfV2DecodeProfileEncodingKind {
  ToUnicode
  CMap
  StandardEncoding
  GlyphName
  CjkFallback
  RawBytes
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2DecodeProfile {
  font_ref : String?
  font_name : String?
  encoding_kind : PdfV2DecodeProfileEncodingKind
  confidence : PdfV2TextDecodeConfidence
  reason_tags : Array[String]
  warnings : Array[PdfV2Warning]
}

///|
pub(all) struct PdfV2FontCache {
  fonts_seen : Array[String]
  decode_profiles : Array[PdfV2DecodeProfile]
  cache_hits : Int
  cache_misses : Int
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
fn pdf_v2_has_tag(tags : Array[String], tag : String) -> Bool {
  tags.contains(tag)
}

///|
fn pdf_v2_tags_join(
  first : Array[String],
  second : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(first)
  out.append(second)
  out
}

///|
fn pdf_v2_font_key(font_ref : String?, font_name : String?) -> String {
  match font_ref {
    Some(value) => value
    None =>
      match font_name {
        Some(value) => value
        None => "<unknown-font>"
      }
  }
}

///|
fn pdf_v2_profile_encoding_kind(
  confidence : PdfV2TextDecodeConfidence,
  reason_tags : Array[String],
) -> PdfV2DecodeProfileEncodingKind {
  if pdf_v2_has_tag(reason_tags, "tounicode_or_font_decode") ||
    confidence == PdfV2TextDecodeConfidence::High {
    PdfV2DecodeProfileEncodingKind::ToUnicode
  } else if pdf_v2_has_tag(reason_tags, "cmap") {
    PdfV2DecodeProfileEncodingKind::CMap
  } else if pdf_v2_has_tag(reason_tags, "gbk") ||
    pdf_v2_has_tag(reason_tags, "cjk") ||
    confidence == PdfV2TextDecodeConfidence::Low {
    PdfV2DecodeProfileEncodingKind::CjkFallback
  } else if pdf_v2_has_tag(reason_tags, "font_encoding_candidate") {
    PdfV2DecodeProfileEncodingKind::StandardEncoding
  } else if pdf_v2_has_tag(reason_tags, "glyph_candidate") {
    PdfV2DecodeProfileEncodingKind::GlyphName
  } else if pdf_v2_has_tag(reason_tags, "missing_font_resource") {
    PdfV2DecodeProfileEncodingKind::RawBytes
  } else {
    PdfV2DecodeProfileEncodingKind::Unknown
  }
}

///|
fn pdf_v2_find_profile_index(
  profiles : Array[PdfV2DecodeProfile],
  font_key : String,
) -> Int? {
  for index = 0; index < profiles.length(); index = index + 1 {
    let profile = profiles[index]
    if pdf_v2_font_key(profile.font_ref, profile.font_name) == font_key {
      return Some(index)
    }
  }
  None
}

///|
fn pdf_v2_low_confidence_decode_risk(
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::DecodeLowConfidence,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 decode profile is not reliable enough for text reconstruction",
    source_refs: [source_ref],
    reason_tags,
  }
}

///|
pub fn pdf_v2_build_font_cache_from_text_events(
  events : Array[PdfV2CoreEvent],
) -> PdfV2FontCache {
  let fonts_seen : Array[String] = []
  let profiles : Array[PdfV2DecodeProfile] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let mut cache_hits = 0
  let mut cache_misses = 0
  let mut active_font_name : String? = None

  for event in events {
    match event.text_state {
      Some(fact) =>
        if event.kind == PdfV2CoreEventKind::FontUse {
          active_font_name = fact.font_name_or_ref
          let font_key = pdf_v2_font_key(None, fact.font_name_or_ref)
          if !fonts_seen.contains(font_key) {
            fonts_seen.push(font_key)
          }
        }
      None => ()
    }
    match event.text_show {
      Some(fact) => {
        let font_key = pdf_v2_font_key(fact.font_ref, active_font_name)
        if !fonts_seen.contains(font_key) {
          fonts_seen.push(font_key)
        }
        match pdf_v2_find_profile_index(profiles, font_key) {
          Some(_) => cache_hits = cache_hits + 1
          None => {
            cache_misses = cache_misses + 1
            let reason_tags = pdf_v2_tags_join(fact.reason_tags, [
              "font_cache_profile",
            ])
            let profile : PdfV2DecodeProfile = {
              font_ref: fact.font_ref,
              font_name: active_font_name,
              encoding_kind: pdf_v2_profile_encoding_kind(
                fact.decode_confidence,
                fact.reason_tags,
              ),
              confidence: fact.decode_confidence,
              reason_tags,
              warnings: fact.warnings,
            }
            profiles.push(profile)
            match fact.decode_confidence {
              Unknown | Failed =>
                risks.push(
                  pdf_v2_low_confidence_decode_risk(
                    fact.source_ref,
                    profile.reason_tags,
                  ),
                )
              _ => ()
            }
          }
        }
        for warning in fact.warnings {
          warnings.push(warning)
        }
      }
      None => ()
    }
  }

  {
    fonts_seen,
    decode_profiles: profiles,
    cache_hits,
    cache_misses,
    warnings,
    risks,
  }
}
