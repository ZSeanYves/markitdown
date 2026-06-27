///|
pub(all) enum NativeXmlStatus {
  Ok
  BackendUnavailable
  ParseFailed
} derive(Eq)

///|
pub struct NativeXmlStructureScan {
  status : NativeXmlStatus
  node_count : Int
  element_count : Int
  attribute_count : Int
  text_node_count : Int
  comment_count : Int
  cdata_count : Int
  processing_instruction_count : Int
  max_depth : Int
  has_doctype : Bool
  has_unsupported_doctype : Bool
  has_complex_mixed_content : Bool
  has_markdown_fence_text : Bool
  has_default_namespace : Bool
  error_code : Int
}

///|
pub struct NativeXlsxWorkbookSheet {
  name : String
  sheet_id : String?
  relationship_id : String
  state : String?
}

///|
pub struct NativeXlsxWorkbookScan {
  status : NativeXmlStatus
  uses_date_1904 : Bool
  sheets : Array[NativeXlsxWorkbookSheet]
  error_code : Int
}

///|
pub struct NativeXlsxSharedStringsScan {
  status : NativeXmlStatus
  items : Array[String]
  error_code : Int
}

///|
pub struct NativeXlsxWorksheetCell {
  row_index : Int
  column_index : Int
  cell_ref : String
  cell_type : String
  style_id : String?
  raw_value : String?
  inline_text : String?
  formula_text : String?
  formula_kind : String?
}

///|
pub struct NativeXlsxWorksheetScan {
  status : NativeXmlStatus
  dimension_ref : String?
  hidden_rows : Array[Int]
  merged_ranges : Array[String]
  cells : Array[NativeXlsxWorksheetCell]
  error_code : Int
}

///|
#external
priv type NativeXmlWorksheetScannerHandle

///|
#borrow(xml_blob, out_status, out_error_code)
extern "C" fn native_xml_scan_structure_blob_ffi(
  xml_blob : Bytes,
  xml_len : Int,
  out_status : Ref[Int],
  out_error_code : Ref[Int],
) -> Bytes = "markitdown_xml_native_scan_structure_blob"

///|
#borrow(xml_blob, out_status, out_error_code)
extern "C" fn native_xlsx_scan_workbook_blob_ffi(
  xml_blob : Bytes,
  xml_len : Int,
  out_status : Ref[Int],
  out_error_code : Ref[Int],
) -> Bytes = "markitdown_xml_native_xlsx_scan_workbook_blob"

///|
#borrow(xml_blob, out_status, out_error_code)
extern "C" fn native_xlsx_scan_shared_strings_blob_ffi(
  xml_blob : Bytes,
  xml_len : Int,
  out_status : Ref[Int],
  out_error_code : Ref[Int],
) -> Bytes = "markitdown_xml_native_xlsx_scan_shared_strings_blob"

///|
#borrow(xml_blob, out_status, out_error_code)
extern "C" fn native_xlsx_scan_worksheet_blob_ffi(
  xml_blob : Bytes,
  xml_len : Int,
  out_status : Ref[Int],
  out_error_code : Ref[Int],
) -> Bytes = "markitdown_xml_native_xlsx_scan_worksheet_blob"

///|
#borrow(out_status, out_error_code)
extern "C" fn native_xlsx_worksheet_scanner_new_ffi(
  limits_enabled : Int,
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  out_status : Ref[Int],
  out_error_code : Ref[Int],
) -> NativeXmlWorksheetScannerHandle = "markitdown_xml_native_xlsx_worksheet_scanner_new"

///|
extern "C" fn native_xlsx_worksheet_scanner_is_null_ffi(
  handle : NativeXmlWorksheetScannerHandle,
) -> Int = "markitdown_xml_native_xlsx_worksheet_scanner_is_null"

///|
#borrow(out_status, out_error_code, xml_chunk)
extern "C" fn native_xlsx_worksheet_scanner_feed_ffi(
  handle : NativeXmlWorksheetScannerHandle,
  xml_chunk : Bytes,
  xml_len : Int,
  is_final : Int,
  out_status : Ref[Int],
  out_error_code : Ref[Int],
) -> Int = "markitdown_xml_native_xlsx_worksheet_scanner_feed"

///|
#borrow(out_status, out_error_code)
extern "C" fn native_xlsx_worksheet_scanner_finish_ffi(
  handle : NativeXmlWorksheetScannerHandle,
  out_status : Ref[Int],
  out_error_code : Ref[Int],
) -> Bytes = "markitdown_xml_native_xlsx_worksheet_scanner_finish"

///|
extern "C" fn native_xlsx_worksheet_scanner_free_ffi(
  handle : NativeXmlWorksheetScannerHandle,
) -> Unit = "markitdown_xml_native_xlsx_worksheet_scanner_free"

///|
const XML_NATIVE_MAGIC : Int = 0x4d584d4c

///|
const XML_NATIVE_VERSION : Int = 1

///|
const XML_KIND_WORKBOOK : Int = 1

///|
const XML_KIND_SHARED_STRINGS : Int = 2

///|
const XML_KIND_WORKSHEET : Int = 3

///|
const XML_KIND_STRUCTURE_SUMMARY : Int = 4

///|
fn native_xml_status_from_int(code : Int) -> NativeXmlStatus {
  if code == 0 {
    NativeXmlStatus::Ok
  } else if code == 1 {
    NativeXmlStatus::BackendUnavailable
  } else {
    NativeXmlStatus::ParseFailed
  }
}

///|
pub fn native_xml_scan_structure_bytes(
  xml_bytes : Bytes,
) -> NativeXmlStructureScan {
  let status = Ref(0)
  let error_code = Ref(0)
  let blob = native_xml_scan_structure_blob_ffi(
    xml_bytes,
    xml_bytes.length(),
    status,
    error_code,
  )
  let summary = decode_native_xml_structure_blob(blob)
  {
    ..summary,
    status: native_xml_status_from_int(status.val),
    error_code: error_code.val,
  }
}

///|
pub fn native_xml_scan_structure(xml : String) -> NativeXmlStructureScan {
  native_xml_scan_structure_bytes(@utf8.encode(xml))
}

///|
pub fn native_xlsx_scan_workbook_bytes(
  xml_bytes : Bytes,
) -> NativeXlsxWorkbookScan {
  let status = Ref(0)
  let error_code = Ref(0)
  let blob = native_xlsx_scan_workbook_blob_ffi(
    xml_bytes,
    xml_bytes.length(),
    status,
    error_code,
  )
  let (uses_date_1904, sheets) = decode_xlsx_workbook_blob(blob)
  {
    status: native_xml_status_from_int(status.val),
    uses_date_1904,
    sheets,
    error_code: error_code.val,
  }
}

///|
pub fn native_xlsx_scan_workbook(xml : String) -> NativeXlsxWorkbookScan {
  native_xlsx_scan_workbook_bytes(@utf8.encode(xml))
}

///|
pub fn native_xlsx_scan_shared_strings_bytes(
  xml_bytes : Bytes,
) -> NativeXlsxSharedStringsScan {
  let status = Ref(0)
  let error_code = Ref(0)
  let blob = native_xlsx_scan_shared_strings_blob_ffi(
    xml_bytes,
    xml_bytes.length(),
    status,
    error_code,
  )
  {
    status: native_xml_status_from_int(status.val),
    items: decode_xlsx_shared_strings_blob(blob),
    error_code: error_code.val,
  }
}

///|
pub fn native_xlsx_scan_shared_strings(
  xml : String,
) -> NativeXlsxSharedStringsScan {
  native_xlsx_scan_shared_strings_bytes(@utf8.encode(xml))
}

///|
pub fn native_xlsx_scan_worksheet_bytes(
  xml_bytes : Bytes,
) -> NativeXlsxWorksheetScan {
  let status = Ref(0)
  let error_code = Ref(0)
  let blob = native_xlsx_scan_worksheet_blob_ffi(
    xml_bytes,
    xml_bytes.length(),
    status,
    error_code,
  )
  let (dimension_ref, hidden_rows, merged_ranges, cells) = decode_xlsx_worksheet_blob(
    blob,
  )
  {
    status: native_xml_status_from_int(status.val),
    dimension_ref,
    hidden_rows,
    merged_ranges,
    cells,
    error_code: error_code.val,
  }
}

///|
pub fn native_xlsx_scan_worksheet(xml : String) -> NativeXlsxWorksheetScan {
  native_xlsx_scan_worksheet_bytes(@utf8.encode(xml))
}

///|
pub fn native_xlsx_scan_cells(xml : String) -> NativeXlsxWorksheetScan {
  native_xlsx_scan_worksheet(xml)
}

///|
priv struct NativeXlsxWorksheetScanner {
  handle : NativeXmlWorksheetScannerHandle
  status : Ref[Int]
  error_code : Ref[Int]
}

///|
fn native_xlsx_worksheet_scanner_new(
  max_rows? : Int? = None,
  max_cols? : Int? = None,
  max_cells? : Int? = None,
) -> Result[NativeXlsxWorksheetScanner, NativeXlsxWorksheetScan] {
  let status = Ref(0)
  let error_code = Ref(0)
  let limits_enabled = max_rows is Some(_) ||
    max_cols is Some(_) ||
    max_cells is Some(_)
  let handle = native_xlsx_worksheet_scanner_new_ffi(
    if limits_enabled {
      1
    } else {
      0
    },
    max_rows.unwrap_or(0),
    max_cols.unwrap_or(0),
    max_cells.unwrap_or(0),
    status,
    error_code,
  )
  if native_xlsx_worksheet_scanner_is_null_ffi(handle) != 0 {
    return Err({
      status: native_xml_status_from_int(status.val),
      dimension_ref: None,
      hidden_rows: [],
      merged_ranges: [],
      cells: [],
      error_code: error_code.val,
    })
  }
  Ok({ handle, status, error_code })
}

///|
fn NativeXlsxWorksheetScanner::feed(
  self : NativeXlsxWorksheetScanner,
  xml_chunk : Bytes,
  is_final? : Bool = false,
) -> Result[Unit, NativeXlsxWorksheetScan] {
  let accepted = native_xlsx_worksheet_scanner_feed_ffi(
    self.handle,
    xml_chunk,
    xml_chunk.length(),
    if is_final {
      1
    } else {
      0
    },
    self.status,
    self.error_code,
  )
  if accepted == 0 {
    return Err({
      status: native_xml_status_from_int(self.status.val),
      dimension_ref: None,
      hidden_rows: [],
      merged_ranges: [],
      cells: [],
      error_code: self.error_code.val,
    })
  }
  Ok(())
}

///|
fn NativeXlsxWorksheetScanner::finish(
  self : NativeXlsxWorksheetScanner,
) -> NativeXlsxWorksheetScan {
  let blob = native_xlsx_worksheet_scanner_finish_ffi(
    self.handle,
    self.status,
    self.error_code,
  )
  let (dimension_ref, hidden_rows, merged_ranges, cells) = decode_xlsx_worksheet_blob(
    blob,
  )
  {
    status: native_xml_status_from_int(self.status.val),
    dimension_ref,
    hidden_rows,
    merged_ranges,
    cells,
    error_code: self.error_code.val,
  }
}

///|
fn NativeXlsxWorksheetScanner::free(self : NativeXlsxWorksheetScanner) -> Unit {
  native_xlsx_worksheet_scanner_free_ffi(self.handle)
}

///|
pub fn native_xlsx_scan_worksheet_with_chunk_feeder(
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  feed_chunks : ((Bytes) -> Result[Unit, String]) -> Result[Unit, String],
) -> Result[NativeXlsxWorksheetScan, String] {
  let scanner = match
    native_xlsx_worksheet_scanner_new(
      max_rows=Some(max_rows),
      max_cols=Some(max_cols),
      max_cells=Some(max_cells),
    ) {
    Ok(value) => value
    Err(scan) =>
      return Err(
        "native worksheet scanner unavailable: status=" +
        native_xml_status_name(scan.status) +
        ", error_code=" +
        scan.error_code.to_string(),
      )
  }
  let feed_result = feed_chunks(fn(chunk : Bytes) {
    match scanner.feed(chunk) {
      Ok(_) => Ok(())
      Err(scan) =>
        Err(
          "native worksheet scanner feed failed: status=" +
          native_xml_status_name(scan.status) +
          ", error_code=" +
          scan.error_code.to_string(),
        )
    }
  })
  match feed_result {
    Ok(_) => ()
    Err(err) => {
      scanner.free()
      return Err(err)
    }
  }
  let scan = scanner.finish()
  scanner.free()
  if scan.status != NativeXmlStatus::Ok {
    return Err(
      "native worksheet scanner finish failed: status=" +
      native_xml_status_name(scan.status) +
      ", error_code=" +
      scan.error_code.to_string(),
    )
  }
  Ok(scan)
}

///|
fn native_xml_status_name(status : NativeXmlStatus) -> String {
  match status {
    NativeXmlStatus::Ok => "ok"
    NativeXmlStatus::BackendUnavailable => "backend_unavailable"
    NativeXmlStatus::ParseFailed => "parse_failed"
  }
}

///|
fn decode_native_xml_structure_blob(blob : Bytes) -> NativeXmlStructureScan {
  match xml_native_read_header(blob) {
    Ok((kind, node_count, header_flags, payload_offset, _)) => {
      if kind != XML_KIND_STRUCTURE_SUMMARY ||
        payload_offset + 28 > blob.length() {
        return empty_native_xml_structure_scan()
      }
      {
        status: NativeXmlStatus::ParseFailed,
        node_count,
        element_count: xml_native_read_u32_le(blob, payload_offset),
        attribute_count: xml_native_read_u32_le(blob, payload_offset + 4),
        text_node_count: xml_native_read_u32_le(blob, payload_offset + 8),
        comment_count: xml_native_read_u32_le(blob, payload_offset + 12),
        cdata_count: xml_native_read_u32_le(blob, payload_offset + 16),
        processing_instruction_count: xml_native_read_u32_le(
          blob,
          payload_offset + 20,
        ),
        max_depth: xml_native_read_u32_le(blob, payload_offset + 24),
        has_doctype: (header_flags & 1) != 0,
        has_unsupported_doctype: (header_flags & 2) != 0,
        has_complex_mixed_content: (header_flags & 4) != 0,
        has_markdown_fence_text: (header_flags & 8) != 0,
        has_default_namespace: (header_flags & 16) != 0,
        error_code: 0,
      }
    }
    Err(_) => empty_native_xml_structure_scan()
  }
}

///|
fn empty_native_xml_structure_scan() -> NativeXmlStructureScan {
  {
    status: NativeXmlStatus::ParseFailed,
    node_count: 0,
    element_count: 0,
    attribute_count: 0,
    text_node_count: 0,
    comment_count: 0,
    cdata_count: 0,
    processing_instruction_count: 0,
    max_depth: 0,
    has_doctype: false,
    has_unsupported_doctype: false,
    has_complex_mixed_content: false,
    has_markdown_fence_text: false,
    has_default_namespace: false,
    error_code: 0,
  }
}

///|
fn decode_xlsx_workbook_blob(
  blob : Bytes,
) -> (Bool, Array[NativeXlsxWorkbookSheet]) {
  match xml_native_read_header(blob) {
    Ok((kind, record_count, header_flags, payload_offset, string_offset)) => {
      if kind != XML_KIND_WORKBOOK {
        return (false, [])
      }
      let record_size = 32
      if payload_offset + record_count * record_size > blob.length() ||
        string_offset < payload_offset {
        return (false, [])
      }
      let sheets : Array[NativeXlsxWorkbookSheet] = []
      let mut i = 0
      while i < record_count {
        let base = payload_offset + i * record_size
        sheets.push({
          name: xml_native_read_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base),
            xml_native_read_u32_le(blob, base + 4),
          ),
          sheet_id: xml_native_read_optional_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 8),
            xml_native_read_u32_le(blob, base + 12),
          ),
          relationship_id: xml_native_read_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 16),
            xml_native_read_u32_le(blob, base + 20),
          ),
          state: xml_native_read_optional_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 24),
            xml_native_read_u32_le(blob, base + 28),
          ),
        })
        i += 1
      }
      ((header_flags & 1) != 0, sheets)
    }
    Err(_) => (false, [])
  }
}

///|
fn decode_xlsx_shared_strings_blob(blob : Bytes) -> Array[String] {
  match xml_native_read_header(blob) {
    Ok((kind, record_count, _, payload_offset, string_offset)) => {
      if kind != XML_KIND_SHARED_STRINGS {
        return []
      }
      let record_size = 8
      if payload_offset + record_count * record_size > blob.length() ||
        string_offset < payload_offset {
        return []
      }
      let items : Array[String] = []
      let mut i = 0
      while i < record_count {
        let base = payload_offset + i * record_size
        items.push(
          xml_native_read_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base),
            xml_native_read_u32_le(blob, base + 4),
          ),
        )
        i += 1
      }
      items
    }
    Err(_) => []
  }
}

///|
fn decode_xlsx_worksheet_blob(
  blob : Bytes,
) -> (String?, Array[Int], Array[String], Array[NativeXlsxWorksheetCell]) {
  match xml_native_read_header(blob) {
    Ok((kind, record_count, hidden_count, payload_offset, string_offset)) => {
      if kind != XML_KIND_WORKSHEET {
        return (None, [], [], [])
      }
      if payload_offset + 12 > blob.length() || string_offset < payload_offset {
        return (None, [], [], [])
      }
      let dimension_ref = xml_native_read_optional_string(
        blob,
        string_offset,
        xml_native_read_u32_le(blob, payload_offset),
        xml_native_read_u32_le(blob, payload_offset + 4),
      )
      let merge_count = xml_native_read_u32_le(blob, payload_offset + 8)
      let hidden_start = payload_offset + 12
      let merges_start = hidden_start + hidden_count * 4
      let cells_start = merges_start + merge_count * 8
      let cell_record_size = 64
      if merges_start > blob.length() ||
        cells_start > blob.length() ||
        cells_start + record_count * cell_record_size > blob.length() ||
        string_offset < cells_start {
        return (dimension_ref, [], [], [])
      }
      let hidden_rows : Array[Int] = []
      let mut hidden_index = 0
      while hidden_index < hidden_count {
        hidden_rows.push(
          xml_native_read_u32_le(blob, hidden_start + hidden_index * 4),
        )
        hidden_index += 1
      }
      let merged_ranges : Array[String] = []
      let mut merge_index = 0
      while merge_index < merge_count {
        let base = merges_start + merge_index * 8
        merged_ranges.push(
          xml_native_read_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base),
            xml_native_read_u32_le(blob, base + 4),
          ),
        )
        merge_index += 1
      }
      let cells : Array[NativeXlsxWorksheetCell] = []
      let mut cell_index = 0
      while cell_index < record_count {
        let base = cells_start + cell_index * cell_record_size
        cells.push({
          row_index: xml_native_read_u32_le(blob, base),
          column_index: xml_native_read_u32_le(blob, base + 4),
          cell_ref: xml_native_read_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 8),
            xml_native_read_u32_le(blob, base + 12),
          ),
          cell_type: xml_native_read_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 16),
            xml_native_read_u32_le(blob, base + 20),
          ),
          style_id: xml_native_read_optional_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 24),
            xml_native_read_u32_le(blob, base + 28),
          ),
          raw_value: xml_native_read_optional_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 32),
            xml_native_read_u32_le(blob, base + 36),
          ),
          inline_text: xml_native_read_optional_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 40),
            xml_native_read_u32_le(blob, base + 44),
          ),
          formula_text: xml_native_read_optional_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 48),
            xml_native_read_u32_le(blob, base + 52),
          ),
          formula_kind: xml_native_read_optional_string(
            blob,
            string_offset,
            xml_native_read_u32_le(blob, base + 56),
            xml_native_read_u32_le(blob, base + 60),
          ),
        })
        cell_index += 1
      }
      (dimension_ref, hidden_rows, merged_ranges, cells)
    }
    Err(_) => (None, [], [], [])
  }
}

///|
fn xml_native_read_header(
  blob : Bytes,
) -> Result[(Int, Int, Int, Int, Int), String] {
  if blob.length() < 28 {
    return Err("blob too short")
  }
  if xml_native_read_u32_le(blob, 0) != XML_NATIVE_MAGIC ||
    xml_native_read_u32_le(blob, 4) != XML_NATIVE_VERSION {
    return Err("invalid header")
  }
  let kind = xml_native_read_u32_le(blob, 8)
  let record_count = xml_native_read_u32_le(blob, 12)
  let header_flags = xml_native_read_u32_le(blob, 16)
  let payload_offset = xml_native_read_u32_le(blob, 20)
  let string_offset = xml_native_read_u32_le(blob, 24)
  if payload_offset < 28 ||
    string_offset < payload_offset ||
    string_offset > blob.length() ||
    record_count < 0 {
    return Err("invalid bounds")
  }
  Ok((kind, record_count, header_flags, payload_offset, string_offset))
}

///|
fn xml_native_read_optional_string(
  blob : Bytes,
  string_offset : Int,
  relative_offset : Int,
  len : Int,
) -> String? {
  let text = xml_native_read_string(blob, string_offset, relative_offset, len)
  if text == "" {
    None
  } else {
    Some(text)
  }
}

///|
fn xml_native_read_string(
  blob : Bytes,
  string_offset : Int,
  relative_offset : Int,
  len : Int,
) -> String {
  if len <= 0 {
    return ""
  }
  let start = string_offset + relative_offset
  let end_ = start + len
  if relative_offset < 0 || start < string_offset || end_ > blob.length() {
    return ""
  }
  @utf8.decode(blob[start:end_].to_owned(), ignore_bom=false) catch {
    _ => ""
  }
}

///|
fn xml_native_read_u16_le(blob : Bytes, offset : Int) -> Int {
  if offset < 0 || offset + 2 > blob.length() {
    return 0
  }
  xml_native_byte_to_int(blob[offset]) |
  (xml_native_byte_to_int(blob[offset + 1]) << 8)
}

///|
fn xml_native_read_u32_le(blob : Bytes, offset : Int) -> Int {
  if offset < 0 || offset + 4 > blob.length() {
    return 0
  }
  xml_native_byte_to_int(blob[offset]) |
  (xml_native_byte_to_int(blob[offset + 1]) << 8) |
  (xml_native_byte_to_int(blob[offset + 2]) << 16) |
  (xml_native_byte_to_int(blob[offset + 3]) << 24)
}

///|
fn xml_native_byte_to_int(byte : Byte) -> Int {
  let value = byte.to_int()
  if value >= 0 {
    value
  } else {
    value + 256
  }
}
