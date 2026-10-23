///|
priv struct OoxmlContentTypes {
  defaults : Map[String, String]
  overrides : Map[String, String]
  stats : @xml.XmlCursorStats
}

///|
priv struct ContentTypesConsumer {
  defaults : Map[String, String]
  overrides : Map[String, String]
  mut depth : Int32
  mut root_seen : Bool
  mut root_namespace : String?
}

///|
async fn read_archive_content_types(
  archive : @zip.ZipArchive,
  chunk_size~ : Int32 = 64 * 1024,
) -> OoxmlContentTypes raise OoxmlError {
  let context = @zip.archive_budget_context(archive)
  let consumer = {
    defaults: Map([]),
    overrides: Map([]),
    depth: 0,
    root_seen: false,
    root_namespace: None,
  }
  let stats = visit_ooxml_xml_tokens(
    archive,
    "[Content_Types].xml",
    token => consume_content_types_token(consumer, token, context),
    chunk_size~,
  )
  { defaults: consumer.defaults, overrides: consumer.overrides, stats, }
}

///|
fn content_types_attr(
  attributes : Array[@xml.XmlCursorAttribute],
  key : String,
) -> String raise OoxmlError {
  for attribute in attributes {
    if !attribute.namespace_declaration &&
      attribute.name.namespace_uri is None &&
      attribute.name.local_name == key {
      if attribute.value.trim() != "" {
        return attribute.value
      }
      break
    }
  }
  raise InvalidXml("[Content_Types].xml: missing attribute: " + key)
}

///|
fn ooxml_metadata_utf8_bytes(value : String) -> Int64 {
  let mut bytes = 0L
  for ch in value {
    let scalar = ch.to_int()
    bytes += if scalar <= 0x7f {
      1L
    } else if scalar <= 0x7ff {
      2L
    } else if scalar <= 0xffff {
      3L
    } else {
      4L
    }
  }
  bytes
}

///|
// Cursor token fields are bare owned Strings. Reserve before storing them in
// a Map, then let the conversion scope hold that reservation beyond next/EOF.
// Removal, parse failure and cursor.close do not refund escaped payloads. This
// is a conservative scope upper bound, not a claim to measure allocator/RSS.
fn retain_content_type(
  context : @budget.BudgetContext?,
  key : String,
  value : String,
) -> Unit raise OoxmlError {
  if context is Some(context) {
    match
      context.account.charge(
        @budget.SourceMetadataBytes,
        ooxml_metadata_utf8_bytes(key) + ooxml_metadata_utf8_bytes(value),
      ) {
      Err(error) => raise BudgetExceeded(error)
      Ok(_) => ()
    }
    match
      (context.retain_resident)(
        @budget.CacheBytes,
        (key.length().to_int64() + value.length().to_int64()) * 2L,
      ) {
      Err(error) => raise BudgetExceeded(error)
      Ok(_) => ()
    }
  }
}

///|
fn consume_content_types_token(
  consumer : ContentTypesConsumer,
  token : @xml.XmlCursorToken,
  context : @budget.BudgetContext?,
) -> Unit raise OoxmlError {
  match token {
    StartElement(name, attributes, self_closing, _) => {
      if consumer.depth == 0 {
        if consumer.root_seen ||
          name.local_name != "Types" ||
          (
            name.namespace_uri is Some(uri) &&
            uri !=
            "http://schemas.openxmlformats.org/package/2006/content-types"
          ) {
          raise InvalidXml(
            "[Content_Types].xml: expected content-types Types root",
          )
        }
        consumer.root_seen = true
        // Store the canonical static URI, not the cursor token's owned String.
        // Only the maps retain token payloads past the next pull, and those
        // payloads have explicit conversion-scope reservations below.
        consumer.root_namespace = match name.namespace_uri {
          None => None
          Some(_) =>
            Some("http://schemas.openxmlformats.org/package/2006/content-types")
        }
      } else if name.namespace_uri == consumer.root_namespace {
        match name.local_name {
          "Default" => {
            let extension = content_types_attr(attributes, "Extension")
            let value = content_types_attr(attributes, "ContentType")
            if consumer.defaults.contains(extension) {
              raise InvalidXml(
                "[Content_Types].xml: duplicate content type default extension: " +
                extension,
              )
            }
            retain_content_type(context, extension, value)
            consumer.defaults.set(extension, value)
          }
          "Override" => {
            let part = content_types_attr(attributes, "PartName")
            let value = content_types_attr(attributes, "ContentType")
            // Existing normalization keeps at most five source-sized UTF16
            // payloads (trim/copy/segments/join) plus the prefixed result. Admit
            // their conservative payload capacity before allocating them.
            let scratch = match context {
              None => None
              Some(context) =>
                match
                  context.account.reserve(
                    @budget.WorkingBytes,
                    part.length().to_int64() * 12L + 2L,
                  ) {
                  Ok(lease) => Some(lease)
                  Err(error) => raise BudgetExceeded(error)
                }
            }
            defer (if scratch is Some(lease) { lease.release() })
            let key = "/" + normalize_part_name(part)
            if consumer.overrides.contains(key) {
              raise InvalidXml(
                "[Content_Types].xml: duplicate content type override: " + key,
              )
            }
            retain_content_type(context, key, value)
            consumer.overrides.set(key, value)
          }
          _ => ()
        }
      }
      if !self_closing {
        consumer.depth += 1
      }
    }
    EndElement(_, _) => consumer.depth -= 1
    _ => ()
  }
}
