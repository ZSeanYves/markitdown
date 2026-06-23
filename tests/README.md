# tests

Role:
  repo-level regression, architecture guard, and contract coverage

Owns:
  behavior regressions for the active main CLI
  architecture boundary guards
  negative assertions that keep retired roots and obsolete helper paths from returning

Does not own:
  retired-root timelines
  sample payloads
  shell helper implementation

Run:

```bash
moon test tests
```

Notes:
  keep tests aligned with the current stable package layout
  prefer active behavior and boundary guards over historical bookkeeping
