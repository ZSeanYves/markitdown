///|
/// The first object fixes one record schema. Keep its key order and membership
/// index together, shared by scanning and both pull replay phases.
priv struct LineJsonColumns {
  keys : Array[String]
  positions : Map[String, Int32]
}

///|
fn LineJsonColumns::new(members : Array[JsonMember]) -> LineJsonColumns {
  let keys = members.map(entry => entry.key)
  { keys, positions: @fshared.key_position_index(keys), }
}

///|
fn LineJsonColumns::matches(
  self : LineJsonColumns,
  members : Array[JsonMember],
) -> Bool {
  // Preserve the existing count/membership rule, including duplicate keys.
  @fshared.keys_match_position_index(
    self.keys,
    self.positions,
    members.map(entry => entry.key),
  )
}
