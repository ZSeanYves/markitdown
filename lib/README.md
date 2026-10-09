# Stable library API

This is the sole compatibility-stable library package for the 0.8 release
line. Import `ZSeanYves/markitdown/lib` for asynchronous conversion and the
facade-owned input, output, option, diagnostic, asset, and error models.

Its generated interface is reviewed against `pkg.generated.mbti`. Read the
[API contract](../docs/api-v0.8.md) and [migration guide](../docs/migration-0.8.md)
for usage and compatibility boundaries. Internal readers, parser registries,
IR, and runtime adapters are not supported consumer imports.
