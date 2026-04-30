///|
pub fn parse_csv(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  parse_delimited_file(input_path, DelimitedFormat::Csv)
}

///|
pub fn parse_tsv(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  parse_delimited_file(input_path, DelimitedFormat::Tsv)
}

///|
fn parse_delimited_file(
  input_path : String,
  format : DelimitedFormat,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("csv: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("csv: read failed: " + e.to_string())
  }

  let text = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("csv: utf8 decode failed: " + e.to_string())
  }

  let rows = parse_delimited_table(text, format)
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  if rows.length() == 0 {
    return doc
  }

  @cor.push_with_origin(
    doc,
    @cor.Block::Table(rows),
    Some({
      source_name: Some(src),
      page: None,
      slide: None,
      sheet: None,
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref: None,
      relationship_id: None,
      key_path: None,
    }),
  )

  doc
}
