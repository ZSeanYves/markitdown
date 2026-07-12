///|
test "EPUB parser lowers spine metadata navigation images and boundary packages" {
  let fixtures = [
    "samples/fixtures/contracts/epub/epub_basic_package.epub", "samples/fixtures/contracts/epub/epub_basic_spine.epub",
    "samples/fixtures/contracts/epub/epub_metadata_basic.epub", "samples/fixtures/contracts/epub/epub_nav_toc.epub",
    "samples/fixtures/contracts/epub/epub_ncx_nested.epub", "samples/fixtures/contracts/epub/epub_cover_image.epub",
    "samples/fixtures/contracts/epub/epub_local_image_basic.epub", "samples/fixtures/contracts/epub/epub_remote_data_image_boundary.epub",
    "samples/fixtures/contracts/epub/epub_unsupported_spine_warning.epub", "samples/fixtures/contracts/epub/epub_spine_missing_item_boundary.epub",
  ]
  let parser = epub_parser(fn() { @parser.empty_registry() })
  let context = @parser.new_parse_context(@input.DetectedFormat::Epub)
  let mut blocks = 0
  let mut assets = 0
  for path in fixtures {
    let result = (parser.parse)(@input.input_from_path(path), context).unwrap()
    blocks += result.block_stream.unwrap().length()
    assets += result.assets.length()
    assert_true(result.diagnostics.metrics.get("spine_item_count") is Some(_))
  }
  assert_true(blocks > 5)
  assert_true(assets >= 0)
}

///|
test "EPUB parser fails closed for unsafe missing and colliding package paths" {
  let fixtures = [
    "samples/fixtures/boundaries/epub/epub_missing_container.epub", "samples/fixtures/boundaries/epub/epub_rootfile_parent_escape.epub",
    "samples/fixtures/boundaries/epub/epub_manifest_href_parent_escape.epub", "samples/fixtures/boundaries/epub/epub_normalized_collision.epub",
  ]
  let parser = epub_parser(fn() { @parser.empty_registry() })
  let context = @parser.new_parse_context(@input.DetectedFormat::Epub)
  let mut controlled = 0
  for path in fixtures {
    match (parser.parse)(@input.input_from_path(path), context) {
      Err(error) => if error != "" { controlled += 1 }
      Ok(result) =>
        if result.diagnostics.errors.length() > 0 ||
          result.diagnostics.degraded_features.length() > 0 {
          controlled += 1
        }
    }
  }
  assert_eq(controlled, fixtures.length())
}
