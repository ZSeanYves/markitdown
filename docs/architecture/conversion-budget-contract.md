# Conversion budget contract — partial production integration

This document records the proposed shared resource contract required by P2 of
the Native upgrade plan. It does not change the plan or close its acceptance
criteria. The ledger, shared InputSession ownership, source read traffic,
incremental ZIP payloads and final output admission are implemented. New
production defaults, complete format/metadata/IR coverage, cache eviction and
temporary-file management remain **unaccepted and incomplete**. See the
[progress report](../native-upgrade-progress.md) for exact frozen artifacts and
validation boundaries; new edits do not inherit a prior pass.

P4 must use the same units and ownership contract after implementation and
validation. It must not introduce a separate PDF budget or reset the budget
for each page, embedded document or nested container. Numeric defaults and the
exact parsing-work unit remain to be frozen using recorded evidence.

## Verified implementation boundary

`internal/resource_budget` contains a Native-only, synchronous, no-I/O account
with six cumulative kinds (inflate bytes, parsing work, output UTF8 bytes,
source metadata, RAG metadata and read traffic) and four resident kinds (cache,
working, temporary and IR bytes). Its implemented APIs are
`BudgetLimits::new`, `Budget::new/charge/reserve/failure/snapshot/close`, and
`BudgetLease::release`. All ten caps must be supplied explicitly. `Enforced`
rejects a missing cap; explicitly selected `MeasurementOnly` permits `None`
while enforcing any finite cap that is supplied. Neither profile supplies new
production defaults. Production InputSession explicitly selects MeasurementOnly
with no new finite caps; tests supply finite caps to exercise enforcement.

The eleven leaf tests cover exact caps, negative values, overflow, first
failure, shared account/lease handles, repeated release, and cleanup after
failure or close. The narrow Budget + ZIP run passed 43/43 with
`--deny-warn` and `MOONBIT_ASYNC_CHECK_FD_LEAK=1`; the later full Native run
passed 903/903 under the same gates. Logs are
`.audit/2026-10-23-native-upgrade/budget-zip-tests-v1.log` and
`async-native-tests-v6.log` (SHA-256
`df47641c90c352a06b2594431ff34f7825387447b550f7a5f078a7d9a8052be5`).
The leaf's existence alone does not complete P2 or provide a measured default.

The verified async-input archive is `async-input-source.tar` (SHA-256
`ee4050452c0d0e78c8fa075d7b781d48e7a87a7a2f7ab4411b8e85441c635c18`);
`async-input-step.exe` is
`3d28113945301effc44d4b1e04cd80d6fded895e10d165af38d7cdd0f0e431d9`.
Its 935/935 contracts are recorded in `async-input-step-regression/summary.tsv`;
`async-input-comparison/summary.tsv` records 3329 equal and zero unexpected
items against the Registry step under the declared comparison normalization.
Local install v4 and its independent consumer passed, with a 7,462,368-byte
installed executable (`d1df32578f1cf3888d64b3cada20ee661e7eabcfb2dd4b731da0baffd27fcce9`).
These paths are relative to the audit directory above. Git HEAD remains
`035d47a036e7541429113421e67256427c6b3bd7`; the dirty patch/archive, not that
old commit alone, identifies this implementation. Release construction also
retains the external `libtool: warning: 'watch_windows.o' has no symbols`
diagnostic in `async-release-build.log`. No fixed-Git install, Linux result,
formal performance result or P3–P6 acceptance follows from this evidence.

## Existing limits remain in force

The seven existing `ResourceLimits` fields remain independent checks. Their
defaults in `lib/product/options.mbt` must not be increased to make a corpus,
benchmark or new aggregate limit pass.

| Field | Current default | Unit |
| --- | ---: | --- |
| `max_rows` | 2,000 | Rows |
| `max_cols` | 50 | Columns |
| `max_cells` | 100,000 | Cells |
| `max_line_chars` | 4,000 | Existing line-character policy |
| `max_input_bytes` | 512 MiB | Original user input bytes |
| `max_asset_bytes` | 32 MiB | One asset payload |
| `max_total_asset_bytes` | 128 MiB | Asset payloads in one conversion |

New aggregate limits supplement these checks. An archive entry must still
respect its current per-entry request limit even when the conversion has
remaining aggregate capacity or the entry is already cached.

## One conversion owns the ledger

The ledger is implemented in `internal/resource_budget`, with no input,
parser, renderer or conversion dependencies and no I/O. This avoids a
dependency cycle through ZIP and Input.
`InputSession` owns one ledger and the conversion-scope resident leases; input
sources, parser contexts and nested entries borrow that same instance. Cleanup
closes owned handles, releases scope leases, then closes the ledger. Caller-owned
Readers retain caller ownership.

An embedded document or archive entry receives a restricted view of the same
ledger. Its local entry, depth, row or asset constraints may become smaller;
neither cumulative consumption nor available capacity is reset. CLI batch
creates a new conversion scope per input and promptly releases the previous
scope. There is no global or cross-document cache.

The minimum operations are:

```text
Budget.charge(kind: CumulativeKind, amount: Int64) -> Result[Unit, BudgetError]
Budget.reserve(kind: ResidentKind, bytes: Int64) -> Result[BudgetLease, BudgetError]
BudgetLease.release() -> Unit
Budget.failure() -> BudgetError?
Budget.snapshot() -> BudgetSnapshot
Budget.close() -> Result[Unit, BudgetError]
```

These are synchronous ledger operations returning errors as data. They must
not obscure the separate asynchronous cancellation channel. Check negative
amounts and `amount > limit - used` before arithmetic or allocation. A budget
failure becomes the conversion's first fatal resource error; subsequent work
must stop. A syntax, encoding, raw-content or full-part fallback must not
recover from a budget failure.

The leaf does not implement a generic restricted-view framework: copied
`Budget` handles share the same state, while consumers must preserve local
entry/request limits. `close` marks the account closed and reports outstanding
leases without pretending their resources were freed. Release remains valid
after failure/close; closing again after cleanup succeeds while snapshots
retain the first error and peaks. A zero-byte reservation owns no lease.

## Units and accounting

| Quantity | Measurement | Lifetime |
| --- | --- | --- |
| Original input extent | The original source's byte extent; repeated reads do not add to it | Checked against `max_input_bytes` |
| Input read traffic | Actual bytes returned across reads, including repeated reads | Diagnostic/work evidence; not the input extent |
| Inflated bytes | Each produced decompressed byte, including nested containers and repeated real decompression | Cumulative; never refunded |
| Parsing work | Deterministic scanning, node/edge visits and logical expansion work | Cumulative; the exact unit and default still require freezing |
| Decoded representation | Actual decoded bytes/text retained or scanned | Separate from original input; resident storage and parsing work are accounted separately |
| Output | UTF8 bytes actually emitted by the shared output path | Cumulative; count once, whether collected or sent to a Sink |
| Cache | Retained payload bytes and text storage, plus an explicitly defined entry/metadata policy | Resident lease, released after eviction and outstanding borrows end |
| Working memory | Transient compressed, inflated, decoded or parse buffers covered by the contract | Resident lease, released when the owning operation ends |
| Temporary storage | Reserved bytes of registered conversion-owned temporary files | Resident storage lease, released after deletion |
| Source metadata | Source references, source-map entries and their retained fields | Account separately from source input bytes and body text |
| RAG metadata | Chunk metadata, heading paths and source/asset references | Account separately from chunk body text and rendered output |

Record the components of parsing work so a loop reduction cannot silently
change a benchmark's accounting policy. YAML aliases/merges and equivalent
shared structures must charge logical expansion or traversal, not only the
number of physically allocated nodes. A cache hit saves actual decoding work
but does not make repeated logical expansion free.

The cache/work measurements are declared payload accounting, not a claim of
exact process RSS. Bytes payload length and text storage units must be stated
explicitly; MoonBit `String.length()` is not an original-file byte count.
Container entries, metadata keys and values must not allocate first and check
their budget only after materialization.

The collecting API may retain the final body as its result. That retention is
not a second cache. The Sink path must not retain another complete body;
output, source metadata, RAG metadata and assets still have bounded accounting.

The implemented output policy admits each bounded fragment before writing: the current
`Sink.write` result carries no committed-byte count. A write-before-charge
policy cannot enforce the limit, while a charge-before-write counter includes
the admitted fragment even if the callback fails after a partial write. The
measurement report therefore distinguishes admitted UTF8 bytes from
the prefix confirmed by successful writes; the failing fragment's committed
size is unknown. Successful conversions have equal admitted/confirmed values.
Do not refund the failed fragment or label its count as exact committed bytes.

## Raw input and derived representation

`with_text_payload` can turn bounded CP932, Latin1 or UTF16 bytes into a longer
UTF8 representation. Text normalization can also make a representation shorter.
Neither change alters the original user's input size.

The input layer needs private provenance that distinguishes the original
physical source from decoded or container-derived representations. Preserve
the original source identity, effective raw ceiling and verified extent when
attaching a prepared payload. Do not clear the ceiling and do not compare a
decoded UTF8 length to the original-byte limit.

For a derived cursor, `size`, offsets and requested ranges still describe its
current representation. Its decoded/working/cache checks use that
representation's size. The original source cap remains attached to provenance
and continues to constrain original source access. Nested entry bytes consume
entry and shared inflate/work budgets; they do not become an unrelated fresh
user input with a reset conversion budget.

The raw-lineage mechanism is implemented: trusted prepared-payload adapters
preserve physical byte extent, cursor offsets/size describe the current
representation, and manual payload replacement does not inherit the decoder's
proof. `lib/input_lineage_test.mbt` validates an exact-cap Latin1 XML whose UTF8
representation expands and is reused after probing, including Reader short
reads and a smaller raw cap that must reject. Private input tests also exercise
representation offsets independently of raw extent. Broader CP932/UTF16 and
format-consumer coverage remains part of the acceptance matrix; decoded/work
budgets are only connected for the consumers listed below.

Container-derived entry bytes carry an entry ceiling and share the parent
account/session. They do not reuse the compressed root extent as the decoded
entry cap. A 169-byte ZIP expanding into a 5,632-byte text entry is a regression
case; reducing the root cap below 169 still rejects the original input. Trusted
text decode preserves physical-byte proof; ordinary child bytes do not acquire it.

## Leases and caches

Reservations precede allocation or temporary-file growth. Release is
idempotent and explicit. Normal return, read/decode failure, output failure
and cancellation all release operation-owned leases through scoped cleanup.
Conversion cleanup releases remaining caches, handles and registered temporary
files. Garbage collection is not the acceptance mechanism for owned files.

A private cache entry records its charged size, ownership, last use and active
borrows. LRU may evict only entries that are no longer borrowed. Removing a map
key does not justify releasing a lease while a consumer still retains the
payload. A retained borrower needs a scoped borrow or an explicit working
lease/ownership transfer. If all entries are pinned, use a separately bounded
transient path or report budget exhaustion; do not exceed the cache ceiling.

Keep cache authority at one layer for a payload. In particular, OOXML can read
ZIP parts transiently and retain only selected frequently used package parts,
rather than retaining every decoded part in both archive and package caches.
Bytes, decoded text and semantic trees are distinct retained representations;
their lifetimes and charges must be explicit.

The first measurement integration may conservatively hold escaped payload
leases until conversion-scope cleanup. Existing ZIP cache/transient reads and
visitor callbacks expose bare `Bytes`; a caller can retain them after the read
or callback returns. Map eviction or callback completion therefore cannot
justify an early refund. Such scope-retained resident statistics must be
labelled upper bounds, not exact live payload/RSS. Private, non-escaping
scratch buffers may use ordinary scoped leases. This proposal does not by
itself implement LRU or satisfy the enforced cache-lifetime acceptance gate.

Keys remain conversion-local:

- ZIP: archive identity and the validated entry identity/decoding parameters.
- OOXML: package identity, normalized part and decoding/parse parameters.
- PDF: document/object identity, generation and decoding parameters, as needed
  by the P4 object, font, CMap and ObjStm consumers.

Every hit revalidates the current request's size and policy limits. A cache
key must not freeze an earlier, larger request allowance. Deterministic syntax
or decode failures may be cached within the document to avoid repeated work.
I/O failures, cancellation and request/aggregate budget exhaustion must not be
cached as a reusable format failure. Their outcome depends on ownership or
the current budget, and fatal failures must stop the conversion.

## Implemented coverage and remaining consumers

1. Source reads charge actual returned traffic once, including repeated reads.
   Presence getters do not count a payload merely because it exists. Traffic is
   distinct from original input extent.
2. ZIP `read_entry`, `read_entry_transient` and
   `visit_inflated_entry_chunks`: share entry integrity and accounting checks.
   Charge actual produced inflate bytes before retaining or delivering them;
   preserve decoded-size, CRC, path and compression-policy checks. A cache hit
   does not inflate again but still checks `max_output_size`. Nested ZIP work
   charges the same conversion ledger. These paths now share one incremental
   implementation. Failed steps charge actual produced bytes before the codec
   error; budget failure takes priority. Decoder provenance is recorded in
   `internal/inflate/UPSTREAM.md`.
3. Collecting and Sink output use one asynchronous write path. Each fragment
   is admitted once; successful writes add confirmed bytes. Markdown/Debug/RAG
   are covered; existing IR/chunk retention is not thereby measured or removed.
   CLI framing and provenance sidecars are outside body-output units.

Remaining format consumers include:

1. OOXML `read_xml_part_payload`, relationships and XLSX shared strings/styles:
   cache only bounded parts that are reused, with explicit bytes/text leases.
   Media inventory uses declared sizes; actual asset reads retain CRC and
   decoded-size validation. Inventory must not pre-decompress all media before
   asset-budget checks.
2. XLSX worksheet and EPUB chapter consumption: use scoped transient buffers,
   release raw XML/text after lowering, and account separately for retained
   blocks, source references and RAG metadata. A hard read or budget failure
   cannot trigger a whole-part retry.

These are existing consumers, not a general parsing framework or plugin API.
Public library result types must not expose ledger internals or host handles.

CLI provenance adds `budget_usage` with explicit profile/coverage/unmeasured
policies and six decimal-string counters: read traffic, ZIP inflate, admitted
and confirmed output, ZIP cache payload peak and ZIP working payload peak.
Scope-retained peaks are conservative payload upper bounds, not RSS.
`parse_work,source_metadata,rag_metadata,ir,temporary_storage,non_zip_inflate,
non_zip_working_and_cache` remain unmeasured under this policy. A zero ZIP
inflate value for PDF does not measure PDF stream inflation.

The `budget-empty-fixed` freeze has no product XML cursor consumer. The following
P3 content-types migration feeds ZIP chunks into the cursor and retains only its
maps. Map fields reserve scope-owned UTF16 cache payload and charge UTF8 source
metadata before retention; maps publish only after XML EOF and ZIP CRC succeed.
Cursor numeric caps remain MeasurementOnly; the existing 128 MiB part bound is
unchanged.

This migration uses `budget_schema=partial_v2`: resident counters become
`budget_cache_payload_peak_bytes` and `budget_working_payload_peak_bytes`, because
the account now includes content-types cursor/map payloads. It also emits
`budget_parse_work` and `budget_source_metadata_bytes`. Coverage names only
content-types XML work/map metadata; other parsing work/source metadata,
RAG/IR/temp storage, non-ZIP inflate and other resident payloads stay unmeasured.
No new numeric default follows from these partial measurements. The old frozen
binary retains v1; budget profiling must not mix the two schemas.

The subsequent PDF bounded-zlib integration uses `partial_v3`, retaining the
same generic counter fields. `InflateBytes` now includes actual produced PDF
Flate bytes, including failed steps. Its WorkingBytes coverage names only
leased Flate scratch/chunks/aggregation and scope-retained decoded Bytes.
PDF non-Flate filters, predictor copies, Bytes-to-String, token/page/IR and
other workspace remain explicitly unmeasured. ZIP and PDF use the same pinned
`inflater_payload_upper_bound()` allocation model. This model is not a default
resource ceiling or RSS estimate; profile evidence must match the exact schema
and frozen binary rather than mixing it with v1/v2 totals.

The next integrated candidate uses `partial_v4` with the same thirteen fields
and eight counters. It adds the relationship cursor, YAML reference-resolution
admission and the PDF structural session. Historical v1/v2/v3 profiles retain
their exact policies; their maxima must not be combined with v4 maxima. The
regression and budget tools reject a v4 label carrying an older policy.

`ParseWork` in v4 is **modeled_parse_work_units**. It is a cumulative admission
ledger for several declared kinds of work, not a UTF8 byte counter, machine
instruction count, elapsed-time estimate or complete parser cost:

| Consumer | One modeled unit / admission |
| --- | --- |
| OOXML content-types and relationships | Existing cursor UTF8 work; error-only relationship integrity replay also admits the bytes it actually validates |
| YAML reference resolution | One ordinary resolved-value visit; an alias admits its final retained target's logical node count; a merge admits each member copied, including copies later overridden |
| PDF structure probe | One raw tail/metadata-window byte, one resolved xref entry, one uncached metadata-object load, one binary-search comparison, one page-tree visit, or one necessary ObjStm decoded UTF16 code unit |

The YAML anchor cache stores the final retained node count and per-member
weights. It never replays the historical merge work discarded when that value
was created. The creation charges are still cumulative and are not refunded.
The same account is borrowed across documents; overflow and the first finite
limit failure stop preparation before event expansion. Lexical parsing, event
expansion and weight-storage residency are not covered. Default accounts still
use MeasurementOnly; this integration does not establish finite default alias
protection or choose new default limits.

Relationships retain raw `Id`, `Type` and `Target` after single entity decoding.
Their UTF8 payloads, the normalized relationship-part cache key and newly
derived Internal target strings charge SourceMetadata; External targets reuse
the raw string. Corresponding retained String payloads reserve two bytes per
UTF16 code unit. Rows publish only after XML EOF and ZIP CRC; successful reader
and Strict validation reuse them. A recoverable syntax error at a reader that
permits soft recovery performs only an integrity replay before returning that
error. Actual repeated reads/inflation/validation are charged; no retry follows
I/O, cancellation, encoding, CRC or budget failure. Validation issue messages,
temporary trim/source keys and Map/Array/node/allocator overhead remain outside
the model.

The PDF structural session borrows the original live input owner and account.
Its cache model admits twenty scalar payload bytes per resolved xref entry,
four times each metadata source window before fetching/parsing, and four times
each necessary ObjStm decoded String length before member splitting. These
scope-retained payload bounds exclude allocator/Map overhead and parser scratch.
The existing xref resolver has already run before its returned entry count can
be charged; this is explicitly not full xref-work or preallocation coverage.
Ordinary deferred repair can repeat previously attempted work and must charge
it again. A cache hit cannot bypass owner closure or an existing first failure.

The v4 unmeasured policy additionally names full PDF xref parsing/scratch, YAML
lexing/events/weight storage and OOXML validation issues/temporary metadata.
Other parse/source metadata, RAG metadata, IR, temporary storage, non-Flate PDF
filters/predictors/text and other working/cache allocations remain unmeasured.
Neither the mixed work units nor payload peaks establish RSS bounds, default
profile acceptance or completion of P2/P3/P4.

The frozen core/app and indexed-PDF integration uses `partial_v5`, retaining the thirteen fields
and eight canonical string counters. It adds the accepted core/app consumers
and indexed PDF stream ranges. Its exact policy is separate from v4; historical
schema/policy pairs remain strictly validated and their maxima stay separate.
This schema is an instrumentation contract, not an accepted full profile window.

| New scope | Accounting model and lifetime |
| --- | --- |
| Core/app selected values | Existing XML cursor work plus one ParseWork per scalar appended to each selected active value; nesting may append a scalar to more than one selected value |
| Core/app final strings | UTF8 SourceMetadata admission and UTF16 code units × 2 Cache admission before constructing final trimmed strings; static catalog keys and object/container overhead excluded; successful values retained through input scope |
| Core/app private scalar buffers | Working admission of 4 bytes per capacity slot, geometric growth admits old and replacement arrays together; buffers retire at field completion or error/cancellation |
| PDF indexed direct source windows | Working admission of requested window bytes before I/O; release after dictionary/range extraction, as the original full window does not escape |
| PDF non-prepaid dictionary/range metadata | Cache admission of original dictionary byte length × 2 plus 44 numeric-field bytes for a stream range; pre-existing probe objects keep their older 4 × window prepayment rather than charging the same dictionary again |
| PDF consumed stream ranges | Private Working admission of primary length plus a distinct endstream length, plus separate raw-read scratch of their maximum; returned Bytes are explicitly copied, and successful payloads transfer to scope-held ownership synchronously before publication |
| PDF indexed ObjStm members | ParseWork per decoded UTF16 code unit before splitting; Cache payload model 4 × decoded code units + 16 numeric bytes for the identity key; successful entries cached by object ID, selected definition offset and generation in the same session |

The 44-byte range descriptor and 16-byte ObjStm key models exclude references,
Option/enum tags, Map/Array capacity, allocator headers and alignment. ObjStm
parser scratch, decoded text conversions, non-Flate filters/predictors, fonts,
images, SourceCursor internal buffers, full xref parsing and the other v4
unmeasured scopes remain unmeasured. Indexed metadata/global resource surveys
still read their previous windows; repeated stream consumption can read and
retain the same encoded payload again. Neither lazy object reachability nor
page-lifetime cleanup is complete. Missing/unusable indexes still use the owned
repair path. No read-traffic, RSS or timing benefit is inferred from this schema.
All stream cache hits and delayed reads retain owner/first-failure checks.
Budget, I/O and cancellation cannot become a recoverable missing CMap/image or
ordinary framing retry. The legacy v1/v2/v3/v4 policies are unchanged.

The CLI asset integration uses `partial_v6`. It retains the same thirteen
fields/eight counters, exact v5 unmeasured list and
`scope_retained_payload_upper_bound` resident policy. Immediately before
`output_utf8_admission`, its exact coverage adds only
`cli_source_asset_read_traffic,cli_source_asset_scope_cache,cli_source_asset_collection_working`.
The v1-v5 policies remain unchanged and are grouped separately. All runtime
routes use v6, including public-library conversions without CLI SourcePath
activity; the policy does not switch based on whether an asset happened to read.
Extra `cli_source_asset_*` diagnostic metrics are not budget_usage fields.
V6's full binary-bound profile is pending execution. Schema support and scoped
correctness tests do not accept a new profile, defaults or complete budgets.

| V6 added CLI scope | Accounting model and lifetime |
| --- | --- |
| SourcePath actual read traffic | Actual returned content bytes from the admitted opened descriptor, charged to the same outer conversion account; a successfully cached pathname is read once, with no second persistence read |
| SourcePath final Bytes | `size` Cache payload admitted before publication, retained through the outer single/batch owner's cleanup because multiple AssetRefs can borrow it |
| SourcePath private collection | `size + 2 * min(size, 65536)` Working payload before collection allocation: the collection buffer and two bounded native read payloads; released on success/error/cancellation |
| Empty or existing owned payloads | Empty admitted extents return `b""` without a collection buffer/content read/resident lease. Existing Bytes/Utf8 assets undergo per-logical-asset size admission but gain no extra new CLI cache charge |

The consumer supplies the existing 32 MiB single-asset and 128 MiB total-asset
limits. Every logical asset counts toward total admission even when its Bytes
come from the pathname cache. Root physical input extent and asset access extent
remain separate, while owner/account/typed first failure are shared. Metadata
admission and bounded reads use one pinned descriptor; known-size early EOF,
hard reads, first failure and cancellation cannot become a successful missing
placeholder. Only a typed ENOENT probe may preserve the existing missing-asset
contract, frozen for that AssetRef. Other probe errors, including ENOTDIR,
ELOOP and EACCES, remain hard IO failures. A failed/closed parent stops before
new asset probing or opening.

The CLI outer owner spans conversion, admission, persistence and usage refresh
for both single-file and batch calls. Refresh preserves the renderer's actual
confirmed-output count and excludes the provenance sidecar itself. It borrows
the same ledger rather than opening a fresh asset budget. This is descriptor
identity plus actual-byte admission, not a file snapshot or protection from
concurrent external mutation. Output I/O can leave earlier files; multi-file
transactional persistence is not added. SourceMetadata and ParseWork coverage
and units are exactly those of v5; neither gains CLI path/string accounting.
Full metadata/IR/temp/RAG/allocator coverage remains unmeasured as declared.

The accepted local v7 freezes use `partial_v7`, with the same thirteen fields, eight
canonical string counters, profile meanings and
`scope_retained_payload_upper_bound` policy. Its exact coverage extends v6 by
these five items immediately before `output_utf8_admission`:
`ooxml_custom_cursor_and_serialized_value_work,ooxml_custom_name_type_value_metadata,ooxml_custom_namespace_and_value_buffer_payload,ooxml_custom_retained_string_payload,pdf_ranged_font_program_retained_payload`.
Only one unmeasured item changes spelling/scope:
`ooxml_validation_issues_and_temporary_metadata` becomes
`ooxml_validation_issues_and_other_temporary_metadata`; all other items remain
unchanged. V1-v6 policy literals and profile groups are preserved. A v7 label
with old coverage or the old unmeasured item is rejected. Actual v7 profiling
now has independently reviewed1313-sample runs for both custom-font-assets-v7
and the later office-html-literal-v7 freeze, each with its own source, executable
and935 quality sidecars. The later run verifies all1162 source inventory files
against a second archive extraction with zero outside files or drift. Both
recompute10504 raw values and2488 grouped maxima/witnesses. See
[the progress record](../native-upgrade-progress.md) and its exact evidence paths.
These are measurement-only observations, not numeric-default or full-budget
acceptance; schema self-tests alone establish none of those gates.

| V7 added scope | Accounting model and lifetime |
| --- | --- |
| Custom property name, local type and final value | UTF8 SourceMetadata admission and two Cache bytes per UTF16 unit before final String ownership; structural values include serialized wrappers, attributes, namespace context and escaping |
| Custom emitted value work | One modeled ParseWork unit per emitted consumer character, in addition to the existing XML cursor's work; this includes structural serialization and remains a mixed admission unit rather than raw bytes or CPU work |
| Custom name/type and namespace state | Two Working bytes per UTF16 code unit for raw name/local type Strings held across `next()` and active namespace declaration names/URIs; shadowed bindings retain their leases until restoration/scope end |
| Custom value buffers | Four Working bytes per actual Char capacity slot; geometric growth admits old and new arrays together before releasing the old lease. Incomplete values/namespaces retire on completion, recovery, hard failure or cancellation |
| Ranged parsed font programs | After pure parsing, before successful cache publication: three Int32 array capacities × 4, two String-reference array capacities × 8, stored String UTF16 units × 2, four bytes for a present default width, and twenty numeric key bytes. Retain the resulting Cache lease through the outer InputSession because returned program arrays remain borrowed |

Custom properties publish only completed rows after XML EOF/ZIP integrity or
the approved syntax-only integrity replay. Replay charges the actual repeated
read/inflate/cursor work; hard failures do not replay. Duplicate property names
retain array order. Static catalog/part literals and shallow-copy/container/GC
overhead remain unmeasured. Existing visitor chunks still use the conservative
scope-retained model, so the consumer is not claimed constant-memory. The
existing 128 MiB part boundary and explicit MeasurementOnly cursor caps remain;
no new property/depth/token default is inferred.

The parsed-font cache applies only to Ranged streams in the same document and
uses `(object ID, selected absolute definition offset, generation, parser kind)`.
Successful parsed programs, including the existing recoverable empty program,
publish only after live-owner/first-failure checks and Cache admission. Loaded/
repair streams remain uncached. Hard errors retain the existing typed first
failure; cancellation publishes no entry. This stage adds **no ParseWork or
SourceMetadata** for font parsing. Its Native64 capacity/payload model may
conservatively count aliased strings repeatedly and excludes parser scratch,
preparse allocations, temporary maps/sort buffers, object/Map/enum/GC/allocator
headers and alignment. It is neither a unique-heap/RSS model nor a preparse
allocation guard. Existing decoded/encoded Bytes keep their earlier Working
ownership, and are not retained by the parsed-program cache.

## Partial v8: paragraph projection and pending PDF images

The frozen paragraph/JSON/content integration uses `partial_v8`, still thirteen fields, eight
canonical string counters, the existing profile meanings and
`scope_retained_payload_upper_bound`. V1-v7 policies, units and profile groups
remain independently strict. V8 leaves the v7 unmeasured string unchanged and
adds these six exact coverage entries before `output_utf8_admission`:

```text
docx_paragraph_cursor_work
docx_paragraph_selected_string_metadata
docx_paragraph_cursor_and_raw_range_payload
docx_paragraph_retained_string_payload
pdf_pending_image_descriptor_and_reference_buffer_payload
pdf_pending_image_scope_name_utf16_payload
```

The authoritative frozen literals and per-counter measurement scopes are in
the local `budget-v8-policy-contract.json` evidence. ParseWork remains mixed
modeled admission units: the shared XML cursor's deterministic UTF8 decode and
markup/entity work now includes DOCX paragraphs and their synthetic roots.
It does not measure all paragraph processing, lexer instructions or CPU time.

| New scope | Admission and lifetime |
| --- | --- |
| DOCX raw paragraph | Validate Unicode and reserve exact UTF8 Working payload before encoding; scope lasts through semantic dispatch. Complete part/body Strings remain outside this added model. |
| DOCX feed and retained fields | Reserve actual bounded feed-copy bytes, at most64KiB; the cursor separately accounts its decoded/carry/markup scratch. QName and selected field Strings held past `next()` reserve2Working bytes per UTF16 unit through dispatch. |
| DOCX original inline interval | Reserve2Working bytes per raw UTF16 unit before copying the run's original lexical inner interval into the existing semantic helper. Downstream opaque helper allocations remain unmeasured. |
| DOCX escaping selected fields | Selected style/alignment/numbering/run-style and retained raw tag fields charge actual UTF8 SourceMetadata plus2Cache bytes per UTF16 unit before domain retention. Resident credit stays through the outer input session; unused fields are not admitted. |
| PDF pending image descriptors | Native64 field payload is56bytes per item: three8-byte pointers and four8-byte Doubles. The reference buffer charges actual capacity times8. Reserve the complete new buffer before growth, then release the old lease after growth; their temporary overlap is included. Each item is admitted before construction/append. |
| PDF pending image names | Charge2Working bytes per alias UTF16 unit before queue retention, after the existing lexer has produced that name. Credit remains scope-held through the input session because names can escape to source metadata. This is not a guard on the lexer's initial allocation. |

DOCX uses one paragraph-local batch projection with private unbound-prefix
compatibility; a paragraph can approach the existing128MiB part boundary.
There is no new finite depth/token/attribute default here. Complete package
bytes/text, outer body/table scopes, retained domain runs/IR, arrays/Maps,
headers, allocator/GC overhead and remaining semantic helpers remain outside
this additional accounting. Metadata and resident encodings use different
UTF8/UTF16 units; their observed values must not be combined as unique heap.

PDF uses one root-content queue across reachable Forms. Text completes before
actual image/SMask/colorspace IO or CRC checks, and image fulfillment retains
the original depth-first order before the next root content. Item/buffer
leases and references retire on success, failure or cancellation. Alias credit
keeps the documented conservative session lifetime. Growth, length and byte
arithmetic are checked before allocation; this model excludes object/enum/
Array/GC headers, lexer/token and graphics stacks, allocator overhead, final
image/IR payloads and unrelated parser scratch.

Queue admission introduces one explicit error-order boundary: a Working limit
hit during text interpretation terminates immediately, before a later bad Form
CRC; no later reads are attempted. With sufficient queue budget, a text/Form
failure still precedes an earlier queued image's CRC failure, as before.
Neither case may be converted into successful syntax recovery. Removal of a
second Form interpretation is reflected only by actual observed decode/read/
inflate work; cache hits must not be replaced with invented saved charges.

Fresh integrated source/executable, separately executed935 quality sidecars and
1313 sampling have now passed independent v8 review. It recomputed10504 values
and2488 maxima with actual witnesses, checked all1313 raw sidecars, and bound
all1171 source files to the frozen tar and two independent copies. The nine
missing benchmark candidates remain unverified. The accepted v7 measurements
were not inherited by label or unchanged output. Source SHA256 is
`3fa3fd531475f41a5f9d61b2977f0f5ac4152f64b5aa35a88559c8e544b8b058`;
Native executable SHA256 is
`23e5343a69869bde93f1e685995dc34e22995d3b50b1913799a6cc4099be1e3c`.

The new global ParseWork maximum is355911 modeled units on the complex DOCX
quality fixture; increased instrumentation coverage is not a measured timing
regression. Other global maxima are read47586693B, inflate373376428B,
Working373998986B, Cache8127767B, source metadata22296B and admitted/confirmed
output179356432B. Exact values, units and all attaining samples are retained
in `paragraph-json-content-v8-review-preparation/actual-review-v4/` local
evidence. These added models establish neither numeric defaults, complete
P2/P3/P4 budgets, RSS bounds nor timing gains.

## Partial v9: local Ranged CMap retention

The next combined candidate uses `partial_v9` with the same thirteen fields,
eight decimal-string counters, profiles, unmeasured/resident policy and numeric
defaults. Its one new coverage tag is
`pdf_ranged_local_cmap_postparse_retained_payload`. Only the Cache measurement
scope expands; the other seven scopes and ParseWork units remain unchanged.
The proposed literal contract is the local `budget-v9-policy-contract.json`,
SHA2569784f6fac5bbec71d40375be610b6e81e62bb8591c754b156a543fb26673930f.

The cache stores local decode/parse Results before parent lookup, visited/depth
handling or merge. Each full extraction owns a fresh cache; selected Ranged
identity, complete dictionary/decode parameters and framing participate in the
key. Empty successful results and recoverable errors are real hits. Existing
hard CRC/IO/encoding/resource failures and cancellation do not become ordinary
negative entries. Hits require the original live owner without a first hard
failure. Loaded definitions remain outside this cache.

Cache admission occurs after parsing and before publication. The Native64
selected field model counts60B for the key (including an always-present8B
packed Option[Int]),16B for the selected outer Entry's key/value references,
8B for the Result value reference, and40B for successful Info references.
It also counts actual inner-map capacities×8, widths capacity×4, live mapping
key/value references16B or invalid-map key/Bool payload12B, and retained String
contents2B per UTF16 unit by occurrence. Generated C and pinned SDK source
prove these representations; the model does not use padded `sizeof` as a
complete heap bound. Outer cache bucket growth, other map/wrapper bookkeeping,
tags/headers/padding/allocator, and parse/merge scratch remain unmeasured.
Leases conservatively remain through the outer input session.

A finite Cache limit can now terminate immediately after the local parse,
before a later bad parent CRC. This additional admission order is intentional;
the first typed failure is preserved, no failed entry is published and no
later parent read occurs. The model neither admits parser allocation in
advance nor establishes RSS or CPU bounds.

The isolated cache passed14 contracts, strict/info/fmt/release,935 regression
and3329 equal stable outputs, with independent source/C-field review. Five
real PDFs show no Read/Inflate/Working savings; only Cache peaks increase
536B/4344B/842B for hello3/Arabic/images, with Loaded iw9/W4 unchanged. A
separate shared construction demonstrates eight-to-one reads/inflation;
neither result is a formal latency/RSS gain. The integrated main, new source/
executable freeze,935 sidecars and1313 v9 sampling/review remain pending.
Historical v8 observations are not relabeled or inherited.

## Default values and freeze gate

Existing constraints provide reference points, not an invented aggregate
bound: ZIP/EPUB currently limit selected decoded content to 32 MiB and one
selected entry to 8 MiB; the low-level ZIP read default is 128 MiB per entry.
Those checks do not prove a maximum for all Office XML, cumulative nested
inflate, output, metadata or parsing work.

Therefore this document assigns no new unmeasured default numbers. The leaf
uses explicit test limits; next, connect its consumers and record each covered
quantity for the frozen
935-contract corpus and the 126 accepted benchmark inputs, and keep the nine
missing benchmark inputs explicitly unverified. Measurement runs remain under
the existing limits and external process bounds. Record maxima, cumulative
cost, representative large inputs and a documented headroom policy before
freezing the default profile. A new limit may introduce an intentional
rejection, but it must be identified and reviewed, not hidden by widening an
old limit or changing fixtures.

Before P4 depends on the contract, freeze the field names, parsing-work unit,
resident-size accounting, numeric defaults, nested-view policy and failure
mapping together with an evidence fingerprint. Required tests include:

- Exact-limit, over-limit and overflow-safe charges; idempotent lease release.
- A cache populated under a larger request and read under a smaller request.
- LRU eviction with pinned borrowers and deterministic failure-cache behavior.
- Shared exhaustion across nested archives rather than fresh child budgets.
- Cache/transient/visitor parity for CRC, decoded size and budget errors.
- Raw-versus-derived encoding size, source/RAG metadata growth and output
  failure/cancellation cleanup.
- Registered temporary-file deletion and restored resident usage on every
  exit path.

The partial coverage above does not imply complete budget integration,
default-profile acceptance, P2 completion or a P4 performance result.
