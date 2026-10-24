///|
fn XmlCursor::namespace_uri(self : XmlCursor, prefix : String) -> String? {
  if prefix == "xml" {
    return Some("http://www.w3.org/XML/1998/namespace")
  }
  match self.namespaces.get(prefix) {
    Some(bindings) =>
      match bindings.last() {
        Some("") | None => None
        Some(uri) => Some(uri)
      }
    None => None
  }
}

///|
fn XmlCursor::install_namespaces(
  self : XmlCursor,
  attributes : Array[XmlCursorAttribute],
) -> Array[String] raise XmlCursorAbort {
  let prefixes : Array[String] = []
  for attribute in attributes {
    if !attribute.namespace_declaration {
      continue
    }
    let raw = attribute.name.raw
    self.charge(cursor_string_bytes(raw) + cursor_string_bytes(attribute.value))
    let prefix = if raw == "xmlns" {
      ""
    } else {
      self.own_substring(raw, 6, raw.length())
    }
    if prefix.contains(":") ||
      (prefix == "" && raw != "xmlns") ||
      prefix == "xmlns" {
      self.syntax(InvalidName, "invalid XML namespace prefix")
    }
    if prefix != "" {
      self.check_qname_component(prefix)
    }
    let uri = attribute.value
    if uri == "http://www.w3.org/2000/xmlns/" ||
      (prefix == "xml" && uri != "http://www.w3.org/XML/1998/namespace") ||
      (prefix != "xml" && uri == "http://www.w3.org/XML/1998/namespace") ||
      (prefix != "" && uri == "") {
      self.syntax(InvalidName, "invalid reserved XML namespace binding")
    }
    let bindings = self.namespaces.get_or_init(prefix, () => [])
    bindings.push(uri)
    prefixes.push(prefix)
    self.bindings += 1L
    self.max_bindings = self.max_bindings.max(self.bindings)
  }
  prefixes
}

///|
fn XmlCursor::restore_namespaces(
  self : XmlCursor,
  prefixes : Array[String],
) -> Unit {
  for prefix in prefixes {
    if self.namespaces.get(prefix) is Some(bindings) {
      ignore(bindings.pop())
      if bindings.is_empty() {
        self.namespaces.remove(prefix)
      }
      self.bindings -= 1L
    }
  }
}

///|
fn XmlCursor::resolve_name(
  self : XmlCursor,
  raw : String,
  attribute : Bool,
) -> XmlCursorName raise XmlCursorAbort {
  self.charge(raw.length().to_int64())
  // Existing XML name grammar is ASCII, so these offsets are also UTF16
  // offsets. This helper does not reinterpret scalar offsets as String units.
  let mut colon = -1
  for i, ch in raw.iter2() {
    if ch == ':' {
      if colon >= 0 {
        self.syntax(InvalidName, "multiple colons in XML QName")
      }
      colon = i
    }
  }
  if colon < 0 {
    return {
      raw,
      local_name: raw,
      namespace_uri: if attribute {
        None
      } else {
        self.namespace_uri("")
      },
    }
  }
  if colon == 0 || colon + 1 == raw.length() {
    self.syntax(InvalidName, "empty XML QName component")
  }
  let prefix = self.own_substring(raw, 0, colon)
  let local_name = self.own_substring(raw, colon + 1, raw.length())
  self.check_qname_component(prefix)
  self.check_qname_component(local_name)
  // Compatibility covers unknown application prefixes, never the reserved
  // namespace-declaration prefix. Strict mode rejected it as unbound before.
  if prefix == "xmlns" {
    self.syntax(InvalidName, "reserved xmlns prefix cannot name an XML node")
  }
  let namespace_uri = match self.namespace_uri(prefix) {
    Some(uri) => Some(uri)
    None =>
      if self.allow_unbound_prefixes {
        None
      } else {
        self.syntax(InvalidName, "unbound XML namespace prefix")
      }
  }
  { raw, local_name, namespace_uri, }
}

///|
fn XmlCursor::check_qname_component(
  self : XmlCursor,
  name : String,
) -> Unit raise XmlCursorAbort {
  let mut first = true
  for ch in name {
    if first && (!is_name_start(ch) || ch == ':') {
      self.syntax(InvalidName, "invalid XML QName component")
    }
    first = false
  }
}
