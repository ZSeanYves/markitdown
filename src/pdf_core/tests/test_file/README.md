# PDF Core test_file fixtures

These fixtures are dedicated to low-level PDF native parsing checks.

## Generate fixtures

```bash
python3 src/pdf_core/tests/test_file/generate_phase5_native_test_files.py
```

This generates:

- `pdf_native_real_en_single_page.pdf`
- `pdf_native_real_zh_single_page.pdf`
- `pdf_native_real_text_multipage.pdf`
- `pdf_native_real_tounicode_basic.pdf`
- `pdf_native_real_header_footer_simple.pdf`

and corresponding `*.expected.md` files in the same directory.
