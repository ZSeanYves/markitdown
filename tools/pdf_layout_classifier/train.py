#!/usr/bin/env python3
import argparse
import csv
import json
import math
import os
from collections import Counter, defaultdict


def read_tsv(path):
    with open(path, "r", encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_tsv(path, rows, fieldnames):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def load_manifest(path):
    return read_tsv(path)


def load_manual_labels(path):
    rows = read_tsv(path)
    out = {}
    for row in rows:
        key = (
            row["record_kind"],
            row["page_index"],
            row["block_index"],
            row["line_index"],
            row.get("next_page_index", ""),
            row.get("next_block_index", ""),
            row.get("next_line_index", ""),
        )
        out[key] = row["label"]
    return out


def annotate_features(feature_rows, manual_labels):
    out = []
    for row in feature_rows:
        key = (
            row["record_kind"],
            row["page_index"],
            row["block_index"],
            row["line_index"],
            row.get("next_page_index", ""),
            row.get("next_block_index", ""),
            row.get("next_line_index", ""),
        )
        if key in manual_labels:
            row = dict(row)
            row["label"] = manual_labels[key]
            out.append(row)
    return out


def feature_names(rows):
    reserved = {
        "sample_id",
        "source_path",
        "record_kind",
        "page_index",
        "block_index",
        "line_index",
        "next_page_index",
        "next_block_index",
        "next_line_index",
        "text",
        "label",
        "notes",
    }
    return [name for name in rows[0].keys() if name not in reserved]


def parse_float(raw):
    if raw is None or raw == "":
        return 0.0
    return float(raw)


def vectorize(rows, names):
    xs = []
    ys = []
    for row in rows:
        xs.append([parse_float(row.get(name, "")) for name in names])
        ys.append(row["label"])
    return xs, ys


def compute_normalization(xs):
    if not xs:
        return [], []
    cols = len(xs[0])
    means = []
    scales = []
    for i in range(cols):
        values = [row[i] for row in xs]
        mean = sum(values) / len(values)
        var = sum((v - mean) ** 2 for v in values) / len(values)
        scale = math.sqrt(var) if var > 1e-12 else 1.0
        means.append(mean)
        scales.append(scale)
    return means, scales


def normalize(xs, means, scales):
    out = []
    for row in xs:
        out.append([(row[i] - means[i]) / (scales[i] or 1.0) for i in range(len(row))])
    return out


def train_centroid_linear(xs, ys, labels):
    positives = defaultdict(list)
    negatives = defaultdict(list)
    for x, y in zip(xs, ys):
        for label in labels:
            if y == label:
                positives[label].append(x)
            else:
                negatives[label].append(x)

    weights = {}
    thresholds = {}
    for label in labels:
        pos = positives[label]
        neg = negatives[label]
        if not pos:
            continue
        pos_mean = [sum(col) / len(pos) for col in zip(*pos)]
        if neg:
            neg_mean = [sum(col) / len(neg) for col in zip(*neg)]
        else:
            neg_mean = [0.0 for _ in pos_mean]
        values = [p - n for p, n in zip(pos_mean, neg_mean)]
        midpoint = [(p + n) / 2.0 for p, n in zip(pos_mean, neg_mean)]
        bias = -sum(v * m for v, m in zip(values, midpoint))
        pos_scores = [bias + sum(v * x for v, x in zip(values, row)) for row in pos]
        neg_scores = [bias + sum(v * x for v, x in zip(values, row)) for row in neg] or [0.0]
        min_score = (min(pos_scores) + max(neg_scores)) / 2.0
        thresholds[label] = {"min_score": min_score, "min_confidence": 0.5}
        weights[label] = {"bias": bias, "values": values}
    return weights, thresholds


def build_model(rows):
    names = feature_names(rows)
    xs, ys = vectorize(rows, names)
    labels = sorted(set(ys))
    means, scales = compute_normalization(xs)
    norm_xs = normalize(xs, means, scales)
    weights, thresholds = train_centroid_linear(norm_xs, ys, labels)
    return {
        "version": 1,
        "task": "pdf_layout_classifier",
        "model_type": "linear_v1",
        "labels": labels,
        "features": names,
        "normalization": {"mean": means, "scale": scales},
        "weights": weights,
        "thresholds": thresholds,
        "metadata": {
            "trained_from": "samples/pdf_layout_classifier/manifest.tsv",
            "sample_count": str(len(rows)),
            "notes": "training spike / local corpus only",
        },
    }


def load_training_rows(manifest_path, feature_dir):
    manifest = load_manifest(manifest_path)
    training_rows = []
    for row in manifest:
        feature_path = os.path.join(feature_dir, f"{row['sample_id']}.features.tsv")
        feature_rows = read_tsv(feature_path)
        if row["label_source"] == "manual" and row["label_path"]:
            manual = load_manual_labels(row["label_path"])
            training_rows.extend(annotate_features(feature_rows, manual))
    return training_rows


def predict_label(model, row):
    names = model["features"]
    means = model["normalization"]["mean"]
    scales = model["normalization"]["scale"]
    vector = [(parse_float(row.get(name, "")) - means[i]) / (scales[i] or 1.0) for i, name in enumerate(names)]
    best = None
    for label, payload in model["weights"].items():
        score = payload["bias"] + sum(v * x for v, x in zip(payload["values"], vector))
        if best is None or score > best[1] or (score == best[1] and label < best[0]):
            best = (label, score)
    return best


def evaluate_predictions(manifest_path, feature_dir, pred_dir):
    manifest = load_manifest(manifest_path)
    labels = Counter()
    tp = Counter()
    fp = Counter()
    fn = Counter()

    for row in manifest:
        if row["label_source"] != "manual" or not row["label_path"]:
          continue
        gold = load_manual_labels(row["label_path"])
        pred_rows = read_tsv(os.path.join(pred_dir, f"{row['sample_id']}.predictions.tsv"))
        for pred in pred_rows:
            key = (
                pred["record_kind"],
                pred["page_index"],
                pred["block_index"],
                pred["line_index"],
                pred.get("next_page_index", ""),
                pred.get("next_block_index", ""),
                pred.get("next_line_index", ""),
            )
            if key not in gold:
                continue
            g = gold[key]
            p = pred["predicted_label"]
            labels[g] += 1
            if p == g:
                tp[g] += 1
            else:
                fp[p] += 1
                fn[g] += 1

    rows = []
    all_labels = sorted(set(labels) | set(tp) | set(fp) | set(fn))
    for label in all_labels:
        t = tp[label]
        f_p = fp[label]
        f_n = fn[label]
        precision = t / (t + f_p) if (t + f_p) else 0.0
        recall = t / (t + f_n) if (t + f_n) else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
        rows.append(
            {
                "label": label,
                "tp": t,
                "fp": f_p,
                "fn": f_n,
                "precision": f"{precision:.4f}",
                "recall": f"{recall:.4f}",
                "f1": f"{f1:.4f}",
                "support": labels[label],
                "notes": "training spike / local corpus only",
            }
        )
    return rows


def main():
    parser = argparse.ArgumentParser(description="Train or evaluate the PDF layout classifier spike.")
    parser.add_argument("--manifest", default="samples/pdf_layout_classifier/manifest.tsv")
    parser.add_argument("--feature-dir", default=".tmp/pdf_layout_classifier/features")
    parser.add_argument("--output", default=".tmp/pdf_layout_classifier/models/pdf_layout_linear.json")
    parser.add_argument("--pred-dir", default=".tmp/pdf_layout_classifier/predictions")
    parser.add_argument("--summary", default=".tmp/pdf_layout_classifier/eval/summary.tsv")
    parser.add_argument("--evaluate-only", action="store_true")
    args = parser.parse_args()

    if args.evaluate_only:
        rows = evaluate_predictions(args.manifest, args.feature_dir, args.pred_dir)
        write_tsv(
            args.summary,
            rows,
            ["label", "tp", "fp", "fn", "precision", "recall", "f1", "support", "notes"],
        )
        return

    rows = load_training_rows(args.manifest, args.feature_dir)
    if not rows:
        raise SystemExit("no labeled training rows found")
    model = build_model(rows)
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(model, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
