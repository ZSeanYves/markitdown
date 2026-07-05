# Bench Runner

`bench/runner/` is the formal benchmark executor. It organizes the external corpus, comparison tools, and product paths into reproducible benchmark runs.

Main responsibilities:

- parse benchmark commands
- expand presets and scenarios
- execute measurements
- aggregate results and produce reports

Main files:

- `main.mbt`
- `runner.mbt`

Maintenance rules:

- benchmark strategy, scheduling, and result protocols should stay centralized
- avoid adding one-off benchmark main paths for individual formats

Validation:

```bash
moon test
bash samples/check_quality.sh
```
