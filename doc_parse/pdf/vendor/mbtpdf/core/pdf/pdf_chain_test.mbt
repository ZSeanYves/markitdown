///|
test "lookup_chain handles array keys" {
  let pdf = Pdf::empty()
  pdf.trailerdict = Dictionary([("/A", Array([Integer(10), Integer(20)]))])
  let keys = ["/A", "/[1]"]
  match pdf.lookup_chain(pdf.trailerdict, keys[:]) {
    Some(Integer(value)) => assert_eq(value, 20)
    _ => fail("expected array element")
  }
}

///|
test "replace_chain updates array elements" {
  let pdf = Pdf::empty()
  pdf.trailerdict = Dictionary([("/A", Array([Integer(1), Integer(2)]))])
  let chain = ["/A", "/[0]"]
  pdf.replace_chain(chain, Integer(99))
  match pdf.lookup_chain(pdf.trailerdict, chain[:]) {
    Some(Integer(value)) => assert_eq(value, 99)
    _ => fail("expected replaced array element")
  }
}
