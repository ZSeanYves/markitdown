# Native FFI inventory

The product targets Linux x86_64 and macOS arm64. Small host bindings remain
inside their owning input, encoding and CLI packages; the public façade
exposes no FFI handles. There is no Wasm/JavaScript compatibility branch and
no PDFium, Poppler, OCR, transcription or external converter runtime.

## Product bindings

| Boundary | Native source | Ownership and lifetime | Runtime dependency and necessity | Removal condition |
| --- | --- | --- | --- | --- |
| CP932 decoding | `internal/readers/source_io/cp932_native.mbt`, `cp932_native_stub.c` | Input bytes are borrowed. iconv converter and dynamic-library handle close before return. Decoded bytes are copied into owned MoonBit bytes. | Dynamically resolves host iconv: macOS libiconv, Linux libiconv or glibc. Supplies CP932 extension rows and rejects malformed byte sequences; unavailable conversion fails closed. No vendored encoding library remains. | A measured MoonBit implementation or official API matches the CP932 mappings, malformed-input behavior and corpus. |
| Random-access source file | `lib/input/source_cursor_native.mbt`, `source_cursor_native_stub.c` | Borrowed UTF8 path bytes. Small C code opens with `O_NONBLOCK`/`O_CLOEXEC`, verifies a regular file with `fstat`, and holds that descriptor while `async/fs` opens its `/dev/fd/<fd>` bridge. The guard descriptor closes with `defer`; the returned cursor owns the async file and the Path conversion session closes it explicitly. Caller-owned Reader resources remain with the caller. | The C boundary only guards descriptor acquisition and identity; actual size/content I/O uses `moonbitlang/async/fs`, with content reads dispatched through its worker pool. Holding the original descriptor avoids reopening a caller path after a rename/symlink/FIFO swap. No full-input materialization is required for random access. | An official API can safely adopt an already validated descriptor, or provides an equivalent nonblocking regular-file open with the same identity, range/error, ownership and cancellation guarantees. Replacing the guard with an unchecked path reopen is insufficient. |
| CLI stdin | `internal/host/stdin_native.mbt`, `stdin_native_stub.c` | The maximum byte count crosses the boundary; temporary C buffers are freed and returned MoonBit bytes own their payload. | System libc stdin supplies the CLI's existing bounded input operation. | Official async stdio supplies the same bounded short-read, EOF, I/O and cancellation contract, verified against stdin fixtures. |
| Atomic output | `internal/cli/atomic_file_sink.mbt`, `atomic_file_sink_native_stub.c` | Borrowed paths/chunks; opaque writer owns file and temporary path. Commit flushes, fsyncs, closes and renames; abort/finalizer closes and removes uncommitted temporary data. | libc/POSIX mkstemp, write/flush/fsync, rename and unlink preserve atomic path output and cleanup. | An official filesystem API proves the same write-failure, cancellation, cleanup and atomic-rename behavior. |

All four bindings compile as Native C stubs. They depend on the MoonBit C ABI
and the listed system APIs. They do not introduce a second parsing or
conversion engine. Package/link checks on both supported platforms remain
required; this inventory is source evidence, not proof that a hosted platform
or sanitizer gate passed.

### Input cursor validation boundary

The current source implements explicit Path close, borrowed Reader ownership,
short-read filling, known-size premature EOF errors, bounded unknown-size EOF
discovery, and a first-error latch. The C object's finalizer only provides a
fallback for its small guard descriptor; it does not own or finalize the
separate `async/fs` file. Internal tests or helpers that open a Path cursor
directly must close it, or keep a caller-owned input session alive until all
prepared archive reads finish. They must not close a borrowed archive cursor
at the end of preparation while its consumer still needs it.

Validate the descriptor bridge on Linux x86_64 and macOS arm64, including
regular files, a FIFO with no writer, invalid paths/NULs, path replacement,
short reads, early EOF, limits, read failure and cancellation. Keep
`MOONBIT_ASYNC_CHECK_FD_LEAK=1` enabled for the applicable Native tests. Size,
open and cancellation failure paths must release both guard and async-file
ownership; finalization or disabling dependency leak checks is not a pass.
Use evidence for the current frozen binary/source: earlier cursor or Registry
results do not automatically validate this driver, hosted platforms,
sanitizers or long-running FD stability. Current milestone status belongs in
`docs/native-upgrade-progress.md`.

The previous `horideicom/encoding_sjis@0.1.1` dependency and
`cp932_portable.mbt` adapter are removed. The retained Native CP932 path uses
iconv directly.

## Official host dependencies

`moonbitlang/async@0.22.4` supplies asynchronous execution, stdio and filesystem
I/O (including the input cursor's range-read worker pool);
`moonbitlang/x@0.5.5` supplies filesystem and process-exit APIs.
Their Native runtime bindings remain transitive dependencies and must be
included in installation size and toolchain fingerprints. Their handles stay
behind project-owned boundaries. Replacing them requires equivalent ownership,
failure and cancellation semantics, rather than another target compatibility
layer. `moonbit-community/flate@0.8.5` supplies the MoonBit compression code.

## Repository-only process support

`internal/runtime/command/command_native.mbt` and
`path_native_stub.c` implement executable lookup using borrowed UTF-8 paths
and return copied results. `process_runner_native.mbt` and
`process_runner_native_stub.c` implement the existing bounded child-process
test helper: argv bytes are borrowed, copied C allocations have an external
object finalizer, and stdout/stderr cross back as owned copies. The system
dependencies are POSIX executable/file APIs, spawn, pipes, polling, signals
and wait. Its async path uses the official async process API.

The current consumer is `internal/testsupport/hermetic`; the conversion
packages do not import this command boundary. Keep it separate from product
runtime requirements. Remove its custom C implementation once the official
process API meets the same bounded output, timeout, cancellation and reaping
tests, or when repository tests no longer need it. Measurement bindings in
experimental benchmark tools are also tooling, not product capabilities.
