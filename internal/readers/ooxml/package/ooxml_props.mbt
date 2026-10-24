///|
/// Read lightweight core document properties.
///
/// Missing `docProps/core.xml` is represented by a struct whose fields are
/// `None`.
pub async fn read_core_properties(
  pkg : OoxmlPackage,
) -> OoxmlCoreProperties raise OoxmlError {
  require_relationship_archive_healthy(pkg.archive)
  if pkg.core_properties_cache.val is Some(value) {
    return value
  }
  let fields = read_core_app_values(pkg, "docProps/core.xml", [
    "title", "subject", "creator", "lastModifiedBy", "description", "keywords", "category",
    "created", "modified",
  ])
  let value = {
    title: fields.get("title").unwrap_or(None),
    subject: fields.get("subject").unwrap_or(None),
    creator: fields.get("creator").unwrap_or(None),
    last_modified_by: fields.get("lastModifiedBy").unwrap_or(None),
    description: fields.get("description").unwrap_or(None),
    keywords: fields.get("keywords").unwrap_or(None),
    category: fields.get("category").unwrap_or(None),
    created: fields.get("created").unwrap_or(None),
    modified: fields.get("modified").unwrap_or(None),
  }
  pkg.core_properties_cache.val = Some(value)
  value
}

///|
/// Read lightweight app document properties.
///
/// Missing `docProps/app.xml` is represented by a struct whose fields are
/// `None`.
pub async fn read_app_properties(
  pkg : OoxmlPackage,
) -> OoxmlAppProperties raise OoxmlError {
  require_relationship_archive_healthy(pkg.archive)
  if pkg.app_properties_cache.val is Some(value) {
    return value
  }
  let fields = read_core_app_values(pkg, "docProps/app.xml", [
    "Application", "Company", "Manager", "Pages", "Words", "Slides", "Worksheets",
  ])
  let value = {
    application: fields.get("Application").unwrap_or(None),
    company: fields.get("Company").unwrap_or(None),
    manager: fields.get("Manager").unwrap_or(None),
    pages: fields.get("Pages").unwrap_or(None),
    words: fields.get("Words").unwrap_or(None),
    slides: fields.get("Slides").unwrap_or(None),
    sheets: fields.get("Worksheets").unwrap_or(None),
  }
  pkg.app_properties_cache.val = Some(value)
  value
}

///|
/// Read lightweight custom document properties.
///
/// Missing `docProps/custom.xml` is represented by an empty array.
/// Scalar values contain XML character content; structural values preserve
/// the complete selected VT element, type attributes and namespace context.
/// Binary, numeric, date and OOXML string-escape coercion is not performed.
pub async fn read_custom_properties(
  pkg : OoxmlPackage,
) -> Array[OoxmlCustomProperty] raise OoxmlError {
  require_relationship_archive_healthy(pkg.archive)
  if pkg.custom_properties_cache.val is Some(values) {
    return values.copy()
  }
  let values = read_custom_values(pkg)
  pkg.custom_properties_cache.val = Some(values)
  values.copy()
}

///|
/// Select a prefix of complete raw `property` candidates using the same custom
/// XML consumer. Missing names, empty values and self-closing properties still
/// consume slots. Nested properties consume no additional slot. The remaining
/// XML is validated through EOF/CRC, without buffering skipped property values.
///
/// qualified_value_type preserves the selected raw `vt:*` name for legacy
/// consumers. omit_empty_scalar_values drops empty character-content values;
/// structural values retain their complete selected element, even when empty.
/// Each policy has an independent projected cache; this does not materialize or
/// truncate the unlimited reader's result. Cached arrays are shallow copies.
pub async fn read_custom_properties_projected(
  pkg : OoxmlPackage,
  max_candidates~ : Int32,
  qualified_value_type~ : Bool = false,
  omit_empty_scalar_values~ : Bool = false,
) -> OoxmlCustomPropertyProjection raise OoxmlError {
  require_relationship_archive_healthy(pkg.archive)
  if max_candidates < 0 {
    raise InvalidXml("negative custom-property candidate limit")
  }
  let policy : CustomPropertyProjectionPolicy = {
    max_candidates: Some(max_candidates),
    qualified_value_type,
    omit_empty_scalar_values,
  }
  if pkg.custom_projections_cache.get(policy) is Some(value) {
    return { ..value, properties: value.properties.copy(), }
  }
  let value = read_custom_projection(pkg, policy)
  pkg.custom_projections_cache.set(policy, value)
  { ..value, properties: value.properties.copy(), }
}
