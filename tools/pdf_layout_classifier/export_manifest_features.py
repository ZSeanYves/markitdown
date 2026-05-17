#!/usr/bin/env python3
import argparse
import csv
import os
import subprocess
import sys


DEFAULT_TOOL = "_build/native/debug/build/tools/pdf_layout_classifier/pdf_layout_classifier.exe"
DEFAULT_OUTPUT_DIR = ".external/layout_model/features/raw"


def read_tsv(path):
    with open(path, "r", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def ensure_columns(rows, path):
    required = {"sample_id", "pdf_path", "record_kind", "split"}
    keys = set(rows[0].keys()) if rows else set()
    missing = sorted(required - keys)
    if missing:
        raise SystemExit(f"{path} missing required columns: {', '.join(missing)}")


def run_export(tool_path, sample_id, pdf_path, record_kind, output_path, root):
    cmd = [
        tool_path,
        "export",
        "--sample-id",
        sample_id,
        "--input",
        pdf_path,
        "--record-kind",
        record_kind,
        "--output",
        output_path,
    ]
    subprocess.run(cmd, cwd=root, check=True)


def main():
    parser = argparse.ArgumentParser(
        description="Export PDF layout feature TSVs for every sample in one or more manifests.",
    )
    parser.add_argument(
        "--manifest",
        action="append",
        required=True,
        help="TSV manifest path. Can be provided multiple times.",
    )
    parser.add_argument(
        "--tool",
        default=DEFAULT_TOOL,
        help=f"Native export tool path. Defaults to {DEFAULT_TOOL}",
    )
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help=f"Output directory for *.features.tsv. Defaults to {DEFAULT_OUTPUT_DIR}",
    )
    parser.add_argument(
        "--split",
        action="append",
        help="Optional split filter. Can be provided multiple times.",
    )
    parser.add_argument(
        "--sample-id",
        action="append",
        help="Optional sample_id filter. Can be provided multiple times.",
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip files that already exist.",
    )
    args = parser.parse_args()

    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    tool_path = os.path.join(root, args.tool)
    output_dir = os.path.join(root, args.output_dir)
    split_filter = set(args.split or [])
    sample_filter = set(args.sample_id or [])

    if not os.path.exists(tool_path):
        raise SystemExit(
            "native pdf_layout_classifier tool not found: "
            f"{tool_path}\nrun: moon build tools/pdf_layout_classifier --target native"
        )

    os.makedirs(output_dir, exist_ok=True)
    exported = 0
    skipped = 0

    for manifest_path in args.manifest:
        abs_manifest = os.path.join(root, manifest_path)
        rows = read_tsv(abs_manifest)
        ensure_columns(rows, manifest_path)
        for row in rows:
            sample_id = row["sample_id"].strip()
            if not sample_id:
                continue
            if split_filter and row["split"] not in split_filter:
                continue
            if sample_filter and sample_id not in sample_filter:
                continue
            pdf_path = row["pdf_path"].strip()
            record_kind = (row.get("record_kind") or "block").strip() or "block"
            output_path = os.path.join(output_dir, f"{sample_id}.features.tsv")
            if args.skip_existing and os.path.exists(output_path):
                skipped += 1
                continue
            run_export(tool_path, sample_id, pdf_path, record_kind, output_path, root)
            exported += 1
            print(f"exported {sample_id} -> {os.path.relpath(output_path, root)}")

    print(
        f"feature export complete: exported={exported} skipped={skipped} "
        f"output_dir={os.path.relpath(output_dir, root)}"
    )


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode)
