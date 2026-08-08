///|
#cfg(target="native")
#borrow(payload)
extern "C" fn decode_cp932_native_ffi(
  payload : Bytes,
  payload_len : Int,
) -> Bytes = "markitdown_decode_cp932"

///|
fn decode_cp932_native(payload : Bytes) -> Bytes {
  decode_cp932_native_ffi(payload, payload.length())
}
