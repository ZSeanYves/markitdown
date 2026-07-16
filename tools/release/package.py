#!/usr/bin/env python3
"""Create deterministic local release archives, checksums, and SPDX SBOMs."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import re
import subprocess
import tarfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def project_version() -> str:
    module = (ROOT / "moon.mod").read_text(encoding="utf-8")
    match = re.search(r'^version = "([^"]+)"$', module, re.MULTILINE)
    if not match:
        raise SystemExit("moon.mod version is missing")
    return match.group(1)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def add_file(archive: tarfile.TarFile, source: Path, name: str, executable: bool) -> None:
    if not source.is_file():
        raise SystemExit(f"release input is missing: {source}")
    data = source.read_bytes()
    info = tarfile.TarInfo(name)
    info.size = len(data)
    info.mode = 0o755 if executable else 0o644
    info.mtime = 0
    info.uid = info.gid = 0
    info.uname = info.gname = "root"
    archive.addfile(info, io.BytesIO(data))


def dependency_packages() -> list[dict[str, str]]:
    module = (ROOT / "moon.mod").read_text(encoding="utf-8")
    imports = re.findall(r'"([^"@]+)@([^"]+)"', module)
    return [
        {
            "name": name,
            "SPDXID": f"SPDXRef-Package-{index}",
            "versionInfo": version,
            "downloadLocation": "NOASSERTION",
        }
        for index, (name, version) in enumerate(imports, 1)
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--platform", required=True)
    parser.add_argument("--output", default="dist", type=Path)
    args = parser.parse_args()

    version = project_version()
    if not args.binary.is_file() or not args.binary.stat().st_mode & 0o111:
        raise SystemExit(f"release binary is missing or not executable: {args.binary}")
    reported = subprocess.check_output([str(args.binary), "--version"], text=True).strip()
    if reported != f"markitdown-mb {version}":
        raise SystemExit(f"version mismatch: moon.mod={version}, cli={reported!r}")

    args.output.mkdir(parents=True, exist_ok=True)
    stem = f"markitdown-mb-{version}-{args.platform}"
    archive_path = args.output / f"{stem}.tar.gz"
    with archive_path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as archive:
                add_file(archive, args.binary, f"{stem}/markitdown-mb", True)
                add_file(archive, ROOT / "README.md", f"{stem}/README.md", False)
                add_file(archive, ROOT / "LICENSE", f"{stem}/LICENSE", False)

    digest = sha256(archive_path)
    (args.output / f"{archive_path.name}.sha256").write_text(
        f"{digest}  {archive_path.name}\n", encoding="utf-8"
    )
    sbom = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": stem,
        "documentNamespace": f"https://github.com/ZSeanYves/markitdown/releases/{stem}",
        "creationInfo": {
            "created": "1970-01-01T00:00:00Z",
            "creators": ["Tool: tools/release/package.py"],
        },
        "packages": [
            {
                "name": "markitdown-mb",
                "SPDXID": "SPDXRef-Package-markitdown-mb",
                "versionInfo": version,
                "downloadLocation": "NOASSERTION",
            },
            *dependency_packages(),
        ],
    }
    (args.output / f"{stem}.spdx.json").write_text(
        json.dumps(sbom, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(archive_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
