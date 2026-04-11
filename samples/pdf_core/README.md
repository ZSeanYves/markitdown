# PDF Core test_file fixtures

These fixtures are dedicated to low-level PDF native parsing checks.

## Generate fixtures

```bash
python3 samples/pdf_core/generate_phase7_native_fixtures.py
```

This script generates/refreshes the phase-7 boundary fixtures:

- `pdf_native_real_normal_multipage_current_boundary.pdf`
- `pdf_native_real_xref_stream_multipage.pdf`
- `pdf_native_real_objstm_multipage.pdf`
- `pdf_native_real_xref_objstm_multipage.pdf`
- `pdf_native_real_mixed_lang_objstm_simple.pdf`
- `pdf_native_real_font_fallback_multipage.pdf`

Other fixtures in this directory are source-controlled baselines.
