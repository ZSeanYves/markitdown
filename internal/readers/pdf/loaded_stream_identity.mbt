///|
// One selected materialized definition, shared by the FontFile and local CMap
// caches. Authority is Native mutable identity; the current raw values prove
// framing rather than trusting a numeric object ID or a hash alone.
priv struct PdfLoadedStreamProof {
  snapshot : PdfLoadedSnapshot
  body_start : Int64
  dict_text : String
  primary_bytes : Bytes
  endstream_bytes : Bytes
}

///|
impl Eq for PdfLoadedStreamProof with fn equal(left, right) {
  physical_equal(left.snapshot.authority, right.snapshot.authority) &&
  left.snapshot.source_size == right.snapshot.source_size &&
  left.body_start == right.body_start &&
  left.dict_text == right.dict_text &&
  left.primary_bytes == right.primary_bytes &&
  left.endstream_bytes == right.endstream_bytes
}

///|
impl Hash for PdfLoadedStreamProof with fn hash_combine(self, hasher) {
  // Opaque pointer identity is deliberately absent from the hash. Equal raw
  // values on foreign snapshots may collide, but strict physical Eq rejects it.
  hasher.combine(self.snapshot.source_size)
  hasher.combine(self.body_start)
  hasher.combine(self.dict_text)
  hasher.combine(self.primary_bytes)
  hasher.combine(self.endstream_bytes)
}

///|
fn pdf_loaded_stream_proof(object : PdfNativeObject) -> PdfLoadedStreamProof? {
  match object.stream {
    Some(SelectedLoaded(stream, definition)) =>
      Some({
        snapshot: definition.snapshot,
        body_start: definition.body_start,
        dict_text: object.dict_text,
        primary_bytes: stream.primary_bytes,
        endstream_bytes: stream.endstream_bytes,
      })
    _ => None
  }
}

///|
fn pdf_loaded_store_snapshot(
  objects : Array[PdfNativeObject],
) -> PdfLoadedSnapshot? {
  for object in objects {
    if object.stream is Some(SelectedLoaded(_, definition)) {
      return Some(definition.snapshot)
    }
  }
  None
}

///|
// Five Native64 fields40, plus conservative logical payload by occurrence.
// Each source length is a nonnegative Native Int32; these four terms cannot
// overflow Int64. Callers still check addition into their overall result model.
fn pdf_loaded_stream_proof_retained_payload(
  proof : PdfLoadedStreamProof,
) -> Int64 {
  40L +
  proof.dict_text.length().to_int64() * 2L +
  proof.primary_bytes.length().to_int64() +
  proof.endstream_bytes.length().to_int64()
}
