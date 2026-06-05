Sample PDFs for text-extraction tests.

Sources:
- pdfjs_identity_tounicode.pdf: https://github.com/mozilla/pdf.js/blob/master/test/pdfs/IdentityToUnicodeMap_charCodeOf.pdf
- pdfjs_arial_unicode_ab_cidfont.pdf: https://github.com/mozilla/pdf.js/blob/master/test/pdfs/arial_unicode_ab_cidfont.pdf
- SFAA_Japanese.pdf: https://web.archive.org/web/20150307061027/http://www.project2061.org/publications/sfaa/SFAA_Japanese.pdf
- pandoc/pandoc_basic.pdf: generated from testdata/pandoc/pandoc_basic.md using pandoc
- pandoc/pandoc_unicode.pdf: generated from testdata/pandoc/pandoc_unicode.md using pandoc

Pandoc fixtures in `testdata/pandoc/` were originally generated from the
paired Markdown sources during upstream fixture preparation. The unicode
fixture uses a CJK main font (currently "PingFang SC") and may need adjustment
or an installed CJK font on non-macOS machines.
