///|
async test "OOXML inventory reports declared media size without reading its payload" {
  let bytes = @zip.build_store_zip_bytes([
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<Types><Default Extension=\"png\" ContentType=\"image/png\"/></Types>",
      ),
    ),
    ("word/media/image.png", Bytes::make(4096, b'x')),
  ])
  let reject_payload = Ref(false)
  let payload_offset = Ref(-1)
  let rejected_reads = Ref(0)
  let archive = @zip.open_zip_reader(bytes.length(), async fn(offset, length) {
    @async.sleep(0)
    if reject_payload.val && offset == payload_offset.val {
      rejected_reads.val += 1
      return Err("media payload read forbidden during inventory")
    }
    Ok(bytes[offset:(offset + length).min(bytes.length())].to_owned())
  })
  let slice = @zip.read_entry_data_slice(archive, "word/media/image.png")
  payload_offset.val = slice.data_start
  let pkg = open_ooxml_archive(archive)
  reject_payload.val = true
  let inventory = inspect_ooxml_inventory(pkg)
  let assets = list_media_assets(pkg)
  assert_eq(inventory.media_asset_count, 1)
  assert_eq(assets.length(), 1)
  assert_eq(assets[0].size, 4096)
  assert_eq(rejected_reads.val, 0)
  let materialize = try
    read_part_bytes(pkg, "word/media/image.png") |> Ok
  catch {
    error => Err(error)
  }
  assert_true(materialize is Err(ZipError(_)))
  assert_eq(rejected_reads.val, 1)
}
