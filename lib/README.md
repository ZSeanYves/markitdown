# Stable Native library API

Import `ZSeanYves/markitdown/lib` for the 0.8 public asynchronous conversion
API and façade-owned input, output, option, diagnostic, asset and error types.
The supported platforms are Linux x86_64 and macOS arm64; consumers select the
Native backend in their `moon.mod`.

The generated [interface](pkg.generated.mbti) defines the currently available
surface. See the [API contract](../docs/api-v0.8.md) and
[migration guide](../docs/migration-0.8.md). Internal readers, registries, IR,
pipeline contexts, async handles and FFI values are not supported consumer
imports.

`convert`, the versioned façade and Path/Text/Bytes/sync Reader/async Reader
constructors remain available. The public Sink API, direct bounded async
input access and unified parsing protocol belong to P2 in the
[Native plan](../docs/architecture/native-performance-plan.md); existing
internal helpers do not establish their completion.

Validate an independent Native consumer with
[native installation tooling](../tools/regression/README.md). Local, fixed
Git and post-publication exact-version consumption provide distinct evidence.
Current unit tests do not complete P2–P6 or formal release acceptance.
