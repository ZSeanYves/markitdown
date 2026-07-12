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
