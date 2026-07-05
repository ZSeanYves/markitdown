///|
pub fn indexed_table_row_path(base_path : String, row_index : Int) -> String {
  base_path + "/row[" + row_index.to_string() + "]"
}

///|
pub fn indexed_table_cell_path(row_path : String, col_index : Int) -> String {
  row_path + "/col[" + col_index.to_string() + "]"
}

///|
pub fn indexed_table_row_span(row_number : Int, col_count : Int) -> String {
  "R" +
  row_number.to_string() +
  "C1:R" +
  row_number.to_string() +
  "C" +
  col_count.to_string()
}

///|
pub fn indexed_table_cell_span(row_number : Int, col_number : Int) -> String {
  "R" + row_number.to_string() + "C" + col_number.to_string()
}

///|
pub fn key_position_index(keys : Array[String]) -> Map[String, Int] {
  let index : Map[String, Int] = Map([])
  for i in 0..<keys.length() {
    index.set(keys[i], i)
  }
  index
}

///|
pub fn keys_match_position_index(
  schema_keys : Array[String],
  schema_index : Map[String, Int],
  keys : Array[String],
) -> Bool {
  if schema_keys.length() != keys.length() {
    return false
  }
  for key in keys {
    if schema_index.get(key) is None {
      return false
    }
  }
  true
}

///|
pub fn projected_row_from_key_index(
  schema_keys : Array[String],
  value_index : Map[String, Int],
  value_at : (Int) -> String,
) -> Array[String] {
  let row : Array[String] = []
  for key in schema_keys {
    match value_index.get(key) {
      Some(index) => row.push(value_at(index))
      None => row.push("")
    }
  }
  row
}

///|
pub fn make_indexed_table_block(
  rows : Array[Array[String]],
  table_ref : @core.SourceRef,
  row_ref : (Int, Array[String]) -> @core.SourceRef,
  cell_ref : (Int, Int) -> @core.SourceRef,
) -> @core.CoreBlock {
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=table_ref,
  )
  table.attrs.set("header_rows", "1")
  for row_index in 0..<rows.length() {
    let row_values = rows[row_index]
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      row_values.join(" | "),
      source_ref=row_ref(row_index, row_values),
    )
    for col_index in 0..<row_values.length() {
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          row_values[col_index],
          source_ref=cell_ref(row_index, col_index),
        ),
      )
    }
    table.children.push(row)
  }
  table
}
