from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from .utils import config_root, read_key_value_metadata, repo_root


MODEL_METADATA_NAME = ".markitdown-model.meta"


@lru_cache(maxsize=1)
def runtime_args(repo: str | None = None) -> dict:
    root = Path(repo) if repo else repo_root()
    path = config_root(root) / "runtime_args.json"
    import json

    return json.loads(path.read_text(encoding="utf-8"))


def stable_env(repo: str | None = None) -> dict[str, str]:
    return dict(runtime_args(repo)["stable_env"])


def ffmpeg_normalize_args(repo: str | None = None) -> list[str]:
    return list(runtime_args(repo)["commands"]["ffmpeg"])


def paddle_env(repo: str | None = None) -> dict[str, str]:
    return dict(runtime_args(repo)["paddle"]["env"])


def paddle_init_kwargs(repo: str | None = None) -> dict[str, object]:
    return dict(runtime_args(repo)["paddle"]["init_kwargs"])


def paddle_predict_kwargs(repo: str | None = None) -> dict[str, object]:
    return dict(runtime_args(repo)["paddle"]["predict_kwargs"])


def load_model_metadata(path: Path) -> dict[str, str]:
    return read_key_value_metadata(path / MODEL_METADATA_NAME)
