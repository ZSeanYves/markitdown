///|
test "IPYNB parser lowers every supported MIME payload independently" {
  let notebook =
    #|{
    #| "nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[
    #| {"cell_type":"code","source":"x","outputs":[
    #|  {"output_type":"display_data","data":{"image/jpeg":"aGVsbG8="}},
    #|  {"output_type":"display_data","data":{"image/gif":"aGVsbG8="}},
    #|  {"output_type":"display_data","data":{"image/svg+xml":"<svg></svg>"}},
    #|  {"output_type":"display_data","data":{"text/markdown":"**bold**"}},
    #|  {"output_type":"display_data","data":{"text/latex":"x^2"}},
    #|  {"output_type":"display_data","data":{"application/json":{"ok":true}}},
    #|  {"output_type":"display_data","data":{"application/problem+json":{"type":"test"}}},
    #|  {"output_type":"display_data","data":{"application/octet-stream":"YWJj"}},
    #|  {"output_type":"display_data","data":{"text/plain":"plain"}}
    #| ]}
    #| ]}
  let result = (ipynb_parser().parse)(
    @input.input_from_text_with_format(
      notebook,
      "mime-matrix.ipynb",
      Some(Ipynb),
    ),
    @parser.new_parse_context(Ipynb),
  ).unwrap()
  let document = result.document.unwrap()
  assert_true(document.blocks.length() >= 9)
  assert_true(document.assets.length() >= 3)
  assert_true(
    document.assets.any(asset => asset.path.unwrap_or("").has_suffix(".jpg")),
  )
  assert_true(
    document.assets.any(asset => asset.path.unwrap_or("").has_suffix(".gif")),
  )
  assert_true(
    document.assets.any(asset => asset.path.unwrap_or("").has_suffix(".svg")),
  )
  assert_true(result.diagnostics.metrics.get("output_count") == Some("9"))
}
