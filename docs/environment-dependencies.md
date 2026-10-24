# Environment and runtime dependencies

The product supports Native builds on Linux x86_64 and macOS arm64.
Wasm, Wasm-GC and JavaScript product distributions are retired.

## Build and installation

Use MoonBit `0.1.20261021` with
`moonc v0.10.17+093cb8f9c`, Git for pinned source installation, and the
platform C toolchain. CI checks the actual Moon/compiler versions and runner
architecture. Toolchain upgrades require a separate baseline.

The official installer's archive label differs from the `moon` display version:
use `0.10.17+093cb8f9c`, without the compiler display's leading `v`.

```text
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash -s -- '0.10.17+093cb8f9c'
moon version --all
```

The verified official archive SHA-256 values are:

| Archive | SHA-256 |
| --- | --- |
| moonbit-linux-x86_64.tar.gz | e9a52300d137d43d122f26b78d307e08aaaaa644b9fad50ebfd709d7ae927cf6 |
| moonbit-darwin-aarch64.tar.gz | b3155ff869e7feed98a316f0375e0500e0bf5173731a14de9038ca64e58f3e7e |
| core-0.10.17+093cb8f9c.tar.gz | a83410b3e337edf275176291a4532604997f9180fd5ed7a5ba7cf521ff0898e0 |

See the [official binary-verification instructions](https://www.moonbitlang.com/download#verifying-binaries).
The historical archive responses currently declare a 60-day deletion rule;
archiving exact verified downloads is separate from selecting a fixed label.
An expired download must fail rather than silently switching to `latest`.

The CLI is built and installed with `moon install`; the Native library is
imported through `ZSeanYves/markitdown/lib`. Local source, fixed Git revision,
and exact registry installation are different evidence lanes. Registry
confirmation runs after publication; publication is a separate action.

```text
moon install --path .
moon install https://github.com/ZSeanYves/markitdown.git . --rev <full-40-character-sha>
```

After the exact version is published:

```text
moon install ZSeanYves/markitdown@0.8.0
moon add ZSeanYves/markitdown@0.8.0
```

See the [README](../README.md) for consumer configuration and
[Native installation checks](../tools/regression/README.md) for saved evidence.

## Runtime boundary

The retained project C stubs use system libc/POSIX APIs for seekable files,
bounded stdin and atomic output. CP932 decoding dynamically resolves host
iconv and fails closed if the requested conversion is unavailable. Official
MoonBit async and filesystem packages supply their Native runtime bindings.
See the [FFI inventory](ffi-inventory.md) for ownership and remaining P2 work.

The conversion product does not require Python, an OCR/audio model, an
external converter, a browser or a runtime installer. Offline references and
experimental candidate modules are development inputs, not product runtime
dependencies or alternative conversion chains.

## Acceptance boundary

Source compilation does not establish installed CLI behavior. Local
installation does not establish fixed Git or published-version consumption.
The [Native plan](architecture/native-performance-plan.md) keeps P2 execution
and budgets, P3 format migration, P4 PDF optimization, P5 cross-platform RC and
P6 post-publication confirmation as separate unfinished gates.
