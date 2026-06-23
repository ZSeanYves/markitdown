///|
pub fn micro_textlike_smoke_rows() -> Array[BenchManifestRow] {
  let formats = ["txt", "csv", "tsv", "json", "yaml", "xml", "markdown", "html"]
  select_rows_for_layer_and_formats(BenchTier::Smoke, "micro", formats).filter(row => {
    row.size_class == "tiny" || row.size_class == "small"
  })
}

///|
pub fn micro_detector_smoke_rows() -> Array[BenchManifestRow] {
  select_rows_for_layer(BenchTier::Smoke, "micro")
}

///|
pub fn pipeline_smoke_textlike_rows() -> Array[BenchManifestRow] {
  let formats = ["txt", "csv", "tsv", "json", "yaml", "xml", "markdown", "html"]
  select_rows_for_layer_and_formats(BenchTier::Smoke, "pipeline", formats)
}

///|
pub fn pipeline_smoke_binary_rows() -> Array[BenchManifestRow] {
  let formats = ["zip", "epub", "pdf", "docx", "pptx", "xlsx"]
  select_rows_for_layer_and_formats(BenchTier::Smoke, "pipeline", formats)
}

///|
pub fn product_smoke_rows() -> Array[BenchManifestRow] {
  select_rows_for_layer(BenchTier::Smoke, "product")
}
