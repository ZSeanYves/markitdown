#!/usr/bin/env python3
from __future__ import annotations

from io import BytesIO
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[2]

MAIN_DIR = ROOT / "samples" / "main_process" / "zip"
META_DIR = ROOT / "samples" / "metadata" / "zip"
BENCH_DIR = ROOT / "samples" / "benchmark" / "zip"
TEST_DIR = ROOT / "samples" / "test" / "zip"

IMG_RED = ROOT / "samples" / "main_process" / "html" / "img" / "img_red.jpg"

FIXED_DATE = (2026, 5, 6, 0, 0, 0)


def zip_info(name: str) -> ZipInfo:
    info = ZipInfo(name)
    info.date_time = FIXED_DATE
    info.compress_type = ZIP_DEFLATED
    return info


def write_zip(path: Path, entries: list[tuple[str, bytes]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(path, "w") as zf:
      for name, data in entries:
        zf.writestr(zip_info(name), data)


def text(value: str) -> bytes:
    return value.encode("utf-8")


def read_bytes(path: Path) -> bytes:
    return path.read_bytes()


def build_inner_zip_bytes() -> bytes:
    buf = BytesIO()
    with ZipFile(buf, "w") as zf:
        zf.writestr(zip_info("inner.txt"), text("nested"))
    return buf.getvalue()


def generate_main_process() -> None:
    img = read_bytes(IMG_RED)
    inner_zip = build_inner_zip_bytes()

    write_zip(
        MAIN_DIR / "zip_mixed_supported_entries.zip",
        [
            ("zeta/notes.txt", text("Archive note.\n")),
            ("gamma/data.csv", text("Name,Role\nAda,Engineer\n")),
            ("alpha/readme.md", text("# Alpha\n\nMarkdown inside zip.\n")),
            ("delta/page.html", text("<h1>HTML Entry</h1><p>Plain HTML body.</p>")),
            ("beta/info.json", text('{"name":"Ada","role":"Engineer"}')),
        ],
    )

    write_zip(
        MAIN_DIR / "zip_unsupported_entries.zip",
        [
            ("supported/readme.md", text("# Supported\n\nKept.\n")),
            ("unsupported/blob.bin", b"\x00\x01binary"),
            ("unsupported/raw.jpg", img),
        ],
    )

    write_zip(
        MAIN_DIR / "zip_nested_archive_boundary.zip",
        [
            ("docs/readme.md", text("# Outer\n\nArchive note.\n")),
            ("nested/archive.zip", inner_zip),
            ("nested/tool.jar", inner_zip),
        ],
    )

    write_zip(
        MAIN_DIR / "zip_duplicate_asset_names.zip",
        [
            (
                "beta/page.html",
                text(
                    "<figure><img src=\"img/img_red.jpg\" alt=\"beta red\" "
                    "title=\"Beta Red\"><figcaption>Beta caption</figcaption></figure>"
                ),
            ),
            ("beta/img/img_red.jpg", img),
            (
                "alpha/page.html",
                text(
                    "<figure><img src=\"img/img_red.jpg\" alt=\"alpha red\" "
                    "title=\"Alpha Red\"><figcaption>Alpha caption</figcaption></figure>"
                ),
            ),
            ("alpha/img/img_red.jpg", img),
        ],
    )

    write_zip(
        MAIN_DIR / "zip_hidden_entries_policy.zip",
        [
            ("__MACOSX/._junk", text("junk")),
            (".DS_Store", text("hidden")),
            ("docs/readme.md", text("# Visible\n\nBody.\n")),
            ("dir/.env", text("SECRET=1\n")),
        ],
    )


def generate_metadata() -> None:
    img = read_bytes(IMG_RED)
    inner_zip = build_inner_zip_bytes()

    write_zip(
        META_DIR / "zip_metadata_mixed_supported.zip",
        [
            ("notes/plain.txt", text("Plain note.\n")),
            ("tables/people.csv", text("Name,Role\nAda,Engineer\nBob,Designer\n")),
            ("data/info.json", text('{"team":"Infra","owner":"Ada"}')),
            ("site/page.html", text("<h2>HTML Note</h2><p>Inside archive.</p>")),
        ],
    )

    write_zip(
        META_DIR / "zip_metadata_assets_remap.zip",
        [
            (
                "beta/page.html",
                text(
                    "<figure><img src=\"img/img_red.jpg\" alt=\"beta red\" "
                    "title=\"Beta Red\"><figcaption>Beta caption</figcaption></figure>"
                ),
            ),
            ("beta/img/img_red.jpg", img),
            (
                "alpha/page.html",
                text(
                    "<figure><img src=\"img/img_red.jpg\" alt=\"alpha red\" "
                    "title=\"Alpha Red\"><figcaption>Alpha caption</figcaption></figure>"
                ),
            ),
            ("alpha/img/img_red.jpg", img),
        ],
    )

    write_zip(
        META_DIR / "zip_metadata_unsupported_entries.zip",
        [
            ("notes/readme.md", text("# Archive Notes\n\nBody.\n")),
            ("unsupported/blob.bin", b"\x00\x01binary"),
            ("unsupported/raw.jpg", img),
        ],
    )

    write_zip(
        META_DIR / "zip_metadata_nested_archive_boundary.zip",
        [
            ("docs/readme.md", text("# Outer\n\nArchive note.\n")),
            ("nested/archive.zip", inner_zip),
            ("nested/tool.jar", inner_zip),
        ],
    )


def generate_benchmark() -> None:
    img = read_bytes(IMG_RED)
    inner_zip = build_inner_zip_bytes()

    write_zip(
        BENCH_DIR / "zip_unsupported_degrade.zip",
        [
            ("docs/readme.md", text("# Mixed\n\nArchive note.\n")),
            ("nested/archive.zip", inner_zip),
            ("unsupported/blob.bin", b"\x00\x01binary"),
            ("unsupported/raw.jpg", img),
        ],
    )


def generate_tests() -> None:
    write_zip(
        TEST_DIR / "zip_path_traversal_boundary.zip",
        [
            ("../evil.txt", text("evil")),
            ("docs/readme.md", text("safe")),
        ],
    )

    write_zip(
        TEST_DIR / "zip_absolute_path_boundary.zip",
        [
            ("/abs.txt", text("abs")),
            ("docs/readme.md", text("safe")),
        ],
    )

    write_zip(
        TEST_DIR / "zip_normalized_collision_boundary.zip",
        [
            ("docs/readme.md", text("safe")),
            ("a\\b.png", text("first")),
            ("a/b.png", text("second")),
        ],
    )


def main() -> None:
    generate_main_process()
    generate_metadata()
    generate_benchmark()
    generate_tests()


if __name__ == "__main__":
    main()
