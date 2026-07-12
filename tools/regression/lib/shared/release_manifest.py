#!/usr/bin/env python3
"""Write deterministic, machine-readable validation run metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def command_output(argv: list[str], cwd: Path) -> str:
    try:
        completed = subprocess.run(
            argv,
            cwd=cwd,
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        return "unavailable"
    if completed.returncode != 0:
        return "unavailable"
    return (completed.stdout.strip() or completed.stderr.strip() or "unknown")


def sha_for(path: Path) -> str:
    if not (path / ".git").exists():
        return "unavailable"
    return command_output(["git", "rev-parse", "HEAD"], path)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def binary_fingerprint(root: Path, raw_path: str) -> dict[str, object]:
    path = (root / raw_path).resolve()
    return {
        "path": os.path.relpath(path, root),
        "available": path.is_file(),
        "sha256": file_sha256(path) if path.is_file() else None,
    }


def command_fingerprint(name: str, version_args: list[str], cwd: Path) -> dict[str, object]:
    resolved = shutil.which(name)
    if resolved is None:
        return {"path": None, "available": False, "version": "unavailable"}
    version = command_output([resolved, *version_args], cwd).splitlines()[0]
    return {"path": resolved, "available": True, "version": version}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--root", default=".")
    parser.add_argument("--quality-lab", default="markitdown-quality-lab")
    parser.add_argument("--command", required=True)
    parser.add_argument("--status", choices=("pass", "fail"), required=True)
    parser.add_argument("--exit-code", required=True, type=int)
    parser.add_argument("--started-at", required=True)
    parser.add_argument("--finished-at", required=True)
    parser.add_argument("--artifact", action="append", default=[])
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    quality_lab = (root / args.quality_lab).resolve()
    artifacts = []
    missing = []
    for raw in args.artifact:
        path = (root / raw).resolve()
        exists = path.exists()
        artifacts.append({"path": os.path.relpath(path, root), "exists": exists})
        if not exists:
            missing.append(os.path.relpath(path, root))
    payload = {
        "schema_version": 2,
        "repository_sha": sha_for(root),
        "quality_lab_sha": sha_for(quality_lab),
        "moon_version": command_output(["moon", "version"], root).splitlines()[0],
        "python_version": platform.python_version(),
        "os": platform.system(),
        "os_release": platform.release(),
        "architecture": platform.machine(),
        "command": args.command,
        "status": args.status,
        "started_at": args.started_at,
        "finished_at": args.finished_at,
        "result_summary": {
            "status": args.status,
            "exit_code": args.exit_code,
            "artifact_count": len(artifacts),
            "missing_artifact_count": len(missing),
        },
        "artifacts": artifacts,
        "missing_artifacts": missing,
        "runtime_fingerprints": {
            "cli": binary_fingerprint(root, "_build/native/release/build/cli/cli.exe"),
            "bench_runner": binary_fingerprint(
                root,
                "_build/native/release/build/bench/runner/runner.exe",
            ),
            "tesseract": command_fingerprint("tesseract", ["--version"], root),
            "pdftoppm": command_fingerprint("pdftoppm", ["-v"], root),
            "ffmpeg": command_fingerprint("ffmpeg", ["-version"], root),
            "markitdown": command_fingerprint("markitdown", ["--version"], root),
        },
    }
    output = (root / args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
