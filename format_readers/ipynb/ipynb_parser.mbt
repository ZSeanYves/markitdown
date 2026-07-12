///|
pub fn parse_ipynb_notebook(text : String) -> IpynbNotebook raise {
  let root = @djson.parse_json_document(text)
  lower_ipynb_notebook(root)
}

///|
pub fn classify_ipynb_error(err : IpynbError) -> String {
  err.to_string()
}

///|
fn lower_ipynb_notebook(root : @djson.JsonDocument) -> IpynbNotebook raise {
  let root_members = match root.root {
    @djson.JsonValue::Object(members) => members
    _ => raise ParseError("top-level notebook must be a JSON object")
  }
  let cells_value = ipynb_required_member(root_members, "cells")
  let cells_array = match cells_value {
    @djson.JsonValue::Array(items) => items
    _ => raise ParseError("top-level cells must be an array")
  }
  let metadata = ipynb_optional_member(root_members, "metadata")
  let summary = {
    nbformat: ipynb_optional_int(root_members, "nbformat"),
    nbformat_minor: ipynb_optional_int(root_members, "nbformat_minor"),
    kernelspec_name: ipynb_nested_string(metadata, ["kernelspec", "name"]),
    kernelspec_display_name: ipynb_nested_string(metadata, [
      "kernelspec", "display_name",
    ]),
    language_name: ipynb_nested_string(metadata, ["language_info", "name"]),
    language_version: ipynb_nested_string(metadata, ["language_info", "version"]),
    cell_count: cells_array.length(),
  }
  let cells : Array[IpynbCell] = []
  for i in 0..<cells_array.length() {
    cells.push(lower_ipynb_cell(cells_array[i], i))
  }
  { summary, metadata, cells, raw_root: root }
}

///|
fn lower_ipynb_cell(value : @djson.JsonValue, index : Int) -> IpynbCell raise {
  let members = match value {
    @djson.JsonValue::Object(items) => items
    _ =>
      raise ParseError(
        "cell at index " + index.to_string() + " must be an object",
      )
  }
  let cell_type = ipynb_required_string(
    members,
    "cell_type",
    "cell at index " + index.to_string() + " cell_type must be a string",
  )
  let kind = ipynb_cell_kind(cell_type)
  let json_pointer = "/cells/" + index.to_string()
  {
    index,
    kind,
    cell_type,
    cell_id: ipynb_optional_string(members, "id"),
    metadata: ipynb_optional_member(members, "metadata"),
    source: ipynb_required_multiline_string(
      members,
      "source",
      "cell at index " +
      index.to_string() +
      " source must be string or string[]",
    ),
    execution_count: ipynb_optional_int(members, "execution_count"),
    attachments: ipynb_lower_attachments(
      ipynb_optional_member(members, "attachments"),
      json_pointer + "/attachments",
    ),
    outputs: ipynb_lower_outputs(
      ipynb_optional_member(members, "outputs"),
      json_pointer + "/outputs",
    ),
    json_pointer,
  }
}

///|
fn ipynb_lower_outputs(
  value : @djson.JsonValue?,
  base_pointer : String,
) -> Array[IpynbOutput] raise {
  match value {
    None => []
    Some(@djson.JsonValue::Array(items)) => {
      let outputs : Array[IpynbOutput] = []
      for i in 0..<items.length() {
        outputs.push(
          ipynb_lower_output(items[i], i, base_pointer + "/" + i.to_string()),
        )
      }
      outputs
    }
    Some(_) => raise ParseError("cell outputs must be an array")
  }
}

///|
fn ipynb_lower_output(
  value : @djson.JsonValue,
  index : Int,
  pointer : String,
) -> IpynbOutput raise {
  let members = match value {
    @djson.JsonValue::Object(items) => items
    _ =>
      raise ParseError(
        "output at index " + index.to_string() + " must be an object",
      )
  }
  let output_type = ipynb_required_string(
    members,
    "output_type",
    "output at index " + index.to_string() + " output_type must be a string",
  )
  {
    kind: ipynb_output_kind(output_type),
    output_type,
    name: ipynb_optional_string(members, "name"),
    execution_count: ipynb_optional_int(members, "execution_count"),
    text: ipynb_optional_multiline_string(members, "text"),
    mime_entries: ipynb_lower_mime_bundle(
      ipynb_optional_member(members, "data"),
    ),
    ename: ipynb_optional_string(members, "ename"),
    evalue: ipynb_optional_string(members, "evalue"),
    traceback: ipynb_optional_multiline_lines(members, "traceback"),
    display_id: ipynb_nested_string(
      ipynb_optional_member(members, "transient"),
      ["display_id"],
    ),
    clear_wait: ipynb_optional_bool(members, "wait"),
    json_pointer: pointer,
  }
}

///|
fn ipynb_lower_attachments(
  value : @djson.JsonValue?,
  _base_pointer : String,
) -> Array[IpynbAttachment] raise {
  match value {
    None => []
    Some(@djson.JsonValue::Object(members)) => {
      let attachments : Array[IpynbAttachment] = []
      for entry in members {
        let mime_entries = match entry.value {
          @djson.JsonValue::Object(_) =>
            ipynb_lower_mime_bundle(Some(entry.value))
          _ =>
            raise ParseError(
              "attachment " + entry.key + " must be a mime bundle object",
            )
        }
        attachments.push({ name: entry.key, mime_entries })
      }
      attachments
    }
    Some(_) => raise ParseError("attachments must be an object")
  }
}

///|
fn ipynb_lower_mime_bundle(
  value : @djson.JsonValue?,
) -> Array[IpynbMimeEntry] raise {
  match value {
    None => []
    Some(@djson.JsonValue::Object(members)) => {
      let entries : Array[IpynbMimeEntry] = []
      for entry in members {
        entries.push(ipynb_lower_mime_entry(entry.key, entry.value))
      }
      entries
    }
    Some(_) => raise ParseError("mime bundle must be an object")
  }
}

///|
fn ipynb_lower_mime_entry(
  mime_type : String,
  value : @djson.JsonValue,
) -> IpynbMimeEntry raise {
  match value {
    @djson.JsonValue::String(text) =>
      { mime_type, text: Some(text), json_value: None, raw_json_text: None }
    @djson.JsonValue::Array(items) => {
      let text_parts : Array[String] = []
      for item in items {
        match item {
          @djson.JsonValue::String(part) => text_parts.push(part)
          _ =>
            raise ParseError(
              "mime entry " +
              mime_type +
              " string array contains non-string item",
            )
        }
      }
      {
        mime_type,
        text: Some(text_parts.join("")),
        json_value: None,
        raw_json_text: None,
      }
    }
    _ =>
      {
        mime_type,
        text: None,
        json_value: Some(value),
        raw_json_text: Some(ipynb_stringify_json_value(value)),
      }
  }
}

///|
fn ipynb_required_member(
  members : Array[@djson.JsonMember],
  key : String,
) -> @djson.JsonValue raise {
  match ipynb_optional_member_from_members(members, key) {
    Some(value) => value
    None => raise ParseError("missing notebook field: " + key)
  }
}

///|
fn ipynb_optional_member(
  members : Array[@djson.JsonMember],
  key : String,
) -> @djson.JsonValue? {
  ipynb_optional_member_from_members(members, key)
}

///|
fn ipynb_optional_member_from_members(
  members : Array[@djson.JsonMember],
  key : String,
) -> @djson.JsonValue? {
  for entry in members {
    if entry.key == key {
      return Some(entry.value)
    }
  }
  None
}

///|
fn ipynb_required_string(
  members : Array[@djson.JsonMember],
  key : String,
  err : String,
) -> String raise {
  match ipynb_optional_member_from_members(members, key) {
    Some(@djson.JsonValue::String(text)) => text
    _ => raise ParseError(err)
  }
}

///|
fn ipynb_optional_string(
  members : Array[@djson.JsonMember],
  key : String,
) -> String? {
  match ipynb_optional_member_from_members(members, key) {
    Some(@djson.JsonValue::String(text)) => Some(text)
    _ => None
  }
}

///|
fn ipynb_optional_int(members : Array[@djson.JsonMember], key : String) -> Int? {
  match ipynb_optional_member_from_members(members, key) {
    Some(@djson.JsonValue::Number(text)) =>
      Some(@string.parse_int(text.trim().to_owned()) catch { _ => return None })
    _ => None
  }
}

///|
fn ipynb_required_multiline_string(
  members : Array[@djson.JsonMember],
  key : String,
  err : String,
) -> String raise {
  match ipynb_optional_member_from_members(members, key) {
    Some(value) => ipynb_multiline_string_value(value, err)
    None => raise ParseError("missing field: " + key)
  }
}

///|
fn ipynb_optional_multiline_string(
  members : Array[@djson.JsonMember],
  key : String,
) -> String? {
  match ipynb_optional_member_from_members(members, key) {
    Some(@djson.JsonValue::String(text)) => Some(text)
    Some(@djson.JsonValue::Array(items)) => {
      let parts : Array[String] = []
      for item in items {
        match item {
          @djson.JsonValue::String(part) => parts.push(part)
          _ => return None
        }
      }
      Some(parts.join(""))
    }
    None => None
    Some(_) => None
  }
}

///|
fn ipynb_optional_multiline_lines(
  members : Array[@djson.JsonMember],
  key : String,
) -> Array[String] {
  match ipynb_optional_member_from_members(members, key) {
    Some(@djson.JsonValue::String(text)) => [text]
    Some(@djson.JsonValue::Array(items)) => {
      let lines : Array[String] = []
      for item in items {
        match item {
          @djson.JsonValue::String(line) => lines.push(line)
          _ => ()
        }
      }
      lines
    }
    _ => []
  }
}

///|
fn ipynb_multiline_string_value(
  value : @djson.JsonValue,
  err : String,
) -> String raise {
  match value {
    @djson.JsonValue::String(text) => text
    @djson.JsonValue::Array(items) => {
      let parts : Array[String] = []
      for item in items {
        match item {
          @djson.JsonValue::String(part) => parts.push(part)
          _ => raise ParseError(err)
        }
      }
      parts.join("")
    }
    _ => raise ParseError(err)
  }
}

///|
fn ipynb_nested_string(
  root : @djson.JsonValue?,
  path : Array[String],
) -> String? {
  let mut current = root
  for segment in path {
    current = match current {
      Some(@djson.JsonValue::Object(members)) =>
        ipynb_optional_member_from_members(members, segment)
      _ => None
    }
  }
  match current {
    Some(@djson.JsonValue::String(text)) => Some(text)
    _ => None
  }
}

///|
fn ipynb_cell_kind(text : String) -> IpynbCellKind {
  match text {
    "markdown" => IpynbCellKind::Markdown
    "code" => IpynbCellKind::Code
    "raw" => IpynbCellKind::Raw
    _ => IpynbCellKind::Unknown
  }
}

///|
fn ipynb_output_kind(text : String) -> IpynbOutputKind {
  match text {
    "stream" => IpynbOutputKind::Stream
    "display_data" => IpynbOutputKind::DisplayData
    "update_display_data" => IpynbOutputKind::DisplayData
    "execute_result" => IpynbOutputKind::ExecuteResult
    "error" => IpynbOutputKind::Error
    _ => IpynbOutputKind::Unknown
  }
}

///|
fn ipynb_optional_bool(
  members : Array[@djson.JsonMember],
  key : String,
) -> Bool? {
  match ipynb_optional_member_from_members(members, key) {
    Some(@djson.JsonValue::Bool(value)) => Some(value)
    _ => None
  }
}

///|
fn ipynb_stringify_json_value(value : @djson.JsonValue) -> String {
  match value {
    @djson.JsonValue::Object(members) => {
      let pairs : Array[String] = []
      for entry in members {
        pairs.push(
          "\"" +
          ipynb_escape_json_string(entry.key) +
          "\":" +
          ipynb_stringify_json_value(entry.value),
        )
      }
      "{" + pairs.join(",") + "}"
    }
    @djson.JsonValue::Array(items) =>
      "[" + items.map(item => ipynb_stringify_json_value(item)).join(",") + "]"
    @djson.JsonValue::String(text) =>
      "\"" + ipynb_escape_json_string(text) + "\""
    @djson.JsonValue::Number(text) => text
    @djson.JsonValue::Bool(flag) => if flag { "true" } else { "false" }
    @djson.JsonValue::Null => "null"
  }
}

///|
fn ipynb_escape_json_string(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}
