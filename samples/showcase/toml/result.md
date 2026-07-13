# build-system

| Key | Value |
| --- | --- |
| requires | [hatchling, hatch-fancy-pypi-readme>=22.5.0] |
| build-backend | hatchling.build |

# project

| Key | Value |
| --- | --- |
| name | pydantic |
| description | Data validation using Python type hints |
| authors | array[12] of tables |
| license | MIT |
| license-files | [LICENSE] |
| classifiers | [Development Status :: 5 - Production/Stable, Programming Language :: Python, Programming Language :: Python :: Implementation :: CPython, Programming Language :: Python :: Implementation :: PyPy, Programming Language :: Python :: 3, Programming Language :: Python :: 3 :: Only, Programming Language :: Python :: 3.10, Programming Language :: Python :: 3.11, Programming Language :: Python :: 3.12, Programming Language :: Python :: 3.13, Programming Language :: Python :: 3.14, Intended Audience :: Developers, Intended Audience :: Information Technology, Operating System :: OS Independent, Framework :: Hypothesis, Framework :: Pydantic, Topic :: Software Development :: Libraries :: Python Modules, Topic :: Internet] |
| requires-python | >=3.10 |
| dependencies | [typing-extensions>=4.15.0, annotated-types>=0.6.0, pydantic-core==2.47.0, typing-inspection>=0.4.2] |
| dynamic | [version, readme] |

## project.optional-dependencies

| Key | Value |
| --- | --- |
| email | [email-validator>=2.0.0] |
| timezone | [tzdata; platform_system == "Windows"] |

## project.urls

| Key | Value |
| --- | --- |
| Homepage | https://github.com/pydantic/pydantic |
| Documentation | https://pydantic.dev/docs/validation/latest/get-started/ |
| Funding | https://github.com/sponsors/samuelcolvin |
| Source | https://github.com/pydantic/pydantic |
| Changelog | https://pydantic.dev/docs/validation/latest/get-started/changelog/ |

# dependency-groups

| Key | Value |
| --- | --- |
| dev | [coverage[toml], pytz, dirty-equals, pytest, pytest-mock, pytest-pretty, pytest-examples, faker, pytest-benchmark, pytest-codspeed, pytest-run-parallel>=0.3.1, packaging, jsonschema] |
| coverage | [coverage[toml]] |
| docs | [autoflake, mkdocs, mkdocs-exclude, mkdocs-llmstxt, mkdocs-material[imaging], mkdocs-redirects, mkdocstrings-python, tomli, pyupgrade, mike, pydantic-settings, requests, build>=1.3.0, pydantic-extra-types>=2.10.6, pydantic-docs] |
| docs-upload | [algoliasearch>=4.12.0, beautifulsoup4>=4.13.3] |
| linting | [ruff, pyright] |
| testing-extra | [cloudpickle, ansi2html, devtools, sqlalchemy, pytest-memray; platform_python_implementation == "CPython" and platform_system != "Windows"] |
| typechecking | [mypy, pyright, pyrefly, pydantic-settings] |
| build | [build, twine] |
| pyodide-build | [pyodide-build] |
| tweet | [tweepy] |
| all | array[7] of tables |

### tool.hatch.version

| Key | Value |
| --- | --- |
| path | pydantic/version.py |

### tool.hatch.metadata

| Key | Value |
| --- | --- |
| allow-direct-references | true |

##### tool.hatch.build.targets.sdist

| Key | Value |
| --- | --- |
| include | [/README.md, /HISTORY.md, /Makefile, /pydantic, /tests] |

##### tool.hatch.metadata.hooks.fancy-pypi-readme

| Key | Value |
| --- | --- |
| content-type | text/markdown |
| substitutions | array[3] of tables |

###### fragments

```toml
[{ path = README.md }, { text = 
## Changelog

 }, { path = HISTORY.md, pattern = (.+?)<!-- package description limit --> }, { text = 
... see [here](https://pydantic.dev/docs/validation/latest/get-started/changelog/#v2100b1-2024-11-06) for earlier changes.
 }]
```

## tool.pytest

| Key | Value |
| --- | --- |
| testpaths | [tests] |
| strict | true |
| filterwarnings | [error, ignore:path is deprecated.*:DeprecationWarning:] |
| addopts | [--benchmark-columns, min,mean,stddev,outliers,rounds,iterations, --benchmark-group-by, group, --benchmark-warmup, on, --benchmark-disable] |
| markers | [skip_json_schema_validation: Disable JSON Schema validation., timeout: pytest-timeout marker (no-op when plugin not installed)] |

## tool.uv

| Key | Value |
| --- | --- |
| default-groups | [dev] |
| required-version | >=0.8.4 |

### tool.uv.sources

| Key | Value |
| --- | --- |
| pydantic-core | { workspace = true } |
| pydantic-docs | { git = https://github.com/pydantic/pydantic-docs } |

### tool.uv.workspace

| Key | Value |
| --- | --- |
| members | [pydantic-core] |

## tool.hooky

| Key | Value |
| --- | --- |
| reviewers | [Viicos] |
| require_change_file | false |
| unconfirmed_label | pending |

## tool.ruff

| Key | Value |
| --- | --- |
| line-length | 120 |
| target-version | py310 |
| extend-exclude | [pydantic/v1, tests/mypy, tests/pydantic_core] |

### tool.ruff.lint

| Key | Value |
| --- | --- |
| select | [F, E, I, D, UP, YTT, B, T10, T20, C4, PERF, PIE, PYI006, PYI062, PYI063, PYI066] |
| ignore | [D105, D107, D205, D415, E501, B011, B028, B904, PIE804] |
| flake8-quotes | { inline-quotes = single, multiline-quotes = double } |
| isort | { known-first-party = [pydantic, tests] } |
| mccabe | { max-complexity = 14 } |
| pydocstyle | { convention = google } |

#### tool.ruff.lint.per-file-ignores

| Key | Value |
| --- | --- |
| docs/* | [D] |
| pydantic/__init__.py | [F405, F403, D] |
| tests/test_forward_ref.py | [F821] |
| tests/test_deferred_annotations.py | [F821, F841] |
| tests/test_main.py | [PIE807] |
| tests/* | [D, B, C4] |
| pydantic/_internal/_known_annotated_metadata.py | [PIE800] |
| pydantic/deprecated/* | [D, PYI, UP007] |
| pydantic/color.py | [PYI] |
| pydantic/_internal/_decorators_v1.py | [PYI] |
| pydantic/json_schema.py | [D] |
| release/*.py | [T201] |

#### tool.ruff.lint.extend-per-file-ignores

| Key | Value |
| --- | --- |
| docs/**/*.py | [T] |
| tests/**/*.py | [T, E721, F811] |
| tests/benchmarks/**/*.py | [UP006, UP007] |

### tool.ruff.format

| Key | Value |
| --- | --- |
| quote-style | single |

### tool.coverage.run

| Key | Value |
| --- | --- |
| source | [pydantic, pydantic_core] |
| omit | [pydantic/deprecated/*, pydantic/v1/*] |
| branch | true |
| relative_files | true |
| context | ${CONTEXT} |

### tool.coverage.report

| Key | Value |
| --- | --- |
| precision | 2 |
| exclude_also | [raise\sNotImplementedError, @(typing\.)?overload, class .*\bProtocol\):, (typing\.)?.assert_never] |

### tool.coverage.paths

| Key | Value |
| --- | --- |
| source | [pydantic/, /Users/runner/work/pydantic/pydantic/pydantic/, D:\a\pydantic\pydantic\pydantic] |

## tool.pyright

| Key | Value |
| --- | --- |
| include | [pydantic, tests/test_pipeline.py] |
| exclude | [pydantic/_hypothesis_plugin.py, pydantic/mypy.py, pydantic/v1] |
| strict | [tests/test_pipeline.py] |
| enableExperimentalFeatures | true |

## tool.codespell

| Key | Value |
| --- | --- |
| skip | .git,env*,pydantic/v1/*,uv.lock |
| ignore-words-list | gir,ser,crate,deques |
