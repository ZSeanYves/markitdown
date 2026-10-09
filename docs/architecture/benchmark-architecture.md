# Benchmark architecture

Performance validation is part of the MoonX consumer contract. The repository
keeps one `.mbtx` entrypoint, `tools/regression/moonx_benchmark.mbtx`, and one
fixed case list. It invokes the exact package coordinate through MoonX, records
the target and elapsed time for each case, and writes an auditable TSV summary.

The benchmark deliberately measures the product path users consume. It does not
contain a parser shortcut, a local binary fallback, a Python oracle, or a second
Native-only conversion implementation. Wasm and Native are separate baselines:
the shared semantics must agree, while startup, linear memory, and host I/O
costs remain target-specific.

The regression runner and benchmark share the same quality-lab checkout and
exact coordinate discipline. A missing package, failed conversion, missing
output, or incomplete row fails closed. Results are evidence for the same
revision, package version, target, toolchain, host, and corpus only; no global
latency promise is inferred from a single run.
