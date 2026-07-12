# Tools

Repository tooling is divided by responsibility:

- `env/`: optional runtime installation, verification, and deterministic
  wrappers. Use `env/optional_deps.sh` as the public entrypoint.
- `regression/`: coverage, main/quality/accurate gates, mutation smoke,
  release manifests, and self-baseline enforcement.

Tools are development and release infrastructure; they are not imported by the
native conversion core. Generated state belongs under ignored `env/`, `.tmp/` directories.

See each subtree README for commands and ownership rules.
