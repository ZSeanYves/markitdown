# Repository Samples

`samples/fixtures/contracts/` contains small, deterministic fixtures required by
`moon test` and CLI smoke tests. Their origin and admissibility rules are
documented in [fixtures/PROVENANCE.md](./fixtures/PROVENANCE.md).

`samples/showcase/` is the separate, size-bounded demonstration set. It contains
one substantive real-world example for every core balanced input extension,
with exact source, hash, license, and derivation records in its
[manifest](./showcase/MANIFEST.tsv).

These fixtures test one capability or boundary at a time: normal conversion,
structured output, assets, malformed input, resource limits, mode rejection,
and source references. Expected Markdown and asset bytes are checked in only
when they are part of the local contract.

Large third-party, benchmark, and broad quality corpora do not belong here.
They live in the repo-root `markitdown-quality-lab/` checkout. The only external
content admitted to the main repository is the reviewed showcase and its local
legal evidence.

After changing local samples, run:

```bash
moon test
./tools/regression/check_balance.sh
```

Do not update an expected file merely to hide lost text, structure, assets,
diagnostics, route fidelity, or source references.
