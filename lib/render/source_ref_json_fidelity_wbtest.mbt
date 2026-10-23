///|
fn position_fixture() -> @core.SourceRef {
  {
    ..@core.empty_source_ref(),
    file_id: Some("all-fields"),
    format: Some("fixture"),
    page: Some(0),
    bbox: Some({ x0: -1.25, y0: 0.0, x1: 2.5, y1: -0.5, }),
    line_start: Some(2),
    line_end: Some(3),
    byte_start: Some(0),
    byte_end: Some(17),
    time_start: Some("00:00:01,250"),
    time_end: Some("00:00:02.500"),
  }
}

///|
fn check_position_json(value : Json) -> Unit raise {
  guard value is Object(fields) else {
    fail("source location must be an object")
  }
  assert_eq(fields.get("page"), Some(Json(0)))
  assert_eq(
    fields.get("bbox"),
    Some(({ "x0": -1.25, "y0": 0.0, "x1": 2.5, "y1": -0.5 } : Json)),
  )
  assert_eq(fields.get("byte_start"), Some(Json(0)))
  assert_eq(fields.get("byte_end"), Some(Json(17)))
  assert_eq(fields.get("time_start"), Some(Json("00:00:01,250")))
  assert_eq(fields.get("time_end"), Some(Json("00:00:02.500")))
}

///|
fn check_all_position_refs(value : Json) -> Int32 raise {
  match value {
    Object(fields) => {
      let mut count = 0
      if fields.get("file_id") == Some(Json("all-fields")) {
        check_position_json(value)
        count += 1
      }
      for item in fields.values() {
        count += check_all_position_refs(item)
      }
      count
    }
    Array(values) => {
      let mut count = 0
      for item in values {
        count += check_all_position_refs(item)
      }
      count
    }
    _ => 0
  }
}

///|
test "SourceRef JSON adds every present field and preserves exact finite values" {
  let encoded = render_source_ref_json(Some(position_fixture()))
  check_position_json(@probe_json.parse(encoded, reject_duplicate_keys=true))
  let negative = {
    ..position_fixture(),
    page: Some(-2),
    byte_start: Some(-7),
    byte_end: Some(0),
    time_start: Some(""),
    time_end: None,
  }
  guard @probe_json.parse(render_source_ref_json(Some(negative)))
    is Object(fields) else {
    fail("object expected")
  }
  assert_eq(fields.get("page"), Some(Json(-2)))
  assert_eq(fields.get("byte_start"), Some(Json(-7)))
  assert_eq(fields.get("byte_end"), Some(Json(0)))
  assert_eq(fields.get("time_start"), Some(Json("")))
  assert_eq(fields.get("time_end"), None)
}

///|
test "SourceRef None additions preserve legacy JSON keys nulls and order" {
  assert_eq(render_source_ref_json(None), "null")
  assert_eq(
    render_source_ref_json(Some(@core.empty_source_ref())),
    "{\"file_id\": null, \"format\": null, \"line_start\": null, \"line_end\": null, \"json_pointer\": null, \"xpath\": null, \"yaml_path\": null, \"html_path\": null, \"markdown_path\": null, \"container_path\": null, \"entry_path\": null, \"entry_index\": null, \"entry_format\": null, \"inner_path\": null, \"sheet\": null, \"cell_range\": null, \"slide\": null, \"shape_id\": null, \"relationship_id\": null, \"chapter_href\": null, \"extra\": {}}",
  )
}

///|
async test "SourceRef rejects every nonfinite bbox coordinate in collector and Sink" {
  for number in [0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0] {
    for coordinate in ["x0", "y0", "x1", "y1"] {
      let source = {
        ..position_fixture(),
        bbox: Some({
          x0: if coordinate == "x0" {
            number
          } else {
            0.0
          },
          y0: if coordinate == "y0" {
            number
          } else {
            0.0
          },
          x1: if coordinate == "x1" {
            number
          } else {
            1.0
          },
          y1: if coordinate == "y1" {
            number
          } else {
            1.0
          },
        }),
      }
      let caught = try {
        ignore(render_source_ref_json(Some(source)))
        "no error"
      } catch {
        NonFiniteSourceBBox(field) => field
      }
      assert_eq(caught, coordinate)
      for mode in [@product.OutputMode::Debug, Rag] {
        let input = BlockStream([
          @core.make_block(Paragraph, "body", source_ref=source),
        ])
        let context = make_render_context(false, output_mode=mode)
        let renderer = if mode == Debug {
          debug_json_renderer()
        } else {
          rag_json_renderer()
        }
        let caught = try {
          ignore((renderer.render_input)(input, context))
          "no error"
        } catch {
          NonFiniteSourceBBox(field) => field
        }
        assert_eq(caught, coordinate)
        let parts : Array[String] = []
        let result = render_json_input_to_sink(input, context, part => {
          parts.push(part)
          Ok(())
        })
        assert_eq(
          result.map(value => value.content),
          Err("SourceRef bbox " + coordinate + " must be finite"),
        )
        assert_true(parts.length() > 0)
        assert_false(
          parts.join("").contains("Infinity") || parts.join("").contains("NaN"),
        )
      }
    }
  }
}

///|
test "XML legacy source identity excludes new positions without changing the shared old projection" {
  let source = position_fixture()
  let before = {
    ..source,
    page: None,
    bbox: None,
    byte_start: None,
    byte_end: None,
    time_start: None,
    time_end: None,
  }
  assert_eq(
    legacy_source_ref_identity_json(Some(source)),
    render_source_ref_json(Some(before)),
  )
  assert_eq(
    legacy_source_ref_identity_json(
      Some({
        ..source,
        bbox: Some({ x0: 1.0 / 0.0, y0: 0.0, x1: 1.0, y1: 1.0, }),
      }),
    ),
    legacy_source_ref_identity_json(Some(source)),
  )
  assert_eq(legacy_source_ref_identity_json(None), "null")
}

///|
async test "SourceRef full fields roundtrip equally through collecting and Sink every IR shape" {
  let source = position_fixture()
  let inline = @core.make_inline_link(
    "link",
    "https://example.test",
    source_ref=source,
  )
  let child = @core.make_block(Paragraph, "child", source_ref=source)
  let block = @core.make_block(Paragraph, "body", source_ref=source)
    |> @core.block_with_children([child])
    |> @core.block_with_rich_inlines(Some([inline]))
  let asset = @core.make_asset_ref(Image, "asset", source_ref=source)
  let entry = @core.make_source_map_entry(
    primary_ref=Some(source),
    refs=[source],
    merged_from=[source],
  )
  let source_map = @core.empty_source_map()
    |> @core.source_map_with_document_ref(Some(source))
    |> @core.source_map_add_block_entry(entry)
    |> @core.source_map_add_asset_entry(entry)
  let document = {
    ..@core.empty_document_ir(),
    blocks: [block],
    assets: [asset],
    source_map: Some(source_map),
  }
  for mode in [@product.OutputMode::Debug, Rag] {
    for
      input in [
        Document(document),
        BlockStream([block]),
        EventStream([rag_test_event(TextLine, "body", source_ref=Some(source))]),
      ] {
      let context = make_render_context(
        false,
        output_mode=mode,
        assets=Some([asset]),
        source_map=Some(source_map),
      )
      let renderer = if mode == Debug {
        debug_json_renderer()
      } else {
        rag_json_renderer()
      }
      let expected = (renderer.render_input)(input, context)
      let parts : Array[String] = []
      let streamed = render_json_input_to_sink(input, context, async fn(part) {
        @async.pause()
        parts.push(part)
        Ok(())
      }).unwrap()
      assert_eq(parts.join(""), expected.content)
      assert_eq(
        streamed.chunks.map(chunks => chunks.map(chunk => chunk.id)),
        expected.chunks.map(chunks => chunks.map(chunk => chunk.id)),
      )
      assert_true(
        check_all_position_refs(
          @probe_json.parse(expected.content, reject_duplicate_keys=true),
        ) >
        0,
      )
    }
  }
}
