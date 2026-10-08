# Tools

Repository tooling is divided by responsibility:

- `env/`: optional runtime installation, verification, and deterministic
  wrappers. The product conversion path has no optional runtime installer;
  benchmark-only Python setup lives in `env/installers/install_bench_baseline_deps.sh`.
- `regression/`: coverage, main/quality/accurate gates, mutation smoke,
  release manifests, self-baseline enforcement, and the post-publication
  MoonX consumer gate (`moonx_*.mbtx`).
- `governance/`: immutable baseline, API/architecture, PR, toolchain, and
  documentation policy checks.
- `release/`: deterministic local archive, checksum, and SBOM generation.
  `smoke_capabilities.mbtx` runs the root executable's `--help` and
  `--capabilities` smoke checks for Native or Wasm RC artifacts.

Tools are development and release infrastructure; they are not imported by the
native conversion core. Generated state belongs under ignored `env/` and
`.tmp/` directories unless a reviewed benchmark summary is intentionally
committed under `bench/results/`.

Quality intake validates manifest, catalog, license, provenance, and audit
boundaries before regression execution. Coverage, mutation, packaging, and
benchmark gates consume explicit evidence paths and never infer success from a
non-empty output alone.

See each subtree README for commands and ownership rules.
