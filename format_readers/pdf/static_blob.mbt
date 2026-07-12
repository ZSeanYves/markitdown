///|
fn pdf_decode_base64_zlib_blob(payload : String, label : String) -> Bytes {
  let compressed = try @base64.decode(payload, url_safe=false) |> Some catch {
    _ => None
  }
  let compressed = match compressed {
    Some(value) => value
    None => abort("invalid base64 static blob: " + label)
  }
  @zlib.decompress(compressed) catch {
    err => abort("invalid zlib static blob: " + label + ": " + err.to_string())
  }
}

///|
fn pdf_decode_base64_zlib_text(payload : String, label : String) -> String {
  let bytes = pdf_decode_base64_zlib_blob(payload, label)
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => abort("invalid utf8 static blob: " + label)
  }
}

///|
fn pdf_blob_u16_at_byte_offset(blob : Bytes, byte_offset : Int) -> Int {
  ((blob.unsafe_get(byte_offset).to_int() & 0xFF) << 8) |
  (blob.unsafe_get(byte_offset + 1).to_int() & 0xFF)
}

///|
fn pdf_blob_u16_at_index(blob : Bytes, index : Int) -> Int {
  pdf_blob_u16_at_byte_offset(blob, index * 2)
}

///|
fn pdf_blob_u16_triplet_field(
  blob : Bytes,
  byte_offset : Int,
  entry_index : Int,
  field_index : Int,
) -> Int {
  pdf_blob_u16_at_byte_offset(
    blob,
    byte_offset + entry_index * 6 + field_index * 2,
  )
}

///|
fn pdf_blob_u16_pair_field(
  blob : Bytes,
  byte_offset : Int,
  entry_index : Int,
  field_index : Int,
) -> Int {
  pdf_blob_u16_at_byte_offset(
    blob,
    byte_offset + entry_index * 4 + field_index * 2,
  )
}

///|
fn pdf_blob_bmp_codepoint_at(
  blob : Bytes,
  byte_offset : Int,
  code_unit_index : Int,
) -> Int? {
  let codepoint = pdf_blob_u16_at_byte_offset(
    blob,
    byte_offset + code_unit_index * 2,
  )
  if codepoint >= 0xD800 && codepoint <= 0xDFFF {
    None
  } else {
    Some(codepoint)
  }
}
