///|
pub(all) enum BenchTier {
  Smoke
  Regular
  Release
  Stress
} derive(Eq)

///|
pub struct BenchManifestRow {
  bench_id : String
  format : String
  size_class : String
  rel_path : String
  source_kind : String
  source_ref : String
  bytes : Int
  sha256 : String
  enabled_tier : String
  bench_layers : Array[String]
  tags : Array[String]
  review_status : String
  notes : String
}

///|
pub fn samples_bench_root() -> String {
  "samples/bench"
}

///|
pub fn samples_bench_manifest_path() -> String {
  samples_bench_root() + "/MANIFEST.tsv"
}

///|
pub fn load_bench_manifest() -> Array[BenchManifestRow] {
  let path = samples_bench_manifest_path()
  let content = @fs.read_file_to_string(path, encoding="utf8") catch {
    e => abort("bench manifest read failed: " + path + " :: " + e.to_string())
  }
  let lines = content.split("\n").to_array()
  if lines.length() == 0 {
    abort("bench manifest is empty: " + path)
  }
  let rows : Array[BenchManifestRow] = []
  let header = lines[0].trim().to_owned()
  if header == "" {
    abort("bench manifest header is empty: " + path)
  }
  for i in 1..<lines.length() {
    let line = lines[i].trim_end().to_owned()
    if line.trim() == "" {
      continue
    }
    rows.push(parse_bench_manifest_line(line, i + 1, path))
  }
  rows
}

///|
pub fn bench_row_payload_path(row : BenchManifestRow) -> String {
  samples_bench_root() + "/" + row.rel_path
}

///|
pub fn bench_row_payload_exists(row : BenchManifestRow) -> Bool {
  @fs.path_exists(bench_row_payload_path(row))
}

///|
pub fn bench_row_input_source(row : BenchManifestRow) -> @input.InputSource {
  @input.input_from_path(bench_row_payload_path(row))
}

///|
pub fn bench_row_text(row : BenchManifestRow) -> String {
  match @input.read_input_text(bench_row_input_source(row)) {
    Ok(text) => text
    Err(err) => abort("bench text read failed: " + row.bench_id + " :: " + err)
  }
}

///|
pub fn bench_row_bytes(row : BenchManifestRow) -> Bytes {
  match @input.read_input_bytes(bench_row_input_source(row)) {
    Ok(bytes) => bytes
    Err(err) => abort("bench byte read failed: " + row.bench_id + " :: " + err)
  }
}

///|
pub fn bench_row_default_convert_options(
  row : BenchManifestRow,
) -> @convert.ConvertOptions {
  ignore(row)
  @convert.default_convert_options()
}

///|
fn parse_bench_manifest_line(
  line : String,
  line_no : Int,
  path : String,
) -> BenchManifestRow {
  let columns = line.split("\t").to_array().map(part => part.to_owned())
  if columns.length() != 13 {
    abort(
      "bench manifest column mismatch at " + path + ":" + line_no.to_string(),
    )
  }
  {
    bench_id: columns[0],
    format: columns[1],
    size_class: columns[2],
    rel_path: columns[3],
    source_kind: columns[4],
    source_ref: columns[5],
    bytes: parse_manifest_int(columns[6], line_no, path),
    sha256: columns[7],
    enabled_tier: columns[8],
    bench_layers: split_csv_field(columns[9]),
    tags: split_csv_field(columns[10]),
    review_status: columns[11],
    notes: columns[12],
  }
}

///|
fn parse_manifest_int(text : String, line_no : Int, path : String) -> Int {
  @string.parse_int(text.trim()) catch {
    _ =>
      abort(
        "bench manifest integer parse failed at " +
        path +
        ":" +
        line_no.to_string(),
      )
  }
}

///|
fn split_csv_field(text : String) -> Array[String] {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return []
  }
  trimmed
  .split(",")
  .to_array()
  .map(part => part.trim().to_owned())
  .filter(part => part != "")
}
