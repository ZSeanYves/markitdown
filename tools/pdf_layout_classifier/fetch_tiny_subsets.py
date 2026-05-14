#!/usr/bin/env python3
import argparse
import csv
import hashlib
import json
import os
import urllib.error
import urllib.request


PUBLAYNET_ROOT = "https://raw.githubusercontent.com/ibm-aur-nlp/PubLayNet/master"
DOCLAYNET_ROOT = "https://huggingface.co/datasets/ds4sd/DocLayNet/resolve/main"
PUBTABLES_FIRST_ROWS = (
    "https://datasets-server.huggingface.co/first-rows"
    "?dataset=bsmock%2Fpubtables-1m&config=default&split=train"
)


def fetch_bytes(url):
    req = urllib.request.Request(url, headers={"User-Agent": "markitdown-mb-layout-model/1"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def write_bytes(path, payload):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(payload)


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def sha256_hex(payload):
    return hashlib.sha256(payload).hexdigest()


def relative_path(path, root):
    return os.path.relpath(path, root)


def manifest_row(
    dataset,
    source_url,
    license_name,
    license_url,
    local_path,
    labels,
    notes,
    payload=None,
):
    row = {
        "dataset": dataset,
        "source_url": source_url,
        "license": license_name,
        "license_url": license_url,
        "sha256": "",
        "size_bytes": "",
        "local_path": local_path,
        "labels": labels,
        "notes": notes,
    }
    if payload is not None:
        row["sha256"] = sha256_hex(payload)
        row["size_bytes"] = str(len(payload))
    return row


def fetch_publaynet(out_root, rows, image_limit):
    dataset_dir = os.path.join(out_root, "publaynet")
    samples_url = f"{PUBLAYNET_ROOT}/examples/samples.json"
    license_url = f"{PUBLAYNET_ROOT}/LICENSE.md"
    payload = fetch_bytes(samples_url)
    samples_path = os.path.join(dataset_dir, "samples.json")
    write_bytes(samples_path, payload)
    rows.append(
        manifest_row(
            "PubLayNet",
            samples_url,
            "CDLA-Permissive-1.0",
            license_url,
            samples_path,
            "text,title,list,table,figure",
            "official tiny example annotations from repo",
            payload,
        )
    )

    parsed = json.loads(payload.decode("utf-8"))
    file_names = []
    for image in parsed.get("images", []):
        name = image.get("file_name", "").strip()
        if name and name not in file_names:
            file_names.append(name)
        if len(file_names) >= image_limit:
            break

    for name in file_names:
        image_url = f"{PUBLAYNET_ROOT}/examples/{name}"
        image_payload = fetch_bytes(image_url)
        image_path = os.path.join(dataset_dir, name)
        write_bytes(image_path, image_payload)
        rows.append(
            manifest_row(
                "PubLayNet",
                image_url,
                "CDLA-Permissive-1.0",
                license_url,
                image_path,
                "text,title,list,table,figure",
                "official tiny example page image; useful for label-shape audit only",
                image_payload,
            )
        )


def fetch_doclaynet(out_root, rows):
    dataset_dir = os.path.join(out_root, "doclaynet")
    license_url = "https://huggingface.co/datasets/ds4sd/DocLayNet/blob/main/README.md"
    artifacts = [
        ("README.md", f"{DOCLAYNET_ROOT}/README.md"),
        ("DocLayNet.py", f"{DOCLAYNET_ROOT}/DocLayNet.py"),
    ]
    for filename, url in artifacts:
        payload = fetch_bytes(url)
        path = os.path.join(dataset_dir, filename)
        write_bytes(path, payload)
        rows.append(
            manifest_row(
                "DocLayNet",
                url,
                "CDLA-Permissive-2.0",
                license_url,
                path,
                (
                    "caption,footnote,formula,list-item,page-footer,page-header,"
                    "picture,section-header,table,text,title"
                ),
                "metadata/loader only; direct tiny PDF/page subset still blocked this round",
                payload,
            )
        )


def fetch_pubtables(out_root, rows):
    dataset_dir = os.path.join(out_root, "pubtables_1m")
    license_url = "https://huggingface.co/datasets/bsmock/pubtables-1m/blob/main/README.md"
    payload = fetch_bytes(PUBTABLES_FIRST_ROWS)
    path = os.path.join(dataset_dir, "first_rows_train.json")
    write_bytes(path, payload)
    rows.append(
        manifest_row(
            "PubTables-1M",
            PUBTABLES_FIRST_ROWS,
            "CDLA-Permissive-2.0",
            license_url,
            path,
            "table,table_structure,row,column,cell",
            "datasets-server first-rows subset; good for table/form metadata audit",
            payload,
        )
    )


def write_manifest(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fieldnames = [
        "dataset",
        "source_url",
        "license",
        "license_url",
        "sha256",
        "size_bytes",
        "local_path",
        "labels",
        "notes",
    ]
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main():
    parser = argparse.ArgumentParser(
        description="Fetch tiny local-only PDF layout dataset subsets and record a manifest.",
    )
    parser.add_argument(
        "--out-root",
        default=".external/layout_model/datasets",
        help="Dataset subset root directory.",
    )
    parser.add_argument(
        "--manifest",
        default=".external/layout_model/datasets/dataset_subset_manifest.local.tsv",
        help="Manifest TSV output path.",
    )
    parser.add_argument(
        "--publaynet-image-limit",
        type=int,
        default=3,
        help="How many PubLayNet example images to fetch.",
    )
    args = parser.parse_args()

    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_root = os.path.join(root, args.out_root)
    manifest_path = os.path.join(root, args.manifest)
    rows = []

    tasks = [
        ("DocLayNet", fetch_doclaynet),
        ("PubLayNet", lambda out, out_rows: fetch_publaynet(out, out_rows, args.publaynet_image_limit)),
        ("PubTables-1M", fetch_pubtables),
    ]

    for name, fn in tasks:
        try:
            fn(out_root, rows)
            print(f"fetched tiny subset for {name}")
        except urllib.error.HTTPError as exc:
            rows.append(
                manifest_row(
                    name,
                    "",
                    "",
                    "",
                    "",
                    "",
                    f"blocked: HTTP {exc.code} while fetching tiny subset metadata",
                )
            )
            print(f"{name} blocked: HTTP {exc.code}")
        except Exception as exc:
            rows.append(
                manifest_row(
                    name,
                    "",
                    "",
                    "",
                    "",
                    "",
                    f"blocked: {type(exc).__name__}: {exc}",
                )
            )
            print(f"{name} blocked: {exc}")

    write_manifest(manifest_path, rows)
    print(f"wrote manifest: {relative_path(manifest_path, root)}")


if __name__ == "__main__":
    main()
