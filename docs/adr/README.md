# Architecture Decision Records

ADRs record decisions that affect public API, package boundaries, dependencies,
compatibility, security, performance or release operations. Use the template in
`0000-template.md`; number records monotonically and never rewrite a superseded
decision. Link the ADR from the implementation PR.

## Current decision

- [0008: Native-only delivery and staged acceptance](0008-native-only-delivery-and-acceptance.md)
  supersedes ADR 0006/0007 product target and delivery/acceptance policy.
  It records the accepted direction, not completed implementation or RC.
  Its implementation, performance and publication gates remain independent.

## Historical records

Records below retain their original decisions and evidence. Current target,
delivery and acceptance instructions follow ADR 0008.

- `0001-phase-0-baseline.md`: freeze the upstream, fixture and toolchain inputs.
- `0002-stable-api-v0.8.md`: establish the stable 0.8 facade.
- `0003-complete-phase-1-boundaries.md`: complete the internal boundary and
  consolidate the package graph after the Phase 0-1 audit.
- `0004-normalize-source-root.md`: make `src/` the only MoonBit source root
  without changing published package names.
- `0005-phase-2-compatibility-lab.md`: establish the pinned contract corpus,
  structural diff taxonomy, and capability-tier evidence gate.
- `0006-shared-text-runtime.md`: adopt one asynchronous text runtime, Wasm as
  the common capability base, minimal Native extensions and evidence-led reuse.
- `0007-moonx-consumer-gate-and-mode-boundary.md`: former sole MoonX consumer
  gate and preserved text-mode meanings; target and delivery policy superseded.
