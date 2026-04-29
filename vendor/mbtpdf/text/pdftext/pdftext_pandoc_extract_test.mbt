///|
async test "extract text pandoc basic fixture" {
  let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(
    None,
    None,
    "testdata/pandoc/pandoc_basic.pdf",
  )
  let pages = @pdftext.PdfText::new(pdf).extract_text(page_break="\n-----\n")
  inspect(
    pages,
    content=(
      #|PandocFixtureBasic
      #|PandocFixturePageOne
      #|ThisfixturecheckssimpleASCIItokens.
      #|•
      #|AlphaTokenOne
      #|•
      #|BetaTokenTwo
      #|1
      #|-----
      #|PandocFixturePageTwo
      #|Secondpagewithnumbers12345andMixedCaseToken.
      #|2
    ),
  )
}

///|
async test "extract text pandoc unicode fixture" {
  let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(
    None,
    None,
    "testdata/pandoc/pandoc_unicode.pdf",
  )
  let extracted = @pdftext.PdfText::new(pdf).extract_text()
  debug_inspect(
    extracted,
    content=(
      #|"PandocFixtureUnicode\nPandocUnicodePage\nWords:Café,naïve,Español,£pound,€euro,Ωmega.\nChinese:中文测试\n1"
    ),
  )
}
