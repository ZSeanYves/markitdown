///|
async test "EPUB optional navigation preserves typed encoding errors and syntax recovery" {
  for
    (navigation, invalid) in [
      (b"<html><body>\xFF</body></html>", true),
      (b"<html><body>", false),
    ] {
    let raw = @zip.build_store_zip_bytes([
      ("mimetype", b"application/epub+zip"),
      (
        "META-INF/container.xml",
        @utf8.encode(
          wb_minimal_container([
            ("OPS/book.opf", Some("application/oebps-package+xml")),
          ]),
        ),
      ),
      (
        "OPS/book.opf",
        @utf8.encode(
          wb_minimal_opf(
            [
              ("nav", "nav.xhtml", "application/xhtml+xml", Some("nav")),
              ("chapter", "chapter.xhtml", "application/xhtml+xml", None),
            ],
            [("chapter", None)],
          ),
        ),
      ),
      ("OPS/nav.xhtml", navigation),
      ("OPS/chapter.xhtml", b"<html><body>valid</body></html>"),
    ])
    let result = try open_epub_package(raw, "optional.epub") |> Ok catch {
      error => Err(error)
    }
    if invalid {
      match result {
        Err(InvalidEncoding(_)) => ()
        _ =>
          fail("navigation recovery must preserve the typed encoding failure")
      }
    } else {
      assert_true(result is Ok(_))
    }
  }
}
