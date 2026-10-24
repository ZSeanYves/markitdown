///|
// ZIP entry names are ASCII because
// the existing ZIP fixture writer only byte-casts names. XML content uses real
// UTF8 bytes; Unicode path-name coverage requires a separate correct fixture.
async fn container_contract_open(
  container : String,
  opf_paths : Array[String],
) -> EpubPackage raise EpubError {
  let opf = "<package xmlns='http://www.idpf.org/2007/opf' version='3.0'>" +
    "<metadata><title>Container contract</title></metadata>" +
    "<manifest><item id='c' href='chapter.xhtml' media-type='application/xhtml+xml'/></manifest>" +
    "<spine><itemref idref='c'/></spine></package>"
  let entries = [
    ("mimetype", @utf8.encode("application/epub+zip")),
    ("META-INF/container.xml", @utf8.encode(container)),
    (
      "OPS/chapter.xhtml",
      @utf8.encode("<html><body><p>rootfile-selected-content</p></body></html>"),
    ),
  ]
  for path in opf_paths {
    entries.push((path, @utf8.encode(opf)))
  }
  open_epub_package(
    @zip.build_store_zip_bytes(entries),
    "container-contract.epub",
  )
}

///|
fn container_contract_xml(body : String) -> String {
  "<container xmlns='urn:oasis:names:tc:opendocument:xmlns:container'><rootfiles>" +
  body +
  "</rootfiles></container>"
}

///|
async fn container_contract_paths(
  xml : String,
  entries : Array[String],
  expected : Array[String],
  primary : String,
) -> Unit {
  let pkg = container_contract_open(xml, entries)
  assert_eq(pkg.rootfiles.map(item => item.full_path), expected)
  assert_eq(pkg.rootfile_path, primary)
  assert_eq(pkg.rootfiles.filter(item => item.is_primary).length(), 1)
  let chosen = get_epub_primary_rootfile(pkg)
  assert_eq(chosen.normalized_path, Some(primary))
  assert_true(chosen.exists && chosen.usable)
}

///|
async fn container_contract_invalid(
  xml : String,
  paths : Array[String],
) -> Unit {
  let result = Ok(container_contract_open(xml, paths)) catch {
    error => Err(error)
  }
  match result {
    Err(InvalidXml(_)) => ()
    Err(error) =>
      fail("expected controlled InvalidXml, got " + error.to_string())
    Ok(_) => fail("invalid container must not publish an EPUB package")
  }
}

///|
async test "container contract quoted greater-than stays inside full-path" {
  container_contract_paths(
    container_contract_xml(
      "<rootfile full-path='OPS/a>b.opf' media-type='application/oebps-package+xml'/>",
    ),
    ["OPS/a>b.opf"],
    ["OPS/a>b.opf"],
    "OPS/a>b.opf",
  )
}

///|
async test "container contract quoted greater-than in preceding attribute does not truncate rootfile" {
  container_contract_paths(
    container_contract_xml("<rootfile note='x>y' full-path='OPS/content.opf'/>"),
    ["OPS/content.opf"],
    ["OPS/content.opf"],
    "OPS/content.opf",
  )
}

///|
async test "container contract comments cannot inject rootfile candidates" {
  container_contract_paths(
    container_contract_xml(
      "<!-- <rootfile full-path='OPS/poison.opf'/> --><rootfile full-path='OPS/content.opf'/>",
    ),
    ["OPS/poison.opf", "OPS/content.opf"],
    ["OPS/content.opf"],
    "OPS/content.opf",
  )
}

///|
async test "container contract bound prefix preserves standard container semantics" {
  container_contract_paths(
    "<c:container xmlns:c='urn:oasis:names:tc:opendocument:xmlns:container'><c:rootfiles><c:rootfile full-path='OPS/content.opf'/></c:rootfiles></c:container>",
    ["OPS/content.opf"],
    ["OPS/content.opf"],
    "OPS/content.opf",
  )
}

///|
async test "container contract foreign namespace rootfile is not an OCF candidate" {
  container_contract_paths(
    container_contract_xml(
      "<f:rootfile xmlns:f='urn:foreign' full-path='OPS/poison.opf'/><rootfile full-path='OPS/content.opf'/>",
    ),
    ["OPS/poison.opf", "OPS/content.opf"],
    ["OPS/content.opf"],
    "OPS/content.opf",
  )
}

///|
async test "container contract self-closing namespace rebinding restores the parent binding" {
  container_contract_paths(
    "<c:container xmlns:c='urn:oasis:names:tc:opendocument:xmlns:container'><c:rootfiles>" +
    "<c:rootfile xmlns:c='urn:foreign' full-path='OPS/poison.opf'/><c:rootfile full-path='OPS/content.opf'/>" +
    "</c:rootfiles></c:container>",
    ["OPS/poison.opf", "OPS/content.opf"],
    ["OPS/content.opf"],
    "OPS/content.opf",
  )
}

///|
async test "container contract rejects an unbound rootfile prefix" {
  container_contract_invalid(
    container_contract_xml("<u:rootfile full-path='OPS/content.opf'/>"),
    ["OPS/content.opf"],
  )
}

///|
async test "container contract decimal and hexadecimal entities decode once before path lookup" {
  for reference in ["OPS/content&#46;opf", "OPS/content&#x2e;opf"] {
    let pkg = container_contract_open(
      container_contract_xml(
        "<rootfile full-path='" +
        reference +
        "' media-type='application/oebps-package&#43;xml'/>",
      ),
      ["OPS/content.opf"],
    )
    assert_eq(pkg.rootfile_path, "OPS/content.opf")
    assert_eq(pkg.rootfiles[0].full_path, "OPS/content.opf")
    assert_eq(
      pkg.rootfiles[0].media_type,
      Some("application/oebps-package+xml"),
    )
  }
}

///|
async test "container contract numeric ampersand does not recursively decode the resulting named entity text" {
  container_contract_paths(
    container_contract_xml("<rootfile full-path='OPS/a&#38;gt;b.opf'/>"),
    ["OPS/a&gt;b.opf", "OPS/a>b.opf"],
    ["OPS/a&gt;b.opf"],
    "OPS/a&gt;b.opf",
  )
}

///|
async test "container contract non-BMP ignored attribute and prefix text preserve UTF16 slicing boundaries" {
  container_contract_paths(
    container_contract_xml(
      "<!-- 😀 --><rootfile note='😀' full-path='OPS/content.opf'/>",
    ),
    ["OPS/content.opf"],
    ["OPS/content.opf"],
    "OPS/content.opf",
  )
}

///|
async test "container contract BOM and CRLF retain first usable order and duplicate primary rule" {
  container_contract_paths(
    "\u{FEFF}" +
    container_contract_xml(
      "\r\n<rootfile full-path='OPS/missing.opf'/>\r\n<rootfile full-path='OPS/content.opf'/>\r\n<rootfile full-path='OPS/content.opf'/>",
    ) +
    "\r\n",
    ["OPS/content.opf"],
    ["OPS/missing.opf", "OPS/content.opf", "OPS/content.opf"],
    "OPS/content.opf",
  )
}

///|
async test "container contract no-namespace legacy container and blank rootfile remain supported" {
  container_contract_paths(
    "<container><rootfiles><rootfile full-path=' '/><rootfile full-path='OPS/content.opf'/></rootfiles></container>",
    ["OPS/content.opf"],
    ["OPS/content.opf"],
    "OPS/content.opf",
  )
}

///|
async test "container contract validates the complete tail before publishing rootfiles" {
  container_contract_invalid(
    "<container><rootfiles><rootfile full-path='OPS/content.opf'/></rootfiles></container><broken>",
    ["OPS/content.opf"],
  )
}

///|
async test "container contract duplicate full-path attributes are controlled InvalidXml" {
  container_contract_invalid(
    container_contract_xml(
      "<rootfile full-path='OPS/one.opf' full-path='OPS/two.opf'/>",
    ),
    ["OPS/one.opf", "OPS/two.opf"],
  )
}

///|
async test "container contract doctype external identifier is ignored without fetching" {
  container_contract_paths(
    "<!DOCTYPE container SYSTEM 'https://invalid.example/never-loaded.dtd'>" +
    container_contract_xml("<rootfile full-path='OPS/content.opf'/>"),
    ["OPS/content.opf"],
    ["OPS/content.opf"],
    "OPS/content.opf",
  )
}

///|
async test "container contract entity decoding does not permit parent traversal" {
  container_contract_invalid(
    container_contract_xml("<rootfile full-path='&#46;&#46;/secret.opf'/>"),
    ["OPS/content.opf"],
  )
}

///|
async test "container contract rejects rootfile outside direct rootfiles hierarchy" {
  for
    xml in [
      "<container><rootfile full-path='OPS/content.opf'/></container>", "<container><rootfiles><wrapper><rootfile full-path='OPS/content.opf'/></wrapper></rootfiles></container>",
      "<wrong><rootfiles><rootfile full-path='OPS/content.opf'/></rootfiles></wrong>",
    ] {
    container_contract_invalid(xml, ["OPS/content.opf"])
  }
}

///|
async test "container contract foreign root namespace cannot masquerade as OCF" {
  container_contract_invalid(
    "<container xmlns='urn:foreign'><rootfiles><rootfile full-path='OPS/content.opf'/></rootfiles></container>",
    ["OPS/content.opf"],
  )
}

///|
async test "container contract only unqualified attributes select the rootfile" {
  container_contract_paths(
    container_contract_xml(
      "<rootfile xmlns:f='urn:foreign' f:full-path='OPS/poison.opf' full-path='OPS/content.opf'/>",
    ),
    ["OPS/poison.opf", "OPS/content.opf"],
    ["OPS/content.opf"],
    "OPS/content.opf",
  )
}
