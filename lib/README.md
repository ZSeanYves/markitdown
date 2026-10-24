# Stable Native library API

Import `ZSeanYves/markitdown/lib` for the 0.8 public asynchronous conversion
API and façade-owned input, output, option, diagnostic, asset and error types.
The supported platforms are Linux x86_64 and macOS arm64; consumers select the
Native backend in their `moon.mod`.

The generated [interface](pkg.generated.mbti) defines the currently available
surface. See the [usage examples](../README.md) and
[Native delivery decision](../docs/adr/0008-native-only-delivery-and-acceptance.md).
Internal readers, registries, IR, pipeline contexts, async handles and FFI
values are not supported consumer imports.

`convert` collects the output; `convert_to_sink` delivers output through a
caller-provided Sink. The versioned façade and Path/Text/Bytes/sync Reader/async
Reader constructors remain available. Complete execution and resource-budget
acceptance remains separate from the availability of these entrypoints.

Validate an independent Native consumer with
[native installation tooling](../tools/regression/README.md). Local, fixed
Git and post-publication exact-version consumption provide distinct evidence.
Current unit tests do not complete P2–P6 or formal release acceptance.
