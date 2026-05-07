# 第一章 项目概述

本项目旨在将常见办公文档转换为结构化 Markdown。

## 1.1 研究目标

实现 docx、pdf、xlsx、pptx、html 到 Markdown 的统一转换。

# 第二章 技术路线

系统采用统一 IR 作为中间表示。

Alpha page content.

Beta page content.

Gamma page content.

Delta page content.

# Project Report

This is the first page body. It should remain after cleanup.

# Confidential

# Project Report

This is the second page body. The repeated header and footer should be removed.

# Confidential

# Cross Page Paragraph

This paragraph starts on the first page and is intentionally written to flow near the bottom of the page. The goal of this sample is to verify that a paragraph should not be split only because a page boundary appears in the extracted text. In many PDFs, the end of one page and the beginning of the next page still belong to the same logical paragraph. This sample therefore places the final sentence so that it continues across the page break and should still become a single paragraph after the parser removes simple page-level noise such as page numbers or repeated headers.

# Next Section

A new paragraph starts here and should remain separate from the previous one. It exists to confirm that cross-page merging does not accidentally swallow the next real section.

| Product | Region | Status |
| --- | --- | --- |
| Alpha | East | Open |
| Beta | West | Closed |

![image](assets/image01.jpg)
Figure 1. PDF caption

[Visit the example website for details.](https://example.com)

# Pseudo two-column negative sample

LEFT-A1 This paragraph belongs to the left column only.

RIGHT-B1 This paragraph is independent on the right side.

LEFT-A2 It should stay before LEFT-A3 and LEFT-A4.

RIGHT-B2 It should not merge into LEFT-A4.

LEFT-A3 Do not stitch with RIGHT-B1 lines.

RIGHT-B3 Keep local order inside right column.

LEFT-A4 End of left column block.

RIGHT-B4 End of right column block.
