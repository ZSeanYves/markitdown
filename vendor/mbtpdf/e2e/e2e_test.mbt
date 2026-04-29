///|
const OUTPUT_DIR : String = "tmp/e2e"

///|
const MERGE_LEFT_PATH : String = "testdata/e2e/merge_dummy.pdf"

///|
const MERGE_RIGHT_PATH : String = "testdata/pdfjs_identity_tounicode.pdf"

///|
const MERGE_THIRD_PATH : String = "testdata/e2e/pdfjs_tracemonkey.pdf"

///|
const LARGE_PATH : String = "testdata/SFAA_Japanese.pdf"

///|
const BOOKMARK_PATH : String = "testdata/SFAA_Japanese.pdf"

///|
async fn assert_fixture(path : String) -> Unit {
  if !@fs.exists(path) {
    fail("missing fixture: " + path)
  }
}

///|
async fn ensure_dir(path : String) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path, permission=0o755, recursive=true)
  }
}

///|
async fn read_pdf(path : String) -> @pdf.Pdf {
  assert_fixture(path)
  @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, path)
}

///|
async fn write_pdf(path : String, pdf : @pdf.Pdf) -> Unit {
  @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, path)
}

///|
fn page_count(pdf : @pdf.Pdf) -> Int raise {
  @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree_quick()
}

///|
fn full_range(count : Int) -> Array[Int] {
  let out = Array::new(capacity=count)
  for i in 1..<=count {
    out.push(i)
  }
  out
}

///|
fn assert_merged_label_prefixes(
  labels : Array[@pdfpagelabels.PageLabel],
  left_count : Int,
) -> Unit raise {
  let mut found_left = false
  let mut found_right = false
  for label in labels {
    match label.labelprefix {
      Some("L-") => {
        found_left = true
        assert_eq(label.startpage, 1)
      }
      Some("R-") => {
        found_right = true
        assert_eq(label.startpage, left_count + 1)
      }
      _ => ()
    }
  }
  let rendered = labels.map(label => label.to_string()).join(", ")
  if !found_left {
    fail("missing L- label: " + rendered)
  }
  if !found_right {
    fail("missing R- label: " + rendered)
  }
}

///|
fn add_named_destination(
  pdf : @pdf.Pdf,
  name : String,
  page_obj : Int,
) -> Unit raise {
  let dest = @pdfdest.Destination::Fit(
    @pdfdest.TargetPage::PageObject(page_obj),
  )
  let tree_builder = @pdftree.PdfTree::new(pdf)
  let tree = tree_builder.build_name_tree(false, [(name, dest.to_pdf_object())])
  let tree_num = pdf.addobj(tree)
  let rootnum = pdf.root
  let root = pdf.lookup_obj(rootnum)
  let names : @pdf.PdfObject = match pdf.lookup_direct("/Names", root) {
    Some(obj) => obj
    None => Dictionary([])
  }
  let names = names.add_entry("/Dests", Indirect(tree_num))
  let updated_root = root.add_entry("/Names", names)
  pdf.addobj_given_num((rootnum, updated_root))
  pdf.trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(rootnum))
}

///|
fn add_dests_dictionary(
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
) -> Unit raise {
  set_catalog_entry(pdf, "/Dests", Dictionary(entries))
}

///|
fn set_catalog_entry(
  pdf : @pdf.Pdf,
  key : String,
  value : @pdf.PdfObject,
) -> Unit raise {
  let rootnum = pdf.root
  let root = pdf.lookup_obj(rootnum)
  let updated_root = root.add_entry(key, value)
  pdf.addobj_given_num((rootnum, updated_root))
  pdf.trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(rootnum))
}

///|
fn add_names_tree(
  pdf : @pdf.Pdf,
  key : String,
  entries : Array[(String, @pdf.PdfObject)],
) -> Unit raise {
  let tree = @pdftree.PdfTree::new(pdf).build_name_tree(false, entries)
  let tree_num = pdf.addobj(tree)
  let rootnum = pdf.root
  let root = pdf.lookup_obj(rootnum)
  let names : @pdf.PdfObject = match pdf.lookup_direct("/Names", root) {
    Some(obj) => obj
    None => Dictionary([])
  }
  let names = names.add_entry(key, Indirect(tree_num))
  let updated_root = root.add_entry("/Names", names)
  pdf.addobj_given_num((rootnum, updated_root))
  pdf.trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(rootnum))
}

///|
fn add_embedded_file(
  pdf : @pdf.Pdf,
  entry_name : String,
  filename : String,
  payload : String,
) -> Unit raise {
  let bytes = @pdfio.bytes_of_string(payload)
  let stream_dict : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/EmbeddedFile"))),
    ("/Length", Integer(@pdfio.bytes_size(bytes))),
  ])
  let stream_obj : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(bytes))),
  )
  let stream_num = pdf.addobj(stream_obj)
  let filespec : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Filespec"))),
    ("/F", String(filename)),
    ("/UF", String(filename)),
    ("/EF", Dictionary([("/F", Indirect(stream_num))])),
  ])
  add_names_tree(pdf, "/EmbeddedFiles", [(entry_name, filespec)])
}

///|
fn make_ap_stream(payload : String) -> @pdf.PdfObject {
  let bytes = @pdfio.bytes_of_string(payload)
  let dict : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/XObject"))),
    ("/Subtype", Name(@pdf.PdfName::of_string("/Form"))),
    ("/BBox", Array([Integer(0), Integer(0), Integer(10), Integer(10)])),
    ("/Resources", Dictionary([])),
    ("/Length", Integer(@pdfio.bytes_size(bytes))),
  ])
  Stream(Ref::new((dict, @pdf.Stream::Got(bytes))))
}

///|
fn make_ap_entry(
  pdf : @pdf.Pdf,
  name : String,
  payload : String,
) -> (String, @pdf.PdfObject) {
  let stream_obj = make_ap_stream(payload)
  let objnum = pdf.addobj(stream_obj)
  (name, Indirect(objnum))
}

///|
fn make_rendition_dict(name : String, tag : String) -> @pdf.PdfObject {
  Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/MR"))),
    ("/N", String(name)),
    ("/T", String(tag)),
  ])
}

///|
fn make_alt_presentation_dict(name : String, tag : String) -> @pdf.PdfObject {
  Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/AlternatePresentations"))),
    ("/Title", String(name)),
    ("/T", String(tag)),
  ])
}

///|
fn make_bulk_named_dest_entries(
  pdf : @pdf.Pdf,
  prefix : String,
  count : Int,
) -> Array[(String, @pdf.PdfObject)] raise {
  let page_obj = match @pdfpage.PdfPageDoc::new(pdf).page_object_number(1) {
    Some(objnum) => objnum
    None => fail("missing page 1")
  }
  let entries = Array::new(capacity=count)
  for i in 0..<count {
    let name = prefix + i.to_string()
    let dest = @pdfdest.Destination::Fit(
      @pdfdest.TargetPage::PageObject(page_obj),
    )
    entries.push((name, dest.to_pdf_object()))
  }
  entries
}

///|
fn make_bulk_url_entries(
  prefix : String,
  count : Int,
) -> Array[(String, @pdf.PdfObject)] {
  let entries = Array::new(capacity=count)
  for i in 0..<count {
    let name = prefix + i.to_string()
    let uri = "https://example.com/" + prefix + i.to_string()
    entries.push((name, make_url_action(uri)))
  }
  entries
}

///|
fn make_url_action(uri : String) -> @pdf.PdfObject {
  Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/URI"))),
    ("/URI", String(uri)),
  ])
}

///|
fn add_ocg_properties(pdf : @pdf.Pdf, ocg_name : String) -> Unit raise {
  let ocg : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/OCG"))),
    ("/Name", String(ocg_name)),
  ])
  let ocg_num = pdf.addobj(ocg)
  let default_dict : @pdf.PdfObject = Dictionary([
    ("/BaseState", Name(@pdf.PdfName::of_string("/ON"))),
    ("/Intent", Name(@pdf.PdfName::of_string("/View"))),
    ("/Name", String("Default")),
    ("/ON", Array([Indirect(ocg_num)])),
  ])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", Array([Indirect(ocg_num)])),
    ("/D", default_dict),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
}

///|
fn add_ocg_properties_with_config(
  pdf : @pdf.Pdf,
  ocg_name : String,
  config_name : String,
) -> Unit raise {
  let ocg : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/OCG"))),
    ("/Name", String(ocg_name)),
  ])
  let ocg_num = pdf.addobj(ocg)
  let default_dict : @pdf.PdfObject = Dictionary([
    ("/BaseState", Name(@pdf.PdfName::of_string("/ON"))),
    ("/Intent", Name(@pdf.PdfName::of_string("/View"))),
    ("/Name", String("Default")),
    ("/ON", Array([Indirect(ocg_num)])),
  ])
  let config_dict : @pdf.PdfObject = Dictionary([
    ("/Name", String(config_name)),
    ("/BaseState", Name(@pdf.PdfName::of_string("/OFF"))),
    ("/Intent", Name(@pdf.PdfName::of_string("/View"))),
    ("/ON", Array([Indirect(ocg_num)])),
  ])
  let ocprops : @pdf.PdfObject = Dictionary([
    ("/OCGs", Array([Indirect(ocg_num)])),
    ("/D", default_dict),
    ("/Configs", Array([config_dict])),
  ])
  let ocprops_num = pdf.addobj(ocprops)
  set_catalog_entry(pdf, "/OCProperties", Indirect(ocprops_num))
}

///|
fn read_ocg_names(pdf : @pdf.Pdf) -> Array[String] raise {
  let catalog = pdf.catalog_of_pdf()
  let ocprops = match pdf.lookup_direct("/OCProperties", catalog) {
    Some(obj) => obj
    None => fail("missing /OCProperties")
  }
  let ocgs = match (pdf.lookup_direct("/OCGs", ocprops) : @pdf.PdfObject?) {
    Some(Array(arr)) => arr
    _ => fail("missing /OCGs array")
  }
  let names = Array::new(capacity=ocgs.length())
  for ocg in ocgs {
    match (pdf.direct(ocg) : @pdf.PdfObject) {
      Dictionary(entries) => {
        let dict : @pdf.PdfObject = Dictionary(entries)
        match (pdf.lookup_direct("/Name", dict) : @pdf.PdfObject?) {
          Some(String(name)) => names.push(name)
          _ => ()
        }
      }
      _ => ()
    }
  }
  names
}

///|
fn read_ocg_config_names(pdf : @pdf.Pdf) -> Array[String] raise {
  let catalog = pdf.catalog_of_pdf()
  let ocprops = match pdf.lookup_direct("/OCProperties", catalog) {
    Some(obj) => obj
    None => fail("missing /OCProperties")
  }
  let configs = match
    (pdf.lookup_direct("/Configs", ocprops) : @pdf.PdfObject?) {
    Some(Array(arr)) => arr
    _ => fail("missing /Configs array")
  }
  let names = Array::new(capacity=configs.length())
  for config in configs {
    let config = pdf.direct(config)
    match (pdf.lookup_direct("/Name", config) : @pdf.PdfObject?) {
      Some(String(name)) => names.push(name)
      _ => fail("missing /Name in /Configs")
    }
  }
  names
}

///|
fn read_ocg_on_count(pdf : @pdf.Pdf) -> Int raise {
  let catalog = pdf.catalog_of_pdf()
  let ocprops = match pdf.lookup_direct("/OCProperties", catalog) {
    Some(obj) => obj
    None => fail("missing /OCProperties")
  }
  let default_dict = match pdf.lookup_direct("/D", ocprops) {
    Some(obj) => obj
    None => fail("missing /D")
  }
  match (pdf.lookup_direct("/ON", default_dict) : @pdf.PdfObject?) {
    Some(Array(arr)) => arr.length()
    _ => 0
  }
}

///|
fn add_struct_tree_root(
  pdf : @pdf.Pdf,
  page_ref : Int,
  parent_key : Int,
) -> Unit raise {
  let struct_elem : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/StructElem"))),
    ("/S", Name(@pdf.PdfName::of_string("/P"))),
    ("/Pg", Indirect(page_ref)),
  ])
  let struct_elem_num = pdf.addobj(struct_elem)
  let parent_tree = @pdftree.PdfTree::new(pdf).build_name_tree(true, [
    (parent_key.to_string(), Indirect(struct_elem_num)),
  ])
  let struct_root : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/StructTreeRoot"))),
    ("/K", Indirect(struct_elem_num)),
    ("/ParentTree", parent_tree),
  ])
  let struct_root_num = pdf.addobj(struct_root)
  set_catalog_entry(pdf, "/StructTreeRoot", Indirect(struct_root_num))
  let page_obj = pdf.lookup_obj(page_ref)
  let updated_page = page_obj.add_entry("/StructParents", Integer(parent_key))
  pdf.addobj_given_num((page_ref, updated_page))
}

///|
fn read_parent_tree_keys(pdf : @pdf.Pdf) -> Array[String] raise {
  let catalog = pdf.catalog_of_pdf()
  let struct_root = match pdf.lookup_direct("/StructTreeRoot", catalog) {
    Some(obj) => obj
    None => fail("missing /StructTreeRoot")
  }
  let parent_tree = match pdf.lookup_direct("/ParentTree", struct_root) {
    Some(obj) => obj
    None => fail("missing /ParentTree")
  }
  @pdftree.PdfTree::new(pdf).read_number_tree(parent_tree).map(pair => pair.0)
}

///|
fn assert_url_action(
  pdf : @pdf.Pdf,
  action_obj : @pdf.PdfObject,
  expected_uri : String,
) -> Unit raise {
  let action = pdf.direct(action_obj)
  match (pdf.lookup_direct("/S", action) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/URI") => ()
    _ => fail("expected /S /URI")
  }
  match (pdf.lookup_direct("/URI", action) : @pdf.PdfObject?) {
    Some(String(uri)) => assert_eq(uri, expected_uri)
    _ => fail("expected /URI string")
  }
}

///|
fn assert_ap_stream(
  pdf : @pdf.Pdf,
  stream_obj : @pdf.PdfObject,
  expected_payload : String,
) -> Unit raise {
  let stream = pdf.direct(stream_obj)
  match (pdf.lookup_direct("/Type", stream) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/XObject") => ()
    _ => fail("expected /Type /XObject")
  }
  match (pdf.lookup_direct("/Subtype", stream) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/Form") => ()
    _ => fail("expected /Subtype /Form")
  }
  let bytes = stream.bigarray_of_stream()
  let payload = @pdfio.string_of_bytes(bytes)
  assert_eq(payload, expected_payload)
  match (pdf.lookup_direct("/Length", stream) : @pdf.PdfObject?) {
    Some(Integer(length)) => assert_eq(length, @pdfio.bytes_size(bytes))
    _ => fail("expected /Length")
  }
}

///|
fn read_name_tree_entries(
  pdf : @pdf.Pdf,
  key : String,
) -> Array[(String, @pdf.PdfObject)] raise {
  let catalog = pdf.catalog_of_pdf()
  let names = match pdf.lookup_direct("/Names", catalog) {
    Some(obj) => obj
    None => fail("missing /Names dictionary")
  }
  let tree = match pdf.lookup_direct(key, names) {
    Some(obj) => obj
    None => fail("missing name tree: " + key)
  }
  let tree_reader = @pdftree.PdfTree::new(pdf)
  tree_reader.read_name_tree(tree)
}

///|
fn read_named_destination(
  pdf : @pdf.Pdf,
  name : String,
) -> @pdfdest.Destination raise {
  let catalog = pdf.catalog_of_pdf()
  let names = match pdf.lookup_direct("/Names", catalog) {
    Some(obj) => obj
    None => fail("missing /Names dictionary")
  }
  let dests = match pdf.lookup_direct("/Dests", names) {
    Some(obj) => obj
    None => fail("missing /Dests name tree")
  }
  let entries = @pdftree.PdfTree::new(pdf).read_name_tree(dests)
  match entries.search_by(pair => pair.0 == name) {
    Some(idx) => @pdfdest.Destination::read(pdf, entries[idx].1)
    None => fail("missing destination: " + name)
  }
}

///|
fn assert_embedded_file_stream(
  pdf : @pdf.Pdf,
  stream_obj : @pdf.PdfObject,
  expected_payload : String,
) -> Unit raise {
  match (pdf.lookup_direct("/Type", stream_obj) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/EmbeddedFile") => ()
    _ => fail("expected /Type /EmbeddedFile")
  }
  let bytes = stream_obj.bigarray_of_stream()
  let payload = @pdfio.string_of_bytes(bytes)
  assert_eq(payload, expected_payload)
  match (pdf.lookup_direct("/Length", stream_obj) : @pdf.PdfObject?) {
    Some(Integer(length)) => assert_eq(length, @pdfio.bytes_size(bytes))
    _ => fail("expected /Length")
  }
}

///|
fn assert_embedded_file_spec(
  pdf : @pdf.Pdf,
  filespec_obj : @pdf.PdfObject,
  expected_filename : String,
  expected_payload : String,
) -> Unit raise {
  let spec = pdf.direct(filespec_obj)
  match (pdf.lookup_direct("/Type", spec) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/Filespec") => ()
    _ => fail("expected /Type /Filespec")
  }
  match (pdf.lookup_direct("/F", spec) : @pdf.PdfObject?) {
    Some(String(name)) => assert_eq(name, expected_filename)
    _ => fail("expected /F filename")
  }
  let ef = match pdf.lookup_direct("/EF", spec) {
    Some(obj) => obj
    None => fail("missing /EF dictionary")
  }
  let stream_obj = match pdf.lookup_direct("/F", ef) {
    Some(obj) => obj
    None => fail("missing /EF /F")
  }
  assert_embedded_file_stream(pdf, stream_obj, expected_payload)
}

///|
fn assert_embedded_file_entry(
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
  name : String,
  filename : String,
  payload : String,
) -> Unit raise {
  match entries.search_by(pair => pair.0 == name) {
    Some(idx) =>
      assert_embedded_file_spec(pdf, entries[idx].1, filename, payload)
    None => fail("missing embedded file: " + name)
  }
}

///|
fn assert_url_entry(
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
  name : String,
  expected_uri : String,
) -> Unit raise {
  match entries.search_by(pair => pair.0 == name) {
    Some(idx) => assert_url_action(pdf, entries[idx].1, expected_uri)
    None => fail("missing url entry: " + name)
  }
}

///|
fn assert_ap_entry(
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
  name : String,
  expected_payload : String,
) -> Unit raise {
  match entries.search_by(pair => pair.0 == name) {
    Some(idx) => assert_ap_stream(pdf, entries[idx].1, expected_payload)
    None => fail("missing ap entry: " + name)
  }
}

///|
fn assert_rendition_entry(
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
  name : String,
  tag : String,
) -> Unit raise {
  let entry = match entries.search_by(pair => pair.0 == name) {
    Some(idx) => entries[idx].1
    None => fail("missing rendition entry: " + name)
  }
  let dict = pdf.direct(entry)
  match (pdf.lookup_direct("/S", dict) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/MR") => ()
    _ => fail("expected /S /MR")
  }
  match (pdf.lookup_direct("/N", dict) : @pdf.PdfObject?) {
    Some(String(value)) => assert_eq(value, name)
    _ => fail("expected /N string")
  }
  match (pdf.lookup_direct("/T", dict) : @pdf.PdfObject?) {
    Some(String(value)) => assert_eq(value, tag)
    _ => fail("expected /T string")
  }
}

///|
fn assert_alt_presentation_entry(
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
  name : String,
  tag : String,
) -> Unit raise {
  let entry = match entries.search_by(pair => pair.0 == name) {
    Some(idx) => entries[idx].1
    None => fail("missing alternate presentation entry: " + name)
  }
  let dict = pdf.direct(entry)
  match (pdf.lookup_direct("/Type", dict) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/AlternatePresentations") => ()
    _ => fail("expected /Type /AlternatePresentations")
  }
  match (pdf.lookup_direct("/Title", dict) : @pdf.PdfObject?) {
    Some(String(value)) => assert_eq(value, name)
    _ => fail("expected /Title string")
  }
  match (pdf.lookup_direct("/T", dict) : @pdf.PdfObject?) {
    Some(String(value)) => assert_eq(value, tag)
    _ => fail("expected /T string")
  }
}

///|
fn assert_destination_page(
  dest : @pdfdest.Destination,
  expected_obj : Int,
) -> Unit raise {
  match dest {
    @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(obj))
    | @pdfdest.Destination::FitH(@pdfdest.TargetPage::PageObject(obj), _)
    | @pdfdest.Destination::FitV(@pdfdest.TargetPage::PageObject(obj), _)
    | @pdfdest.Destination::FitR(
      @pdfdest.TargetPage::PageObject(obj),
      _,
      _,
      _,
      _
    )
    | @pdfdest.Destination::FitB(@pdfdest.TargetPage::PageObject(obj))
    | @pdfdest.Destination::FitBH(@pdfdest.TargetPage::PageObject(obj), _)
    | @pdfdest.Destination::FitBV(@pdfdest.TargetPage::PageObject(obj), _)
    | @pdfdest.Destination::XYZ(@pdfdest.TargetPage::PageObject(obj), _, _, _) =>
      assert_eq(obj, expected_obj)
    _ => fail("unexpected destination target")
  }
}

///|
async test "e2e merge writes and reads back" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let third = read_pdf(MERGE_THIRD_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  let third_count = page_count(third)
  assert_true(left_count > 0)
  assert_true(right_count > 0)
  assert_true(third_count > 0)
  let merged = @pdfmerge.PdfMerger::new(
    ["merge_left", "merge_right", "merge_third"],
    [left, right, third],
    [full_range(left_count), full_range(right_count), full_range(third_count)],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  assert_eq(page_count(parsed), left_count + right_count + third_count)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge stress repeated" {
  let base = read_pdf(MERGE_LEFT_PATH)
  let count = page_count(base)
  assert_true(count > 0)
  let copies = 8
  let names = Array::new(capacity=copies)
  let pdfs = Array::new(capacity=copies)
  let ranges = Array::new(capacity=copies)
  for i in 0..<copies {
    names.push("stress_" + i.to_string())
    pdfs.push(read_pdf(MERGE_LEFT_PATH))
    ranges.push(full_range(count))
  }
  let merged = @pdfmerge.PdfMerger::new(names, pdfs, ranges).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  assert_eq(page_count(merged), count * copies)
}

///|
async test "e2e merge preserves text extraction" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_true(left_count > 0)
  assert_true(right_count > 0)
  let merged = @pdfmerge.PdfMerger::new(
    ["merge_text_left", "merge_text_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merge_text.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let extracted = @pdfe.with_logger(_ => (), fn() {
    @pdftext.PdfText::new(parsed).extract_text()
  })
  assert_true(extracted.contains("ABCdef"))
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e split subset of large pdf" {
  let pdf = read_pdf(LARGE_PATH)
  let count = page_count(pdf)
  assert_true(count > 10)
  let subset = [1, 2, count]
  let split = @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages(subset)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/split.pdf"
  write_pdf(out_path, split)
  let parsed = read_pdf(out_path)
  assert_eq(page_count(parsed), subset.length())
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e split then bookmark" {
  let pdf = read_pdf(LARGE_PATH)
  let count = page_count(pdf)
  assert_true(count >= 2)
  let subset = [1, 2]
  let split = @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages(subset)
  let page1 = match @pdfpage.PdfPageDoc::new(split).page_object_number(1) {
    Some(objnum) => objnum
    None => fail("missing split page 1")
  }
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Split bookmark",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page1)),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let split_with = @pdfmarks.PdfMarks::new(split).add_bookmarks(marks)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/split_bookmark.pdf"
  write_pdf(out_path, split_with)
  let parsed = read_pdf(out_path)
  let parsed_marks = @pdfmarks.PdfMarks::new(parsed).read_bookmarks()
  assert_eq(parsed_marks.length(), 1)
  let target_page = @pdfpage.PdfPageDoc::new(parsed).pagenumber_of_target(
    parsed_marks[0].target,
  )
  assert_eq(target_page, 1)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e annotation roundtrip" {
  let pdf = read_pdf(MERGE_LEFT_PATH)
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  assert_true(pages.length() > 0)
  let annot = @pdfannot.Annotation::new(
    @pdfannot.Subtype::Text,
    content="E2E note",
    rectangle=(10.0, 20.0, 30.0, 40.0),
  )
  let updated_page = @pdfannot.PdfAnnot::new(pdf).add_annotation(
    pages[0],
    annot,
  )
  pages[0] = updated_page
  let updated_pdf = @pdfpage.PdfPageDoc::new(pdf).change_pages(true, pages)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/annotated.pdf"
  write_pdf(out_path, updated_pdf)
  let parsed = read_pdf(out_path)
  let parsed_pages = @pdfpage.PdfPageDoc::new(parsed).pages_of_pagetree()
  let annots = @pdfannot.PdfAnnot::new(parsed).annotations_of_page(
    parsed_pages[0],
  )
  assert_eq(annots.length(), 1)
  match annots[0].annot_contents {
    Some("E2E note") => ()
    _ => fail("expected annotation contents")
  }
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves annotations" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let left_pages = @pdfpage.PdfPageDoc::new(left).pages_of_pagetree()
  assert_true(left_pages.length() > 0)
  let annot = @pdfannot.Annotation::new(
    @pdfannot.Subtype::Text,
    content="Merged note",
    rectangle=(15.0, 25.0, 35.0, 45.0),
  )
  let updated_page = @pdfannot.PdfAnnot::new(left).add_annotation(
    left_pages[0],
    annot,
  )
  left_pages[0] = updated_page
  let updated_left = @pdfpage.PdfPageDoc::new(left).change_pages(
    true, left_pages,
  )
  let left_count = page_count(updated_left)
  let right_count = page_count(right)
  let merged = @pdfmerge.PdfMerger::new(
    ["merge_annot_left", "merge_annot_right"],
    [updated_left, right],
    [full_range(left_count), full_range(right_count)],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_annot.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_pages = @pdfpage.PdfPageDoc::new(parsed).pages_of_pagetree()
  let annots = @pdfannot.PdfAnnot::new(parsed).annotations_of_page(
    parsed_pages[0],
  )
  assert_eq(annots.length(), 1)
  match annots[0].annot_contents {
    Some("Merged note") => ()
    _ => fail("expected merged annotation contents")
  }
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves page labels" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_true(left_count > 0)
  assert_true(right_count > 0)
  let left_labels = [
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::DecimalArabic,
      labelprefix: Some("L-"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  let right_labels = [
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::DecimalArabic,
      labelprefix: Some("R-"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.PageLabel::write_all(left_labels, left)
  @pdfpagelabels.PageLabel::write_all(right_labels, right)
  let left_read = @pdfpagelabels.PageLabel::read_all(left)
  let right_read = @pdfpagelabels.PageLabel::read_all(right)
  match left_read {
    [label, ..] =>
      match label.labelprefix {
        Some("L-") => ()
        _ => fail("expected left label prefix")
      }
    _ => fail("missing left labels")
  }
  match right_read {
    [label, ..] =>
      match label.labelprefix {
        Some("R-") => ()
        _ => fail("expected right label prefix")
      }
    _ => fail("missing right labels")
  }
  let merged_labels = @pdfpagelabels.PdfPageLabels::new().merge_pagelabels(
    [left, right],
    [full_range(left_count), full_range(right_count)],
  )
  assert_merged_label_prefixes(merged_labels, left_count)
  let merged = @pdfmerge.PdfMerger::new(
    ["merge_labels_left", "merge_labels_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  ).merge_pdfs(
    true,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let in_memory_labels = @pdfpagelabels.PageLabel::read_all(merged)
  assert_merged_label_prefixes(in_memory_labels, left_count)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_labels.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let labels = @pdfpagelabels.PageLabel::read_all(parsed)
  assert_merged_label_prefixes(labels, left_count)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves named destinations" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_eq(left_count, 1)
  assert_eq(right_count, 1)
  let left_page = match @pdfpage.PdfPageDoc::new(left).page_object_number(1) {
    Some(objnum) => objnum
    None => fail("missing left page")
  }
  let right_page = match @pdfpage.PdfPageDoc::new(right).page_object_number(1) {
    Some(objnum) => objnum
    None => fail("missing right page")
  }
  add_named_destination(left, "LeftDest", left_page)
  add_named_destination(right, "RightDest", right_page)
  let merged = @pdfmerge.PdfMerger::new(
    ["named_left", "named_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let merged_pages = merged.page_reference_numbers()
  let left_expected = merged_pages[0]
  let right_expected = merged_pages[left_count]
  let left_dest = read_named_destination(merged, "LeftDest")
  let right_dest = read_named_destination(merged, "RightDest")
  assert_destination_page(left_dest, left_expected)
  assert_destination_page(right_dest, right_expected)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_named_dests.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_pages = parsed.page_reference_numbers()
  let parsed_left = parsed_pages[0]
  let parsed_right = parsed_pages[left_count]
  let parsed_left_dest = read_named_destination(parsed, "LeftDest")
  let parsed_right_dest = read_named_destination(parsed, "RightDest")
  assert_destination_page(parsed_left_dest, parsed_left)
  assert_destination_page(parsed_right_dest, parsed_right)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Dests dictionary" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_eq(left_count, 1)
  assert_eq(right_count, 1)
  let left_page = match @pdfpage.PdfPageDoc::new(left).page_object_number(1) {
    Some(objnum) => objnum
    None => fail("missing left page")
  }
  let right_page = match @pdfpage.PdfPageDoc::new(right).page_object_number(1) {
    Some(objnum) => objnum
    None => fail("missing right page")
  }
  let left_dest = @pdfdest.Destination::Fit(
    @pdfdest.TargetPage::PageObject(left_page),
  ).to_pdf_object()
  let right_dest = @pdfdest.Destination::Fit(
    @pdfdest.TargetPage::PageObject(right_page),
  ).to_pdf_object()
  add_dests_dictionary(left, [("/LeftDest", left_dest)])
  add_dests_dictionary(right, [("/RightDest", right_dest)])
  let merged = @pdfmerge.PdfMerger::new(
    ["dests_left", "dests_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let merged_pages = merged.page_reference_numbers()
  let left_expected = merged_pages[0]
  let right_expected = merged_pages[left_count]
  let left_read = @pdfdest.Destination::read(
    merged,
    Name(@pdf.PdfName::of_string("/LeftDest")),
  )
  let right_read = @pdfdest.Destination::read(
    merged,
    Name(@pdf.PdfName::of_string("/RightDest")),
  )
  assert_destination_page(left_read, left_expected)
  assert_destination_page(right_read, right_expected)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_dests_dict.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_pages = parsed.page_reference_numbers()
  let parsed_left = parsed_pages[0]
  let parsed_right = parsed_pages[left_count]
  let parsed_left_read = @pdfdest.Destination::read(
    parsed,
    Name(@pdf.PdfName::of_string("/LeftDest")),
  )
  let parsed_right_read = @pdfdest.Destination::read(
    parsed,
    Name(@pdf.PdfName::of_string("/RightDest")),
  )
  assert_destination_page(parsed_left_read, parsed_left)
  assert_destination_page(parsed_right_read, parsed_right)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves AcroForm entries" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  let left_form : @pdf.PdfObject = Dictionary([
    ("/Fields", Array([Null])),
    ("/NeedAppearances", Boolean(true)),
  ])
  let right_form : @pdf.PdfObject = Dictionary([
    ("/Fields", Array([Null])),
    ("/SigFlags", Integer(1)),
  ])
  set_catalog_entry(left, "/AcroForm", left_form)
  set_catalog_entry(right, "/AcroForm", right_form)
  let merged = @pdfmerge.PdfMerger::new(
    ["acro_left", "acro_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let catalog = merged.catalog_of_pdf()
  let form = match merged.lookup_direct("/AcroForm", catalog) {
    Some(obj) => obj
    None => fail("missing /AcroForm")
  }
  match (merged.lookup_direct("/Fields", form) : @pdf.PdfObject?) {
    Some(Array(arr)) => assert_eq(arr.length(), 2)
    _ => fail("expected /Fields array")
  }
  match (merged.lookup_direct("/NeedAppearances", form) : @pdf.PdfObject?) {
    Some(Boolean(true)) => ()
    _ => fail("expected /NeedAppearances true")
  }
  match (merged.lookup_direct("/SigFlags", form) : @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected /SigFlags 1")
  }
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_acroform.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_catalog = parsed.catalog_of_pdf()
  let parsed_form = match parsed.lookup_direct("/AcroForm", parsed_catalog) {
    Some(obj) => obj
    None => fail("missing parsed /AcroForm")
  }
  match (parsed.lookup_direct("/Fields", parsed_form) : @pdf.PdfObject?) {
    Some(Array(arr)) => assert_eq(arr.length(), 2)
    _ => fail("expected parsed /Fields array")
  }
  match
    (parsed.lookup_direct("/NeedAppearances", parsed_form) : @pdf.PdfObject?) {
    Some(Boolean(true)) => ()
    _ => fail("expected parsed /NeedAppearances true")
  }
  match (parsed.lookup_direct("/SigFlags", parsed_form) : @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected parsed /SigFlags 1")
  }
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /OCProperties" {
  let left_page = @pdfpage.Page::blank(@pdfpaper.a4)
  let (left0, left_root) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      left_page,
    ],
  )
  let left = @pdfpage.PdfPageDoc::new(left0).add_root(left_root, [])
  let right_page = @pdfpage.Page::blank(@pdfpaper.a4)
  let (right0, right_root) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      right_page,
    ],
  )
  let right = @pdfpage.PdfPageDoc::new(right0).add_root(right_root, [])
  add_ocg_properties(left, "LayerLeft")
  add_ocg_properties(right, "LayerRight")
  let merged = @pdfmerge.PdfMerger::new(
    ["ocg_left", "ocg_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  let merged_names = read_ocg_names(merged)
  match merged_names.search_by(name => name == "LayerLeft") {
    Some(_) => ()
    None => fail("missing OCG LayerLeft")
  }
  match merged_names.search_by(name => name == "LayerRight") {
    Some(_) => ()
    None => fail("missing OCG LayerRight")
  }
  assert_eq(read_ocg_on_count(merged), 2)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_ocg.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_names = read_ocg_names(parsed)
  match parsed_names.search_by(name => name == "LayerLeft") {
    Some(_) => ()
    None => fail("missing parsed OCG LayerLeft")
  }
  match parsed_names.search_by(name => name == "LayerRight") {
    Some(_) => ()
    None => fail("missing parsed OCG LayerRight")
  }
  assert_eq(read_ocg_on_count(parsed), 2)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves OCG configs" {
  let left_page = @pdfpage.Page::blank(@pdfpaper.a4)
  let (left0, left_root) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      left_page,
    ],
  )
  let left = @pdfpage.PdfPageDoc::new(left0).add_root(left_root, [])
  let right_page = @pdfpage.Page::blank(@pdfpaper.a4)
  let (right0, right_root) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      right_page,
    ],
  )
  let right = @pdfpage.PdfPageDoc::new(right0).add_root(right_root, [])
  add_ocg_properties_with_config(left, "LayerLeft", "ConfigLeft")
  add_ocg_properties_with_config(right, "LayerRight", "ConfigRight")
  let merged = @pdfmerge.PdfMerger::new(
    ["ocg_left", "ocg_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  match @pdfocg.OcgProperties::read(merged) {
    Some(_) => ()
    None => fail("expected ocg properties")
  }
  let config_names = read_ocg_config_names(merged)
  match config_names.search_by(name => name == "ConfigLeft") {
    Some(_) => ()
    None => fail("missing config ConfigLeft")
  }
  match config_names.search_by(name => name == "ConfigRight") {
    Some(_) => ()
    None => fail("missing config ConfigRight")
  }
  assert_eq(read_ocg_on_count(merged), 2)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_ocg_configs.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  match @pdfocg.OcgProperties::read(parsed) {
    Some(_) => ()
    None => fail("expected parsed ocg properties")
  }
  let parsed_configs = read_ocg_config_names(parsed)
  match parsed_configs.search_by(name => name == "ConfigLeft") {
    Some(_) => ()
    None => fail("missing parsed config ConfigLeft")
  }
  match parsed_configs.search_by(name => name == "ConfigRight") {
    Some(_) => ()
    None => fail("missing parsed config ConfigRight")
  }
  assert_eq(read_ocg_on_count(parsed), 2)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves structure trees" {
  let left_page = @pdfpage.Page::blank(@pdfpaper.a4)
  let (left0, left_root) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      left_page,
    ],
  )
  let left = @pdfpage.PdfPageDoc::new(left0).add_root(left_root, [])
  let left_refs = left.page_reference_numbers()
  assert_true(left_refs.length() > 0)
  add_struct_tree_root(left, left_refs[0], 0)
  let right_page = @pdfpage.Page::blank(@pdfpaper.a4)
  let (right0, right_root) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      right_page,
    ],
  )
  let right = @pdfpage.PdfPageDoc::new(right0).add_root(right_root, [])
  let right_refs = right.page_reference_numbers()
  assert_true(right_refs.length() > 0)
  add_struct_tree_root(right, right_refs[0], 0)
  let merged = @pdfmerge.PdfMerger::new(
    ["struct_left", "struct_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let parent_keys = read_parent_tree_keys(merged)
  assert_eq(parent_keys.length(), 2)
  assert_true(parent_keys.contains("0"))
  assert_true(parent_keys.contains("1"))
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_struct_trees.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_keys = read_parent_tree_keys(parsed)
  assert_eq(parsed_keys.length(), 2)
  assert_true(parsed_keys.contains("0"))
  assert_true(parsed_keys.contains("1"))
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Names JavaScript" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  let left_action : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/JavaScript"))),
    ("/JS", String("app.alert('left')")),
  ])
  let right_action : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/JavaScript"))),
    ("/JS", String("app.alert('right')")),
  ])
  add_names_tree(left, "/JavaScript", [("LeftScript", left_action)])
  add_names_tree(right, "/JavaScript", [("RightScript", right_action)])
  let merged = @pdfmerge.PdfMerger::new(
    ["js_left", "js_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let entries = read_name_tree_entries(merged, "/JavaScript")
  assert_true(entries.search_by(pair => pair.0 == "LeftScript") is Some(_))
  assert_true(entries.search_by(pair => pair.0 == "RightScript") is Some(_))
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_javascript_names.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_entries = read_name_tree_entries(parsed, "/JavaScript")
  assert_true(
    parsed_entries.search_by(pair => pair.0 == "LeftScript") is Some(_),
  )
  assert_true(
    parsed_entries.search_by(pair => pair.0 == "RightScript") is Some(_),
  )
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Names /EmbeddedFiles" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  add_embedded_file(left, "LeftFile", "left.txt", "left payload")
  add_embedded_file(right, "RightFile", "right.txt", "right payload")
  let merged = @pdfmerge.PdfMerger::new(
    ["embed_left", "embed_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let entries = read_name_tree_entries(merged, "/EmbeddedFiles")
  assert_embedded_file_entry(
    merged, entries, "LeftFile", "left.txt", "left payload",
  )
  assert_embedded_file_entry(
    merged, entries, "RightFile", "right.txt", "right payload",
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_embedded_files.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_entries = read_name_tree_entries(parsed, "/EmbeddedFiles")
  assert_embedded_file_entry(
    parsed, parsed_entries, "LeftFile", "left.txt", "left payload",
  )
  assert_embedded_file_entry(
    parsed, parsed_entries, "RightFile", "right.txt", "right payload",
  )
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Names /URLS" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  add_names_tree(left, "/URLS", [
    ("LeftURL", make_url_action("https://example.com/left")),
  ])
  add_names_tree(right, "/URLS", [
    ("RightURL", make_url_action("https://example.com/right")),
  ])
  let merged = @pdfmerge.PdfMerger::new(
    ["urls_left", "urls_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let entries = read_name_tree_entries(merged, "/URLS")
  assert_url_entry(merged, entries, "LeftURL", "https://example.com/left")
  assert_url_entry(merged, entries, "RightURL", "https://example.com/right")
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_urls.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_entries = read_name_tree_entries(parsed, "/URLS")
  assert_url_entry(
    parsed, parsed_entries, "LeftURL", "https://example.com/left",
  )
  assert_url_entry(
    parsed, parsed_entries, "RightURL", "https://example.com/right",
  )
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Names /AP" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  add_names_tree(left, "/AP", [make_ap_entry(left, "LeftAP", "left ap")])
  add_names_tree(right, "/AP", [make_ap_entry(right, "RightAP", "right ap")])
  let left_entries = read_name_tree_entries(left, "/AP")
  let right_entries = read_name_tree_entries(right, "/AP")
  assert_ap_entry(left, left_entries, "LeftAP", "left ap")
  assert_ap_entry(right, right_entries, "RightAP", "right ap")
  let merged = @pdfmerge.PdfMerger::new(
    ["ap_left", "ap_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let entries = read_name_tree_entries(merged, "/AP")
  assert_ap_entry(merged, entries, "LeftAP", "left ap")
  assert_ap_entry(merged, entries, "RightAP", "right ap")
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_ap.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_entries = read_name_tree_entries(parsed, "/AP")
  assert_ap_entry(parsed, parsed_entries, "LeftAP", "left ap")
  assert_ap_entry(parsed, parsed_entries, "RightAP", "right ap")
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Names /Renditions" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  add_names_tree(left, "/Renditions", [
    ("LeftRendition", make_rendition_dict("LeftRendition", "left")),
  ])
  add_names_tree(right, "/Renditions", [
    ("RightRendition", make_rendition_dict("RightRendition", "right")),
  ])
  let merged = @pdfmerge.PdfMerger::new(
    ["rend_left", "rend_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let entries = read_name_tree_entries(merged, "/Renditions")
  assert_rendition_entry(merged, entries, "LeftRendition", "left")
  assert_rendition_entry(merged, entries, "RightRendition", "right")
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_renditions.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_entries = read_name_tree_entries(parsed, "/Renditions")
  assert_rendition_entry(parsed, parsed_entries, "LeftRendition", "left")
  assert_rendition_entry(parsed, parsed_entries, "RightRendition", "right")
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves /Names /AlternatePresentations" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  add_names_tree(left, "/AlternatePresentations", [
    ("LeftAlt", make_alt_presentation_dict("LeftAlt", "left")),
  ])
  add_names_tree(right, "/AlternatePresentations", [
    ("RightAlt", make_alt_presentation_dict("RightAlt", "right")),
  ])
  let merged = @pdfmerge.PdfMerger::new(
    ["alt_left", "alt_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let entries = read_name_tree_entries(merged, "/AlternatePresentations")
  assert_alt_presentation_entry(merged, entries, "LeftAlt", "left")
  assert_alt_presentation_entry(merged, entries, "RightAlt", "right")
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_alternate_presentations.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_entries = read_name_tree_entries(parsed, "/AlternatePresentations")
  assert_alt_presentation_entry(parsed, parsed_entries, "LeftAlt", "left")
  assert_alt_presentation_entry(parsed, parsed_entries, "RightAlt", "right")
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge stress large name trees" {
  let left = @pdfpage.PdfPageDoc::minimum_valid()
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  let count = 40
  let left_dests = make_bulk_named_dest_entries(left, "L-Dest-", count)
  let right_dests = make_bulk_named_dest_entries(right, "R-Dest-", count)
  add_names_tree(left, "/Dests", left_dests)
  add_names_tree(right, "/Dests", right_dests)
  let left_urls = make_bulk_url_entries("L-URL-", count)
  let right_urls = make_bulk_url_entries("R-URL-", count)
  add_names_tree(left, "/URLS", left_urls)
  add_names_tree(right, "/URLS", right_urls)
  let merged = @pdfmerge.PdfMerger::new(
    ["bulk_left", "bulk_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let merged_dests = read_name_tree_entries(merged, "/Dests")
  let merged_urls = read_name_tree_entries(merged, "/URLS")
  let entries_to_check = [
    "L-Dest-0",
    "L-Dest-" + (count / 2).to_string(),
    "L-Dest-" + (count - 1).to_string(),
    "R-Dest-0",
    "R-Dest-" + (count / 2).to_string(),
    "R-Dest-" + (count - 1).to_string(),
  ]
  for name in entries_to_check {
    match merged_dests.search_by(pair => pair.0 == name) {
      Some(_) => ()
      None => fail("missing bulk dest: " + name)
    }
  }
  let urls_to_check = [
    "L-URL-0",
    "L-URL-" + (count / 2).to_string(),
    "L-URL-" + (count - 1).to_string(),
    "R-URL-0",
    "R-URL-" + (count / 2).to_string(),
    "R-URL-" + (count - 1).to_string(),
  ]
  for name in urls_to_check {
    match merged_urls.search_by(pair => pair.0 == name) {
      Some(_) => ()
      None => fail("missing bulk url: " + name)
    }
  }
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_bulk_names.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_dests = read_name_tree_entries(parsed, "/Dests")
  let parsed_urls = read_name_tree_entries(parsed, "/URLS")
  for name in entries_to_check {
    match parsed_dests.search_by(pair => pair.0 == name) {
      Some(_) => ()
      None => fail("missing parsed bulk dest: " + name)
    }
  }
  for name in urls_to_check {
    match parsed_urls.search_by(pair => pair.0 == name) {
      Some(_) => ()
      None => fail("missing parsed bulk url: " + name)
    }
  }
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge mixed feature pipeline" {
  let left0 = @pdfpage.PdfPageDoc::minimum_valid()
  let pages = @pdfpage.PdfPageDoc::new(left0).pages_of_pagetree()
  let annot = @pdfannot.Annotation::new(
    @pdfannot.Subtype::Text,
    content="Mixed note",
    rectangle=(12.0, 18.0, 40.0, 52.0),
  )
  let updated_page = @pdfannot.PdfAnnot::new(left0).add_annotation(
    pages[0],
    annot,
  )
  pages[0] = updated_page
  let left1 = @pdfpage.PdfPageDoc::new(left0).change_pages(true, pages)
  let page1 = match @pdfpage.PdfPageDoc::new(left1).page_object_number(1) {
    Some(objnum) => objnum
    None => fail("missing left page")
  }
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Mixed bookmark",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page1)),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let left = @pdfmarks.PdfMarks::new(left1).add_bookmarks(marks)
  add_names_tree(left, "/URLS", [
    ("MixURL", make_url_action("https://example.com/mixed")),
  ])
  let right = @pdfpage.PdfPageDoc::minimum_valid()
  add_embedded_file(right, "MixFile", "mixed.txt", "mix payload")
  let merged = @pdfmerge.PdfMerger::new(
    ["mixed_left", "mixed_right"],
    [left, right],
    [full_range(page_count(left)), full_range(page_count(right))],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let merged_pages = @pdfpage.PdfPageDoc::new(merged).pages_of_pagetree()
  let merged_annots = @pdfannot.PdfAnnot::new(merged).annotations_of_page(
    merged_pages[0],
  )
  match merged_annots {
    [first, ..] =>
      match first.annot_contents {
        Some("Mixed note") => ()
        _ => fail("missing mixed annotation")
      }
    _ => fail("missing mixed annotation")
  }
  let merged_marks = @pdfmarks.PdfMarks::new(merged).read_bookmarks()
  assert_true(
    merged_marks.search_by(mark => mark.text == "Mixed bookmark") is Some(_),
  )
  let merged_urls = read_name_tree_entries(merged, "/URLS")
  assert_url_entry(merged, merged_urls, "MixURL", "https://example.com/mixed")
  let merged_embedded = read_name_tree_entries(merged, "/EmbeddedFiles")
  assert_embedded_file_entry(
    merged, merged_embedded, "MixFile", "mixed.txt", "mix payload",
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_mixed.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_pages = @pdfpage.PdfPageDoc::new(parsed).pages_of_pagetree()
  let parsed_annots = @pdfannot.PdfAnnot::new(parsed).annotations_of_page(
    parsed_pages[0],
  )
  match parsed_annots {
    [first, ..] =>
      match first.annot_contents {
        Some("Mixed note") => ()
        _ => fail("missing parsed mixed annotation")
      }
    _ => fail("missing parsed mixed annotation")
  }
  let parsed_marks = @pdfmarks.PdfMarks::new(parsed).read_bookmarks()
  assert_true(
    parsed_marks.search_by(mark => mark.text == "Mixed bookmark") is Some(_),
  )
  let parsed_urls = read_name_tree_entries(parsed, "/URLS")
  assert_url_entry(parsed, parsed_urls, "MixURL", "https://example.com/mixed")
  let parsed_embedded = read_name_tree_entries(parsed, "/EmbeddedFiles")
  assert_embedded_file_entry(
    parsed, parsed_embedded, "MixFile", "mixed.txt", "mix payload",
  )
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge multi-copy mixed stress" {
  let copies = 4
  let names = Array::new(capacity=copies)
  let pdfs = Array::new(capacity=copies)
  let ranges = Array::new(capacity=copies)
  let mut i = 0
  while i < copies {
    let base = @pdfpage.PdfPageDoc::minimum_valid()
    let pages = @pdfpage.PdfPageDoc::new(base).pages_of_pagetree()
    let annot = @pdfannot.Annotation::new(
      @pdfannot.Subtype::Text,
      content="Stress note " + i.to_string(),
      rectangle=(10.0 + i.to_double(), 10.0, 30.0, 40.0),
    )
    let updated_page = @pdfannot.PdfAnnot::new(base).add_annotation(
      pages[0],
      annot,
    )
    pages[0] = updated_page
    let pdf = @pdfpage.PdfPageDoc::new(base).change_pages(true, pages)
    let page1 = match @pdfpage.PdfPageDoc::new(pdf).page_object_number(1) {
      Some(objnum) => objnum
      None => fail("missing page in stress copy")
    }
    let marks : Array[@pdfmarks.Bookmark] = [
      {
        level: 0,
        text: "Stress bookmark " + i.to_string(),
        target: @pdfdest.Destination::Fit(
          @pdfdest.TargetPage::PageObject(page1),
        ),
        isopen: true,
        colour: (0.0, 0.0, 0.0),
        flags: 0,
      },
    ]
    let pdf = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
    let url_name = "StressURL-" + i.to_string()
    add_names_tree(pdf, "/URLS", [
      (url_name, make_url_action("https://example.com/stress/" + i.to_string())),
    ])
    names.push("stress_copy_" + i.to_string())
    pdfs.push(pdf)
    ranges.push(full_range(page_count(pdf)))
    i = i + 1
  }
  let merged = @pdfmerge.PdfMerger::new(names, pdfs, ranges).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let merged_marks = @pdfmarks.PdfMarks::new(merged).read_bookmarks()
  assert_eq(merged_marks.length(), copies)
  let merged_urls = read_name_tree_entries(merged, "/URLS")
  for i in 0..<copies {
    let name = "StressURL-" + i.to_string()
    match merged_urls.search_by(pair => pair.0 == name) {
      Some(_) => ()
      None => fail("missing merged stress url: " + name)
    }
  }
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_mixed_stress.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_marks = @pdfmarks.PdfMarks::new(parsed).read_bookmarks()
  assert_eq(parsed_marks.length(), copies)
  let parsed_urls = read_name_tree_entries(parsed, "/URLS")
  for i in 0..<copies {
    let name = "StressURL-" + i.to_string()
    match parsed_urls.search_by(pair => pair.0 == name) {
      Some(_) => ()
      None => fail("missing parsed stress url: " + name)
    }
  }
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge varied page counts stress" {
  let base = read_pdf(MERGE_THIRD_PATH)
  let base_count = page_count(base)
  assert_true(base_count >= 3)
  let ranges = [[1], [1, base_count], [base_count / 2 + 1]]
  let names = ["varied_one", "varied_two", "varied_three"]
  let pdfs = Array::new(capacity=ranges.length())
  for i in 0..<ranges.length() {
    let subset = @pdfpage.PdfPageDoc::new(base).pdf_of_pages(ranges[i])
    pdfs.push(subset)
  }
  let merge_ranges = Array::new(capacity=pdfs.length())
  for pdf in pdfs {
    merge_ranges.push(full_range(page_count(pdf)))
  }
  add_names_tree(pdfs[0], "/URLS", [
    ("VariedURL-1", make_url_action("https://example.com/varied/1")),
  ])
  add_names_tree(pdfs[1], "/URLS", [
    ("VariedURL-2", make_url_action("https://example.com/varied/2")),
  ])
  add_names_tree(pdfs[2], "/URLS", [
    ("VariedURL-3", make_url_action("https://example.com/varied/3")),
  ])
  let merged = @pdfmerge.PdfMerger::new(names, pdfs, merge_ranges).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let merged_count = page_count(merged)
  assert_eq(merged_count, 1 + 2 + 1)
  let merged_urls = read_name_tree_entries(merged, "/URLS")
  assert_url_entry(
    merged, merged_urls, "VariedURL-1", "https://example.com/varied/1",
  )
  assert_url_entry(
    merged, merged_urls, "VariedURL-2", "https://example.com/varied/2",
  )
  assert_url_entry(
    merged, merged_urls, "VariedURL-3", "https://example.com/varied/3",
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_varied_pages.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  assert_eq(page_count(parsed), merged_count)
  let parsed_urls = read_name_tree_entries(parsed, "/URLS")
  assert_url_entry(
    parsed, parsed_urls, "VariedURL-1", "https://example.com/varied/1",
  )
  assert_url_entry(
    parsed, parsed_urls, "VariedURL-2", "https://example.com/varied/2",
  )
  assert_url_entry(
    parsed, parsed_urls, "VariedURL-3", "https://example.com/varied/3",
  )
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge preserves bookmark targets" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  assert_true(left_count > 0)
  assert_true(right_count > 0)
  let page1 = match @pdfpage.PdfPageDoc::new(left).page_object_number(1) {
    Some(objnum) => objnum
    None => fail("missing page 1")
  }
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Merged bookmark",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page1)),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let left_with = @pdfmarks.PdfMarks::new(left).add_bookmarks(marks)
  let merged = @pdfmerge.PdfMerger::new(
    ["merge_marks_left", "merge_marks_right"],
    [left_with, right],
    [full_range(left_count), full_range(right_count)],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/merged_marks.pdf"
  write_pdf(out_path, merged)
  let parsed = read_pdf(out_path)
  let parsed_marks = @pdfmarks.PdfMarks::new(parsed).read_bookmarks()
  assert_eq(parsed_marks.length(), 1)
  let target_page = @pdfpage.PdfPageDoc::new(parsed).pagenumber_of_target(
    parsed_marks[0].target,
  )
  assert_eq(target_page, 1)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e bookmarks roundtrip" {
  let pdf = read_pdf(BOOKMARK_PATH)
  let count = page_count(pdf)
  assert_true(count >= 2)
  let page1 = match @pdfpage.PdfPageDoc::new(pdf).page_object_number(1) {
    Some(objnum) => objnum
    None => fail("missing page 1")
  }
  let page2 = match @pdfpage.PdfPageDoc::new(pdf).page_object_number(2) {
    Some(objnum) => objnum
    None => fail("missing page 2")
  }
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "E2E Intro",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page1)),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "E2E Details",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(page2)),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/bookmarks.pdf"
  write_pdf(out_path, pdf_with)
  let parsed = read_pdf(out_path)
  let parsed_marks = @pdfmarks.PdfMarks::new(parsed).read_bookmarks()
  assert_eq(parsed_marks.length(), 2)
  assert_eq(parsed_marks[0].text, "E2E Intro")
  assert_eq(parsed_marks[1].text, "E2E Details")
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e write object streams and read back" {
  let pdf = read_pdf(MERGE_THIRD_PATH)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/objstm.pdf"
  let file = @fs.open(out_path, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  @pdfwritefs.PdfWriteFs::new().pdf_to_channel(
    generate_objstm=true,
    compress_objstm=true,
    None,
    true,
    pdf,
    file,
  )
  let parsed = read_pdf(out_path)
  assert_true(parsed.objects.object_stream_ids.length() > 0)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e encrypt pdf and require password" {
  let pdf = read_pdf(MERGE_LEFT_PATH)
  let enc = @pdfwrite.Encryption::new(
    @pdfwrite.EncryptionMethod::AES256bit(true),
    "owner-pass",
    "user-pass",
    [],
  )
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/encrypted.pdf"
  let file = @fs.open(out_path, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  @pdfwritefs.PdfWriteFs::new().pdf_to_channel(Some(enc), true, pdf, file)
  let res : Result[@pdf.Pdf, Error] = try? @pdfreadfs.PdfReadFs::new().pdf_of_file(
    None,
    None,
    out_path,
  )
  match res {
    Ok(parsed) =>
      if @pdfread.PdfRead::new().what_encryption(parsed) is None {
        fail("expected encryption info")
      }
    Err(_) => fail("expected read to succeed without password")
  }
  let parsed_pw = @pdfreadfs.PdfReadFs::new().pdf_of_file(
    Some("user-pass"),
    None,
    out_path,
  )
  assert_eq(page_count(parsed_pw), page_count(pdf))
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e merge split merge pipeline" {
  let left = read_pdf(MERGE_LEFT_PATH)
  let right = read_pdf(MERGE_RIGHT_PATH)
  let third = read_pdf(MERGE_THIRD_PATH)
  let left_count = page_count(left)
  let right_count = page_count(right)
  let third_count = page_count(third)
  let merged = @pdfmerge.PdfMerger::new(
    ["pipeline_left", "pipeline_right"],
    [left, right],
    [full_range(left_count), full_range(right_count)],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  let merged_count = page_count(merged)
  assert_true(merged_count > 1)
  let subset = if merged_count > 2 {
    [1, merged_count / 2, merged_count]
  } else {
    [1, merged_count]
  }
  let subset_pdf = @pdfpage.PdfPageDoc::new(merged).pdf_of_pages(subset)
  let remerged = @pdfmerge.PdfMerger::new(
    ["pipeline_subset", "pipeline_third"],
    [subset_pdf, third],
    [full_range(subset.length()), full_range(third_count)],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=true,
    add_toplevel_document=false,
  )
  assert_eq(page_count(remerged), subset.length() + third_count)
}

///|
async test "e2e page labels roundtrip" {
  let pdf = read_pdf(LARGE_PATH)
  let count = page_count(pdf)
  assert_true(count >= 3)
  let labels = [
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::DecimalArabic,
      labelprefix: Some("E2E-"),
      startpage: 1,
      startvalue: 1,
    },
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::LowercaseRoman,
      labelprefix: None,
      startpage: 3,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.PageLabel::write_all(labels, pdf)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/pagelabels.pdf"
  write_pdf(out_path, pdf)
  let parsed = read_pdf(out_path)
  let read_back = @pdfpagelabels.PageLabel::read_all(parsed)
  assert_eq(read_back.length(), 2)
  match read_back[0].labelprefix {
    Some("E2E-") => ()
    _ => fail("expected prefix E2E-")
  }
  assert_eq(read_back[1].startpage, 3)
  assert_eq(
    @pdfpagelabels.PdfPageLabels::new().pagelabeltext_of_pagenumber(
      1, read_back,
    ),
    "E2E-1",
  )
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}

///|
async test "e2e page ops roundtrip" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops([@pdfops.Op::Opq, @pdfops.Op::OpQ])],
    mediabox: rect,
    resources: Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      page,
    ],
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let updated = pages[0].postpend_operators(
    pdf,
    [@pdfops.Op::Opw(5.0)],
    fast=true,
  )
  pages[0] = updated
  let updated_pdf = @pdfpage.PdfPageDoc::new(pdf).change_pages(true, pages)
  ensure_dir(OUTPUT_DIR)
  let out_path = OUTPUT_DIR + "/page_ops.pdf"
  write_pdf(out_path, updated_pdf)
  let parsed = read_pdf(out_path)
  let parsed_page = @pdfpage.PdfPageDoc::new(parsed).pages_of_pagetree()[0]
  let parsed_ops = @pdfops.Op::parse_operators(
    parsed,
    parsed_page.resources,
    parsed_page.content,
  )
  let mut found = false
  for op in parsed_ops {
    match op {
      @pdfops.Op::Opw(5.0) => found = true
      _ => ()
    }
  }
  assert_true(found)
  let _ : Result[Unit, Error] = try? @fs.remove(out_path)

}
