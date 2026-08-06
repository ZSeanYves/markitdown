# Security Policy

## Supported versions

Security fixes are applied to the current unreleased `0.8.x` development line
until the first stable release policy is published. After 1.0, security fixes
cover the latest released minor and the previous minor during its published
support window.

## Reporting

Do not open a public issue for a suspected vulnerability. Use GitHub's private
security advisory flow and include an exploit-free reproducer, affected input
format, platform, MoonBit version, observed resource usage, and whether the
issue involves native FFI or an external runtime. Do not attach credentials,
private documents or an unfixed parser crash.

## Security boundaries

Core native readers do not perform network access during conversion. Remote
includes, external XML entities, protocol paths, absolute asset paths, and
parent-directory traversal are rejected or retained as inert references. ZIP
and package formats enforce normalized paths and bounded entry, depth, size,
and recursive-dispatch budgets; nested archives are unsupported. Encrypted PDF,
Office, and ODF inputs fail closed. Document-embedded images remain assets and
are not sent to OCR.

Direct image OCR, audio transcription, and accurate PDF are optional local
integrations. Executable and model fingerprints are recorded under
`env/fingerprints/`; install and verify them through
`tools/env/optional_deps.sh`. Conversion should run with the least filesystem
privileges required for the selected input and output paths.

Core conversion is offline by default. Network access, external processes,
OCR/audio runtimes and cloud services are optional capabilities with explicit
resource limits. External commands use direct argv, bounded output, timeouts
and process-group cleanup.

## Dependency Integrity

GitHub Actions are pinned to commit SHAs. Model archives are pinned by SHA-256.
System tools and Python environments are fingerprinted after installation.
Release archives publish SHA-256 checksums and an SPDX SBOM. The Microsoft
MarkItDown benchmark profile is development-only and is not loaded by the
native product runtime.

## Response targets

- Critical: acknowledge within 2 business days; publish a fix or mitigation as
  soon as a verified release is available.
- High: triage within 5 business days and assign a release target.
- Other: include in the next normal maintenance cycle.

Every security fix adds a regression test, updates
`docs/governance/risk-register.md`, and records affected versions, credits and
rollback instructions.
