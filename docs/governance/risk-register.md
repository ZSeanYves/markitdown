# Phase 0 Risk Register

| ID | Risk | Level | Trigger | Owner | Mitigation |
| --- | --- | --- | --- | --- | --- |
| R-001 | Legacy native runtime symbols reappear through an executable dependency | high | blocking new-native suite fails to link on macOS or Linux | Runtime | Use `core/env` for arguments, isolate process exit in `runtime/process`, and keep the complete new-native suite blocking |
| R-002 | Rolling toolchain changes semantics | high | version mismatch or interface drift | Core | toolchain manifest, CI version check and deliberate baseline update |
| R-003 | Generated `.mbti` changes hide API drift | high | unexpected `moon info` diff | API | API golden review and no manual generated-file edits |
| R-004 | Python benchmark silently moves upstream | high | lock or quality-lab SHA changes | Quality | MarkItDown 0.1.7 pin and immutable baseline check |
| R-005 | Community parser lacks security/conformance | high | dual-run mismatch, fuzz crash or limit bypass | Format | shadow adapter and replacement gate |
| R-006 | External runtime leaks process/filesystem access | high | timeout, fd, temp-file or env leak | Security | direct argv, bounded output, process-group cleanup and fingerprints |
| R-007 | One maintainer is a release single point of failure | high | no backup can run RC checklist | Project | nominate backups and perform dry-run release |
| R-008 | Dirty/generated files contaminate baseline | medium | untracked duplicate `.mbti` or non-clean checkout | Quality | tracked-file collector and CI clean checkout requirement |

Risk status is reviewed in every R2/R3 PR and at each release candidate. Closing
an issue requires evidence, not merely an owner comment.
