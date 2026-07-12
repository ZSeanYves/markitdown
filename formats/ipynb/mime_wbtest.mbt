///|
fn ipynb_mime_wbtest_entries() -> Array[@dipynb.IpynbMimeEntry] raise {
  let json =
    #|{"nbformat":4,"cells":[{"cell_type":"code","source":"","outputs":[{"output_type":"display_data","data":{"image/png":"cG5n\n","image/jpeg":"anBn","image/gif":"Z2lm","image/svg+xml":"<svg/>","text/markdown":"**md**","text/html":"<b>html</b>","text/latex":"x^2","text/plain":"plain","application/json":{"ok":true},"application/vnd.test+json":{"n":1},"application/octet-stream":"Ymlu"}}]}]}
  let notebook = @dipynb.parse_ipynb_notebook(json)
  notebook.cells[0].outputs[0].mime_entries
}

///|
fn ipynb_mime_wbtest_find(
  entries : Array[@dipynb.IpynbMimeEntry],
  mime_type : String,
) -> @dipynb.IpynbMimeEntry {
  for entry in entries {
    if entry.mime_type == mime_type {
      return entry
    }
  }
  panic()
}

///|
test "IPYNB MIME helpers classify extensions labels and kind names" {
  let entries = ipynb_mime_wbtest_entries()
  for
    pair in [
      ("image/png", ".png"),
      ("image/jpeg", ".jpg"),
      ("image/gif", ".gif"),
      ("image/svg+xml", ".svg"),
      ("application/json", ".json"),
      ("application/vnd.test+json", ".json"),
      ("text/plain", ".txt"),
      ("text/markdown", ".md"),
      ("text/html", ".html"),
      ("text/latex", ".tex"),
      ("application/octet-stream", ".bin"),
    ] {
    let mime_type = pair.0
    let ext = pair.1
    assert_eq(
      ipynb_asset_ext_for_entry(ipynb_mime_wbtest_find(entries, mime_type)),
      ext,
    )
  }
  for mime_type in ["image/png", "image/jpeg", "image/gif", "image/svg+xml"] {
    assert_true(ipynb_mime_is_image(mime_type))
  }
  assert_true(!ipynb_mime_is_image("image/webp"))
  assert_eq(ipynb_mime_ext("image/webp"), ".bin")
  assert_eq(ipynb_info_from_mime("text/html"), "html")
  assert_eq(ipynb_info_from_mime("text/latex"), "latex")
  assert_eq(ipynb_info_from_mime("application/json"), "json")
  assert_eq(ipynb_info_from_mime("application/vnd.test+json"), "json")
  assert_eq(ipynb_info_from_mime("text/plain"), "text")
  assert_eq(ipynb_cell_kind_name(@dipynb.IpynbCellKind::Markdown), "markdown")
  assert_eq(ipynb_cell_kind_name(@dipynb.IpynbCellKind::Code), "code")
  assert_eq(ipynb_cell_kind_name(@dipynb.IpynbCellKind::Raw), "raw")
  assert_eq(ipynb_cell_kind_name(@dipynb.IpynbCellKind::Unknown), "unknown")
  assert_eq(ipynb_output_kind_name(@dipynb.IpynbOutputKind::Stream), "stream")
  assert_eq(
    ipynb_output_kind_name(@dipynb.IpynbOutputKind::DisplayData),
    "display_data",
  )
  assert_eq(
    ipynb_output_kind_name(@dipynb.IpynbOutputKind::ExecuteResult),
    "execute_result",
  )
  assert_eq(ipynb_output_kind_name(@dipynb.IpynbOutputKind::Error), "error")
  assert_eq(ipynb_output_kind_name(@dipynb.IpynbOutputKind::Unknown), "unknown")
}

///|
test "IPYNB MIME helpers select preferred entries and normalize payloads" {
  let entries = ipynb_mime_wbtest_entries()
  assert_eq(ipynb_preferred_mime_label(entries), "image/png")
  assert_eq(ipynb_preferred_mime_label([]), "none")
  assert_eq(
    ipynb_preferred_mime_label([
      ipynb_mime_wbtest_find(entries, "text/plain"),
      ipynb_mime_wbtest_find(entries, "application/vnd.test+json"),
    ]),
    "application/vnd.test+json",
  )
  assert_eq(
    ipynb_preferred_mime_label([
      ipynb_mime_wbtest_find(entries, "text/latex"),
      ipynb_mime_wbtest_find(entries, "text/plain"),
    ]),
    "text/plain",
  )
  assert_eq(
    ipynb_preferred_mime_label([
      ipynb_mime_wbtest_find(entries, "application/octet-stream"),
    ]),
    "application/octet-stream",
  )
  assert_true(
    ipynb_inline_payload(ipynb_mime_wbtest_find(entries, "image/png")) ==
    Some(("base64", "cG5n")),
  )
  assert_true(
    ipynb_inline_payload(ipynb_mime_wbtest_find(entries, "image/svg+xml")) ==
    Some(("utf8", "<svg/>")),
  )
  assert_true(
    ipynb_inline_payload(ipynb_mime_wbtest_find(entries, "application/json"))
    is Some(_),
  )
  assert_true(
    ipynb_inline_payload(ipynb_mime_wbtest_find(entries, "text/plain")) ==
    Some(("utf8", "plain")),
  )
  assert_true(
    ipynb_inline_payload(
      ipynb_mime_wbtest_find(entries, "application/octet-stream"),
    ) ==
    Some(("base64", "Ymlu")),
  )
  let asset = @core.make_asset_ref(@core.AssetKind::Embedded, "entry.bin")
  ipynb_attach_inline_payload(
    asset,
    ipynb_mime_wbtest_find(entries, "application/octet-stream"),
  )
  assert_true(asset.attrs.get("inline_payload_kind") == Some("base64"))
  assert_true(asset.attrs.get("inline_payload") == Some("Ymlu"))
}
