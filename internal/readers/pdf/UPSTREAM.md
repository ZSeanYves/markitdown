# Bounded PDF zlib adapter provenance

`bounded_zlib.mbt` adapts the framing/exact-body policy of
**`moonbit-community/flate@0.8.5`**, upstream revision
**`3cbcb5c8bde0b34117fd7980b9f41719f2b8f3d7`**.

The exact upstream file is [`flate/zlib/zlib.mbt`](https://github.com/moonbit-community/flate/blob/3cbcb5c8bde0b34117fd7980b9f41719f2b8f3d7/flate/zlib/zlib.mbt).
Its Git blob is **`f65d12e9cc62dc9c0abb18792be33e84a8e00d74`** and SHA256
is **`c944fcf938852cc96d1f9cf1b241a71929405f34936bd34e631088cea7b8332a`**.
The installed pinned source was compared byte-for-byte with a successful GET
of that exact upstream revision; the isolated evidence retains both the fetch
log and fetched file. Initial web-cache/connector transport failures were not
treated as source verification.

Upstream is Apache-2.0. Its complete license is retained at
[`../../inflate/LICENSE`](../../inflate/LICENSE), SHA256
`cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`.
The source file has no separate author-copyright header, and the upstream
source package has no NOTICE file. The local `NOTICE` identifies adaptation
and modifications. This provenance is separate from the raw decoder subset's
[`../../inflate/UPSTREAM.md`](../../inflate/UPSTREAM.md); the zlib wrapper is in
the PDF reader package, not added to that raw-inflate leaf.

| Exact upstream fragment | Adapted role |
| --- | --- |
| `zlib.mbt:38-43`, `u32_be` | Big-endian Adler32 trailer interpretation |
| `zlib.mbt:45-84`, `inflate_exact` | Fixed caller scratch; exact body consumption; trailing-data/truncation categories |
| `zlib.mbt:134-159`, `zlib_decompress` | RFC1950 method/window/header check, no FDICT admission, checksum validation |
| `zlib.mbt:7-28` | Existing ZlibErrorKind taxonomy, still referenced from the pinned dependency |

The raw algorithm is the existing local `internal/inflate` subset at that
revision, including its previously approved failed-step count fix. No encoder,
dictionary decoder, SIMD path or second production backend is copied here.

The adapter preserves the normal framing and exact-consumption policy while
replacing upstream's growing unaccounted Array with private leased chunks and
a leased aggregation Buffer, retaining the returned Bytes allowance with the
owning conversion. It charges actual produced counts before copy, including
a throwing step, and gives typed budget failure priority. Adler32 is updated
incrementally over successful chunks before result publication. The existing
checksum leaf is reused; it is not a new checksum implementation.

Private `PdfHardDecodeFailure` crosses recoverable PDF Result/Option branches,
then the outer source-session boundary latches the hard error and returns a
controlled PdfNativeError. BudgetFailure retains its concrete shared account
error. Cancellation is rethrown in its own async channel. Unsupported filters
and malformed *successfully decoded* font/CMap syntax retain their previous
recovery rules. No resource default, probe/session strategy, text interpretation,
geometry or page lifetime is changed.

Normal tests compare four payloads at four compression levels with pinned
upstream zlib. Further tests cover exact framing/trailer categories, physical
failed-step accounting and budget priority, scratch/returned-Bytes lifecycle,
all optional resource paths, xref fallback suppression, parent/child source
identity, public ZIP→PDF hard rejection and cancellation. Raw 0.8.5 source and
original historical Native baseline evidence remain unchanged. This adapter
establishes no performance gain or complete PDF budget coverage.

## Separate local PDF framing correction

`stream_framing.mbt` and the stream-slice/Length binding changes are local PDF
syntax work. They do not relax or replace this RFC1950 adapter. The slice keeps
the exact marker-bounded source span losslessly as the legacy payload plus its
removed zero-to-two EOL bytes (packed scalar metadata). After the object index
is built, a scalar indirect `/Length` selects its exact span. `/Length1` and
other keys cannot supply `/Length`.

Only a first Flate filter whose selected span returns Truncated or TrailingData
may test source-backed EOL framing candidates. Candidates can only add/remove
the actual CR/LF boundary bytes, never discard non-EOL data or search backwards
for a convenient trailer. Each attempt uses the same strict bounded adapter
and account. Every physically produced byte, including repeats, is charged;
no cumulative counter is refunded. ChecksumMismatch, invalid DEFLATE, budget
failure and all other effects terminate immediately. Hard integrity is latched
at the existing outer PDF source boundary after every allowed framing has
failed. Successful decoding is actually used, so formerly degraded fonts and
image alpha may produce intentional correctness differences requiring review.
The CMap/font syntax, text/geometry algorithms and image encoder are unchanged.
