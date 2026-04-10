# PDF Core test_file fixtures

These fixtures are dedicated to low-level PDF native parsing checks.

## Generate fixtures

```bash
python3 samples/pdf_core/generate_phase7_native_fixtures.py
```

This generates:

- `pdf_native_real_en_single_page.pdf`
- `pdf_native_real_zh_single_page.pdf`
- `pdf_native_real_text_multipage.pdf`
- `pdf_native_real_tounicode_basic.pdf`
- `pdf_native_real_header_footer_simple.pdf`
- `pdf_native_real_xref_stream_simple.pdf`
- `pdf_native_real_objstm_simple.pdf`
- `pdf_native_real_xref_objstm_simple_text.pdf`
- `pdf_native_real_simple_font_fallback.pdf`

and corresponding `*.expected.md` files in the same directory.
