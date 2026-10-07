///|
fn codec_slice(
  compressed : Bytes,
  size : Int,
  crc32 : Int,
) -> ZipEntryDataSlice {
  {
    entry: {
      name: "payload.txt",
      compression_method: DeflateRaw,
      compressed_size: compressed.length(),
      uncompressed_size: size,
      local_header_offset: 0,
      crc32,
      flags: 0,
      is_directory: false,
      is_encrypted: false,
      has_data_descriptor: false,
      uses_zip64: false,
    },
    data_start: 0,
    data_end: compressed.length(),
  }
}

///|
test "incremental ZIP decoder rejects trailing bytes in a later input chunk" {
  let source = b"abc"
  let compressed = @flate.deflate_all(source)
  let payload = compressed.to_array()
  payload.append(b"trailing"[:].to_array()[:])
  let bytes = Bytes::from_array(payload)
  let slice = codec_slice(bytes, 3, wb_crc32_of_string("abc"))
  let result = visit_inflated_entry_chunks_from_slice(
    bytes,
    slice,
    chunk_size=compressed.length(),
    _ => Ok(()),
  )
  match result {
    Err(message) => assert_true(message.contains("trailing compressed bytes"))
    Ok(_) => fail("trailing compressed bytes must fail integrity validation")
  }
}

///|
test "incremental ZIP decoder checks size before delivering overflow to consumer" {
  let compressed = @flate.deflate_all(Bytes::make(100000, b'A'))
  let delivered = Ref(0)
  let result = visit_inflated_entry_chunks_from_slice(
    compressed,
    codec_slice(compressed, 8, 0),
    chunk_size=7,
    chunk => {
      delivered.val += chunk.length()
      Ok(())
    },
  )
  assert_true(result is Err(_))
  assert_true(delivered.val <= 8)
}

///|
test "ZIP convenience decoder enforces output budget inside inflation" {
  let compressed = @flate.deflate_all(Bytes::make(100000, b'A'))
  let limited = try {
    ignore(decompress(DeflateRaw, compressed, max_output_size=1024))
    false
  } catch {
    OutputTooLarge(1024, _) => true
    _ => false
  }
  assert_true(limited)
}
