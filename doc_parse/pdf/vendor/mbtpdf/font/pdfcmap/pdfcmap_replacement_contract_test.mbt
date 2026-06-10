///|
fn contract_cmap_stream(data : String) -> @pdf.PdfObject {
  let bytes = @pdfio.bytes_of_string(data)
  Stream(
    Ref(
      (
        Dictionary([("/Length", Integer(@pdfio.bytes_size(bytes)))]),
        @pdf.Stream::Got(bytes),
      ),
    ),
  )
}

///|
fn contract_cmap_value(
  pairs : Array[(String, String)],
  key : Array[Int],
) -> String? {
  let key = @pdfio.string_of_int_array(key)
  for pair in pairs {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
test "replacement contract: compact ToUnicode CMap essentials" {
  let cmap = contract_cmap_stream(
    "begincodespacerange<00><ff><0000><ffff>endcodespacerange\n" +
    "beginbfchar<41><0041><0001><D83DDE00>endbfchar\n" +
    "beginbfrange<42><43><0042><50><51><0>endbfrange\n",
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.code_space_lengths.length(), 2)
  assert_true(parsed.code_space_lengths.contains(1))
  assert_true(parsed.code_space_lengths.contains(2))
  assert_true(
    contract_cmap_value(parsed.map, [0x41]) ==
    Some(@pdfio.string_of_int_array([0x00, 0x41])),
  )
  assert_true(
    contract_cmap_value(parsed.map, [0x42]) ==
    Some(@pdfio.string_of_int_array([0x00, 0x42])),
  )
  assert_true(
    contract_cmap_value(parsed.map, [0x43]) ==
    Some(@pdfio.string_of_int_array([0x00, 0x43])),
  )
  assert_true(
    contract_cmap_value(parsed.map, [0x00, 0x01]) ==
    Some(@pdfio.string_of_int_array([0xd8, 0x3d, 0xde, 0x00])),
  )
  assert_true(contract_cmap_value(parsed.map, [0x50]) is None)
}
