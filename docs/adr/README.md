# Architecture Decision Records

ADRs record decisions that affect public API, package boundaries, dependencies,
compatibility, security, performance or release operations. Use the template in
`0000-template.md`; number records monotonically and never rewrite a superseded
decision. Link the ADR from the implementation PR and the maintenance plan.

## Accepted records

- `0001-phase-0-baseline.md`: freeze the upstream, fixture and toolchain inputs.
- `0002-stable-api-v0.8.md`: establish the stable 0.8 facade.
- `0003-complete-phase-1-boundaries.md`: complete the internal boundary and
  consolidate the package graph after the Phase 0-1 audit.
