///|
fn freshname(source : () -> Int) -> String {
  "/r" + source().to_string()
}

///|
let resource_keys : Array[String] = [
  "/Font", "/ExtGState", "/ColorSpace", "/Pattern", "/Shading", "/XObject", "/Properties",
]

///|
fn make_changes(
  pdf : @pdf.Pdf,
  pages : Array[Page],
) -> Map[(String, Int, String), String] {
  let src = source(0)
  fn entries_of_page(
    entry : String,
    pageseq : Int,
    page : Page,
  ) -> Array[(String, Int, String, String)] {
    let entries = match pdf.lookup_direct(entry, page.resources) {
      Some(@pdf.PdfObject::Dictionary(es)) => es
      _ => []
    }
    entries.map(pair => (entry, pageseq, pair.0, freshname(src)))
  }

  let pagenums = Array::makei(pages.length(), i => i + 1)
  let entries : Array[(String, Int, String, String)] = Array::new()
  for name in resource_keys {
    for i, page in pages {
      entries.append(entries_of_page(name, pagenums[i], page)[:])
    }
  }
  let table : Map[(String, Int, String), String] = Map::new(
    capacity=entries.length(),
  )
  for entry in entries {
    let (dictname, pageseq, key, name) = entry
    table.set((dictname, pageseq, key), name)
  }
  table
}

///|
fn change_operator(
  pdf : @pdf.Pdf,
  lookup : (String, Int, String) -> String raise,
  lookup_option : (String, Int, String) -> String?,
  seqnum : Int,
  op : @pdfops.Op,
) -> @pdfops.Op raise {
  match op {
    OpTf(f, size) => OpTf(lookup("/Font", seqnum, f), size)
    Opgs(n) => Opgs(lookup("/ExtGState", seqnum, n))
    OpCS(n) =>
      match lookup_option("/ColorSpace", seqnum, n) {
        Some(x) => OpCS(x)
        None => OpCS(n)
      }
    Opcs(n) =>
      match lookup_option("/ColorSpace", seqnum, n) {
        Some(x) => Opcs(x)
        None => Opcs(n)
      }
    OpSCNName(s, ns) => OpSCNName(lookup("/Pattern", seqnum, s), ns)
    OpscnName(s, ns) => OpscnName(lookup("/Pattern", seqnum, s), ns)
    Opsh(s) => Opsh(lookup("/Shading", seqnum, s))
    OpDo(x) => OpDo(lookup("/XObject", seqnum, x))
    OpDP(n, @pdf.PdfObject::Name(p)) =>
      OpDP(
        n,
        @pdf.PdfObject::Name(
          @pdf.PdfName::of_string(
            lookup("/Properties", seqnum, p.to_string_bytes()),
          ),
        ),
      )
    OpBDC(n, @pdf.PdfObject::Name(p)) =>
      match lookup_option("/Properties", seqnum, p.to_string_bytes()) {
        Some(x) => OpBDC(n, @pdf.PdfObject::Name(@pdf.PdfName::of_string(x)))
        None => {
          @pdfe.log("Warning: Missing OpBDC /Properties entry\n")
          OpBDC(n, @pdf.PdfObject::Name(p))
        }
      }
    InlineImage((dict, dp, bytes)) => {
      let dict_updated = match
        pdf.lookup_direct_orelse("/CS", "/ColorSpace", dict) {
        Some(@pdf.PdfObject::Name(n)) =>
          if n.equal_string_bytes("/DeviceGray") ||
            n.equal_string_bytes("/DeviceRGB") ||
            n.equal_string_bytes("/DeviceCMYK") ||
            n.equal_string_bytes("/G") ||
            n.equal_string_bytes("/RGB") ||
            n.equal_string_bytes("/CMYK") {
            dict
          } else {
            let stripped = dict.remove_entry("/ColorSpace").remove_entry("/CS")
            stripped.add_entry(
              "/CS",
              @pdf.PdfObject::Name(
                @pdf.PdfName::of_string(
                  lookup("/ColorSpace", seqnum, n.to_string_bytes()),
                ),
              ),
            )
          }
        _ => dict
      }
      InlineImage((dict_updated, dp, bytes))
    }
    _ => op
  }
}

///|
/// Make a collection of pages capable of being merged.
pub fn PdfPageDoc::renumber_pages(
  self : PdfPageDoc,
  pages : Array[Page],
) -> Array[Page] raise {
  let pdf = self.pdf
  if pages.length() == 0 {
    return []
  }
  let changes = make_changes(pdf, pages)
  fn lookup_option(dictname : String, page : Int, oldkey : String) -> String? {
    changes.get((dictname, page, oldkey))
  }

  fn lookup(dictname : String, page : Int, oldkey : String) -> String raise {
    match changes.get((dictname, page, oldkey)) {
      Some(value) => value
      None => raise @pdf.PdfError::Msg("Pdfpage.renumber_pages: Bad key")
    }
  }

  fn change_content(
    seqnum : Int,
    resources : @pdf.PdfObject,
    content : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] raise {
    let operators = @pdfops.Op::parse_operators(pdf, resources, content)
    let operators_updated = operators.map(op => change_operator(
      pdf, lookup, lookup_option, seqnum, op,
    ))
    [@pdfops.Op::stream_of_ops(operators_updated)]
  }

  fn change_resources(
    seqnum : Int,
    resources : @pdf.PdfObject,
  ) -> @pdf.PdfObject raise {
    fn newdict(name : String) -> @pdf.PdfObject raise {
      match pdf.lookup_direct(name, resources) {
        Some(@pdf.PdfObject::Dictionary(entries)) =>
          @pdf.PdfObject::Dictionary(
            entries.map(pair => (lookup(name, seqnum, pair.0), pair.1)),
          )
        _ => @pdf.PdfObject::Dictionary([])
      }
    }

    let newdicts = resource_keys.map(newdict)
    let mut updated = resources
    for i, key in resource_keys {
      updated = updated.add_entry(key, newdicts[i])
    }
    updated
  }

  let out : Array[Page] = Array::new(capacity=pages.length())
  for i, page in pages {
    let seqnum = i + 1
    out.push({
      content: change_content(seqnum, page.resources, page.content),
      resources: change_resources(seqnum, page.resources),
      mediabox: page.mediabox,
      rotate: page.rotate,
      rest: page.rest,
    })
  }
  out
}
