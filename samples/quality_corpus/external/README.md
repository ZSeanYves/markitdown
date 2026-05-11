# External Cache Convention

This tracked directory documents the local cache convention for externally
curated quality samples.

Actual cached files belong under:

```text
.external/quality_corpus/
  markitdown/
  pandoc/
  paddleocr/
  tablebank/
  cdla/
  publaynet/
```

Rules:

* `.external/` is local-only and must not be committed
* external samples require manual license review before any execution row is
  approved
* do not bulk vendor upstream fixtures or datasets into the repository
* large datasets should be sampled manually, not mirrored wholesale
* curated rows should point at local cache files through
  `external_manifest.local.tsv`, not by copying source files into `samples/`

Recommended workflow:

1. Prepare local cache directories with
   `bash ./samples/quality_corpus/tools/fetch_external_samples.sh --prepare-cache`
2. Manually download or sparse-checkout a small reviewed subset into
   `.external/quality_corpus/...`
3. Add reviewed rows to `samples/quality_corpus/external_manifest.local.tsv`
4. Keep private or locally cached artifacts out of git
