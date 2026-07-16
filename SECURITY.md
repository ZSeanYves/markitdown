# Security Policy

## Supported Versions

Security fixes are applied to the current unreleased `0.7.x` development line
until the first stable release policy is published.

## Reporting

Do not open a public issue for a suspected vulnerability. Use GitHub private
vulnerability reporting and include a reproducer, input format, platform,
MoonBit version, and observed resource usage.

## Trust Boundaries

- Core native readers do not perform network access during conversion.
- Remote includes, external XML entities, protocol paths, absolute asset paths,
  and parent-directory traversal are rejected or retained as inert references.
- ZIP and package formats enforce normalized paths and bounded entry, depth,
  size, and recursive-dispatch budgets. Nested archives are unsupported.
- Encrypted PDF, Office, and ODF inputs are unsupported and fail closed.
- Document-embedded images are exported as assets and are not sent to OCR.
- Direct image OCR, audio transcription, and PDF accurate are optional local
  integrations. Executable and model fingerprints are recorded under
  `env/fingerprints/` and should be reviewed in controlled deployments.
- Install and verify optional runtimes through
  `tools/env/optional_deps.sh`; direct compatibility installers under
  `tools/env/installers/` are not separate trust paths.
- Conversion should run with the least filesystem privileges required for the
  selected input and output paths.

## Dependency Integrity

GitHub Actions are pinned to commit SHAs. Model archives are pinned by SHA-256.
System tools and Python environments are fingerprinted after installation.
Release archives publish SHA-256 checksums and an SPDX SBOM.
The Microsoft MarkItDown benchmark profile is development-only and is not
loaded by the native product runtime.
