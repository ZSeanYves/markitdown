///|
async test "CLI container sidecars use validated payloads without reopening the original archive" {
  let root = test_tmp_root() + "/validated-container-payload"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let observed : Array[(Bool, Bool, Bool, Bytes)] = []
  for nested in [false, true] {
    let asset = @core.make_asset_ref(
      Image,
      if nested {
        "nested"
      } else {
        "direct"
      },
    )
    let asset = {
      ..asset,
      path: Some(if nested { "assets/nested.png" } else { "assets/direct.png" }),
      payload: Some(Bytes(b"verified-payload")),
    }
    if nested {
      asset.attrs.set("zip_nested_archive_entry_path", "child.docx")
      asset.attrs.set("zip_nested_asset_entry_path", "word/media/image.png")
    } else {
      asset.attrs.set("zip_entry_path", "image.png")
    }
    let missing_input = root + "/removed-original.zip"
    let source = root + "/original.zip"
    let archive = if nested {
      @dzip.build_store_zip_bytes([
        (
          "child.docx",
          @dzip.build_store_zip_bytes([
            ("word/media/image.png", b"different-later-payload"),
          ]),
        ),
      ])
    } else {
      @dzip.build_store_zip_bytes([("image.png", b"different-later-payload")])
    }
    @fs.write_bytes_to_file(source, archive)
    let available_without_source = cli_asset_is_materializable(asset)
    let validated_without_source = validate_cli_assets(missing_input, [asset])
      is Ok(_)
    persist_cli_assets(source, root + "/result.md", [asset])
    observed.push(
      (
        false,
        available_without_source,
        validated_without_source,
        @fs.read_file_to_bytes(root + "/" + asset.path.unwrap()),
      ),
    )
  }
  assert_eq(observed, [
    (false, true, true, b"verified-payload"),
    (false, true, true, b"verified-payload"),
  ])
}
