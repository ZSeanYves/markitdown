///|
/// Payload allocation bound for this pinned decoder, excluding object headers
/// and shared global tables. This is an allocation model, not a resource cap.
/// It is the same reviewed model used by ZIP: history, overlapping Huffman
/// banks, header/build arrays and staged input. Re-audit on decoder changes.
pub fn inflater_payload_upper_bound() -> Int64 {
  32768L + 3L * (512L + 32768L) * 4L + (286L + 30L + 19L + 32L) * 4L + 4096L
}
