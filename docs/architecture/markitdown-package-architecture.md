# Package architecture for moonx

The repository follows the package boundaries used by the `cygpath` binary so
that the registry package and the executable are both usable from `moonx`.
There is one product execution chain. Target differences are contained at the
host boundary and do not create a second converter.

```text
main.mbt + moon.pkg
        |
        +-- internal/cli          argument parsing, diagnostics and exit policy
        +-- internal/host         target-specific I/O and Native extensions
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

The module declares `preferred_target = "wasm"`. Every public conversion path
therefore compiles with the portable target. Native builds use the same parser,
IR, pipeline, renderer, and sink protocol. `internal/host` may add a small
Native implementation when a portable equivalent does not exist; the extension
is capability-registered and failure remains explicit when it is unavailable.

The call chain is asynchronous at its resource boundaries:

```text
Input -> detection/capability check -> UnifiedParserRegistry
      -> ParseResult or bounded pull -> shared IR/pipeline -> renderer/sink
```

Pure AST, semantic and rendering transforms remain synchronous. Path resources
created by conversion are closed by the conversion owner; caller-owned Reader
resources remain with the caller. Cancellation, short reads, output failures,
and temporary-file cleanup use the same error mapping on Native and Wasm.

`Input::from_async_reader` is the public asynchronous random-access contract.
During this migration window the shared detector/parser path consumes that
reader through one bounded materialization under the input budget, then enters
the same chain as every other input. This keeps one parser executor and the
same failure policy while direct async random access is added format by format;
it does not claim zero-copy streaming for every package reader.

The package graph deliberately has no compatibility `src/` root. Historical
ADRs may mention the former layout, but current governance and release checks
validate the root executable, `lib/`, and `internal/` layout directly.

The executable package is the repository root, so the local Wasm smoke command
is `moon run --target wasm . -- --capabilities`. A registry consumer invokes
the same root package as `moonx ZSeanYves/markitdown@<version>`.
