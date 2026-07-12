# Sample provenance policy

The tracked `samples/` tree is a closed, project-owned synthetic fixture set.

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

