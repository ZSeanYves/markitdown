#!/usr/bin/env python3
"""Regenerate tracked XML benchmark samples and refresh MANIFEST hashes."""

from __future__ import annotations

import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "samples" / "bench" / "MANIFEST.tsv"

XML_TARGETS = {
    "xml_small_synthetic_entries_v1": {
        "path": ROOT / "samples" / "bench" / "xml" / "small" / "xml_small_synthetic_entries_v1.xml",
        "bytes": 25142,
    },
    "xml_medium_synthetic_entries_v1": {
        "path": ROOT / "samples" / "bench" / "xml" / "medium" / "xml_medium_synthetic_entries_v1.xml",
        "bytes": 300017,
    },
    "xml_huge_synthetic_entries_v1": {
        "path": ROOT / "samples" / "bench" / "xml" / "huge" / "xml_huge_synthetic_entries_v1.xml",
        "bytes": 12000028,
    },
}

REGIONS = ["emea", "apac", "amer", "latam", "africa"]
LANGS = ["中文", "espanol", "francais", "arabic", "hindi"]
OWNERS = ["alice", "bob", "carol", "dave", "erin"]
STATUSES = ["draft", "stable", "review", "published"]


def deterministic_filler(index: int, size: int) -> str:
    if size <= 0:
        return ""
    seed = f"payload-{index}-segment-"
    repeated = (seed * ((size // len(seed)) + 2))[:size]
    return repeated


def entry_xml(index: int, filler_size: int) -> str:
    region = REGIONS[(index - 1) % len(REGIONS)]
    lang = LANGS[(index - 1) % len(LANGS)]
    owner = OWNERS[(index - 1) % len(OWNERS)]
    status = STATUSES[(index - 1) % len(STATUSES)]
    category = f"group-{((index - 1) % 5) + 1}"
    active = "true" if index % 2 == 0 else "false"
    score = (index * 29) % 101
    views = 1000 + index * 17
    downloads = 100 + index * 9
    priority = ((index - 1) % 7) + 1
    filler = deterministic_filler(index, filler_size)
    return (
        f'  <entry id="{index}" category="{category}" active="{active}" priority="{priority}">\n'
        f"    <title>MoonBit XML benchmark row {index}</title>\n"
        f"    <summary>Deterministic UTF-8 文本 row {index} with nested structure and repeatable payload.</summary>\n"
        f"    <region>{region}</region>\n"
        f"    <score>{score}</score>\n"
        f'    <link href="https://example.com/xml/{index}" />\n'
        f"    <labels>\n"
        f"      <label>alpha</label>\n"
        f"      <label>beta</label>\n"
        f"      <label>{lang}</label>\n"
        f"    </labels>\n"
        f'    <details owner="{owner}" status="{status}">\n'
        f'      <metrics views="{views}" downloads="{downloads}" ratio="{views / max(downloads, 1):.3f}" />\n'
        f"      <notes>Stable benchmark payload {index} keeps XML structure honest for routing and streaming scans.</notes>\n"
        f"      <payload>{filler}</payload>\n"
        f"    </details>\n"
        f"  </entry>\n"
    )


def build_xml(target_bytes: int) -> str:
  header = '<?xml version="1.0" encoding="UTF-8"?>\n<benchmarkCorpus>\n'
  footer = "</benchmarkCorpus>\n"
  header_bytes = len(header.encode("utf-8"))
  footer_bytes = len(footer.encode("utf-8"))
  current_bytes = header_bytes
  entries: list[str] = []
  index = 1
  minimum_entries = 12

  while index <= minimum_entries:
    minimal = entry_xml(index, 0)
    minimal_bytes = len(minimal.encode("utf-8"))
    if current_bytes + minimal_bytes + footer_bytes > target_bytes:
      raise RuntimeError(
        f"target {target_bytes} is too small to fit entry {index}"
      )
    entries.append(minimal)
    current_bytes += minimal_bytes
    index += 1

  last_minimal = entry_xml(index, 0)
  last_minimal_bytes = len(last_minimal.encode("utf-8"))
  filler_bytes = target_bytes - current_bytes - footer_bytes - last_minimal_bytes
  if filler_bytes < 0:
    raise RuntimeError(
      f"target {target_bytes} left negative filler budget {filler_bytes}"
    )
  entries.append(entry_xml(index, filler_bytes))

  content = header + "".join(entries) + footer
  encoded = content.encode("utf-8")
  if len(encoded) != target_bytes:
    raise RuntimeError(
      f"generated XML byte size mismatch: want {target_bytes}, got {len(encoded)}"
    )
  return content


def refresh_manifest(digests: dict[str, tuple[int, str]]) -> None:
    lines = MANIFEST_PATH.read_text("utf-8").splitlines()
    updated: list[str] = []
    for line in lines:
        if line.startswith("#") or line.strip() == "":
            updated.append(line)
            continue
        cols = line.split("\t")
        bench_id = cols[0]
        if bench_id in digests:
            size_bytes, sha = digests[bench_id]
            cols[6] = str(size_bytes)
            cols[7] = sha
        updated.append("\t".join(cols))
    MANIFEST_PATH.write_text("\n".join(updated) + "\n", encoding="utf-8")


def main() -> None:
    digests: dict[str, tuple[int, str]] = {}
    for bench_id, spec in XML_TARGETS.items():
        content = build_xml(spec["bytes"])
        path = spec["path"]
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        payload = content.encode("utf-8")
        digests[bench_id] = (len(payload), hashlib.sha256(payload).hexdigest())
    refresh_manifest(digests)


if __name__ == "__main__":
    main()
