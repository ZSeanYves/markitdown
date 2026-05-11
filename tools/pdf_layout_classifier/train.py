#!/usr/bin/env python3
import argparse
import csv
import json
import math
import os
from collections import Counter, defaultdict


RESERVED_COLUMNS = {
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
    "manual_notes",
    "key",
}


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


def parse_float(raw):
    if raw is None or raw == "":
        return 0.0
    return float(raw)


def load_manifest(path):
    rows = read_tsv(path)
    required = {
        "sample_id",
        "pdf_path",
        "record_kind",
        "split",
        "label_source",
        "label_path",
        "notes",
    }
    missing = sorted(required - set(rows[0].keys())) if rows else sorted(required)
    if missing:
        raise SystemExit(f"manifest missing required columns: {', '.join(missing)}")
    return rows


def row_key(row):
    return (
        row["record_kind"],
        row["page_index"],
        row["block_index"],
        row["line_index"],
        row.get("next_page_index", ""),
        row.get("next_block_index", ""),
        row.get("next_line_index", ""),
    )


def load_manual_labels(path):
    rows = read_tsv(path)
    out = {}
    for row in rows:
        out[row_key(row)] = {
            "label": row["label"],
            "notes": row.get("notes", ""),
        }
    return out


def annotate_features(sample_id, feature_rows, manual_labels):
    annotated = []
    for row in feature_rows:
        key = row_key(row)
        if key not in manual_labels:
            continue
        payload = manual_labels[key]
        updated = dict(row)
        updated["sample_id"] = sample_id
        updated["label"] = payload["label"]
        updated["manual_notes"] = payload["notes"]
        updated["key"] = key
        annotated.append(updated)
    return annotated


def feature_names(rows):
    if not rows:
        return []
    return [name for name in rows[0].keys() if name not in RESERVED_COLUMNS]


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
        neg_mean = [sum(col) / len(neg) for col in zip(*neg)] if neg else [0.0 for _ in pos_mean]
        values = [p - n for p, n in zip(pos_mean, neg_mean)]
        midpoint = [(p + n) / 2.0 for p, n in zip(pos_mean, neg_mean)]
        bias = -sum(v * m for v, m in zip(values, midpoint))
        pos_scores = [bias + sum(v * x for v, x in zip(values, row)) for row in pos]
        neg_scores = [bias + sum(v * x for v, x in zip(values, row)) for row in neg] or [0.0]
        min_score = (min(pos_scores) + max(neg_scores)) / 2.0
        thresholds[label] = {"min_score": min_score, "min_confidence": 0.5}
        weights[label] = {"bias": bias, "values": values}
    return weights, thresholds


def build_model(rows, manifest_path):
    names = feature_names(rows)
    xs, ys = vectorize(rows, names)
    labels = sorted(set(ys))
    means, scales = compute_normalization(xs)
    norm_xs = normalize(xs, means, scales)
    weights, thresholds = train_centroid_linear(norm_xs, ys, labels)
    label_counts = Counter(ys)
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
            "trained_from": manifest_path,
            "sample_count": str(len(rows)),
            "label_counts": {label: str(label_counts[label]) for label in sorted(label_counts)},
            "notes": "training spike / local corpus only",
        },
    }


def split_manifest_rows(manifest_rows, split):
    return [row for row in manifest_rows if row["split"] == split]


def load_labeled_rows(manifest_rows, feature_dir):
    labeled_rows = []
    sample_counts = {}
    for row in manifest_rows:
        if row["label_source"] != "manual" or not row["label_path"]:
            continue
        feature_path = os.path.join(feature_dir, f"{row['sample_id']}.features.tsv")
        if not os.path.exists(feature_path):
            raise SystemExit(f"feature file not found: {feature_path}")
        feature_rows = read_tsv(feature_path)
        manual_labels = load_manual_labels(row["label_path"])
        annotated = annotate_features(row["sample_id"], feature_rows, manual_labels)
        if not annotated:
            sample_counts[row["sample_id"]] = 0
            continue
        sample_counts[row["sample_id"]] = len(annotated)
        labeled_rows.extend(annotated)
    return labeled_rows, sample_counts


def sigmoid(score):
    if score >= 0:
        z = math.exp(-score)
        return 1.0 / (1.0 + z)
    z = math.exp(score)
    return z / (1.0 + z)


def predict_row(model, row):
    names = model["features"]
    means = model["normalization"]["mean"]
    scales = model["normalization"]["scale"]
    vector = [
        (parse_float(row.get(name, "")) - means[i]) / (scales[i] or 1.0)
        for i, name in enumerate(names)
    ]
    scored = []
    for label in model["labels"]:
        payload = model["weights"][label]
        threshold_payload = model["thresholds"].get(label, {"min_score": 0.0, "min_confidence": 0.0})
        score = payload["bias"] + sum(v * x for v, x in zip(payload["values"], vector))
        confidence = sigmoid(score)
        scored.append(
            {
                "label": label,
                "score": score,
                "confidence": confidence,
                "threshold": threshold_payload["min_score"],
                "accepted": score >= threshold_payload["min_score"]
                and confidence >= threshold_payload["min_confidence"],
            }
        )
    scored.sort(key=lambda item: (-1 if item["accepted"] else 0, -item["score"], -item["confidence"], item["label"]))
    return scored[0]


def score_split(model, rows):
    predictions = []
    for row in rows:
        best = predict_row(model, row)
        enriched = dict(row)
        enriched["predicted_label"] = best["label"]
        enriched["score"] = best["score"]
        enriched["confidence"] = best["confidence"]
        enriched["threshold"] = best["threshold"]
        enriched["accepted"] = best["accepted"]
        predictions.append(enriched)
    return predictions


def evaluate_rows(rows):
    support = Counter()
    tp = Counter()
    fp = Counter()
    fn = Counter()
    confusion = Counter()
    error_rows = []

    for row in rows:
        gold = row["label"]
        pred = row["predicted_label"]
        support[gold] += 1
        confusion[(gold, pred)] += 1
        if pred == gold:
            tp[gold] += 1
            continue
        fp[pred] += 1
        fn[gold] += 1
        error_rows.append(
            {
                "sample_id": row["sample_id"],
                "record_kind": row["record_kind"],
                "page_index": row["page_index"],
                "block_index": row["block_index"],
                "line_index": row["line_index"],
                "next_page_index": row.get("next_page_index", ""),
                "next_block_index": row.get("next_block_index", ""),
                "next_line_index": row.get("next_line_index", ""),
                "gold_label": gold,
                "predicted_label": pred,
                "score": f"{row['score']:.6f}",
                "confidence": f"{row['confidence']:.6f}",
                "accepted": "true" if row["accepted"] else "false",
                "text": row["text"],
                "notes": row.get("manual_notes", ""),
            }
        )

    summary_rows = []
    all_labels = sorted(set(support) | set(tp) | set(fp) | set(fn))
    for label in all_labels:
        t = tp[label]
        f_p = fp[label]
        f_n = fn[label]
        precision = t / (t + f_p) if (t + f_p) else 0.0
        recall = t / (t + f_n) if (t + f_n) else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
        summary_rows.append(
            {
                "label": label,
                "tp": t,
                "fp": f_p,
                "fn": f_n,
                "precision": f"{precision:.4f}",
                "recall": f"{recall:.4f}",
                "f1": f"{f1:.4f}",
                "support": support[label],
                "notes": "training spike / local corpus only",
            }
        )

    confusion_rows = []
    for gold, pred in sorted(confusion):
        confusion_rows.append(
            {
                "gold_label": gold,
                "predicted_label": pred,
                "count": confusion[(gold, pred)],
                "notes": "training spike / local corpus only",
            }
        )

    return summary_rows, confusion_rows, error_rows


def aggregate_summary_counts(summary_rows):
    tp = sum(int(row["tp"]) for row in summary_rows)
    fp = sum(int(row["fp"]) for row in summary_rows)
    fn = sum(int(row["fn"]) for row in summary_rows)
    support = sum(int(row["support"]) for row in summary_rows)
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
    return {
        "support": support,
        "precision": precision,
        "recall": recall,
        "f1": f1,
    }


def write_json(path, payload):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")


def main():
    parser = argparse.ArgumentParser(description="Train or evaluate the PDF layout classifier spike.")
    parser.add_argument("--manifest", default="samples/pdf_layout_classifier/manifest.tsv")
    parser.add_argument("--train-features", default=".tmp/pdf_layout_classifier/features")
    parser.add_argument("--heldout-features", default=".tmp/pdf_layout_classifier/features")
    parser.add_argument("--output", default=".tmp/pdf_layout_classifier/models/pdf_layout_linear.json")
    parser.add_argument("--train-summary", default=".tmp/pdf_layout_classifier/eval/train_summary.tsv")
    parser.add_argument("--heldout-summary", default=".tmp/pdf_layout_classifier/eval/heldout_summary.tsv")
    parser.add_argument("--confusion", default=".tmp/pdf_layout_classifier/eval/confusion.tsv")
    parser.add_argument("--errors", default=".tmp/pdf_layout_classifier/eval/errors.tsv")
    parser.add_argument("--pred-dir", default=".tmp/pdf_layout_classifier/predictions")
    parser.add_argument("--evaluate-only", action="store_true")
    args = parser.parse_args()

    manifest_rows = load_manifest(args.manifest)
    train_manifest = split_manifest_rows(manifest_rows, "train")
    heldout_manifest = split_manifest_rows(manifest_rows, "heldout")
    train_rows, train_sample_counts = load_labeled_rows(train_manifest, args.train_features)

    if not train_rows:
        raise SystemExit("no labeled training rows found")

    model = build_model(train_rows, args.manifest)

    if not args.evaluate_only:
        write_json(args.output, model)
        train_predictions = score_split(model, train_rows)
        train_summary_rows, _, _ = evaluate_rows(train_predictions)
        write_tsv(
            args.train_summary,
            train_summary_rows,
            ["label", "tp", "fp", "fn", "precision", "recall", "f1", "support", "notes"],
        )
        return

    heldout_rows, heldout_sample_counts = load_labeled_rows(heldout_manifest, args.heldout_features)
    if not heldout_rows:
        raise SystemExit("no labeled held-out rows found")

    train_predictions = score_split(model, train_rows)
    heldout_predictions = score_split(model, heldout_rows)

    train_summary_rows, _, _ = evaluate_rows(train_predictions)
    heldout_summary_rows, confusion_rows, error_rows = evaluate_rows(heldout_predictions)

    write_tsv(
        args.train_summary,
        train_summary_rows,
        ["label", "tp", "fp", "fn", "precision", "recall", "f1", "support", "notes"],
    )
    write_tsv(
        args.heldout_summary,
        heldout_summary_rows,
        ["label", "tp", "fp", "fn", "precision", "recall", "f1", "support", "notes"],
    )
    write_tsv(
        args.confusion,
        confusion_rows,
        ["gold_label", "predicted_label", "count", "notes"],
    )
    write_tsv(
        args.errors,
        error_rows,
        [
            "sample_id",
            "record_kind",
            "page_index",
            "block_index",
            "line_index",
            "next_page_index",
            "next_block_index",
            "next_line_index",
            "gold_label",
            "predicted_label",
            "score",
            "confidence",
            "accepted",
            "text",
            "notes",
        ],
    )

    manifest_report = {
        "train_sample_count": str(len(train_manifest)),
        "heldout_sample_count": str(len(heldout_manifest)),
        "train_labeled_row_count": str(len(train_rows)),
        "heldout_labeled_row_count": str(len(heldout_rows)),
        "train_labeled_rows_per_sample": {k: str(v) for k, v in sorted(train_sample_counts.items())},
        "heldout_labeled_rows_per_sample": {k: str(v) for k, v in sorted(heldout_sample_counts.items())},
        "train_macro_like": aggregate_summary_counts(train_summary_rows),
        "heldout_micro": aggregate_summary_counts(heldout_summary_rows),
        "notes": "training spike / local corpus only",
    }
    write_json(os.path.join(os.path.dirname(args.heldout_summary), "dataset_report.json"), manifest_report)


if __name__ == "__main__":
    main()
