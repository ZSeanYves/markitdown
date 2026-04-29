///|
test "read parses simple AFM data" {
  let afm =
    #|StartFontMetrics 4.1
    #|FontName TestFont
    #|StartCharMetrics 2
    #|C 65 ; WX 600 ; N A ;
    #|C 66 ; WX 500 ; N B ;
    #|EndCharMetrics
    #|StartKernPairs 1
    #|KPX A B -50
    #|EndKernPairs
    #|EndFontMetrics
    #|
  let input = @pdfio.Input::of_string(afm)
  let (headers, widths, kerns, widths_prime) = @pdfafm.PdfAfm::new().read(input)
  match headers.search_by(pair => pair.0 == "FontName") {
    Some(index) => assert_eq(headers[index].1, "TestFont")
    None => fail("expected FontName header")
  }
  assert_eq(widths.length(), 2)
  assert_eq(widths[0].0, 65)
  assert_eq(widths[0].1, 600)
  assert_eq(kerns.length(), 1)
  assert_eq(kerns[0], (65, 66, -50))
  assert_eq(widths_prime.length(), 2)
  assert_eq(widths_prime[0].0, "A")
  assert_eq(widths_prime[0].1, 600)
}

///|
test "read rejects malformed kern lines" {
  let afm =
    #|StartFontMetrics 4.1
    #|FontName BrokenFont
    #|StartCharMetrics 1
    #|C 65 ; WX 600 ; N A ;
    #|EndCharMetrics
    #|StartKernPairs 1
    #|BAD A B 0
    #|EndKernPairs
    #|EndFontMetrics
    #|
  let input = @pdfio.Input::of_string(afm)
  let res : Result[
    (
      Array[(String, String)],
      Array[(Int, Int)],
      Array[(Int, Int, Int)],
      Array[(String, Int)],
    ),
    Error,
  ] = try? @pdfafm.PdfAfm::new().read(input)
  assert_true(res is Err(_))
}
