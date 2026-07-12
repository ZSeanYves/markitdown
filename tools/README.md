# Tools

Repository tooling is divided by responsibility:

- `env/`: optional runtime installation, verification, and deterministic
  wrappers. Use `env/optional_deps.sh` as the public entrypoint.
- `regression/`: coverage, main/quality/accurate gates, mutation smoke,
  release manifests, and self-baseline enforcement.
- `release/`: deterministic binary archives, SHA-256 files, and SPDX SBOMs for
  GitHub Releases.

Tools are development and release infrastructure; they are not imported by the
native conversion core. Generated state belongs under ignored `env/`, `.tmp/`,
or `dist/` directories.

See each subtree README for commands and ownership rules.
