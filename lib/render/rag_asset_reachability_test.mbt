///|
fn rag_asset_object(value : Json) -> Map[String, Json] raise {
  match value {
    Object(fields) => fields
    _ => fail("expected a JSON object")
  }
}

///|
fn rag_asset_array(value : Json) -> Array[Json] raise {
  match value {
    Array(items) => items
    _ => fail("expected a JSON array")
  }
}

///|
fn rag_asset_string(value : Json) -> String raise {
  match value {
    String(text) => text
    _ => fail("expected a JSON string")
  }
}

///|
fn rag_container_source_ref(
  container : String,
  entry : String,
  index : Int32,
) -> @core.SourceRef {
  @core.source_ref_with_container_entry(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(container + "::" + entry),
      Some("html"),
      Some(1),
      Some(1),
    ),
    Some(container + "::" + entry),
    Some("html"),
    Some(container),
    Some(entry),
    Some(index),
    Some("html"),
    Some("/image/html:image:1"),
  )
}

///|
fn rag_asset_source_map(assets : Array[@core.AssetRef]) -> @core.SourceMap {
  let source_map = @core.empty_source_map()
  for asset in assets {
    source_map.asset_entries.push(
      @core.make_source_map_entry(primary_ref=asset.source_ref, refs=[
        asset.source_ref.unwrap(),
      ]),
    )
  }
  source_map
}

///|
fn check_rag_asset_reachability(
  content : String,
  expected : Array[@core.AssetRef],
) -> Array[Json] raise {
  let root = rag_asset_object(@corejson.parse(content))
  let assets = rag_asset_array(root["assets"])
  let entries = rag_asset_array(
    rag_asset_object(root["source_map"])["asset_entries"],
  )
  assert_eq(assets.length(), expected.length())
  assert_eq(entries.length(), expected.length())
  let ids : Map[String, Bool] = Map([])
  for index, asset in assets {
    let fields = rag_asset_object(asset)
    let id = rag_asset_string(fields["asset_id"])
    assert_eq(id, expected[index].asset_id)
    assert_true(!ids.contains(id))
    ids.set(id, true)
    assert_eq(rag_asset_string(fields["path"]), expected[index].path.unwrap())
    let source = rag_asset_object(fields["source_ref"])
    let source_entry = rag_asset_object(
      rag_asset_object(entries[index])["primary_ref"],
    )
    assert_eq(source["entry_path"], source_entry["entry_path"])
    assert_eq(
      rag_asset_string(source["entry_path"]),
      expected[index].source_ref.unwrap().entry_path.unwrap(),
    )
  }
  let chunks = rag_asset_array(root["chunks"])
  let mut reference_count = 0
  for chunk in chunks {
    let fields = rag_asset_object(chunk)
    for reference in rag_asset_array(fields["asset_refs"]) {
      assert_true(ids.contains(rag_asset_string(reference)))
      reference_count += 1
    }
  }
  assert_true(reference_count > 0)
  chunks
}

///|
test "RAG block rendering keeps remapped ZIP assets reachable in stable source order" {
  let alpha_ref = rag_container_source_ref("book.zip", "alpha/page.html", 1)
  let beta_ref = rag_container_source_ref("book.zip", "beta/page.html", 3)
  let alpha_asset = {
    ..@core.make_asset_ref(
      Image,
      "zip:alpha/page.html:html-image-1",
      source_ref=alpha_ref,
    ),
    path: Some("assets/alpha-image.png"),
    mime_type: Some("image/png"),
  }
  let beta_asset = {
    ..@core.make_asset_ref(
      Image,
      "zip:beta/page.html:html-image-1",
      source_ref=beta_ref,
    ),
    path: Some("assets/beta-image.png"),
    mime_type: Some("image/png"),
  }
  // Asset order belongs to the source map, independently of chunk order.
  let assets = [beta_asset, alpha_asset]
  let source_map = rag_asset_source_map(assets)
  let metadata : @core.DocumentMetadata = Map([("format", String("zip"))])
  let blocks = [
    @core.make_block(Image, "Alpha caption", source_ref=alpha_ref)
    |> @core.block_with_attr("asset_id", alpha_asset.asset_id),
    @core.make_block(Image, "Beta caption", source_ref=beta_ref)
    |> @core.block_with_attr("asset_id", beta_asset.asset_id),
  ]
  let context = @render.make_render_context(
    false,
    assets=Some(assets),
    source_map=Some(source_map),
    metadata=Some(metadata),
  )
  let renderer = @render.rag_json_renderer()
  let result = (renderer.render_input)(BlockStream(blocks), context)
  let chunks = check_rag_asset_reachability(result.content, assets)
  assert_eq(chunks.length(), 2)
  assert_eq(rag_asset_array(rag_asset_object(chunks[0])["asset_refs"]), [
    Json(alpha_asset.asset_id),
  ])
  let document = {
    ..@core.empty_document_ir(),
    blocks,
    assets,
    source_map: Some(source_map),
    metadata,
  }
  let document_result = (renderer.render)(document, context)
  assert_eq(
    chunks,
    check_rag_asset_reachability(document_result.content, assets),
  )
  let repeated = (renderer.render_input)(BlockStream(blocks), context)
  assert_eq(chunks, check_rag_asset_reachability(repeated.content, assets))
}

///|
test "RAG event rendering keeps EPUB cover asset IDs and provenance reachable" {
  let source_ref = rag_container_source_ref("book.epub", "OPS/cover.xhtml", 0)
  let asset = {
    ..@core.make_asset_ref(
      Image,
      "epub:OPS/images/cover.png:cover",
      source_ref~,
    ),
    path: Some("assets/cover.png"),
    mime_type: Some("image/png"),
  }
  let event_ref = {
    ..source_ref,
    extra: Map([
      ("ir_event_encoding", "generic_block"),
      ("ir_block_attr_asset_id", asset.asset_id),
    ]),
  }
  let events : Array[@core.CoreEvent] = [
    { kind: StartBlock(Image), text: "Cover art", source_ref: Some(event_ref), },
    { kind: EndBlock(Image), text: "", source_ref: None, },
  ]
  let assets = [asset]
  let context = @render.make_render_context(
    false,
    assets=Some(assets),
    source_map=Some(rag_asset_source_map(assets)),
    metadata=Some(Map([("format", String("epub"))])),
  )
  let renderer = @render.rag_json_renderer()
  let result = (renderer.render_input)(EventStream(events), context)
  let chunks = check_rag_asset_reachability(result.content, assets)
  assert_eq(chunks.length(), 1)
  let chunk = rag_asset_object(chunks[0])
  assert_eq(rag_asset_string(chunk["kind"]), "image_caption")
  assert_eq(rag_asset_string(chunk["text"]), "Cover art")
  let source = rag_asset_object(rag_asset_array(chunk["source_refs"])[0])
  assert_eq(rag_asset_string(source["container_path"]), "book.epub")
  assert_eq(rag_asset_string(source["entry_path"]), "OPS/cover.xhtml")
}
