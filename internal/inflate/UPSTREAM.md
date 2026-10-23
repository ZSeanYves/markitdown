# Streaming inflate subset

Upstream: [moonbit-community/flate](https://github.com/moonbit-community/flate), published module `moonbit-community/flate@0.8.5`.

Exact matching revision: **`3cbcb5c8bde0b34117fd7980b9f41719f2b8f3d7`**. The installed source was compared against that revision before copying. Apache-2.0 `LICENSE` is copied verbatim; its SHA256 is `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`. The upstream source package had no separate `NOTICE`; the local `NOTICE` identifies this subset and modification.

| Original file | Selected upstream lines / blocks | Original Git blob | Original SHA256 |
| --- | --- | --- | --- |
| `flate/inflate.mbt` | Complete file, 1–820 | `16df6f56a3df3d07c6ddbebc7f6ae9e053d0a134` | `6985b512691259fdb6e000936802054d37611ed6620e0c5f95038836365d28c2` |
| `flate/decode_rules.mbt` | Complete file, 1–133 | `526b6e43b09368bf12b42e18995653ff78c37f84` | `f7c3069acbd6b324a2d60ebbfcea62c087c488872cbfb6dbde4da0cd54b6ef7c` |
| `flate/huffman_table.mbt` | 1–149: decoder, initialization and fixed decoder | `8cf869fe7c8cda5a09a59fc04821d2c0838d50e2` | `f8575ce3cd8d2d0287a26c6d9513386e629673bb12b2538dec38ed78baa1dc48` |
| `flate/tables.mbt` | 1–44, 61–81, 164–195: required decode constants / information / bit reversal | `ee299ddb634d0fdd960454781847538b306cee3a` | `49ba8a1ae9e61151e2df9593a0d5ec2fa02dafb1a2a7d1f490aa8488eac6c411` |
| `flate/status.mbt` | 1–20: `Status` and its derived methods | `0eb077c0ddfd305ab48d819a43ef48a0803bcb68` | `3f5a4c59bad7dcbeadffb9044fd79bb4c7ecfdba0cee961d183eb3f23d29d14d` |

The encoder, whole-buffer decoder, native SIMD metadata, gzip/zlib/container wrappers and unrelated backend paths are omitted. No non-core runtime import is required. The external flate module remains an explicit test oracle / encoder dependency and is still used by other unconverted consumers such as PDF; this subset does not claim all product compression has been unified.

The subsequent PDF resource-correctness adapter lives separately in
`internal/readers/pdf/bounded_zlib.mbt`; it is not a zlib wrapper inside this raw
leaf. Its exact pinned wrapper source, license and local changes are registered
in `internal/readers/pdf/UPSTREAM.md`. PDF user Flate streams use this shared
raw decoder through that adapter, while trusted compiled-in PDF blobs and PNG
encoding still use the external package. `allocation_model.mbt` is a local
accessor for the previously reviewed payload allocation bound, not a new
upstream decoding algorithm or a production resource limit.

## Local modification

`Inflater::release_step_views` saves `in_pos` and `out_pos` into the per-step consumed/produced counters **before** clearing borrowed input/output references. Upstream left these counters zero when the call raised even if output scratch already contained decoded bytes. Counter comments describe the changed internal contract. Normal `finish_step`, terminal failure, reset, decoded bytes, state-machine statuses and errors retain the pinned implementation's behavior.

The fixed project toolchain also normalizes the copied source mechanically: `Int` / `UInt` are printed as `Int32` / `UInt32`, defaulted label syntax uses `~`, and block separators / whitespace follow `moon fmt`. Those changes do not introduce a decoder algorithm change. A source review compared the other four selected files after only these canonical aliases and trivia; they contain the selected upstream blocks without additional logic changes. The inflate-file logic delta remains the two counter assignments before view cleanup.

Failed output is never valid content to deliver. The shared ZIP emitter charges its physical produced count, then returns the codec error. If that charge exhausts the owning conversion account, the typed budget error takes priority. Repeated calls after terminal failure clear the new call's counts to zero.

The pre-change runtime evidence is `.audit/2026-10-23-native-upgrade/repro-flate-error-count.log`: a valid non-final stored block writes `A`, the next header has reserved BTYPE=3, scratch byte is 65 while upstream `last_produced=0`. Local tests cover both output APIs, physical EOF after partial output, cleanup of borrowed views, stable failure/reset, valid output/status/count differential behavior and ZIP accounting/error priority.

This P2 correctness candidate is the common baseline for subsequent algorithm measurements. The historical Native baseline and its original failure evidence remain unchanged. The vendoring itself makes no performance claim.
