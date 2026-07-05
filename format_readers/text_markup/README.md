# Text Markup Readers

`format_readers/text_markup/` parses text markup languages such as TeX, reStructuredText, and AsciiDoc into stable source models.

Main responsibilities:

- shared lexical and parsing helpers
- TeX source models
- reStructuredText source models
- AsciiDoc source models

Maintenance rules:

- shared parsing foundations belong in `shared/`
- language-specific semantic rules should still stay separated

Validation:

```bash
moon test
```
