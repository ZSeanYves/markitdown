# Lifecycle, worksheet and ObjStm candidate: local acceptance

This report covers one frozen v11 candidate over remotely accepted v10
commit2b0b1fa5. It adds asynchronous input/parser cleanup, pull-reader buffer
retirement, same-ledger temporary-limit tightening/cleanup completion, XLSX
row selection through the shared XML cursor and Ranged ObjStm local Result
reuse. Public temporary options/JSONL spool and Loaded ObjStm ledger work
remain isolated next-step work. Full P2-P6 is unfinished.

## Frozen identity

| Artifact | SHA256 |
| --- | --- |
| Source `lifecycle-xlsx-objstm-v11-source.tar` | `6fa4f11b892fad5f659a87cf4cea69c05d3957ca32680a80252eb26e5d43ad91` |
| Product `lifecycle-xlsx-objstm-v11-step.exe` | `dd230637356e69e1758ccb21553748ef97b370accb54a405d663f76464839a3e` |
| Installed CLI from local-install-v12 | `e671df3916d3d7604d6edd8b4eb300ecbd7a2450b201ae74bbb23772f032b781` |
| partial_v11 policy | `cd507ee09153d10937166c666df146bfb81cdf1c9dbe77489a1b5901d7f34721` |
| Independent sampling review | `2923df26d8e311b86c961c59edaf9d096f9a5d7c4a6eb3aeefd6fbdda632e6d6` |
| Exact v10/v11 output review | `f6a7aeb0f14f02558ef2323b0a6167f948ad990b15bf7086ba78eb3a0d6c85a9` |

Source contains1208 regular shipping files. Product8277408B and installed
CLI8277648B are separate builds. Public facade SHA remains
`b7ff0f06d43a6611e0fccf4efbf4450e5942b46a15b4e8febc8bc6f5acecaeb5`;
the original plan copy is unchanged. All compilation uses the isolated official
moonc0.10.17+093cb8f9c/core, with absolute moon/MOON_HOME/PATH. The global
externally upgraded SDK is preserved and not substituted into these builds.

## Executed gates

- Whole-module strict Native checking, info/fmt and release build pass.
  Debug and release each pass1424/1424 with FD leak checking and warning73
  denied. All51 ordered restoration guards and final50-path hashes pass.
- Complete runner/profiler sources pass Wasm and Native strict checks and
  full selftests. Prior v1-v10 policy sections remain byte-identical; new
  negative controls reject schema/coverage/scope relabeling and invalid counters.
- Fresh standard and separately executed budget sidecars each pass935/935.
  Raw v10 comparison remains3328equal/1unexpected; exact review permits only
  W4 schema/coverage. All eight counters, remaining fields, arrays and numeric
  spelling are exact. Seventeen negative controls reject mutations.
- Actual local installation passes16 phases and a new public-only Native
  consumer. Its separate935/935 passes;3329 stable persisted outputs match
  the source product,0 repairs/0 unexpected.
- New378 benchmark observations and935 quality observations produce1313
  measured samples,0 failed. Nine missing benchmark candidates remain
  explicitly unverified. Independent review recomputes10504 counter values,
 2488 maxima and witnesses, checks every raw counter and binds the complete
  archive plus1208 files in two independent realpath source copies.

These are correctness and partial-accounting gates. No recorded elapsed time
or process memory from these runs is a formal performance observation. The
independent checker executes on Wasm; Native products are the tested subjects.
The unchanged install driver uses its established deny-warn gate. A separate
extra warning73 preflight found two existing redundant qualifiers before any
installation ran; its failed log is retained separately. Product and changed
tool strict gates above explicitly include73.

## Resulting behavior and limits

The first async input scope owns protected serialized cleanup; nested scopes
borrow it. Parser next/finish/close are serialized, inner close runs once,
failed deletion can retry, and earlier operation errors retain priority over
cleanup failures. Close now retires local line/row buffers and queues in
JSONL, CSV/TSV, TXT and subtitles. It does not release caller-owned Readers
or promise a stronger close outcome than the underlying SDK can observe.

The private limit-tightening method preserves the same ledger and leases,
cannot relax a parent limit and leaves usage unchanged on rejected tightening.
Cleanup completion requires returned SDK close plus confirmed owned-path
removal. There is no public temporary cap or production spool in this freeze.

XLSX selects real direct XML rows rather than row-like comment substrings,
including self-closing rows and quoted `>` tags. Actual before controls and
a real2000-comment CLI reproduction fail before and pass after. Recovery
drains the independent integrity path; CRC/encoding/I/O/budget failures remain
hard errors. Cursor work/workspace are measured; raw selection buffers remain
unmeasured. Existing output and source contracts are preserved by the corpus.

Ranged ObjStm results are document-local and keyed by selected identity,
dictionary, offsets and framing. Whole parse Ok/ordinary Err are cached;
member lookup, visited/depth decisions, repair and Loaded inputs remain
outside this cache. Hard errors/cancellation are not published. Actual entry
counts and Inflate reductions in component controls are operation evidence.
The Cache model covers selected Native64 postparse fields and UTF16 payload;
outer map/allocator/parser scratch remain excluded. It is not actual Heap/RSS.

partial_v11 adds only the three declared XLSX/ObjStm coverage labels and
changes ParseWork/Working/Cache scopes. Five other scopes, eight units,
13-field shape and numeric limits remain equal to v10. Actual quality-sidecar
changes are confined to these dimensions; old observations retain their
schema. Defaults, complete IR/RAG/source/temp budgets, remaining XML consumers,
PDF page lifecycle/geometry and formal two-window/60-minute reliability
acceptance remain unfinished.

Remote acceptance is now complete at exact commit
`f910d979f4cbea6f90dbfe62aad97018cd1e2a10`: Native CI40068757028 and
fixed-Git RC40068810324 both succeed on Linux and macOS. Each platform passes
1424 debug/release tests and installed935/935 with a fresh library consumer.
Complete artifact ZIP digests match GitHub. The raw cross-platform comparison
remains3285equal/44unexpected; exact review explains363 leaves as272 input
paths,84 chunk IDs and7 boundary keys, with0 unproven and10 rejecting mutation
controls. Full metadata, logs and review are in local `v11-remote-acceptance/`.

Only the progress/budget reports and this acceptance report may change after
the source freeze; the candidate shipping manifest must prove all other files
exact before push. The completed remote gates cover that pushed candidate
commit. This report is neither a full RC nor publication.
