# OOXML Readers

`format_readers/ooxml/` reads OOXML containers and prepares stable source models for upper-layer formats such as DOCX and PPTX.

Main responsibilities:

- package / rels / content-types handling
- DOCX source-model reading
- PPTX source-model reading
- shared Office container structures

Maintenance rules:

- shared container logic belongs in `package/`
- document-specific semantic logic should stay in `docx/` and `pptx/`

Validation:

```bash
moon test
```
