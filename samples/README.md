# Repository Samples

`samples/fixtures/contracts/` contains small, deterministic fixtures required by
`moon test` and CLI smoke tests. They are repository-owned or explicitly
documented in [PROVENANCE.md](./PROVENANCE.md).

These fixtures test one capability or boundary at a time: normal conversion,
structured output, assets, malformed input, resource limits, mode rejection,
and source references. Expected Markdown and asset bytes are checked in only
when they are part of the local contract.

Large, third-party, benchmark, and broad quality corpora do not belong here.
They live in the repo-root `markitdown-quality-lab/` checkout with source URL,
license, SHA-256, provenance, manifest signals, and review status.

After changing local samples, run:

```bash
moon test
./tools/regression/check_balance.sh
```

Do not update an expected file merely to hide lost text, structure, assets,
diagnostics, route fidelity, or source references.
