# Native FFI inventory

The product keeps FFI behind target-selected files. The parser, IR, rendering,
RAG and resource policy do not call C directly. Wasm selects a portable file or
an explicit fail-closed implementation for each entry below.

| Boundary | Native entry | Data and ownership | Why it remains | Removal condition |
| --- | --- | --- | --- | --- |
| CP932 decoding | `internal/readers/source_io/cp932_native.mbt` and `cp932_native_stub.c` | Borrowed input `Bytes`; returned MoonBit `Bytes` owns the decoded result | No verified portable full CP932 mapping in the current dependency set | A tested Native/Wasm encoding package preserves the current malformed-input and mapping contract |
| Command discovery | `runtime/command/command_native.mbt` and `path_native_stub.c` | Borrowed UTF-8 path/name bytes; C returns a copied path or status | Native tooling may resolve an executable for explicitly enabled extensions | A portable host capability supplies equivalent executable lookup and permission semantics |
| Bounded child process | `runtime/command/process_runner_native.mbt` and `process_runner_native_stub.c` | Borrowed NUL-delimited argv; opaque external result is GC-finalized; stdout/stderr are copied with byte ceilings | Native-only extension boundary for controlled tools; conversion core does not require it | No product extension needs a child process, or an equivalent official cross-target process API meets the same limits |
| CLI stderr | `cli/cli_help.mbt` and `stderr_native_stub.c` | Borrowed UTF-8 bytes, written synchronously; no retained pointer | Native CLI keeps diagnostics on stderr while Wasm uses stdout | A portable stderr sink with the same observable contract is available |
| CLI stdin | `cli/stdin_native.mbt` and `stdin_native_stub.c` | Maximum byte count is passed; returned bytes are owned by MoonBit | Native CLI reads bounded stdin; Wasm reports the unsupported host operation | A Wasm host binding supplies bounded stdin and short-read semantics |
| Atomic output sink | `cli/atomic_file_sink.mbt` and `atomic_file_sink_native_stub.c` | Borrowed path/chunk bytes; opaque writer is GC-finalized; abort removes the temporary path; commit renames once | Native durable Path output needs bounded writes, cleanup and atomic rename | A portable filesystem API provides the same temp-file, fsync, cleanup and rename guarantees |

The benchmark runner has separate measurement and stderr FFI. Those bindings are
not linked into the product executable and are tracked as benchmark tooling.
Native debug/release builds must compile the C stubs; Wasm must compile without
including them. The Wasm CLI deliberately returns an error for unsupported
stdin, external process and atomic Path-output operations rather than buffering
or silently changing their durability semantics.
