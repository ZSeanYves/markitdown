#!/usr/bin/env python3
"""Generate checked-in balance-mode showcase results with the release CLI."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
CLI = REPO / "_build/native/release/build/cli/cli.exe"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    if not CLI.is_file():
        raise SystemExit(
            "release CLI is missing; run: moon build --target native --release "
            "--package ZSeanYves/markitdown/cli"
        )
    with (ROOT / "MANIFEST.tsv").open(encoding="utf-8", newline="") as stream:
        inputs = list(csv.DictReader(stream, delimiter="\t"))
    rows: list[dict[str, str]] = []
    for item in inputs:
        fmt = item["format"]
        directory = ROOT / fmt
        for generated in (directory / "result.md", directory / "diagnostics.txt"):
            generated.unlink(missing_ok=True)
        shutil.rmtree(directory / "assets", ignore_errors=True)
        markdown = directory / "result.md"
        completed = subprocess.run(
            [str(CLI), "balance", str(ROOT / item["path"]), str(markdown)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if completed.returncode:
            raise SystemExit(
                f"{fmt} conversion failed ({completed.returncode}): "
                + completed.stderr.decode("utf-8", errors="replace")
            )
        if not markdown.is_file() or markdown.stat().st_size < 20:
            raise SystemExit(f"{fmt} conversion produced no substantive Markdown")
        diagnostics = completed.stderr.decode("utf-8", errors="replace")
        if diagnostics:
            (directory / "diagnostics.txt").write_text(diagnostics, encoding="utf-8")
        assets = sorted(path for path in directory.rglob("*") if path.is_file() and "assets" in path.parts)
        rows.append(
            {
                "format": fmt,
                "result_path": str(markdown.relative_to(ROOT)),
                "bytes": str(markdown.stat().st_size),
                "sha256": sha256(markdown),
                "asset_count": str(len(assets)),
                "diagnostic_lines": str(len(diagnostics.splitlines())),
            }
        )
    with (ROOT / "RESULTS.tsv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=("format", "result_path", "bytes", "sha256", "asset_count", "diagnostic_lines"),
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
