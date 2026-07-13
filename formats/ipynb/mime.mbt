///|
fn ipynb_asset_ext_for_entry(entry : @dipynb.IpynbMimeEntry) -> String {
  if ipynb_mime_is_image(entry.mime_type) {
    ipynb_mime_ext(entry.mime_type)
  } else if entry.mime_type == "application/json" ||
    entry.mime_type.contains("+json") {
    ".json"
  } else if entry.mime_type == "text/plain" {
    ".txt"
  } else if entry.mime_type == "text/markdown" {
    ".md"
  } else if entry.mime_type == "text/html" {
    ".html"
  } else if entry.mime_type == "text/latex" {
    ".tex"
  } else {
    ".bin"
  }
}

///|
fn ipynb_attach_asset_payload(
  asset : @core.AssetRef,
  entry : @dipynb.IpynbMimeEntry,
) -> Unit {
  match ipynb_asset_payload(entry) {
    Some(payload) => asset.payload = Some(payload)
    None => ()
  }
}

///|
fn ipynb_asset_payload(entry : @dipynb.IpynbMimeEntry) -> @core.AssetPayload? {
  if entry.mime_type == "image/svg+xml" {
    match entry.text {
      Some(payload) => return Some(@core.AssetPayload::Utf8(payload))
      None => ()
    }
  }
  if ipynb_mime_is_image(entry.mime_type) {
    match entry.text {
      Some(payload) => {
        let normalized = payload
          .replace_all(old="\n", new="")
          .replace_all(old="\r", new="")
        if normalized != "" {
          return try
            @base64.decode(normalized, url_safe=false)
            |> @core.AssetPayload::Bytes
            |> Some
          catch {
            _ => None
          }
        }
      }
      None => ()
    }
  }
  if entry.mime_type == "application/json" || entry.mime_type.contains("+json") {
    match entry.raw_json_text {
      Some(payload) => return Some(@core.AssetPayload::Utf8(payload))
      None => ()
    }
  }
  if entry.mime_type.has_prefix("text/") {
    match entry.text {
      Some(payload) => return Some(@core.AssetPayload::Utf8(payload))
      None => ()
    }
  }
  match entry.text {
    Some(payload) => {
      let normalized = payload
        .replace_all(old="\n", new="")
        .replace_all(old="\r", new="")
      if normalized != "" {
        try
          @base64.decode(normalized, url_safe=false)
          |> @core.AssetPayload::Bytes
          |> Some
        catch {
          _ => None
        }
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn ipynb_cell_kind_name(kind : @dipynb.IpynbCellKind) -> String {
  match kind {
    @dipynb.IpynbCellKind::Markdown => "markdown"
    @dipynb.IpynbCellKind::Code => "code"
    @dipynb.IpynbCellKind::Raw => "raw"
    @dipynb.IpynbCellKind::Unknown => "unknown"
  }
}

///|
fn ipynb_output_kind_name(kind : @dipynb.IpynbOutputKind) -> String {
  match kind {
    @dipynb.IpynbOutputKind::Stream => "stream"
    @dipynb.IpynbOutputKind::DisplayData => "display_data"
    @dipynb.IpynbOutputKind::ExecuteResult => "execute_result"
    @dipynb.IpynbOutputKind::Error => "error"
    @dipynb.IpynbOutputKind::Unknown => "unknown"
  }
}

///|
fn ipynb_preferred_mime_entry(
  entries : Array[@dipynb.IpynbMimeEntry],
) -> @dipynb.IpynbMimeEntry? {
  let order = [
    "image/png", "image/jpeg", "image/gif", "image/svg+xml", "text/markdown", "text/html",
    "application/javascript", "text/javascript", "application/json",
  ]
  for target in order {
    for entry in entries {
      if entry.mime_type == target {
        return Some(entry)
      }
    }
  }
  for entry in entries {
    if entry.mime_type.contains("+json") {
      return Some(entry)
    }
  }
  for target in ["text/plain", "text/latex"] {
    for entry in entries {
      if entry.mime_type == target {
        return Some(entry)
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries[0])
  }
}

///|
fn ipynb_preferred_mime_label(
  entries : Array[@dipynb.IpynbMimeEntry],
) -> String {
  match ipynb_preferred_mime_entry(entries) {
    Some(entry) => entry.mime_type
    None => "none"
  }
}

///|
fn ipynb_mime_is_image(mime_type : String) -> Bool {
  mime_type == "image/png" ||
  mime_type == "image/jpeg" ||
  mime_type == "image/gif" ||
  mime_type == "image/svg+xml"
}

///|
fn ipynb_mime_ext(mime_type : String) -> String {
  match mime_type {
    "image/png" => ".png"
    "image/jpeg" => ".jpg"
    "image/gif" => ".gif"
    "image/svg+xml" => ".svg"
    _ => ".bin"
  }
}

///|
fn ipynb_info_from_mime(mime_type : String) -> String {
  match mime_type {
    "text/html" => "html"
    "text/latex" => "latex"
    "application/json" => "json"
    _ => if mime_type.contains("+json") { "json" } else { "text" }
  }
}
