///|
priv struct CustomNamespaceBinding {
  raw_name : String
  value : String
  depth : Int32
  lease : @budget.BudgetLease?
}

///|
priv struct CustomPropertyState {
  raw_name : String
  depth : Int32
  mut name_lease : @budget.BudgetLease?
  mut value_type : String?
  mut type_lease : @budget.BudgetLease?
  mut value_depth : Int32?
  mut value_closed : Bool
  mut structural : Bool
  value : OoxmlPropertyValue
}

///|
priv struct CustomPropertiesConsumer {
  values : Array[OoxmlCustomProperty]
  mut active : CustomPropertyState?
  mut depth : Int32
  namespaces : Array[CustomNamespaceBinding]
  bindings : Map[String, Array[CustomNamespaceBinding]]
  context : @budget.BudgetContext?
  policy : CustomPropertyProjectionPolicy
  mut candidate_depth : Int32?
  mut completed_candidates : Int32
  mut limit_exceeded : Bool
}

///|
fn CustomPropertyState::close(self : CustomPropertyState) -> Unit {
  self.value.close()
  if self.name_lease is Some(lease) {
    lease.release()
  }
  if self.type_lease is Some(lease) {
    lease.release()
  }
  self.name_lease = None
  self.type_lease = None
}

///|
fn CustomPropertiesConsumer::close(self : CustomPropertiesConsumer) -> Unit {
  if self.active is Some(value) {
    value.close()
  }
  self.active = None
  self.candidate_depth = None
  for binding in self.namespaces {
    if binding.lease is Some(lease) {
      lease.release()
    }
  }
  self.namespaces.clear()
  self.bindings.clear()
}

///|
// Count complete outer candidates, including missing names and empty/self-
// closing properties. Saturating at the supplied limit avoids overflow while
// retaining the first complete extra candidate as the truncation signal.
fn CustomPropertiesConsumer::complete_candidate(
  self : CustomPropertiesConsumer,
) -> Unit {
  if self.policy.max_candidates is Some(limit) {
    if self.completed_candidates < limit {
      self.completed_candidates += 1
    } else {
      self.limit_exceeded = true
    }
  }
  self.candidate_depth = None
}

///|
fn CustomPropertiesConsumer::begin_candidate(
  self : CustomPropertiesConsumer,
  raw_name : String,
  self_closing : Bool,
) -> Bool {
  match self.policy.max_candidates {
    None => true
    Some(limit) => {
      if self.candidate_depth is Some(_) || raw_name != "property" {
        return false
      }
      let admitted = self.completed_candidates < limit
      if self_closing {
        self.complete_candidate()
      } else {
        self.candidate_depth = Some(self.depth)
      }
      admitted
    }
  }
}

///|
// Namespace Strings outlive cursor.next only while their declaration is in
// scope. Their payload reservation is Working, not an escaped cache lease.
fn CustomPropertiesConsumer::enter_namespaces(
  self : CustomPropertiesConsumer,
  attributes : Array[@xml.XmlCursorAttribute],
) -> Unit raise OoxmlError {
  for attribute in attributes {
    if !attribute.namespace_declaration {
      continue
    }
    let bytes = (
        attribute.name.raw.length().to_int64() +
        attribute.value.length().to_int64()
      ) *
      2L
    let lease = property_working_lease(self.context, bytes)
    let binding = {
      raw_name: attribute.name.raw,
      value: attribute.value,
      depth: self.depth,
      lease,
    }
    self.namespaces.push(binding)
    self.bindings.get_or_init(binding.raw_name, () => []).push(binding)
  }
}

///|
fn CustomPropertiesConsumer::leave_namespaces(
  self : CustomPropertiesConsumer,
) -> Unit {
  while self.namespaces.last() is Some(binding) && binding.depth == self.depth {
    ignore(self.namespaces.pop())
    if self.bindings.get(binding.raw_name) is Some(stack) {
      ignore(stack.pop())
      if stack.is_empty() {
        self.bindings.remove(binding.raw_name)
      }
    }
    if binding.lease is Some(lease) {
      lease.release()
    }
  }
}

///|
fn custom_structural_value(
  kind : String,
  attributes : Array[@xml.XmlCursorAttribute],
) -> Bool {
  match kind {
    "lpstr"
    | "lpwstr"
    | "bstr"
    | "bool"
    | "clsid"
    | "cy"
    | "date"
    | "decimal"
    | "empty"
    | "error"
    | "filetime"
    | "i1"
    | "i2"
    | "i4"
    | "i8"
    | "int"
    | "null"
    | "r4"
    | "r8"
    | "ui1"
    | "ui2"
    | "ui4"
    | "ui8"
    | "uint" => false
    "blob" | "oblob" | "ostorage" | "ostream" | "storage" | "stream" =>
      attributes.any(attribute => !attribute.namespace_declaration)
    _ => true
  }
}

///|
fn custom_append_escaped(
  value : OoxmlPropertyValue,
  text : String,
  context : @budget.BudgetContext?,
  attribute~ : Bool = false,
) -> Unit raise OoxmlError {
  for ch in text {
    match ch {
      '&' => value.append("&amp;", context)
      '<' => value.append("&lt;", context)
      '>' => value.append("&gt;", context)
      '"' if attribute => value.append("&quot;", context)
      '\t' if attribute => value.append("&#9;", context)
      '\n' if attribute => value.append("&#10;", context)
      // A CR produced by a character reference is not a raw line ending.
      // Keep it referenced so reparsing this value does not fold it to LF.
      '\r' => value.append("&#13;", context)
      _ => value.push(ch, context)
    }
  }
}

///|
fn custom_append_attribute(
  value : OoxmlPropertyValue,
  raw_name : String,
  text : String,
  context : @budget.BudgetContext?,
) -> Unit raise OoxmlError {
  value.push(' ', context)
  value.append(raw_name, context)
  value.append("=\"", context)
  custom_append_escaped(value, text, context, attribute=true)
  value.push('"', context)
}

///|
// A structural root includes every active declaration, including bindings
// used only in QName-valued attributes. Shadowed declarations are omitted;
// declaration order and all descendant rebinding remain explicit.
fn custom_append_start(
  consumer : CustomPropertiesConsumer,
  property : CustomPropertyState,
  name : @xml.XmlCursorName,
  attributes : Array[@xml.XmlCursorAttribute],
  self_closing : Bool,
  root~ : Bool,
) -> Unit raise OoxmlError {
  let value = property.value
  let context = consumer.context
  value.push('<', context)
  value.append(name.raw, context)
  if root {
    for binding in consumer.namespaces {
      if consumer.bindings.get(binding.raw_name) is Some(stack) &&
        stack.last() is Some(current) &&
        current.depth == binding.depth {
        custom_append_attribute(value, binding.raw_name, binding.value, context)
      }
    }
  }
  for attribute in attributes {
    if root && attribute.namespace_declaration {
      continue
    }
    custom_append_attribute(value, attribute.name.raw, attribute.value, context)
  }
  value.append(if self_closing { "/>" } else { ">" }, context)
}

///|
fn custom_cached_name(
  raw : String,
  context : @budget.BudgetContext?,
) -> String raise OoxmlError {
  let trimmed = raw.trim()
  let mut utf8_bytes = 0L
  for ch in trimmed {
    let scalar = ch.to_int()
    utf8_bytes += if scalar <= 0x7f {
      1L
    } else if scalar <= 0x7ff {
      2L
    } else if scalar <= 0xffff {
      3L
    } else {
      4L
    }
  }
  property_cache_payload(context, utf8_bytes, trimmed.length().to_int64())
  trimmed.to_owned()
}

///|
fn custom_finish_property(
  consumer : CustomPropertiesConsumer,
  property : CustomPropertyState,
) -> Unit raise OoxmlError {
  if consumer.policy.omit_empty_scalar_values &&
    !property.structural &&
    property.value.chars.all(property_trim_char) {
    property.close()
    consumer.active = None
    return
  }
  let name = custom_cached_name(property.raw_name, consumer.context)
  let value_type = property.value_type
  if value_type is Some(kind) {
    property_cache_payload(
      consumer.context,
      ooxml_metadata_utf8_bytes(kind),
      kind.length().to_int64(),
    )
  }
  let value = property.value.finish(consumer.context)
  consumer.values.push({ name, value, value_type, })
  property.close()
  consumer.active = None
}

///|
fn consume_custom_token(
  consumer : CustomPropertiesConsumer,
  token : @xml.XmlCursorToken,
) -> Unit raise OoxmlError {
  match token {
    StartElement(name, attributes, self_closing, _) => {
      consumer.enter_namespaces(attributes)
      let admitted = consumer.begin_candidate(name.raw, self_closing)
      match consumer.active {
        None if admitted && name.raw == "property" && !self_closing =>
          for attribute in attributes {
            if attribute.name.raw == "name" && attribute.value.trim() != "" {
              let name_lease = property_working_lease(
                consumer.context,
                attribute.value.length().to_int64() * 2L,
              )
              consumer.active = Some({
                raw_name: attribute.value,
                depth: consumer.depth,
                name_lease,
                value_type: None,
                type_lease: None,
                value_depth: None,
                value_closed: false,
                structural: false,
                value: {
                  key: "",
                  depth: 0,
                  chars: [],
                  capacity: 0,
                  lease: None,
                },
              })
              break
            }
          }
        Some(property) =>
          match property.value_depth {
            None if name.raw.has_prefix("vt:") => {
              let kind = if consumer.policy.qualified_value_type {
                name.raw
              } else {
                name.local_name
              }
              property.type_lease = property_working_lease(
                consumer.context,
                kind.length().to_int64() * 2L,
              )
              property.value_type = Some(kind)
              property.value_depth = Some(consumer.depth)
              property.value_closed = self_closing
              property.structural = custom_structural_value(
                name.local_name,
                attributes,
              )
              if property.structural {
                custom_append_start(
                  consumer,
                  property,
                  name,
                  attributes,
                  self_closing,
                  root=true,
                )
              }
            }
            Some(_) if !property.value_closed && property.structural =>
              custom_append_start(
                consumer,
                property,
                name,
                attributes,
                self_closing,
                root=false,
              )
            _ => ()
          }
        _ => ()
      }
      if self_closing {
        consumer.leave_namespaces()
      } else {
        consumer.depth += 1
      }
    }
    EndElement(name, _) => {
      consumer.depth -= 1
      if consumer.active is Some(property) {
        if property.value_depth is Some(depth) && !property.value_closed {
          if property.structural {
            property.value.append("</", consumer.context)
            property.value.append(name.raw, consumer.context)
            property.value.push('>', consumer.context)
          }
          if consumer.depth == depth {
            property.value_closed = true
          }
        }
        if consumer.depth == property.depth {
          custom_finish_property(consumer, property)
        }
      }
      if consumer.candidate_depth is Some(depth) && consumer.depth == depth {
        consumer.complete_candidate()
      }
      consumer.leave_namespaces()
    }
    TextFragment(text) | CDataFragment(text) =>
      if consumer.active is Some(property) &&
        property.value_depth is Some(_) &&
        !property.value_closed {
        if property.structural {
          custom_append_escaped(property.value, text.text, consumer.context)
        } else {
          property.value.append(text.text, consumer.context)
        }
      }
    Comment(text, _) =>
      if consumer.active is Some(property) &&
        property.value_depth is Some(_) &&
        !property.value_closed &&
        property.structural {
        property.value.append("<!--", consumer.context)
        property.value.append(text, consumer.context)
        property.value.append("-->", consumer.context)
      }
    ProcessingInstruction(target, body, _) =>
      if consumer.active is Some(property) &&
        property.value_depth is Some(_) &&
        !property.value_closed &&
        property.structural {
        property.value.append("<?", consumer.context)
        property.value.append(target, consumer.context)
        if body != "" {
          property.value.push(' ', consumer.context)
          property.value.append(body, consumer.context)
        }
        property.value.append("?>", consumer.context)
      }
    _ => ()
  }
}

///|
async fn read_custom_values(
  pkg : OoxmlPackage,
  chunk_size~ : Int32 = 64 * 1024,
) -> Array[OoxmlCustomProperty] raise OoxmlError {
  read_custom_projection(
    pkg,
    {
      max_candidates: None,
      qualified_value_type: false,
      omit_empty_scalar_values: false,
    },
    chunk_size~,
  ).properties
}

///|
async fn read_custom_projection(
  pkg : OoxmlPackage,
  policy : CustomPropertyProjectionPolicy,
  chunk_size~ : Int32 = 64 * 1024,
) -> OoxmlCustomPropertyProjection raise OoxmlError {
  let part = "docProps/custom.xml"
  require_relationship_archive_healthy(pkg.archive)
  if !has_part(pkg, part) {
    return { properties: [], limit_exceeded: false, }
  }
  let consumer : CustomPropertiesConsumer = {
    values: [],
    active: None,
    depth: 0,
    namespaces: [],
    bindings: Map([]),
    context: @zip.archive_budget_context(pkg.archive),
    policy,
    candidate_depth: None,
    completed_candidates: 0,
    limit_exceeded: false,
  }
  defer consumer.close()
  let _ = visit_ooxml_xml_tokens(
    pkg.archive,
    part,
    token => consume_custom_token(consumer, token),
    allow_unbound_prefixes=true,
    chunk_size~,
  ) catch {
    InvalidXml(_) => {
      consumer.close()
      verify_ooxml_xml_entry_integrity(pkg.archive, part, chunk_size~)
      require_relationship_archive_healthy(pkg.archive)
      return {
        properties: consumer.values,
        limit_exceeded: consumer.limit_exceeded,
      }
    }
    error => raise error
  }
  require_relationship_archive_healthy(pkg.archive)
  { properties: consumer.values, limit_exceeded: consumer.limit_exceeded, }
}
