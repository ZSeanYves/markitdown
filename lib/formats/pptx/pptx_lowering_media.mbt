///|
fn pptx_lower_picture(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
) -> Unit {
  let media = match pic.media {
    Some(value) => value
    None => return
  }
  if media.is_external {
    state.diagnostics.warnings.push(
      "external pptx media skipped: " +
      media.resolved_target.unwrap_or("unknown target"),
    )
    state.diagnostics.degraded_features.push("pptx_external_media_no_fetch")
    blocks.push(
      pptx_raw_placeholder_block(
        state,
        slide,
        Some(media.source_key),
        media.relationship_id,
        "[Unsupported PPTX media" + pptx_opt_suffix(media.resolved_target) + "]",
        "pptx_external_media_no_fetch",
      ),
    )
    return
  }
  if media.unsupported || media.data is None {
    state.diagnostics.warnings.push(
      "unsupported pptx media skipped: " +
      media.resolved_target.unwrap_or("unknown target"),
    )
    state.diagnostics.degraded_features.push("pptx_media_unsupported")
    blocks.push(
      pptx_raw_placeholder_block(
        state,
        slide,
        Some(media.source_key),
        media.relationship_id,
        "[Unsupported PPTX media" + pptx_opt_suffix(media.resolved_target) + "]",
        "pptx_media_unsupported",
      ),
    )
    return
  }
  let image_block = pptx_image_block_from_media(state, slide, pic, media)
  blocks.push(image_block)
}

///|
fn pptx_image_block_from_media(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
  media : @pptxdoc.PptxMediaRef,
) -> @core.CoreBlock {
  let target_part = media.resolved_target.unwrap_or(
    media.target.unwrap_or("ppt/media/image.bin"),
  )
  let asset_key = pptx_picture_asset_key(slide, pic, media)
  let output_path = pptx_asset_output_path(state, asset_key, target_part)
  let source_ref = pptx_picture_source_ref(
    state.source,
    slide,
    pic,
    pptx_include_block_reading_order_hint(state),
  )
  let observed = media.data.unwrap().length().to_int64()
  if !@parser.asset_payload_within_limits(
      state.context,
      observed,
      pptx_declared_asset_bytes(state.assets),
    ) {
    @parser.record_asset_payload_budget_skip(
      state.diagnostics,
      "pptx:" + asset_key,
      "single_or_total_asset_bytes",
      observed,
      @parser.max_asset_payload_bytes(state.context),
    )
    bump_metric(state.diagnostics, "skipped_asset_count")
    let unavailable = @core.make_block(
      BlockQuote,
      "Asset unavailable: " + target_part,
      source_ref~,
    )
    unavailable.attrs.set("asset_missing", "true")
    unavailable.attrs.set("asset_source_path", target_part)
    unavailable.attrs.set("payload_skipped", "asset_limit")
    return unavailable
  }
  let asset = pptx_ensure_asset(
    state, media, asset_key, output_path, source_ref,
  )
  let alt = pptx_image_alt_text(state, pic, media, slide.slide_index)
  let block = @core.make_block(Image, "", source_ref~)
  block.attrs.set("path", asset.path.unwrap_or(output_path))
  block.attrs.set("alt", alt)
  match media.title {
    Some(title) => if title.trim() != "" { block.attrs.set("title", title) }
    None => ()
  }
  match pptx_image_caption_for_picture(slide, pic.source_key) {
    Some(caption) =>
      if caption.trim() != "" {
        block.attrs.set("caption", caption)
      }
    None => ()
  }
  block
}

///|
fn pptx_ensure_asset(
  state : PptxState,
  media : @pptxdoc.PptxMediaRef,
  asset_key : String,
  output_path : String,
  source_ref : @core.SourceRef,
) -> @core.AssetRef {
  let target_part = media.resolved_target.unwrap_or(media.target.unwrap_or(""))
  match state.asset_ids.get(asset_key) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset
        }
      }
    None => ()
  }
  let asset_id = "pptx:" + asset_key
  let asset = @core.make_asset_ref(Image, asset_id, source_ref~)
  let next_asset = {
    ..asset,
    path: Some(output_path),
    mime_type: media.content_type,
  }
  next_asset.attrs.set("alt", pptx_media_alt_text(media))
  next_asset.attrs.set("source_path", target_part)
  next_asset.attrs.set("zip_entry_path", target_part)
  next_asset.attrs.set("zip_container_format", "pptx")
  match media.data {
    Some(bytes) =>
      next_asset.attrs.set("declared_asset_bytes", bytes.length().to_string())
    None => ()
  }
  match @input.input_path(state.source) {
    Some(path) => next_asset.attrs.set("zip_container_path", path)
    None => ()
  }
  state.assets.push(next_asset)
  state.asset_ids.set(asset_key, asset_id)
  bump_metric(state.diagnostics, "materialized_asset_count")
  next_asset
}

///|
fn pptx_declared_asset_bytes(assets : Array[@core.AssetRef]) -> Int64 {
  let mut total = 0L
  for asset in assets {
    match asset.attrs.get("declared_asset_bytes") {
      Some(raw) => total += (@string.parse_int(raw) catch { _ => 0 }).to_int64()
      None => ()
    }
  }
  total
}

///|
fn metric_int(diagnostics : @core.Diagnostics, key : String) -> Int {
  @string.parse_int(diagnostics.metrics.get(key).unwrap_or("0")) catch {
    _ => 0
  }
}

///|
fn bump_metric(diagnostics : @core.Diagnostics, key : String) -> Unit {
  let current = metric_int(diagnostics, key)
  diagnostics.metrics.set(key, (current + 1).to_string())
}

///|
fn pptx_asset_output_path(
  state : PptxState,
  asset_key : String,
  target_part : String,
) -> String {
  match state.asset_ids.get(asset_key) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset.path.unwrap_or("assets/image01.bin")
        }
      }
    None => ()
  }
  let index = state.assets.length() + 1
  "assets/image" + pptx_two_digits(index) + "." + pptx_media_ext(target_part)
}

///|
fn pptx_picture_asset_key(
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
  media : @pptxdoc.PptxMediaRef,
) -> String {
  slide.slide_index.to_string() +
  ":" +
  pic.source_key.node_key +
  ":" +
  pic.shape_id.unwrap_or("") +
  ":" +
  media.resolved_target.unwrap_or(media.target.unwrap_or(""))
}

///|
fn pptx_media_ext(target_part : String) -> String {
  let lower = target_part.to_lower()
  let chars = lower.to_array()
  let mut last_dot : Int? = None
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = Some(i)
    }
  }
  match last_dot {
    Some(index) =>
      if index + 1 < lower.length() {
        lower[index + 1:].to_owned()
      } else {
        "bin"
      }
    None => "bin"
  }
}

///|
fn pptx_two_digits(index : Int) -> String {
  if index < 10 {
    "0" + index.to_string()
  } else {
    index.to_string()
  }
}

///|
fn pptx_image_alt_text(
  state : PptxState,
  pic : @pptxdoc.PptxPicture,
  media : @pptxdoc.PptxMediaRef,
  slide_index : Int,
) -> String {
  let fallback = pptx_picture_synthetic_id(state, media, slide_index)
  match media.alt_text {
    Some(text) =>
      if pptx_nonsemantic_picture_label(text) {
        fallback
      } else {
        text
      }
    None =>
      match pic.name {
        Some(name) =>
          if pptx_nonsemantic_picture_label(name) ||
            pptx_generic_picture_name(name) {
            fallback
          } else {
            name
          }
        None => fallback
      }
  }
}

///|
fn pptx_generic_picture_name(name : String) -> Bool {
  let trimmed = name.trim().to_owned()
  if trimmed == "" {
    return true
  }
  let lower = trimmed.to_lower()
  lower == "picture" ||
  lower.has_prefix("picture ") ||
  lower.has_prefix("content placeholder") ||
  lower.has_prefix("placeholder ")
}

///|
fn pptx_nonsemantic_picture_label(text : String) -> Bool {
  let lower = text.trim().to_owned().to_lower()
  if lower == "" {
    return true
  }
  if pptx_path_like_descr(lower) {
    return true
  }
  lower.has_suffix(".wav") ||
  lower.has_suffix(".mp3") ||
  lower.has_suffix(".m4a") ||
  lower.has_suffix(".aac") ||
  lower.has_suffix(".wma") ||
  lower.has_suffix(".mp4") ||
  lower.has_suffix(".m4v") ||
  lower.has_suffix(".mov") ||
  lower.has_suffix(".avi") ||
  lower.has_suffix(".wmv")
}

///|
fn pptx_picture_synthetic_id(
  state : PptxState,
  media : @pptxdoc.PptxMediaRef,
  slide_index : Int,
) -> String {
  let key = slide_index.to_string() +
    ":" +
    media.source_key.node_key +
    ":" +
    media.resolved_target.unwrap_or(media.target.unwrap_or(""))
  match state.image_ids.get(key) {
    Some(id) => id
    None => {
      let slide_key = slide_index.to_string()
      let next_index = state.slide_image_counts.get(slide_key).unwrap_or(0) + 1
      state.slide_image_counts.set(slide_key, next_index)
      let id = "slide-" +
        slide_index.to_string() +
        "-image-" +
        next_index.to_string()
      state.image_ids.set(key, id)
      id
    }
  }
}

///|
fn pptx_media_alt_text(media : @pptxdoc.PptxMediaRef) -> String {
  match media.alt_text {
    Some(text) => if pptx_path_like_descr(text) { "image" } else { text }
    None => "image"
  }
}

///|
fn pptx_path_like_descr(text : String) -> Bool {
  let value = text.trim().to_lower()
  if value == "" {
    return false
  }
  if value.contains("/") || value.contains("\\") {
    return true
  }
  value.has_suffix(".png") ||
  value.has_suffix(".jpg") ||
  value.has_suffix(".jpeg") ||
  value.has_suffix(".gif") ||
  value.has_suffix(".bmp") ||
  value.has_suffix(".tif") ||
  value.has_suffix(".tiff") ||
  value.has_suffix(".svg") ||
  value.has_suffix(".webp")
}

///|
fn pptx_image_caption_for_picture(
  slide : @pptxdoc.PptxSlide,
  key : @pptxdoc.PptxSourceKey,
) -> String? {
  for pair in slide.image_caption_pairs {
    if pair.picture_key.part_name == key.part_name &&
      pair.picture_key.node_key == key.node_key &&
      pptx_caption_pair_is_semantic(pair) {
      return Some(pair.caption_text)
    }
  }
  None
}

///|
fn pptx_caption_pair_is_semantic(pair : @pptxdoc.PptxImageCaptionPair) -> Bool {
  pptx_caption_text_has_prefix(pair.caption_text)
}
