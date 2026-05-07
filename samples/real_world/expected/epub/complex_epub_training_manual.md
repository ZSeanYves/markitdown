![cover.jpg](assets/archive/OEBPS_images_cover.jpg/image01.jpg)

# Table of Contents

- [Program Overview](text/chapter-01.xhtml)
- [Release Workflow](text/chapter-02.xhtml)
- [Operational Checklist](text/chapter-03.xhtml)
- [Scenario Matrix](text/chapter-04.xhtml)
- [Visual Guide](text/chapter-05.xhtml)
- [Anchors And References](text/chapter-06.xhtml)

# OEBPS/text/chapter-01.xhtml

# Program Overview

This training manual introduces the operational model for a document conversion service that values stable Markdown, explicit policies, and reproducible validation.

Readers should treat the handbook as a working artifact rather than a marketing brochure.

# OEBPS/text/chapter-02.xhtml

# Release Workflow

1. Build a native binary.
1. Refresh the registry index.
1. Run sample validation.
1. Escalate only after evidence review.

Each step should preserve traceability across README guidance, sample corpora, and metadata sidecars.

# OEBPS/text/chapter-03.xhtml

# Operational Checklist

- confirm checked-in fixtures
- inspect local assets
- review warnings
- capture release notes

Nested procedures appear later in the appendix.

# OEBPS/text/chapter-04.xhtml

# Scenario Matrix

| Scenario | Primary Risk | Fallback |
| --- | --- | --- |
| Large DOCX | layout ambiguity | preserve structural headings |
| Native text-PDF | header noise | keep text-scope boundaries explicit |

# OEBPS/text/chapter-05.xhtml

# Visual Guide

The manual includes local illustrations for cover and in-chapter extraction checks.

# OEBPS/text/chapter-06.xhtml

# Anchors And References

Use internal anchors like [the top-level table of contents](nav.xhtml#toc-top) and local cross references such as [appendix note](#appendix-note).

### Appendix Note

Anchor handling should remain readable after Markdown conversion.
