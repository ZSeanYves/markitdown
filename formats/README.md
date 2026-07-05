# Formats

`formats/` owns product-level format registration, capability declaration, and contract metadata.

Main responsibilities:

- formal format registration
- format capability levels
- regression and contract metadata

Main files:

- `registry.mbt`
- `format_contracts.mbt`
- `profile.mbt`

Maintenance rules:

- new formats should be declared here before they are exposed through the CLI
- do not add only a parser without also adding the formal format declaration

Validation:

```bash
moon test
bash samples/check.sh
```
