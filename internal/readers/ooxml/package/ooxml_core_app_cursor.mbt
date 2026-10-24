///|
// Only selected scalar property values are buffered. Capacity is explicit:
// four bytes per Char slot; geometric growth admits both old and new arrays.
priv struct OoxmlPropertyValue {
  key : String
  depth : Int32
  mut chars : Array[Char]
  mut capacity : Int32
  mut lease : @budget.BudgetLease?
}

///|
priv struct CoreAppPropertiesConsumer {
  fields : Array[String]
  values : Map[String, String?]
  active : Array[OoxmlPropertyValue]
  mut depth : Int32
  context : @budget.BudgetContext?
}

///|
fn property_working_lease(
  context : @budget.BudgetContext?,
  bytes : Int64,
) -> @budget.BudgetLease? raise OoxmlError {
  match context {
    None => None
    Some(context) =>
      match context.account.reserve(WorkingBytes, bytes) {
        Ok(lease) => Some(lease)
        Err(error) => raise BudgetExceeded(error)
      }
  }
}

///|
fn OoxmlPropertyValue::close(self : OoxmlPropertyValue) -> Unit {
  self.chars = []
  self.capacity = 0
  if self.lease is Some(lease) {
    lease.release()
  }
  self.lease = None
}

///|
fn OoxmlPropertyValue::append(
  self : OoxmlPropertyValue,
  text : String,
  context : @budget.BudgetContext?,
) -> Unit raise OoxmlError {
  for ch in text {
    self.push(ch, context)
  }
}

///|
fn OoxmlPropertyValue::push(
  self : OoxmlPropertyValue,
  ch : Char,
  context : @budget.BudgetContext?,
) -> Unit raise OoxmlError {
  if context is Some(context) {
    match context.account.charge(ParseWork, 1L) {
      Ok(_) => ()
      Err(error) => raise BudgetExceeded(error)
    }
  }
  if self.chars.length() == self.capacity {
    if self.capacity > 1073741823 {
      raise InvalidXml("property scalar capacity overflow")
    }
    let capacity = if self.capacity == 0 { 1 } else { self.capacity * 2 }
    let lease = property_working_lease(context, capacity.to_int64() * 4L)
    let replacement : Array[Char] = Array(capacity~)
    replacement.append(self.chars[:])
    self.chars = replacement
    self.capacity = capacity
    if self.lease is Some(lease) {
      lease.release()
    }
    self.lease = lease
  }
  self.chars.push(ch)
}

///|
fn OoxmlPropertyValue::finish(
  self : OoxmlPropertyValue,
  context : @budget.BudgetContext?,
) -> String raise OoxmlError {
  let mut first = 0
  let mut end = self.chars.length()
  while first < end && property_trim_char(self.chars[first]) {
    first += 1
  }
  while end > first && property_trim_char(self.chars[end - 1]) {
    end -= 1
  }
  let mut utf8_bytes = 0L
  let mut utf16_units = 0L
  for index in first..<end {
    let scalar = self.chars[index].to_int()
    utf8_bytes += if scalar <= 0x7f {
      1L
    } else if scalar <= 0x7ff {
      2L
    } else if scalar <= 0xffff {
      3L
    } else {
      4L
    }
    utf16_units += if scalar > 0xffff { 2L } else { 1L }
  }
  // Admit the final bare owned String before constructing it. Catalog keys
  // are static; only final trimmed values escape into the property cache.
  property_cache_payload(context, utf8_bytes, utf16_units)
  String::from_array(self.chars[first:end])
}

///|
fn property_cache_payload(
  context : @budget.BudgetContext?,
  utf8_bytes : Int64,
  utf16_units : Int64,
) -> Unit raise OoxmlError {
  if context is Some(context) {
    match context.account.charge(SourceMetadataBytes, utf8_bytes) {
      Ok(_) => ()
      Err(error) => raise BudgetExceeded(error)
    }
    match (context.retain_resident)(CacheBytes, utf16_units * 2L) {
      Ok(_) => ()
      Err(error) => raise BudgetExceeded(error)
    }
  }
}

///|
fn property_trim_char(ch : Char) -> Bool {
  // Match String.trim's existing default exactly; Unicode whitespace such
  // as NBSP was never removed by this metadata API.
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn consume_core_app_token(
  consumer : CoreAppPropertiesConsumer,
  token : @xml.XmlCursorToken,
) -> Unit raise OoxmlError {
  match token {
    StartElement(name, _, self_closing, _) => {
      for key in consumer.fields {
        if key == name.local_name && !consumer.values.contains(key) {
          // Mark the first occurrence even when it is empty/self-closing.
          consumer.values.set(key, None)
          if !self_closing {
            consumer.active.push({
              key,
              depth: consumer.depth,
              chars: [],
              capacity: 0,
              lease: None,
            })
          }
          break
        }
      }
      if !self_closing {
        consumer.depth += 1
      }
    }
    EndElement(_, _) => {
      consumer.depth -= 1
      if consumer.active.last() is Some(value) && value.depth == consumer.depth {
        let text = value.finish(consumer.context)
        consumer.values.set(value.key, Some(text))
        value.close()
        ignore(consumer.active.pop())
      }
    }
    TextFragment(value) | CDataFragment(value) =>
      for field in consumer.active {
        field.append(value.text, consumer.context)
      }
    _ => ()
  }
}

///|
async fn read_core_app_values(
  pkg : OoxmlPackage,
  part : String,
  fields : Array[String],
  chunk_size~ : Int32 = 64 * 1024,
) -> Map[String, String?] raise OoxmlError {
  require_relationship_archive_healthy(pkg.archive)
  if !has_part(pkg, part) {
    return Map([])
  }
  let consumer : CoreAppPropertiesConsumer = {
    fields,
    values: Map([]),
    active: [],
    depth: 0,
    context: @zip.archive_budget_context(pkg.archive),
  }
  defer (for field in consumer.active {
    field.close()
  })
  let _ = visit_ooxml_xml_tokens(
    pkg.archive,
    part,
    token => consume_core_app_token(consumer, token),
    allow_unbound_prefixes=true,
    chunk_size~,
  ) catch {
    // Retain completed first properties on a malformed XML tail only after
    // the shared replay completes UTF8/CRC/EOF verification.
    InvalidXml(_) => {
      // An incomplete field cannot be published. Retire that private buffer
      // before the shared integrity replay allocates its decode workspace.
      for field in consumer.active {
        field.close()
      }
      consumer.active.clear()
      verify_ooxml_xml_entry_integrity(pkg.archive, part, chunk_size~)
      require_relationship_archive_healthy(pkg.archive)
      return consumer.values
    }
    error => raise error
  }
  require_relationship_archive_healthy(pkg.archive)
  consumer.values
}
