///|
/// Summarize structure for a parsed YAML-subset document.
pub fn inspect_yaml_document(doc : YamlDocument) -> YamlInspectReport {
  match doc.root {
    None =>
      {
        is_empty: true,
        node_count: 0,
        mapping_count: 0,
        sequence_count: 0,
        scalar_count: 0,
        max_depth: 0,
        root_kind: None,
      }
    Some(root) => {
      let stats = inspect_yaml_value(root, 1)
      {
        is_empty: false,
        node_count: stats.node_count,
        mapping_count: stats.mapping_count,
        sequence_count: stats.sequence_count,
        scalar_count: stats.scalar_count,
        max_depth: stats.max_depth,
        root_kind: Some(yaml_value_kind(root)),
      }
    }
  }
}

///|
priv struct YamlInspectStats {
  node_count : Int
  mapping_count : Int
  sequence_count : Int
  scalar_count : Int
  max_depth : Int
}

///|
fn inspect_yaml_value(value : YamlValue, depth : Int) -> YamlInspectStats {
  match value {
    YamlValue::Mapping(members) => {
      let mut node_count = 1
      let mut mapping_count = 1
      let mut sequence_count = 0
      let mut scalar_count = 0
      let mut max_depth = depth
      for entry in members {
        let child = inspect_yaml_value(entry.value, depth + 1)
        node_count += child.node_count
        mapping_count += child.mapping_count
        sequence_count += child.sequence_count
        scalar_count += child.scalar_count
        if child.max_depth > max_depth {
          max_depth = child.max_depth
        }
      }
      { node_count, mapping_count, sequence_count, scalar_count, max_depth }
    }
    YamlValue::Sequence(values) => {
      let mut node_count = 1
      let mut mapping_count = 0
      let mut sequence_count = 1
      let mut scalar_count = 0
      let mut max_depth = depth
      for child_value in values {
        let child = inspect_yaml_value(child_value, depth + 1)
        node_count += child.node_count
        mapping_count += child.mapping_count
        sequence_count += child.sequence_count
        scalar_count += child.scalar_count
        if child.max_depth > max_depth {
          max_depth = child.max_depth
        }
      }
      { node_count, mapping_count, sequence_count, scalar_count, max_depth }
    }
    YamlValue::String(_) | YamlValue::Bool(_) | YamlValue::Null =>
      {
        node_count: 1,
        mapping_count: 0,
        sequence_count: 0,
        scalar_count: 1,
        max_depth: depth,
      }
  }
}
