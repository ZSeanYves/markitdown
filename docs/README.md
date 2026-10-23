# Documentation index

The current product is a Native library and CLI for Linux x86_64 and macOS
arm64. The [Native upgrade plan](architecture/native-performance-plan.md) is
the source of truth for scope, staged work and acceptance. Local fixes and
passing tests do not establish completion of P2–P6.

## Start here

| Need | Read |
| --- | --- |
| Supported formats, modes and limitations | [Capabilities and limitations](capabilities-and-limitations.md) |
| Install and run the Native CLI | [Root README](../README.md), [CLI guide](cli-usage-guide.md) |
| Import the Native public library | [API 0.8](api-v0.8.md), [library package](../lib/README.md) |
| Migrate an existing integration | [Migration to 0.8](migration-0.8.md) |
| Check Native artifacts and installation | [Regression tools](../tools/regression/README.md) |
| Review measured results and missing gates | [Performance](performance.md), [release candidate](release-candidate.md) |

## Implementation and dependencies

- [Environment](environment-dependencies.md): pinned toolchain, Native build
  requirements and host dependencies.
- [Compatibility matrix](compatibility-matrix.md): supported platforms and
  the contracts that must be checked.
- [FFI inventory](ffi-inventory.md): necessity, ownership, dependencies and
  removal conditions.
- [Dependency register](dependency-register.md): retained packages and
  experiment boundaries.
- [ADR 0008](adr/0008-native-only-delivery-and-acceptance.md): the Native-only
  target, delivery and acceptance decision.
- [Architecture records](adr/README.md): current decisions and preserved
  historical evidence.

## Maintenance and release

- [Contributing](../CONTRIBUTING.md)
- [Release checklist](governance/release-checklist.md)
- [Branch protection](governance/branch-protection.md)
- [Maintainer responsibilities](maintainer-responsibilities.md)
- [Risk register](governance/risk-register.md)
- [RFC template](rfcs/0000-template.md)

The active automation is documented in [tools](../tools/README.md). It tests
actual Native executables and independent public-library consumers. The
historical MoonX package runners are retired; standalone scripts may still
use the toolchain's script runtime.

## Historical records

[Native/Wasm upgrade](native-wasm-upgrade.md), older ADRs, architecture
proposals and compatibility experiments preserve their original commands,
targets and results. Their historical target/delivery instructions are
superseded by the current Native plan. They do not certify a current
installation, benchmark, platform, RC or publication gate.

Generated interfaces, output goldens, corpus hashes and saved command logs
are evidence. Update them through their owning checks. Keep historical
decisions intact and supersede changed policy with a new ADR.
