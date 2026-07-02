///|
test "ipynb reader normalizes string array fields and attachments" {
  let notebook = @ipynb.parse_ipynb_notebook(
    "{\n" +
    "  \"nbformat\": 4,\n" +
    "  \"nbformat_minor\": 5,\n" +
    "  \"metadata\": {\n" +
    "    \"kernelspec\": {\"name\": \"python3\", \"display_name\": \"Python 3\"},\n" +
    "    \"language_info\": {\"name\": \"python\", \"version\": \"3.11\"}\n" +
    "  },\n" +
    "  \"cells\": [\n" +
    "    {\n" +
    "      \"cell_type\": \"markdown\",\n" +
    "      \"id\": \"m1\",\n" +
    "      \"attachments\": {\n" +
    "        \"dot.png\": {\n" +
    "          \"image/png\": \"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0MsAAAAASUVORK5CYII=\"\n" +
    "        }\n" +
    "      },\n" +
    "      \"source\": [\"# Title\\n\", \"body\\n\"]\n" +
    "    },\n" +
    "    {\n" +
    "      \"cell_type\": \"code\",\n" +
    "      \"id\": \"c1\",\n" +
    "      \"execution_count\": 3,\n" +
    "      \"source\": \"print(1)\\n\",\n" +
    "      \"outputs\": [\n" +
    "        {\n" +
    "          \"output_type\": \"stream\",\n" +
    "          \"name\": \"stdout\",\n" +
    "          \"text\": [\"1\", \"\\\\n\"]\n" +
    "        },\n" +
    "        {\n" +
    "          \"output_type\": \"display_data\",\n" +
    "          \"data\": {\n" +
    "            \"application/json\": {\"ok\": true}\n" +
    "          }\n" +
    "        }\n" +
    "      ]\n" +
    "    }\n" +
    "  ]\n" +
    "}\n",
  )
  let report = @ipynb.inspect_ipynb_notebook(notebook)
  assert_eq(notebook.summary.nbformat.unwrap_or(0), 4)
  assert_eq(notebook.summary.language_name.unwrap_or(""), "python")
  assert_eq(notebook.cells.length(), 2)
  assert_eq(notebook.cells[0].source, "# Title\nbody\n")
  assert_eq(notebook.cells[0].attachments.length(), 1)
  assert_eq(notebook.cells[1].outputs.length(), 2)
  assert_eq(notebook.cells[1].outputs[0].text.unwrap_or(""), "1\\n")
  assert_true(
    notebook.cells[1].outputs[1].mime_entries[0].raw_json_text is Some(_),
  )
  assert_eq(report.attachment_count, 1)
  assert_eq(report.output_count, 2)
  assert_eq(report.stream_output_count, 1)
  assert_eq(report.display_data_count, 1)
}

///|
test "ipynb reader rejects malformed notebooks and classifies errors" {
  assert_true(
    (try
      @ipynb.parse_ipynb_notebook("{\"nbformat\":4,\"cells\":\"oops\"}") |> Ok
    catch {
      e => Err(e)
    })
    is Err(_),
  )
  let classified = @ipynb.classify_ipynb_error(
    @ipynb.IpynbError::ParseError("top-level cells must be an array"),
  )
  assert_true(classified.contains("top-level cells must be an array"))
}
