///|
test "JSON strings roundtrip every ASCII control without dropping content" {
  for code in 0..<32 {
    let control = String::from_array([code.to_char().unwrap()])
    let original = "before" + control + "after 😀"
    let encoded = json_string(original)
    assert_false(encoded.iter().any(ch => ch.to_int() < 32))
    assert_eq(@json.parse(encoded, reject_duplicate_keys=true), Json(original))
  }
}
