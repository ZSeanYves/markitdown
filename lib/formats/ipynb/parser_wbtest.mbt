///|
fn ipynb_wbtest_complex_notebook() -> String {
  (
    #|{
    #|  "nbformat": 4,
    #|  "nbformat_minor": 5,
    #|  "metadata": {
    #|    "kernelspec": {"name": "python3", "display_name": "Python 3"},
    #|    "language_info": {"name": "python", "version": "3.11"}
    #|  },
    #|  "cells": [
    #|    {"cell_type":"markdown","id":"m1","attachments":{"dot.png":{"image/png":"aGVsbG8="}},"source":["# Title\n","![dot](attachment:dot.png)\n"]},
    #|    {"cell_type":"code","id":"c1","execution_count":3,"source":"print(1)\n","outputs":[
    #|      {"output_type":"stream","name":"stdout","text":["1","\n"]},
    #|      {"output_type":"display_data","data":{"text/html":"<b>bold</b>","application/json":{"ok":true},"image/png":"aGVsbG8="}},
    #|      {"output_type":"execute_result","execution_count":3,"data":{"text/plain":"result"}},
    #|      {"output_type":"error","ename":"ValueError","evalue":"bad","traceback":["Traceback","ValueError: bad"]}
    #|    ]},
    #|    {"cell_type":"raw","id":"r1","source":"raw body"}
    #|  ]
    #|}
  )
}

///|
test "IPYNB parser lowers markdown code rich outputs errors and attachments" {
  let text = ipynb_wbtest_complex_notebook()
  let source = @input.input_from_text_with_format(
    text,
    "complex.ipynb",
    Some(Ipynb),
  )
  let result = (ipynb_parser().parse)(source, @parser.new_parse_context(Ipynb)).unwrap()
  assert_true(result.document.unwrap().blocks.length() >= 3)
  assert_true(result.assets.length() >= 1)
  assert_true(result.diagnostics.metrics.get("cell_count") == Some("3"))
  assert_true(result.diagnostics.metrics.get("output_count") == Some("4"))
  assert_true(result.diagnostics.metrics.get("attachment_count") == Some("1"))
  assert_true(result.diagnostics.metrics.get("error_output_count") == Some("1"))
  assert_true(result.diagnostics.pass_trace.contains("parse:ipynb_parser"))
}

///|
test "IPYNB parser reuses lowering for block streaming route" {
  let text = ipynb_wbtest_complex_notebook()
  let source = @input.input_from_text_with_format(
    text,
    "stream.ipynb",
    Some(Ipynb),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Ipynb),
    Some(BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let result = (ipynb_parser().parse)(source, context).unwrap()
  assert_true(result.block_stream.unwrap().length() >= 3)
  assert_true(
    result.diagnostics.metrics.get("effective_mode") == Some("block_streaming"),
  )
  assert_true(
    result.diagnostics.metrics.get("probe_artifact_reused") == Some("true"),
  )
}

///|
test "IPYNB malformed notebook produces raw fenced fallback" {
  let source = @input.input_from_text_with_format(
    "{\"nbformat\":4,\"cells\":\"oops\"}",
    "broken.ipynb",
    Some(Ipynb),
  )
  let result = (ipynb_parser().parse)(source, @parser.new_parse_context(Ipynb)).unwrap()
  assert_true(result.document.unwrap().blocks.length() == 1)
  assert_true(
    result.diagnostics.degraded_features.contains("ipynb_raw_fenced_fallback"),
  )
  assert_true(result.diagnostics.metrics.get("syntax_error_count") == Some("1"))
  assert_true(ipynb_parser_capability().supports_document_ir)
}

///|
test "IPYNB extended display messages resolve to final visible output" {
  let text =
    #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[
    #|{"cell_type":"code","source":"run()","metadata":{},"execution_count":1,"outputs":[
    #|{"output_type":"display_data","data":{"text/plain":"old"},"transient":{"display_id":"one"}},
    #|{"output_type":"update_display_data","data":{"text/plain":"updated"},"transient":{"display_id":"one"}},
    #|{"output_type":"clear_output","wait":false},
    #|{"output_type":"display_data","data":{"text/plain":"final"},"transient":{"display_id":"two"}}
    #|]}]}
  let source = @input.input_from_text_with_format(
    text,
    "display.ipynb",
    Some(Ipynb),
  )
  let result = (ipynb_parser().parse)(source, @parser.new_parse_context(Ipynb)).unwrap()
  let blocks = result.document.unwrap().blocks
  assert_true(blocks.any(block => block.text.contains("final")))
  assert_true(!blocks.any(block => block.text.contains("old")))
  assert_true(!blocks.any(block => block.text.contains("updated")))
}

///|
test "IPYNB compact large markdown cell preserves visible label source and attachments" {
  let notebook = @dipynb.parse_ipynb_notebook(ipynb_wbtest_complex_notebook())
  let cell = notebook.cells[0]
  let source = @input.input_from_text_with_format(
    ipynb_wbtest_complex_notebook(),
    "large.ipynb",
    Some(Ipynb),
  )
  let block = lower_ipynb_large_markdown_cell(cell, source)
  assert_true(block.text.has_prefix("[Cell 1 | markdown]\n\n# Title"))
  assert_true(
    block.text.contains(ipynb_attachment_asset_path(cell, cell.attachments[0])),
  )
  assert_true(block.attrs.get("raw_kind") == Some("markdown_literal"))
  let source_ref = block.source_ref.unwrap()
  assert_true(source_ref.json_pointer == Some("/cells/0/source"))
  assert_true(
    source_ref.extra.get("ipynb_cell_label_json_pointer") == Some("/cells/0"),
  )
  assert_true(source_ref.extra.get("ipynb_compact_cell") == Some("true"))
  assert_eq(
    ipynb_cell_label_text(notebook.cells[1]),
    "[Cell 2 | code | execution=3]",
  )
}
