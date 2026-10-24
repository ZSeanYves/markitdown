# Conversion resource account

This leaf package contains synchronous accounting only. It performs no I/O,
defines no production defaults, and imports no input/parser/convert package.
InputSession now owns this account and its retained leases, and input read
traffic is connected to it. ZIP/Sink integration and complete dimension
coverage still require validation; this does not complete P2 or freeze the
defaults in the architecture design record.

Supply all ten optional limits explicitly to `BudgetLimits::new`. `Enforced`
requires every cap to be finite and nonnegative. `MeasurementOnly` explicitly
allows `None`; finite caps in that profile still apply. Even measurement
accounts reject negative charges and Int64 overflow.
`BudgetLimits::measurement_only` explicitly constructs the all-unbounded
measurement profile without selecting finite production defaults. Zero in
an uninstrumented dimension is not evidence of zero consumption.

`BudgetContext` borrows an account and a conversion-owned `retain_resident`
callback. It does not own cleanup. The callback reserves capacity and keeps
the resulting lease until scope cleanup; it does not refund escaped payloads
on map eviction or callback completion. `budget_error_message` supplies a
shared diagnostic without replacing the typed error.

Charge cumulative work before doing it, and reserve resident capacity before
allocation or file growth. First failure blocks all subsequent charges and
reservations, including zero amounts. Release remains valid and idempotent
after failure or close. Zero-byte reservations own no capacity.

`close` marks the account closed without pretending live leases were freed.
It reports outstanding leases and latches that violation if no earlier error
exists. Release the resources and their leases, then a repeated close returns
`Ok`; the first error and resident peaks remain observable in snapshots.
Closing a clean account is idempotent. New work after a clean close fails with
`Closed`.

Copies of `Budget` share the same account. Nested consumers must borrow it,
not create a fresh account. Local per-entry/request checks remain the
consumer's responsibility; this package does not introduce a generic nested
scope framework. Cumulative totals are monotone and therefore also their
peaks. Snapshots copy typed values and include the limits/profile, resident
current/peak usage, active leases, first error and close state.

`ReadTrafficBytes` counts returned read traffic, including repeats. It is not
the user's original input extent. Decoded representations must not redefine
that extent. `ParseWork` requires the consumer's documented, frozen unit;
output/source/RAG and resident dimensions also remain distinct.
