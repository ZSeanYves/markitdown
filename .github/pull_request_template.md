## Change summary

<!-- Describe the user-visible problem and the smallest complete solution. -->

## Scope

- [ ] This PR is limited to one concern (behavior, refactor, dependency, performance, or governance).
- [ ] Non-goals are stated below.

Non-goals:

## Risk and ownership

- Risk: `R0` / `R1` / `R2` / `R3`
- Affected formats/packages:
- Required owner(s):
- Rollback version or procedure:

## Contract and compatibility

- Upstream MarkItDown behavior/vector, if applicable:
- Surface compatibility impact:
- Semantic compatibility impact:
- Operational/security impact (network, external process, resource limits):
- API/CLI/error/golden changes:
- RFC/ADR (`docs/rfcs/...` or `docs/adr/...`) for stable API changes:

## Performance

- Before/after command and platform:
- Wall time / RSS / output size:
- Why the output remains semantically equivalent:

## Verification

Commands run:

```text
paste commands and relevant output here
```

- [ ] `moon fmt --check`
- [ ] `moon info` and expected `.mbti` diff reviewed
- [ ] `moon check --target all --warn-list +73 --deny-warn`
- [ ] Relevant native Tier 1 tests (macOS arm64/Linux x86_64)
- [ ] Contract/regression/coverage/security/performance lane as applicable
- [ ] Python/shell tooling tests as applicable

## Fixtures, dependencies and generated files

- Fixture source/license/hash and behavior protected:
- Dependency/version/license/SBOM change:
- Generated artifacts and regeneration command:
- Golden output explanation (required for every golden change):

## Checklist

- [ ] I have not mixed an unrelated refactor into this PR.
- [ ] I added a regression test before changing an existing golden where possible.
- [ ] I updated capability/limitation, migration or changelog documentation when needed.
- [ ] I did not add Python/network/external-runtime requirements to core installation.
