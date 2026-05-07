# Cross Page Paragraph

This paragraph starts on the first page and is intentionally written to flow near the bottom of the page. The goal of this sample is to verify that a paragraph should not be split only because a page boundary appears in the extracted text. In many PDFs, the end of one page and the beginning of the next page still belong to the same logical paragraph. This sample therefore places the final sentence so that it continues across the page break and should still become a single paragraph after the parser removes simple page-level noise such as page numbers or repeated headers.

## Next Section

A new paragraph starts here and should remain separate from the previous one. It exists to confirm that cross-page merging does not accidentally swallow the next real section.
