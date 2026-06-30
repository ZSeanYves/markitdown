#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--markdown", required=True)
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--rows-tsv", required=True)
    parser.add_argument("--results-tsv", required=True)
    return parser.parse_args()


def normalize_newlines(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def normalize_markdown_literal(text: str) -> str:
    return re.sub(r"\\([\\`*_{}\[\]()#+!<>|])", r"\1", text)


def normalize_signal_literal(text: str) -> str:
    return re.sub(r"\\([\\`*_{}\[\]()#+!<>|])", r"\1", text)


def normalized_text_without_asset_urls(text: str) -> str:
    text = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", r"!\1", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1", text)
    text = re.sub(r"https?://\S+", "", text)
    return text


def count_assets_on_disk(artifact_dir: Path) -> int:
    asset_root = artifact_dir / "assets"
    if not asset_root.is_dir():
        return 0
    return sum(1 for path in asset_root.rglob("*") if path.is_file())


@dataclass
class Snapshot:
    markdown_text: str
    normalized_text: str
    literal_text: str
    token_text: str
    lines: list[str]
    asset_count: int


class Evaluator:
    def __init__(self, snapshot: Snapshot) -> None:
        self.snapshot = snapshot
        self._memo: dict[str, bool] = {}

    def evaluate(self, signal: str) -> bool:
        if signal in self._memo:
            return self._memo[signal]
        result = self._evaluate_uncached(signal)
        self._memo[signal] = result
        return result

    def _evaluate_uncached(self, signal: str) -> bool:
        literal_text = self.snapshot.literal_text
        if signal == "no_empty_output":
            return any(not ch.isspace() for ch in self.snapshot.markdown_text)
        if signal.startswith("contains:"):
            needle = normalize_signal_literal(signal[len("contains:") :])
            return needle in literal_text
        if signal.startswith("contains_all:"):
            rest = normalize_signal_literal(signal[len("contains_all:") :])
            parts = [part for part in rest.split("|") if part]
            return all(part in literal_text for part in parts)
        if signal.startswith("exact_count:"):
            return self._count_occurrence_check("exact_count", normalize_signal_literal(signal[len("exact_count:") :]))
        if signal.startswith("min_count:"):
            return self._count_occurrence_check("min_count", normalize_signal_literal(signal[len("min_count:") :]))
        if signal.startswith("max_count:"):
            return self._count_occurrence_check("max_count", normalize_signal_literal(signal[len("max_count:") :]))
        if signal.startswith("not_contains:"):
            needle = normalize_signal_literal(signal[len("not_contains:") :])
            return needle not in literal_text
        if signal.startswith("heading_marker:"):
            needle = signal[len("heading_marker:") :]
            pattern = re.compile(rf"^[ \t]*#+[ \t]+.*{re.escape(needle)}.*$", re.MULTILINE)
            return pattern.search(self.snapshot.markdown_text) is not None
        if signal == "table_marker":
            return any(re.match(r"^[ \t]*\|.*\|[ \t]*$", line) for line in self.snapshot.lines)
        if signal == "image_ref":
            return re.search(r"!\[[^]]*\]\([^)]*\)", self.snapshot.markdown_text) is not None
        if signal == "link_ref":
            return re.search(r"\[[^]]+\]\([^)]*\)", self.snapshot.markdown_text) is not None
        if signal.startswith("asset_count_min:"):
            limit = int(signal[len("asset_count_min:") :])
            return self.snapshot.asset_count >= limit
        if signal.startswith("order:"):
            rest = normalize_signal_literal(signal[len("order:") :])
            pos = -1
            for part in [part for part in rest.split("|") if part]:
                nxt = literal_text.find(part, pos + 1)
                if nxt < 0:
                    return False
                pos = nxt
            return True
        if signal.startswith("line_fragmentation_max:"):
            limit = int(signal[len("line_fragmentation_max:") :])
            count = 0
            for line in self.snapshot.lines:
                trimmed = line.rstrip()
                if trimmed and len(trimmed) <= 40:
                    count += 1
            return count <= limit
        if signal.startswith("max_long_token_len:"):
            limit = int(signal[len("max_long_token_len:") :])
            for token in re.findall(r"\S+", self.snapshot.token_text):
                if len(token) > limit:
                    return False
            return True
        if signal.startswith("page_noise_absent:"):
            needle = normalize_signal_literal(signal[len("page_noise_absent:") :])
            return needle not in literal_text
        if signal.startswith("review_note:"):
            return True
        raise SystemExit(f"unknown quality signal: {signal}")

    def _count_occurrence_check(self, kind: str, spec: str) -> bool:
        if "=" not in spec:
            raise SystemExit(f"{kind}: invalid spec (expected TEXT=N): {spec}")
        needle, expected_raw = spec.rsplit("=", 1)
        if not needle:
            raise SystemExit(f"{kind}: empty needle in spec: {spec}")
        if not expected_raw.isdigit():
            raise SystemExit(f"{kind}: invalid count {expected_raw!r} for needle {needle!r}")
        expected = int(expected_raw)
        actual = self.snapshot.literal_text.count(needle)
        if kind == "exact_count":
            return actual == expected
        if kind == "min_count":
            return actual >= expected
        if kind == "max_count":
            return actual <= expected
        raise SystemExit(f"unknown count assertion kind: {kind}")


def load_snapshot(args: argparse.Namespace) -> Snapshot:
    markdown_text = normalize_newlines(Path(args.markdown).read_text(encoding="utf-8"))
    literal_text = normalize_markdown_literal(markdown_text)
    return Snapshot(
        markdown_text=markdown_text,
        normalized_text=markdown_text,
        literal_text=literal_text,
        token_text=normalized_text_without_asset_urls(markdown_text),
        lines=markdown_text.split("\n"),
        asset_count=count_assets_on_disk(Path(args.artifact_dir)),
    )


def evaluate_rows(args: argparse.Namespace) -> list[dict[str, str]]:
    snapshot = load_snapshot(args)
    evaluator = Evaluator(snapshot)
    results: list[dict[str, str]] = []

    with open(args.rows_tsv, "r", encoding="utf-8", newline="") as f:
      rows = list(csv.DictReader(f, delimiter="\t"))

    for row in rows:
        expected_signals = row["expected_signals"]
        real_signals: list[str] = []
        review_notes: list[str] = []
        for signal in expected_signals.split(";"):
            signal = signal.strip()
            if not signal:
                continue
            if signal.startswith("review_note:"):
                review_notes.append(signal[len("review_note:") :])
                continue
            real_signals.append(signal)

        failed_signals: list[str] = []
        passed_signals = 0
        for signal in real_signals:
            if evaluator.evaluate(signal):
                passed_signals += 1
            else:
                failed_signals.append(signal)

        results.append(
            {
                "row_id": row["row_id"],
                "format": row["format"],
                "source_scope": row["source_scope"],
                "source_id": row["source_id"],
                "quality_tier": row["quality_tier"],
                "passed_signals": str(passed_signals),
                "total_signals": str(len(real_signals)),
                "failed_signals": " ; ".join(failed_signals).replace(" ; ", "; "),
                "review_notes": " ; ".join(review_notes).replace(" ; ", "; "),
            }
        )

    return results


def write_results(path: str, rows: list[dict[str, str]]) -> None:
    fieldnames = [
        "row_id",
        "format",
        "source_scope",
        "source_id",
        "quality_tier",
        "passed_signals",
        "total_signals",
        "failed_signals",
        "review_notes",
    ]
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> None:
    args = parse_args()
    results = evaluate_rows(args)
    write_results(args.results_tsv, results)


if __name__ == "__main__":
    main()
