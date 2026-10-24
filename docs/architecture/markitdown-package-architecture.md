# Package architecture for the Native CLI and library

The root executable is installed with `moon install`; consumers import the
Native library through its public façade. There is one product execution chain
for Linux x86_64 and macOS arm64. The current policy is recorded in
[ADR 0008](../adr/0008-native-only-delivery-and-acceptance.md).

```text
main.mbt + moon.pkg
        |
        +-- internal/cli          argument parsing, diagnostics and exit policy
        +-- internal/host         Native process I/O
        +-- lib                   public façade and shared product/domain code
            +-- input             input ownership and detection
            +-- convert           one async conversion entry
            +-- core/product/rag  public result and policy models
            +-- formats/render    shared format and output layers
        +-- internal              parsers, readers, pipeline, runtime and tests
```

`main.mbt` only composes the CLI and process boundary. Consumers import
`ZSeanYves/markitdown/lib`; no consumer needs to know the parser, reader,
pipeline, or FFI package names. Internal packages may depend on `lib` domain
packages and on lower internal layers, but `lib` never depends on the root
executable.

The module declares `preferred_target = "native"` and product packages support
Native only. Small FFI components have explicit ownership and necessity in the
[inventory](../ffi-inventory.md).

The call chain is asynchronous at its resource boundaries:

```text
Input -> detection/capability check -> ParserRegistry (async parse/open/next/finish)
      -> ParseResult or bounded pull -> shared IR/pipeline -> renderer/sink
```

Pure AST, semantic and rendering transforms remain synchronous. Path resources
created by conversion are closed by the conversion owner; caller-owned Reader
resources remain with the caller. Cancellation, short reads, output failures,
and cleanup belong to the same execution protocol. Aggregate cache/work and
temporary-storage budgets remain open items in the upgrade progress report.

`Input::from_async_reader` is the public asynchronous random-access contract.
Path, Bytes, Text and both Reader constructors use the same bounded async
cursor. Prefix/fixed-range reads handle short reads, and unknown-size ZIPs
locate EOF without a whole-input bridge. Tree formats still collect selected
text where their current semantics require it; CSV/JSONL retain multipass
ordering. This does not establish complete bounded memory for all formats.

The package graph deliberately has no compatibility `src/` root. Historical
ADRs may mention the former layout, but current governance and release checks
validate the root executable, `lib/`, and `internal/` layout directly.

The executable package is the repository root. The local smoke command is
`moon run --target native . -- --capabilities`; an exact-version installed
consumer uses `moon install ZSeanYves/markitdown@<version>` and invokes the
installed executable. Standalone `.mbtx` acceptance tools inspect actual
Native artifacts and are separate from product delivery.
