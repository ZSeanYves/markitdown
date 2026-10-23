///|
priv struct RelationshipsConsumer {
  rows : Array[OoxmlRelationshipRow]
  mut depth : Int32
  mut root_seen : Bool
  mut root_namespace : String?
}

///|
/// Inspect an already admitted relationship part without reading it again.
/// These counters describe actual cursor work; no numeric caps are inferred.
pub fn inspect_relationship_cursor(
  pkg : OoxmlPackage,
  source_part : String,
) -> @xml.XmlCursorStats? raise OoxmlError {
  let source = normalize_source_part_for_resolve(source_part)
  let part = if source == "" {
    "_rels/.rels"
  } else {
    rels_part_name_for_source(source)
  }
  pkg.relationship_cache.rows_by_rels_part.get(part).map(rows => rows.stats)
}

///|
fn require_relationship_archive_healthy(
  archive : @zip.ZipArchive,
) -> Unit raise OoxmlError {
  if @zip.archive_budget_context(archive) is Some(context) &&
    context.account.failure() is Some(error) {
    raise ooxml_cursor_hard_failure(archive, BudgetExceeded(error))
  }
  if @zip.archive_hard_failure(archive) is Some(message) {
    raise ZipError(message)
  }
}

///|
async fn read_relationship_rows_from_rels_part(
  pkg : OoxmlPackage,
  rels_part : String,
  allow_syntax_recovery~ : Bool = false,
) -> OoxmlRelationshipRows raise OoxmlError {
  require_relationship_archive_healthy(pkg.archive)
  let key = normalize_part_name(rels_part)
  match pkg.relationship_cache.rows_by_rels_part.get(key) {
    Some(rows) => return rows
    None => ()
  }
  let scanned = read_archive_relationship_rows(
    pkg.archive,
    key,
    allow_syntax_recovery~,
  )
  let context = @zip.archive_budget_context(pkg.archive)
  retain_relationship_payload(context, [key]) catch {
    error => raise ooxml_cursor_hard_failure(pkg.archive, error)
  }
  // Neither these rows nor the lookup index are published before CRC + EOF.
  // Missing required attributes remain raw rows for Strict validation; the
  // reader separately rejects them without manufacturing placeholder values.
  pkg.relationship_cache.rows_by_rels_part.set(key, scanned)
  scanned
}

///|
async fn read_archive_relationship_rows(
  archive : @zip.ZipArchive,
  part : String,
  chunk_size~ : Int32 = 64 * 1024,
  allow_syntax_recovery~ : Bool = false,
) -> OoxmlRelationshipRows raise OoxmlError {
  let context = @zip.archive_budget_context(archive)
  let consumer : RelationshipsConsumer = {
    rows: [],
    depth: 0,
    root_seen: false,
    root_namespace: None,
  }
  let stats = visit_ooxml_xml_tokens(
    archive,
    part,
    token => consume_relationships_token(consumer, part, token, context),
    chunk_size~,
    allow_syntax_recovery~,
  )
  { rows: consumer.rows, stats, }
}

///|
fn relationship_attribute(
  attributes : Array[@xml.XmlCursorAttribute],
  key : String,
) -> String {
  for attribute in attributes {
    if !attribute.namespace_declaration &&
      attribute.name.namespace_uri is None &&
      attribute.name.local_name == key {
      return attribute.value
    }
  }
  ""
}

///|
// Returned cursor Strings are bare owned values. Admit their retained payload
// before storing a row; conversion-scope leases survive next/EOF and removal.
// Container/Map/Array/object overhead remains explicitly unmeasured.
fn retain_relationship_payload(
  context : @budget.BudgetContext?,
  values : Array[String],
) -> Unit raise OoxmlError {
  if context is Some(context) {
    let mut metadata_bytes = 0L
    let mut resident_bytes = 0L
    for value in values {
      metadata_bytes += ooxml_metadata_utf8_bytes(value)
      resident_bytes += value.length().to_int64() * 2L
    }
    match context.account.charge(@budget.SourceMetadataBytes, metadata_bytes) {
      Err(error) => raise BudgetExceeded(error)
      Ok(_) => ()
    }
    match (context.retain_resident)(@budget.CacheBytes, resident_bytes) {
      Err(error) => raise BudgetExceeded(error)
      Ok(_) => ()
    }
  }
}

///|
fn relationship_normalization_scratch(
  context : @budget.BudgetContext?,
  source_part : String,
  target : String,
) -> @budget.BudgetLease? raise OoxmlError {
  match context {
    None => None
    Some(context) =>
      match
        context.account.reserve(
          @budget.WorkingBytes,
          (source_part.length().to_int64() + target.length().to_int64()) * 12L +
          2L,
        ) {
        Ok(lease) => Some(lease)
        Err(error) => raise BudgetExceeded(error)
      }
  }
}

///|
fn consume_relationships_token(
  consumer : RelationshipsConsumer,
  part : String,
  token : @xml.XmlCursorToken,
  context : @budget.BudgetContext?,
) -> Unit raise OoxmlError {
  match token {
    StartElement(name, attributes, self_closing, _) => {
      if consumer.depth == 0 {
        if consumer.root_seen ||
          name.local_name != "Relationships" ||
          (
            name.namespace_uri is Some(uri) &&
            uri !=
            "http://schemas.openxmlformats.org/package/2006/relationships"
          ) {
          raise InvalidXml(part + ": expected relationships Relationships root")
        }
        consumer.root_seen = true
        consumer.root_namespace = match name.namespace_uri {
          None => None
          Some(_) =>
            Some("http://schemas.openxmlformats.org/package/2006/relationships")
        }
      } else if name.namespace_uri == consumer.root_namespace &&
        name.local_name == "Relationship" {
        let id = relationship_attribute(attributes, "Id")
        let rel_type = relationship_attribute(attributes, "Type")
        let target = relationship_attribute(attributes, "Target")
        let target_mode = parse_target_mode(
          relationship_attribute(attributes, "TargetMode"),
        )
        retain_relationship_payload(context, [id, rel_type, target])
        consumer.rows.push({ id, rel_type, target, target_mode, })
      }
      if !self_closing {
        consumer.depth += 1
      }
    }
    EndElement(_, _) => consumer.depth -= 1
    _ => ()
  }
}
