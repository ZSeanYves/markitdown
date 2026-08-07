# Tools

Repository tooling is divided by responsibility:

- `env/`: optional runtime installation, verification, and deterministic
  wrappers. Use `env/optional_deps.sh` as the public entrypoint.
- `regression/`: coverage, main/quality/accurate gates, mutation smoke,
  release manifests, and self-baseline enforcement.
- `governance/`: immutable baseline, API/architecture, PR, toolchain, and
  documentation policy checks.
- `release/`: deterministic local archive, checksum, and SBOM generation.

Tools are development and release infrastructure; they are not imported by the
native conversion core. Generated state belongs under ignored `env/` and
`.tmp/` directories unless a reviewed benchmark summary is intentionally
committed under `bench/results/`.

Quality intake validates manifest, catalog, license, provenance, and audit
boundaries before regression execution. Coverage, mutation, packaging, and
benchmark gates consume explicit evidence paths and never infer success from a
non-empty output alone.

See each subtree README for commands and ownership rules.
