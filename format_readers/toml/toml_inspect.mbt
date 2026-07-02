///|
/// Summarize structure for a parsed TOML document.
pub fn inspect_toml_document(doc : TomlDocument) -> TomlInspectReport {
  let mut node_count = 0
  let mut scalar_count = 0
  let mut array_count = 0
  let mut table_like_count = 0
  let mut max_depth = 0
  for entry in doc.root_members {
    let stats = inspect_toml_value(entry.value, path_depth(entry.path))
    node_count += 1 + stats.node_count
    scalar_count += stats.scalar_count
    array_count += stats.array_count
    table_like_count += stats.table_like_count
    if stats.max_depth > max_depth {
      max_depth = stats.max_depth
    }
  }
  for table in doc.tables {
    table_like_count += 1
    node_count += 1
    let table_depth = path_depth(table.path)
    if table_depth > max_depth {
      max_depth = table_depth
    }
    for entry in table.members {
      let stats = inspect_toml_value(entry.value, path_depth(entry.path))
      node_count += 1 + stats.node_count
      scalar_count += stats.scalar_count
      array_count += stats.array_count
      table_like_count += stats.table_like_count
      if stats.max_depth > max_depth {
        max_depth = stats.max_depth
      }
    }
  }
  {
    node_count,
    scalar_count,
    array_count,
    table_like_count,
    table_count: doc.tables.length(),
    max_depth,
    root_kind: "document",
  }
}

///|
priv struct TomlInspectStats {
  node_count : Int
  scalar_count : Int
  array_count : Int
  table_like_count : Int
  max_depth : Int
}

///|
fn inspect_toml_value(value : TomlValue, depth : Int) -> TomlInspectStats {
  match value {
    TomlValue::Table(members) | TomlValue::InlineTable(members) => {
      let mut node_count = 1
      let mut scalar_count = 0
      let mut array_count = 0
      let mut table_like_count = 1
      let mut max_depth = depth
      for entry in members {
        let child = inspect_toml_value(entry.value, depth + 1)
        node_count += 1 + child.node_count
        scalar_count += child.scalar_count
        array_count += child.array_count
        table_like_count += child.table_like_count
        if child.max_depth > max_depth {
          max_depth = child.max_depth
        }
      }
      { node_count, scalar_count, array_count, table_like_count, max_depth }
    }
    TomlValue::Array(values) => {
      let mut node_count = 1
      let mut scalar_count = 0
      let mut array_count = 1
      let mut table_like_count = 0
      let mut max_depth = depth
      for item in values {
        let child = inspect_toml_value(item, depth + 1)
        node_count += child.node_count
        scalar_count += child.scalar_count
        array_count += child.array_count
        table_like_count += child.table_like_count
        if child.max_depth > max_depth {
          max_depth = child.max_depth
        }
      }
      { node_count, scalar_count, array_count, table_like_count, max_depth }
    }
    TomlValue::String(_)
    | TomlValue::Integer(_)
    | TomlValue::Float(_)
    | TomlValue::Bool(_)
    | TomlValue::Datetime(_) =>
      {
        node_count: 1,
        scalar_count: 1,
        array_count: 0,
        table_like_count: 0,
        max_depth: depth,
      }
  }
}

///|
fn path_depth(path : String) -> Int {
  if path == "/" || path == "" {
    return 1
  }
  let mut depth = 1
  let chars = path.to_array()
  for ch in chars {
    if ch == '/' {
      depth += 1
    }
  }
  depth
}
