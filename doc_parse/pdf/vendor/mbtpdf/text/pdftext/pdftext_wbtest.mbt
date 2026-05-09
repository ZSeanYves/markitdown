///|
test "write_encoding predefined encodings" {
  let pdf = @pdf.Pdf::empty()
  let ctx = PdfText::new(pdf)
  let objnum = ctx.write_encoding(WinAnsiEncoding)
  let obj = pdf.lookup_obj(objnum)
  match obj {
    Name(name) => assert_eq(name.to_string_bytes(), "/WinAnsiEncoding")
    _ => fail("expected encoding name")
  }
}

///|
test "write_encoding custom encoding base and differences" {
  let pdf = @pdf.Pdf::empty()
  let ctx = PdfText::new(pdf)
  let diffs : @pdffont.Differences = [("/A", 65), ("/B", 66)]
  let objnum = ctx.write_encoding(CustomEncoding(StandardEncoding, diffs))
  let obj = pdf.lookup_obj(objnum)
  match obj {
    Dictionary(entries) => {
      let base_idx = entries.search_by(pair => pair.0 == "/BaseEncoding")
      let diff_idx = entries.search_by(pair => pair.0 == "/Differences")
      match (base_idx, diff_idx) {
        (Some(bi), Some(di)) => {
          match entries[bi].1 {
            Name(name) => assert_eq(name.to_string_bytes(), "/StandardEncoding")
            _ => fail("expected /BaseEncoding name")
          }
          match entries[di].1 {
            Array(elts) => {
              assert_eq(elts.length(), 4)
              match (elts[0], elts[1], elts[2], elts[3]) {
                (Integer(a), Name(n1), Integer(b), Name(n2)) => {
                  assert_eq(a, 65)
                  assert_eq(n1.to_string_bytes(), "/A")
                  assert_eq(b, 66)
                  assert_eq(n2.to_string_bytes(), "/B")
                }
                _ => fail("unexpected /Differences entries")
              }
            }
            _ => fail("expected /Differences array")
          }
        }
        _ => fail("missing encoding dictionary entries")
      }
    }
    _ => fail("expected encoding dictionary")
  }
}
