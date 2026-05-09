///|
pub fn inspect_json_document(doc : JsonDocument) -> JsonInspectReport {
  let root_kind = json_value_kind(doc.root)
  let stats = inspect_json_value(doc.root, 1)
  {
    node_count: stats.node_count,
    object_count: stats.object_count,
    array_count: stats.array_count,
    scalar_count: stats.scalar_count,
    member_count: stats.member_count,
    max_depth: stats.max_depth,
    root_kind,
  }
}

///|
priv struct JsonInspectStats {
  node_count : Int
  object_count : Int
  array_count : Int
  scalar_count : Int
  member_count : Int
  max_depth : Int
}

///|
fn inspect_json_value(value : JsonValue, depth : Int) -> JsonInspectStats {
  match value {
    JsonValue::Object(members) => {
      let mut node_count = 1
      let mut object_count = 1
      let mut array_count = 0
      let mut scalar_count = 0
      let mut member_count = members.length()
      let mut max_depth = depth
      for entry in members {
        let child = inspect_json_value(entry.value, depth + 1)
        node_count += child.node_count
        object_count += child.object_count
        array_count += child.array_count
        scalar_count += child.scalar_count
        member_count += child.member_count
        if child.max_depth > max_depth {
          max_depth = child.max_depth
        }
      }
      {
        node_count,
        object_count,
        array_count,
        scalar_count,
        member_count,
        max_depth,
      }
    }
    JsonValue::Array(values) => {
      let mut node_count = 1
      let mut object_count = 0
      let mut array_count = 1
      let mut scalar_count = 0
      let mut member_count = 0
      let mut max_depth = depth
      for child_value in values {
        let child = inspect_json_value(child_value, depth + 1)
        node_count += child.node_count
        object_count += child.object_count
        array_count += child.array_count
        scalar_count += child.scalar_count
        member_count += child.member_count
        if child.max_depth > max_depth {
          max_depth = child.max_depth
        }
      }
      {
        node_count,
        object_count,
        array_count,
        scalar_count,
        member_count,
        max_depth,
      }
    }
    JsonValue::String(_)
    | JsonValue::Number(_)
    | JsonValue::Bool(_)
    | JsonValue::Null =>
      {
        node_count: 1,
        object_count: 0,
        array_count: 0,
        scalar_count: 1,
        member_count: 0,
        max_depth: depth,
      }
  }
}
