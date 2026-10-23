# Fixture policy

The tracked `samples/` tree is a closed, project-owned synthetic fixture set.

## Directory contract

- `fixtures/contracts/<format>/` contains inputs expected to convert
  successfully or through a controlled degradation path. Boundary conditions
  belong here when the supported contract preserves useful output, warnings,
  or diagnostics instead of rejecting the input.
- `fixtures/rejections/<format>/` contains inputs expected to be rejected or to
  fail closed. Tests using these fixtures must assert the controlled error or
  rejection behavior.
- Small malformed values and unit-level boundary cases may remain inline in
  tests when a standalone fixture would not improve readability or reuse.

Do not introduce a general `fixtures/boundaries/` category. A boundary can be
either accepted or rejected, so classify it by its expected observable
contract instead.

## Provenance

Allowed content:

- text authored for this project, including maintainer-reviewed AI-assisted text;
- deterministic document containers generated from that text;
- project-generated geometric images, tones, and other non-semantic media;
- expected outputs derived from allowed inputs.

Not allowed:

- real-world documents, photographs, recordings, or personal data;
- files copied from upstream test suites or public corpora;
- assets whose origin cannot be established from repository history;
- external assets merely because their license permits redistribution.

External compatibility and quality fixtures are maintained under
`markitdown-quality-lab/`. Its manifests and source catalogs record upstream
URLs, licenses, review state, and local cache paths.

## Restored PDF contracts (2026-10-23)

Two contract files had been replaced by the same 38-byte Markdown error
sentinel. The per-file PDF gate now uses their project-owned PDF originals
from the main-regression corpus at quality-lab revision
`eb80a4a3ccc8ca2fa6b39816789a854ba2c20d2c` (the corpus README identifies this
lane as repo-owned; these are not upstream quality fixtures).

| Contract | Source under `external_main_process/` | SHA-256 |
| --- | --- | --- |
| `pdf_metadata_uri_link.pdf` | `pdf/rag/pdf_metadata_uri_link.pdf` | `1dc80185a3c14f585a3fbb4c5abec8c0736730d0555dbf5319ca19b60a1c821d` |
| `pdf_simple_table_like.pdf` | `pdf/markdown/pdf_simple_table_like.pdf` | `534d83ca3dd17738565ae38b5f1705df780d6cff8eeec8da09404652b2ecd707` |

The pre-upgrade source archive and file inventory retain the original
sentinel evidence. No external corpus input or expected output was changed.
