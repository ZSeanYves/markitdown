# Repository tools

Active automation uses MoonBit `.mbtx` scripts in `tools/regression/`.
Product acceptance executes actual Native artifacts for Linux x86_64 and
macOS arm64. The scripts may use the toolchain's script runtime; the product
CLI is installed with `moon install`.

| Entrypoint | Purpose | Evidence boundary |
| --- | --- | --- |
| `freeze_native.mbtx` | Freeze tracked source/corpus files, Git state, dependencies, toolchain and machine | Fingerprints, not product acceptance |
| `run_native_regression.mbtx` | Execute main/quality/accurate contracts against a supplied Native executable | Quality execution; validation-only/self-test are narrower |
| `compare_native.mbtx` | Compare saved baseline/candidate outputs | Differences require review; does not measure timing |
| `native_install.mbtx` | Fresh local/fixed-Git/exact-registry CLI installation and independent public-library consumer | Only the source lane actually executed is accepted |
| `native_benchmark.mbtx` | Paired Native CLI windows with corpus/output/asset hashes, 3 warmups and 30 interleaved measurements per lane | Two admissible windows establish only the selected CLI scope; library/cost/reliability gates remain pending |

The installation helper's optional `--audit-bench true` checks benchmark
manifest files, sizes and hashes. It does not implement formal performance
measurement. `--prepare-only true` records prepared commands and consumer
sources, executes no installation gate, and reports `prepared_only`.
The benchmark helper's `--validate-only true` and `--self-test true` also execute
zero product measurements. Its [protocol and contract](regression/README.md#native-benchmark-protocol)
describe the conditions that force `inconclusive` and suppress improvement ratios.

The old `moonx_smoke.mbtx`, `run_moonx_regression.mbtx` and
`moonx_benchmark.mbtx` are retired entrypoints that report the replacement.
Their historical results and fake-runner outputs do not establish current
Native product, installation or publication acceptance.

Use the independent `markitdown-quality-lab` checkout without changing
existing user work. Each execution needs a fresh evidence directory and
records the exact corpus/source state. See the
[tooling guide](regression/README.md) for commands and channels.

P2–P4 execution/format/PDF work, P5 two-platform quality/performance/reliability,
and P6 exact published-version confirmation remain unfinished under the
[Native delivery decision](../docs/adr/0008-native-only-delivery-and-acceptance.md).
No current script alone certifies all those gates.
