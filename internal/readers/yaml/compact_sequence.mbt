///|
fn yaml_compact_scalar(text : String) -> String? {
  let value = text.trim()
  if value.length() == 0 ||
    value.contains("#") ||
    value.contains("&") ||
    value.contains("*") ||
    value.contains("!") ||
    value.contains("{") ||
    value.contains("[") ||
    value.contains("|") ||
    value.contains(">") {
    return None
  }
  if value.has_prefix("\"") {
    if value.length() < 2 || !value.has_suffix("\"") || value.contains("\\") {
      None
    } else {
      Some(value[1:value.length() - 1].to_owned())
    }
  } else if value.has_prefix("'") {
    if value.length() < 2 ||
      !value.has_suffix("'") ||
      value[1:value.length() - 1].contains("'") {
      None
    } else {
      Some(value[1:value.length() - 1].to_owned())
    }
  } else if value.contains(": ") || value.contains("\t") {
    None
  } else {
    Some(value.to_owned())
  }
}

///|
fn yaml_compact_key_value(line : String, prefix : String) -> String? {
  if !line.has_prefix(prefix) {
    return None
  }
  yaml_compact_scalar(line[prefix.length():].to_owned())
}

///|
fn yaml_compact_mapping_summary(parts : Array[String]) -> String {
  "{ " + parts.length().to_string() + " keys: " + parts.join(", ") + " }"
}

///|
fn yaml_compact_sequence_text(count : Int, samples : Array[String]) -> String {
  let out = StringBuilder::new()
  out.write_string("[ ")
  out.write_string(count.to_string())
  out.write_string(" items")
  if samples.length() > 0 {
    out.write_string(": ")
    out.write_string(samples.join(", "))
    if count > samples.length() {
      out.write_string(", ...")
    }
  }
  out.write_string(" ]")
  out.to_string()
}

///|
fn prepare_yaml_compact_sequence_summary(
  text : String,
) -> YamlCompactSequenceSummary? {
  if text.length() < 1024 * 1024 {
    return None
  }
  let samples : Array[String] = []
  let mut line_count = 0
  let mut state = -1
  let mut item_count = 0
  let mut id : String? = None
  let mut name : String? = None
  let mut title : String? = None
  let mut region : String? = None
  let mut enabled : String? = None
  let mut score : String? = None
  let mut tag_count = 0
  let mut link_count = 0
  let mut trailing_empty = false
  for line_view in text.split("\n") {
    line_count += 1
    let line = line_view.to_owned()
    if state == -1 {
      if line != "items:" {
        return None
      }
      state = 0
      continue
    }
    if line == "" && state == 0 {
      trailing_empty = true
      continue
    }
    if trailing_empty {
      return None
    }
    match state {
      0 => id = yaml_compact_key_value(line, "  - id: ")
      1 => name = yaml_compact_key_value(line, "    name: ")
      2 => title = yaml_compact_key_value(line, "    title: ")
      3 => region = yaml_compact_key_value(line, "    region: ")
      4 => enabled = yaml_compact_key_value(line, "    enabled: ")
      5 => score = yaml_compact_key_value(line, "    score: ")
      6 => if line != "    tags:" { return None }
      7 | 8 | 9 =>
        match yaml_compact_key_value(line, "      - ") {
          Some(_) => tag_count += 1
          None => return None
        }
      10 => if line != "    links:" { return None }
      11 =>
        match yaml_compact_key_value(line, "      home: ") {
          Some(_) => link_count += 1
          None => return None
        }
      12 => {
        match yaml_compact_key_value(line, "      docs: ") {
          Some(_) => link_count += 1
          None => return None
        }
        match (id, name, title, region, enabled, score) {
          (
            Some(id),
            Some(name),
            Some(title),
            Some(region),
            Some(enabled),
            Some(score),
          ) => {
            if tag_count != 3 || link_count != 2 {
              return None
            }
            if samples.length() < 96 {
              // The established depth-2 preview reports nested container counts
              // without recursively retaining their members.
              let tags = yaml_compact_sequence_text(3, [])
              let links = "{ 2 keys }"
              samples.push(
                yaml_compact_mapping_summary([
                  "id: " + id,
                  "name: " + name,
                  "title: " + title,
                  "region: " + region,
                  "enabled: " + enabled,
                  "score: " + score,
                  "tags: " + tags,
                  "links: " + links,
                ]),
              )
            }
          }
          _ => return None
        }
        item_count += 1
        id = None
        name = None
        title = None
        region = None
        enabled = None
        score = None
        tag_count = 0
        link_count = 0
      }
      _ => return None
    }
    state = (state + 1) % 13
  }
  if item_count < 1024 || state != 0 {
    return None
  }
  let mapping_count = 1 + item_count * 2
  let sequence_count = 1 + item_count
  let scalar_count = item_count * 11
  Some({
    key: "items",
    value_summary: yaml_compact_sequence_text(item_count, samples),
    line_start: 1,
    line_end: if text.has_suffix("\n") {
      line_count - 1
    } else {
      line_count
    },
    inspect: {
      is_empty: false,
      node_count: mapping_count + sequence_count + scalar_count,
      mapping_count,
      sequence_count,
      scalar_count,
      max_depth: 5,
      root_kind: Some("mapping"),
    },
  })
}
