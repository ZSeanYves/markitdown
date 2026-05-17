#!/usr/bin/env python3
import argparse
import collections
import csv
import json
import math
import os
import re

from train import (
    build_model,
    parse_float,
    read_tsv,
    row_key,
    sigmoid,
    write_json,
    write_tsv,
)


BLOCK_LABELS = {
    "paragraph",
    "heading",
    "table_like",
    "form_row",
    "list_item",
    "caption",
    "footer_header_noise",
    "separator",
    "link_text",
    "keep_as_text",
}

LEGACY_LABEL_MAP = {
    "BodyText": "paragraph",
    "Heading": "heading",
    "Noise": "footer_header_noise",
    "PageNumber": "footer_header_noise",
    "HeaderFooter": "footer_header_noise",
    "Caption": "caption",
    "TableLike": "table_like",
    "Unknown": "keep_as_text",
}

MODEL_EXTRA_COLUMNS = {
    "split",
    "manifest_notes",
    "label_source",
    "label_confidence",
    "raw_label",
    "gold_label",
    "manual_notes",
}

DEFAULT_PRESET = "gated_conservative_v1"

PRESETS = {
    "gated_conservative_v1": {
        "notes": (
            "Round-4 style report-only baseline: conservative gated arbitration "
            "with evidence-aware confidence/margin thresholds and precision guards."
        ),
        "naive_weights": {"rule": 0.5, "model": 0.5, "context": 0.0},
        "weighted_weights": {"rule": 0.55, "model": 0.30, "context": 0.15},
        "gated_min_confidence": {
            "default": 0.80,
            "footer_header_noise_with_evidence": 0.65,
            "paragraph_demotion_with_evidence": 0.70,
            "link_text_with_evidence": 0.65,
            "list_item_with_evidence": 0.68,
            "keep_as_text_with_evidence": 0.72,
            "table_like": 0.88,
            "form_row": 0.88,
        },
        "gated_min_gap": {
            "default": 0.08,
            "footer_header_noise_with_evidence": 0.03,
            "paragraph_demotion_with_evidence": 0.03,
            "link_text_with_evidence": 0.03,
            "list_item_with_evidence": 0.04,
            "keep_as_text_with_evidence": 0.05,
            "table_like": 0.10,
            "form_row": 0.10,
        },
    },
    "gated_conservative_tuned": {
        "notes": (
            "Slightly looser report-only gate for future ablation; not the current "
            "best-report baseline."
        ),
        "naive_weights": {"rule": 0.5, "model": 0.5, "context": 0.0},
        "weighted_weights": {"rule": 0.52, "model": 0.32, "context": 0.16},
        "gated_min_confidence": {
            "default": 0.79,
            "footer_header_noise_with_evidence": 0.63,
            "paragraph_demotion_with_evidence": 0.68,
            "link_text_with_evidence": 0.64,
            "list_item_with_evidence": 0.67,
            "keep_as_text_with_evidence": 0.70,
            "table_like": 0.87,
            "form_row": 0.87,
        },
        "gated_min_gap": {
            "default": 0.07,
            "footer_header_noise_with_evidence": 0.02,
            "paragraph_demotion_with_evidence": 0.03,
            "link_text_with_evidence": 0.03,
            "list_item_with_evidence": 0.04,
            "keep_as_text_with_evidence": 0.05,
            "table_like": 0.09,
            "form_row": 0.09,
        },
    },
}


def boolish(row, key):
    return parse_float(row.get(key, "")) >= 0.5


def number(row, key):
    return parse_float(row.get(key, ""))


def has_value(row, key):
    raw = row.get(key, "")
    return raw not in ("", None)


def near_distance(row, key, max_value):
    return has_value(row, key) and number(row, key) <= max_value


def load_manifest_rows(path):
    rows = read_tsv(path)
    if not rows:
        return []
    required = {
        "sample_id",
        "pdf_path",
        "record_kind",
        "split",
        "label_source",
        "label_path",
        "notes",
    }
    missing = sorted(required - set(rows[0].keys()))
    if missing:
        raise SystemExit(f"{path} missing required columns: {', '.join(missing)}")
    return rows


def normalize_label(raw, record_kind):
    if not raw:
        return None
    if raw in LEGACY_LABEL_MAP:
        return LEGACY_LABEL_MAP[raw]
    if raw in BLOCK_LABELS:
        return raw
    if record_kind == "boundary":
        return None
    return None


def load_label_map(path):
    rows = read_tsv(path)
    labels = {}
    for row in rows:
        label = normalize_label(row["label"], row["record_kind"])
        if not label:
            continue
        labels[row_key(row)] = {
            "raw_label": row["label"],
            "gold_label": label,
            "notes": row.get("notes", ""),
        }
    return labels


def locate_feature_path(sample_id, feature_dirs):
    for feature_dir in feature_dirs:
        path = os.path.join(feature_dir, f"{sample_id}.features.tsv")
        if os.path.exists(path):
            return path
    return None


def load_labeled_rows(manifest_rows, feature_dirs):
    labeled = []
    controls = []
    skipped = collections.Counter()
    counts_per_sample = collections.Counter()

    for manifest_row in manifest_rows:
        sample_id = manifest_row["sample_id"]
        split = manifest_row["split"]
        record_kind = manifest_row["record_kind"]
        label_source = manifest_row["label_source"]
        label_path = manifest_row.get("label_path", "")
        confidence = manifest_row.get("label_confidence", "")
        feature_path = locate_feature_path(sample_id, feature_dirs)
        if feature_path is None:
            raise SystemExit(f"missing feature file for {sample_id} in {feature_dirs}")
        feature_rows = read_tsv(feature_path)

        if label_source == "none" or not label_path:
            controls.append(
                {
                    "sample_id": sample_id,
                    "split": split,
                    "record_kind": record_kind,
                    "feature_path": feature_path,
                    "candidate_count": str(len(feature_rows)),
                    "notes": manifest_row.get("notes", ""),
                }
            )
            continue

        label_map = load_label_map(label_path)
        if record_kind != "block":
            skipped["non_block_record_kind"] += len(label_map)
            continue

        for feature_row in feature_rows:
            key = row_key(feature_row)
            if key not in label_map:
                continue
            payload = label_map[key]
            enriched = dict(feature_row)
            enriched["sample_id"] = sample_id
            enriched["split"] = split
            enriched["manifest_notes"] = manifest_row.get("notes", "")
            enriched["label_source"] = label_source
            enriched["label_confidence"] = confidence or "unspecified"
            enriched["raw_label"] = payload["raw_label"]
            enriched["gold_label"] = payload["gold_label"]
            enriched["label"] = payload["gold_label"]
            enriched["manual_notes"] = payload["notes"]
            labeled.append(enriched)
            counts_per_sample[sample_id] += 1

    return labeled, controls, skipped, counts_per_sample


def prepare_model_rows(rows):
    prepared = []
    for row in rows:
        cleaned = {}
        for key, value in row.items():
            if key in MODEL_EXTRA_COLUMNS:
                continue
            cleaned[key] = value
        prepared.append(cleaned)
    return prepared


def model_score_map(model, row):
    names = model["features"]
    means = model["normalization"]["mean"]
    scales = model["normalization"]["scale"]
    vector = [
        (parse_float(row.get(name, "")) - means[i]) / (scales[i] or 1.0)
        for i, name in enumerate(names)
    ]
    scores = {}
    raw_scores = {}
    thresholds = {}
    for label in model["labels"]:
        payload = model["weights"][label]
        threshold_payload = model["thresholds"].get(
            label,
            {"min_score": 0.0, "min_confidence": 0.0},
        )
        raw = payload["bias"] + sum(v * x for v, x in zip(payload["values"], vector))
        raw_scores[label] = raw
        scores[label] = sigmoid(raw)
        thresholds[label] = threshold_payload
    return scores, raw_scores, thresholds


def top_label(score_map):
    if not score_map:
        return ""
    return max(score_map.items(), key=lambda item: (item[1], item[0]))[0]


def second_label(score_map):
    items = sorted(score_map.items(), key=lambda item: (-item[1], item[0]))
    if len(items) < 2:
        return ""
    return items[1][0]


def hard_constraints(row, rule_label, rule_scores):
    constraints = []
    if boolish(row, "is_table_cell_candidate") and rule_label in {"table_like", "form_row"}:
        constraints.append("table_geometry")
    if boolish(row, "is_caption_candidate") and number(row, "near_image_distance") > 0:
        constraints.append("caption_geometry")
    if rule_label == "link_text" and strong_link_payload_signal(row):
        constraints.append("link_payload")
    return constraints


_BULLET_ONLY_RE = re.compile(r"^[\s\u2022\u2023\u25E6\u2043\u2219\u00B7\uF0B7]+$")
_NUMBERED_SECTION_RE = re.compile(r"^\d+(?:\.\d+)*\s+\S")
_NUMBERED_SENTENCE_RE = re.compile(r"^\d+\.\s+[a-z]")
_PHONE_TOKEN_RE = re.compile(
    r"^(?:\+?\d{1,3}[\s-]?)?(?:\(\d{2,4}\)|\d{2,4})[\s-]?\d{3,4}[\s-]?\d{4}$"
)
_CJK_SECTION_MARKER_RE = re.compile(
    r"^(?:第?[一二三四五六七八九十百千万零〇0-9]+[章节篇部卷]|[章节篇部卷附录])\S+$"
)


def text_value(row):
    return (row.get("text") or "").strip()


def standalone_bullet_marker_signal(row):
    text = text_value(row)
    return bool(text) and bool(_BULLET_ONLY_RE.fullmatch(text))


def numbered_section_heading_signal(row):
    return bool(_NUMBERED_SECTION_RE.match(text_value(row)))


def cjk_section_heading_signal(row):
    text = text_value(row)
    return number(row, "cjk_ratio") >= 0.6 and bool(_CJK_SECTION_MARKER_RE.match(text))


def numbered_sentence_signal(row):
    return (
        number(row, "word_count") >= 6
        and boolish(row, "has_terminal_period")
        and bool(_NUMBERED_SENTENCE_RE.match(text_value(row).lower()))
    )


def contact_value_signal(row):
    text = text_value(row)
    return (
        boolish(row, "contains_email")
        or boolish(row, "contains_url_or_email")
        or bool(_PHONE_TOKEN_RE.match(text))
    )


def dense_form_contact_signal(row):
    return (
        number(row, "page_block_count") >= 40
        and number(row, "word_count") <= 2
        and not boolish(row, "top_zone_candidate")
        and not boolish(row, "bottom_zone_candidate")
        and contact_value_signal(row)
    )


def technical_keep_as_text_signal(row):
    if boolish(row, "contains_url_or_email") or boolish(row, "visible_url_without_annotation"):
        return False
    if boolish(row, "repeated_edge_candidate") and number(row, "repeated_text_score") >= 0.5:
        return False
    if (
        any(boolish(row, key) for key in ("contains_currency", "contains_time", "contains_date"))
        and not any(boolish(row, key) for key in ("contains_path_like", "identifier_like_signal", "option_like_signal"))
    ):
        return False
    if (
        any(boolish(row, key) for key in ("looks_like_bullet", "looks_like_list_marker_token"))
        and not boolish(row, "option_like_signal")
        and number(row, "word_count") >= 4
    ):
        return False
    return any(
        boolish(row, key)
        for key in (
            "technical_literal_signal",
            "identifier_like_signal",
            "contains_path_like",
            "code_like_signal",
            "option_like_signal",
        )
    )


def sentence_paragraph_signal(row):
    return boolish(row, "sentence_like_signal") and not boolish(row, "technical_literal_signal")


def citation_paragraph_signal(row):
    return (
        boolish(row, "citation_reference_signal")
        and sentence_paragraph_signal(row)
        and number(row, "link_text_coverage_ratio") <= 0.35
    )


def receipt_form_signal(row):
    return any(
        boolish(row, key)
        for key in (
            "receipt_line_item_signal",
            "quantity_price_signal",
            "payment_card_signal",
        )
    )


def cleanup_shell_heading_signal(row):
    return boolish(row, "cleanup_shell_signal")


def toc_internal_anchor_signal(row):
    return boolish(row, "toc_like_anchor_signal") and any(
        boolish(row, key) for key in ("link_target_internal", "link_target_named")
    )


def page_anchor_link_signal(row):
    return boolish(row, "page_number_like_link") and (
        number(row, "word_count") >= 2
        or not any(
            boolish(row, key)
            for key in ("is_page_number_candidate", "is_header_footer_candidate", "looks_like_page_number")
        )
    )


def paragraph_link_context_signal(row):
    return (
        boolish(row, "link_target_uri")
        and not toc_internal_anchor_signal(row)
        and not boolish(row, "page_number_like_link")
        and not boolish(row, "contains_path_like")
        and (
            number(row, "word_count") >= 8
            or (
                number(row, "word_count") >= 5
                and (
                    boolish(row, "has_terminal_period")
                    or boolish(row, "contains_clause_punctuation")
                    or boolish(row, "ends_with_colon")
                )
            )
        )
    )


def narrative_anchor_paragraph_signal(row):
    return (
        any(boolish(row, key) for key in ("link_target_internal", "link_target_named"))
        and not toc_internal_anchor_signal(row)
        and not page_anchor_link_signal(row)
        and not boolish(row, "is_link_only_candidate")
        and number(row, "link_text_coverage_ratio") >= 0.75
        and (
            number(row, "word_count") >= 16
            or (
                number(row, "word_count") >= 8
                and (
                    boolish(row, "has_terminal_period")
                    or boolish(row, "contains_clause_punctuation")
                    or boolish(row, "same_paragraph_candidate")
                    or boolish(row, "wrapped_candidate")
                )
            )
        )
    )


def strong_link_payload_signal(row):
    if paragraph_link_context_signal(row) or narrative_anchor_paragraph_signal(row):
        return False
    if boolish(row, "has_link_inline"):
        return True
    if boolish(row, "is_link_only_candidate"):
        return not (
            any(
                boolish(row, key)
                for key in ("is_page_number_candidate", "is_header_footer_candidate", "looks_like_page_number")
            )
            and not page_anchor_link_signal(row)
        )
    if page_anchor_link_signal(row) or toc_internal_anchor_signal(row):
        return True
    if boolish(row, "link_target_uri") and number(row, "link_text_coverage_ratio") >= 0.55:
        return True
    return (
        any(boolish(row, key) for key in ("link_target_internal", "link_target_named"))
        and number(row, "link_overlap_ratio") >= 0.55
    )


def partial_link_paragraph_signal(row):
    return (
        boolish(row, "has_partial_link")
        and not boolish(row, "is_link_only_candidate")
        and number(row, "word_count") >= 4
        and (
            number(row, "word_count") >= 7
            or boolish(row, "contains_clause_punctuation")
            or boolish(row, "has_terminal_period")
        )
    )


def visible_url_boundary_signal(row):
    if receipt_form_signal(row):
        return False
    return boolish(row, "visible_url_without_annotation") or (
        boolish(row, "contains_url_or_email")
        and not strong_link_payload_signal(row)
        and number(row, "word_count") >= 6
    )


def caption_negative_signal(row):
    return any(
        boolish(row, key)
        for key in (
            "caption_reference_only_signal",
            "caption_lead_in_signal",
            "asset_metadata_noise_signal",
            "caption_heading_conflict_signal",
        )
    )


def caption_positive_signal(row):
    if caption_negative_signal(row):
        return False
    if boolish(row, "is_caption_candidate"):
        return True
    if boolish(row, "caption_marker_signal") and not any(
        boolish(row, key) for key in ("is_header_footer_candidate", "is_page_number_candidate")
    ):
        return True
    return boolish(row, "caption_marker_starts_line") and boolish(row, "near_image_object_signal")


def short_title_heading_signal(row):
    if boolish(row, "has_terminal_period") or boolish(row, "contains_clause_punctuation"):
        return False
    if any(
        boolish(row, key)
        for key in (
            "contains_currency",
            "contains_time",
            "contains_date",
            "looks_like_address",
            "contains_path_like",
            "code_like_signal",
        )
    ):
        return False
    if number(row, "word_count") > 3 or boolish(row, "bottom_zone_candidate"):
        return False
    if not (boolish(row, "top_zone_candidate") or number(row, "relative_font_size") >= 1.15):
        return False
    return numbered_section_heading_signal(row) or cjk_section_heading_signal(row)


def rule_score_map(row):
    scores = collections.defaultdict(float)
    scores["paragraph"] = 0.52
    scores["keep_as_text"] = 0.20
    scores["link_text"] = 0.12

    if boolish(row, "is_heading_kind"):
        scores["heading"] = 0.96
    elif boolish(row, "is_heading_candidate"):
        scores["heading"] = 0.76
    if "heading" in scores:
        heading_cap = None
        if any(
            boolish(row, key)
            for key in ("contains_currency", "contains_time", "contains_date")
        ):
            heading_cap = 0.28
            scores["form_row"] = max(scores["form_row"], 0.74)
        if boolish(row, "looks_like_address"):
            heading_cap = min(heading_cap or 0.28, 0.28)
            scores["paragraph"] = max(scores["paragraph"], 0.72)
        if any(
            boolish(row, key)
            for key in ("contains_path_like", "code_like_signal")
        ):
            heading_cap = min(heading_cap or 0.28, 0.28)
            scores["keep_as_text"] = max(scores["keep_as_text"], 0.82)
        if (
            not boolish(row, "top_zone_candidate")
            and number(row, "relative_font_size") <= 0.95
            and number(row, "word_count") >= 3
            and number(row, "uppercase_ratio") <= 0.3
        ):
            heading_cap = min(heading_cap or 0.34, 0.34)
            scores["paragraph"] = max(scores["paragraph"], 0.62)
        if (
            number(row, "uppercase_ratio") >= 0.85
            and number(row, "relative_font_size") <= 1.02
            and number(row, "page_block_count") >= 30
        ):
            heading_cap = min(heading_cap or 0.34, 0.34)
            scores["paragraph"] = max(scores["paragraph"], 0.62)
        if (
            number(row, "cjk_ratio") >= 0.55
            and boolish(row, "contains_clause_punctuation")
            and not boolish(row, "top_zone_candidate")
        ):
            heading_cap = min(heading_cap or 0.18, 0.18)
            scores["paragraph"] = max(scores["paragraph"], 0.84)
        if (
            has_value(row, "near_annotation_distance")
            and number(row, "near_annotation_distance") <= 4.0
            and not link_text_evidence(row)
            and number(row, "word_count") <= 2
            and not boolish(row, "has_terminal_period")
        ):
            heading_cap = min(heading_cap or 0.26, 0.26)
            scores["keep_as_text"] = max(scores["keep_as_text"], 0.68)
        if heading_cap is not None:
            scores["heading"] = min(scores["heading"], heading_cap)
    elif short_title_heading_signal(row):
        scores["heading"] = max(scores["heading"], 0.82)

    if caption_positive_signal(row):
        scores["caption"] = max(
            scores["caption"],
            0.86 if boolish(row, "near_image_object_signal") else 0.78,
        )
    elif boolish(row, "caption_marker_signal"):
        scores["caption"] = max(scores["caption"], 0.68)
    if caption_negative_signal(row):
        scores["paragraph"] = max(scores["paragraph"], 0.78)
        scores["caption"] = min(scores["caption"], 0.24)
        if boolish(row, "asset_metadata_noise_signal"):
            scores["keep_as_text"] = max(scores["keep_as_text"], 0.68)
    if boolish(row, "is_table_cell_candidate"):
        scores["table_like"] = max(scores["table_like"], 0.82)
    if number(row, "form_key_value_signal") >= 0.5:
        scores["form_row"] = max(scores["form_row"], 0.86)
    elif any(
        boolish(row, key)
        for key in ("contains_currency", "contains_time", "contains_date")
    ):
        scores["form_row"] = max(scores["form_row"], 0.64)
    if (
        boolish(row, "ends_with_colon")
        and number(row, "word_count") >= 5
        and not boolish(row, "option_like_signal")
        and not boolish(row, "looks_like_bullet")
    ):
        scores["paragraph"] = max(scores["paragraph"], 0.74)
        scores["form_row"] = min(scores["form_row"], 0.22)
    if (
        boolish(row, "ends_with_colon")
        and 2 <= number(row, "word_count") <= 3
        and not boolish(row, "top_zone_candidate")
        and not any(
            boolish(row, key)
            for key in (
                "contains_currency",
                "contains_time",
                "contains_date",
                "looks_like_address",
                "contains_path_like",
                "code_like_signal",
            )
        )
    ):
        scores["paragraph"] = max(scores["paragraph"], 0.68)
        scores["form_row"] = min(scores["form_row"], 0.18)
    if boolish(row, "looks_like_separator"):
        scores["separator"] = max(scores["separator"], 0.95)
        scores["list_item"] = min(scores["list_item"], 0.05)
    if boolish(row, "looks_like_bullet") and not boolish(row, "looks_like_separator"):
        scores["list_item"] = max(scores["list_item"], 0.72)
        if number(row, "digit_ratio") >= 0.5 and number(row, "word_count") <= 2:
            scores["list_item"] = min(scores["list_item"], 0.16)
            scores["footer_header_noise"] = max(scores["footer_header_noise"], 0.58)
    if standalone_bullet_marker_signal(row):
        scores["paragraph"] = max(scores["paragraph"], 0.58)
        scores["list_item"] = min(scores["list_item"], 0.05)
    if numbered_sentence_signal(row):
        scores["paragraph"] = max(scores["paragraph"], 0.72)
        scores["list_item"] = min(scores["list_item"], 0.18)
    if boolish(row, "looks_like_list_marker_token") and not standalone_bullet_marker_signal(row):
        scores["list_item"] = max(scores["list_item"], 0.82)
    if boolish(row, "option_like_signal"):
        scores["keep_as_text"] = max(scores["keep_as_text"], 0.86)
        scores["paragraph"] = max(scores["paragraph"], 0.58)
        if not boolish(row, "contains_path_like"):
            scores["list_item"] = min(scores["list_item"], 0.18)
        if number(row, "form_key_value_signal") >= 0.5:
            scores["form_row"] = min(scores["form_row"], 0.26)
    if any(
        boolish(row, key)
        for key in (
            "is_noise_kind",
            "is_page_number_candidate",
            "is_header_footer_candidate",
            "is_artifact_candidate",
        )
    ):
        scores["footer_header_noise"] = max(scores["footer_header_noise"], 0.88)
    if boolish(row, "repeated_edge_candidate") or (
        number(row, "repeated_text_score") >= 0.34
        and (
            boolish(row, "top_zone_candidate")
            or boolish(row, "bottom_zone_candidate")
        )
    ):
        scores["footer_header_noise"] = max(scores["footer_header_noise"], 0.94)
    elif repeated_shell_evidence(row):
        scores["footer_header_noise"] = max(scores["footer_header_noise"], 0.92)
    if repeated_shell_evidence(row):
        scores["heading"] = min(scores.get("heading", 0.0), 0.24)
    if cleanup_shell_heading_signal(row):
        scores["heading"] = max(scores["heading"], 0.92)
        scores["paragraph"] = max(scores["paragraph"], 0.58)
        scores["footer_header_noise"] = min(scores["footer_header_noise"], 0.54)

    if citation_paragraph_signal(row):
        scores["paragraph"] = max(scores["paragraph"], 0.84)
        scores["keep_as_text"] = min(scores["keep_as_text"], 0.34)
        scores["link_text"] = min(scores["link_text"], 0.18)
    elif sentence_paragraph_signal(row) and (
        boolish(row, "contains_url_or_email") or boolish(row, "citation_reference_signal")
    ):
        scores["paragraph"] = max(scores["paragraph"], 0.72)

    if technical_keep_as_text_signal(row):
        technical_floor = 0.86
        if boolish(row, "identifier_like_signal") or boolish(row, "contains_path_like"):
            technical_floor = 0.90
        elif boolish(row, "option_like_signal") or boolish(row, "code_like_signal"):
            technical_floor = 0.88
        scores["keep_as_text"] = max(scores["keep_as_text"], technical_floor)
        if not sentence_paragraph_signal(row) and not citation_paragraph_signal(row):
            scores["paragraph"] = min(scores["paragraph"], 0.48)
        if "heading" in scores:
            scores["heading"] = min(scores["heading"], 0.24)
        scores["list_item"] = min(scores["list_item"], 0.16)
        scores["footer_header_noise"] = min(scores["footer_header_noise"], 0.28)

    if receipt_form_signal(row):
        form_floor = 0.88
        if boolish(row, "payment_card_signal"):
            form_floor = 0.92
        elif boolish(row, "receipt_line_item_signal"):
            form_floor = 0.90
        scores["form_row"] = max(scores["form_row"], form_floor)
        scores["paragraph"] = min(scores["paragraph"], 0.42)
        scores["keep_as_text"] = min(scores["keep_as_text"], 0.26)
        scores["list_item"] = min(scores["list_item"], 0.10)
        if "heading" in scores:
            scores["heading"] = min(scores["heading"], 0.18)

    if visible_url_boundary_signal(row):
        scores["paragraph"] = max(scores["paragraph"], 0.66)
        scores["keep_as_text"] = max(scores["keep_as_text"], 0.72)
        scores["link_text"] = min(scores["link_text"], 0.22)
    elif paragraph_link_context_signal(row):
        scores["paragraph"] = max(scores["paragraph"], 0.86)
        scores["link_text"] = min(scores["link_text"], 0.20)
    elif narrative_anchor_paragraph_signal(row):
        scores["paragraph"] = max(scores["paragraph"], 0.84)
        scores["link_text"] = min(scores["link_text"], 0.20)
    elif partial_link_paragraph_signal(row):
        scores["paragraph"] = max(scores["paragraph"], 0.82)
        scores["keep_as_text"] = max(scores["keep_as_text"], 0.44)
        scores["link_text"] = min(scores["link_text"], 0.30)
    if page_anchor_link_signal(row):
        scores["link_text"] = max(scores["link_text"], 0.97)
        scores["footer_header_noise"] = min(scores["footer_header_noise"], 0.58)
    elif toc_internal_anchor_signal(row):
        scores["link_text"] = max(scores["link_text"], 0.95)
        scores["list_item"] = min(scores["list_item"], 0.18)
        scores["caption"] = min(scores["caption"], 0.20)
    elif strong_link_payload_signal(row):
        scores["link_text"] = max(scores["link_text"], 0.97)
    elif near_distance(row, "near_dest_annotation_distance", 2.0) and short_link_anchor_candidate(row):
        scores["link_text"] = max(scores["link_text"], 0.96)
    elif near_distance(row, "near_link_annotation_distance", 2.0) and short_link_anchor_candidate(row):
        scores["link_text"] = max(scores["link_text"], 0.92)
    elif (
        boolish(row, "link_target_uri")
        and number(row, "link_text_coverage_ratio") >= 0.45
        and number(row, "word_count") <= 8
    ):
        scores["link_text"] = max(scores["link_text"], 0.88)
    elif near_distance(row, "near_dest_annotation_distance", 8.0) and short_link_anchor_candidate(row):
        scores["link_text"] = max(scores["link_text"], 0.79)
    if dense_form_contact_signal(row):
        scores["form_row"] = max(scores["form_row"], 0.86)
        scores["link_text"] = min(scores["link_text"], 0.34)
        scores["keep_as_text"] = min(scores["keep_as_text"], 0.42)
    if boolish(row, "contains_url_or_email") and not citation_paragraph_signal(row) and not receipt_form_signal(row):
        scores["keep_as_text"] = max(scores["keep_as_text"], 0.58)
        scores["paragraph"] = max(scores["paragraph"], 0.56)
    if any(
        boolish(row, key)
        for key in (
            "contains_path_like",
            "code_like_signal",
            "monospace_hint",
            "technical_literal_signal",
            "identifier_like_signal",
        )
    ):
        scores["keep_as_text"] = max(scores["keep_as_text"], 0.74)
    if boolish(row, "looks_like_address"):
        scores["paragraph"] = max(scores["paragraph"], 0.72)
    if boolish(row, "caption_marker_signal") and not caption_negative_signal(row):
        scores["paragraph"] = max(scores["paragraph"], 0.44)

    return dict(scores)


def context_score_map(row):
    scores = collections.defaultdict(float)
    if boolish(row, "looks_like_address"):
        scores["paragraph"] += 0.18
    if any(
        boolish(row, key)
        for key in ("contains_currency", "contains_time", "contains_date")
    ):
        scores["form_row"] += 0.14
    if receipt_form_signal(row):
        scores["form_row"] += 0.28
        if boolish(row, "payment_card_signal"):
            scores["form_row"] += 0.06
    if boolish(row, "looks_like_separator"):
        scores["separator"] += 0.20
    if boolish(row, "is_table_cell_candidate"):
        scores["table_like"] += 0.16
    if number(row, "form_key_value_signal") >= 0.5:
        scores["form_row"] += 0.22
    if boolish(row, "is_page_number_candidate") or boolish(row, "is_header_footer_candidate"):
        if not cleanup_shell_heading_signal(row):
            scores["footer_header_noise"] += 0.12
    if boolish(row, "looks_like_bullet") and not boolish(row, "looks_like_separator"):
        scores["list_item"] += 0.12
    if boolish(row, "looks_like_list_marker_token") and not standalone_bullet_marker_signal(row):
        scores["list_item"] += 0.18
    if number(row, "relative_font_size") >= 1.12 and number(row, "line_count") <= 1:
        scores["heading"] += 0.10
    if cleanup_shell_heading_signal(row):
        scores["heading"] += 0.24
    if boolish(row, "same_paragraph_candidate") or boolish(row, "wrapped_candidate"):
        scores["paragraph"] += 0.10
    if caption_positive_signal(row):
        scores["caption"] += 0.18
    elif boolish(row, "caption_marker_signal"):
        scores["caption"] += 0.16
    if caption_negative_signal(row):
        scores["paragraph"] += 0.18
        if boolish(row, "asset_metadata_noise_signal"):
            scores["keep_as_text"] += 0.12
    if boolish(row, "contains_url_or_email") and not citation_paragraph_signal(row) and not receipt_form_signal(row):
        scores["keep_as_text"] += 0.10
        scores["paragraph"] += 0.04
    if page_anchor_link_signal(row):
        scores["link_text"] += 0.28
    elif toc_internal_anchor_signal(row):
        scores["link_text"] += 0.30
    elif strong_link_payload_signal(row):
        scores["link_text"] += 0.24
    if near_distance(row, "near_dest_annotation_distance", 2.0) and short_link_anchor_candidate(row):
        scores["link_text"] += 0.24
    elif near_distance(row, "near_link_annotation_distance", 2.0) and short_link_anchor_candidate(row):
        scores["link_text"] += 0.20
    if boolish(row, "link_target_uri") and number(row, "link_text_coverage_ratio") >= 0.35:
        scores["link_text"] += 0.18
    if near_distance(row, "near_dest_annotation_distance", 8.0) and short_link_anchor_candidate(row):
        scores["link_text"] += 0.12
    if partial_link_paragraph_signal(row):
        scores["paragraph"] += 0.18
    if paragraph_link_context_signal(row):
        scores["paragraph"] += 0.20
    if narrative_anchor_paragraph_signal(row):
        scores["paragraph"] += 0.18
    if citation_paragraph_signal(row):
        scores["paragraph"] += 0.24
    elif sentence_paragraph_signal(row) and (
        boolish(row, "contains_url_or_email") or boolish(row, "citation_reference_signal")
    ):
        scores["paragraph"] += 0.12
    if visible_url_boundary_signal(row):
        scores["paragraph"] += 0.10
        scores["keep_as_text"] += 0.14
    if boolish(row, "repeated_edge_candidate") and not cleanup_shell_heading_signal(row):
        scores["footer_header_noise"] += 0.28
    elif repeated_shell_evidence(row):
        scores["footer_header_noise"] += 0.24
    elif (
        number(row, "repeated_text_score") >= 0.34
        and (
            boolish(row, "top_zone_candidate")
            or boolish(row, "bottom_zone_candidate")
        )
        and not cleanup_shell_heading_signal(row)
    ):
        scores["footer_header_noise"] += 0.18
    if technical_keep_as_text_signal(row):
        scores["keep_as_text"] += 0.20
    elif boolish(row, "contains_path_like") or boolish(row, "code_like_signal"):
        scores["keep_as_text"] += 0.16
    if boolish(row, "monospace_hint"):
        scores["keep_as_text"] += 0.10
    if boolish(row, "has_terminal_period"):
        scores["paragraph"] += 0.06
    if boolish(row, "option_like_signal"):
        scores["keep_as_text"] += 0.18
        scores["paragraph"] += 0.04
    if (
        number(row, "cjk_ratio") >= 0.55
        and boolish(row, "contains_clause_punctuation")
        and not boolish(row, "top_zone_candidate")
    ):
        scores["paragraph"] += 0.16
    return dict(scores)


def merge_labels(rule_scores, model_scores):
    labels = set(rule_scores) | set(model_scores) | BLOCK_LABELS
    return sorted(labels)


def combine_weighted(rule_scores, model_scores, context_scores, labels, config):
    out = {}
    for label in labels:
        out[label] = (
            config["rule"] * rule_scores.get(label, 0.0)
            + config["model"] * model_scores.get(label, 0.0)
            + config["context"] * context_scores.get(label, 0.0)
        )
    return out


def allowed_override(rule_label, model_label):
    allowed = {
        ("heading", "paragraph"),
        ("heading", "form_row"),
        ("heading", "footer_header_noise"),
        ("heading", "separator"),
        ("heading", "link_text"),
        ("heading", "keep_as_text"),
        ("separator", "paragraph"),
        ("separator", "footer_header_noise"),
        ("list_item", "separator"),
        ("list_item", "footer_header_noise"),
        ("list_item", "link_text"),
        ("paragraph", "form_row"),
        ("paragraph", "table_like"),
        ("paragraph", "caption"),
        ("paragraph", "link_text"),
        ("paragraph", "keep_as_text"),
        ("footer_header_noise", "link_text"),
        ("form_row", "paragraph"),
        ("form_row", "list_item"),
        ("caption", "paragraph"),
        ("table_like", "form_row"),
        ("form_row", "table_like"),
        ("link_text", "paragraph"),
        ("link_text", "keep_as_text"),
    }
    return (rule_label, model_label) in allowed


def safe_figure_reference_paragraph_override(row, rule_label, weighted_label):
    return (
        rule_label == "keep_as_text"
        and weighted_label == "paragraph"
        and boolish(row, "figure_reference_sentence_signal")
        and boolish(row, "sentence_like_signal")
        and caption_negative_signal(row)
        and not caption_positive_signal(row)
        and not boolish(row, "near_image_object_signal")
        and not any(
            boolish(row, key)
            for key in (
                "contains_path_like",
                "identifier_like_signal",
                "option_like_signal",
                "monospace_hint",
                "visible_url_without_annotation",
                "contains_url_or_email",
                "payment_card_signal",
                "quantity_price_signal",
                "receipt_line_item_signal",
            )
        )
    )


def footer_noise_evidence(row):
    if cleanup_shell_heading_signal(row):
        return False
    return repeated_shell_evidence(row) or boolish(row, "repeated_edge_candidate") or any(
        boolish(row, key)
        for key in ("is_page_number_candidate", "is_header_footer_candidate", "looks_like_page_number")
    )


def paragraph_demote_evidence(row):
    return (
        boolish(row, "looks_like_address")
        or boolish(row, "has_terminal_period")
        or boolish(row, "same_paragraph_candidate")
        or boolish(row, "wrapped_candidate")
        or number(row, "word_count") >= 6
    )


def repeated_shell_evidence(row):
    if cleanup_shell_heading_signal(row):
        return False
    return (
        number(row, "repeated_text_score") >= 0.9
        and number(row, "word_count") <= 4
        and number(row, "page_block_count") <= 8
        and not boolish(row, "has_terminal_period")
    )


def short_link_anchor_candidate(row):
    if page_anchor_link_signal(row) or toc_internal_anchor_signal(row):
        return True
    if any(
        boolish(row, key)
        for key in ("is_page_number_candidate", "is_header_footer_candidate", "looks_like_page_number")
    ):
        return False
    word_count = number(row, "word_count")
    text = (row.get("text") or "").strip().lower()
    if word_count <= 2:
        return True
    return word_count <= 5 and (
        text.startswith("go to ")
        or text.startswith("see ")
        or text.startswith("open ")
    )


def link_text_evidence(row):
    return strong_link_payload_signal(row) or (
        boolish(row, "link_target_uri") and number(row, "link_text_coverage_ratio") >= 0.45
    )


def list_item_evidence(row):
    return boolish(row, "looks_like_bullet") or boolish(row, "looks_like_list_marker_token")


def keep_as_text_evidence(row):
    return any(
        boolish(row, key)
        for key in (
            "contains_path_like",
            "code_like_signal",
            "monospace_hint",
            "option_like_signal",
            "technical_literal_signal",
            "identifier_like_signal",
        )
    )


def resolve_gated_threshold(config, family, row, rule_label, weighted_label):
    thresholds = config[family]
    if weighted_label == "footer_header_noise" and footer_noise_evidence(row):
        return thresholds["footer_header_noise_with_evidence"]
    if weighted_label == "paragraph" and rule_label in {"heading", "form_row"} and paragraph_demote_evidence(row):
        return thresholds["paragraph_demotion_with_evidence"]
    if weighted_label == "link_text" and link_text_evidence(row):
        return thresholds["link_text_with_evidence"]
    if weighted_label == "list_item" and list_item_evidence(row):
        return thresholds["list_item_with_evidence"]
    if weighted_label == "keep_as_text" and keep_as_text_evidence(row):
        return thresholds["keep_as_text_with_evidence"]
    if weighted_label in {"table_like", "form_row"}:
        return thresholds[weighted_label]
    return thresholds["default"]


def fails_precision_guard(row, rule_label, weighted_label, rule_scores):
    if weighted_label in {"heading", "table_like"} and rule_scores.get(weighted_label, 0.0) < 0.45:
        return True
    if weighted_label == "form_row":
        return rule_scores.get(weighted_label, 0.0) < 0.45 and not (
            number(row, "form_key_value_signal") >= 0.5
            or any(boolish(row, key) for key in ("contains_currency", "contains_time", "contains_date"))
            or receipt_form_signal(row)
        )
    if weighted_label == "link_text":
        return rule_scores.get(weighted_label, 0.0) < 0.45 and not link_text_evidence(row)
    if weighted_label == "list_item":
        return rule_scores.get(weighted_label, 0.0) < 0.45 and not list_item_evidence(row)
    return False


def predict_row(row, model, config):
    rule_scores = rule_score_map(row)
    context_scores = context_score_map(row)
    model_scores, model_raw, thresholds = model_score_map(model, row)
    labels = merge_labels(rule_scores, model_scores)

    rule_label = top_label(rule_scores)
    model_label = top_label(model_scores)
    model_second = second_label(model_scores)
    model_confidence = model_scores.get(model_label, 0.0)
    model_margin = model_confidence - model_scores.get(model_second, 0.0)
    constraints = hard_constraints(row, rule_label, rule_scores)

    naive_scores = combine_weighted(
        rule_scores,
        model_scores,
        {},
        labels,
        config["naive_weights"],
    )
    weighted_scores = combine_weighted(
        rule_scores,
        model_scores,
        context_scores,
        labels,
        config["weighted_weights"],
    )

    weighted_label = top_label(weighted_scores)
    weighted_second = second_label(weighted_scores)
    weighted_margin = weighted_scores.get(weighted_label, 0.0) - weighted_scores.get(weighted_second, 0.0)
    gated_label = rule_label
    override_blocked = ""
    if weighted_label != rule_label:
        if constraints:
            override_blocked = ",".join(constraints)
        elif safe_figure_reference_paragraph_override(row, rule_label, weighted_label):
            gated_label = weighted_label
        elif not allowed_override(rule_label, weighted_label):
            override_blocked = "conflict_policy"
        elif model_confidence < resolve_gated_threshold(
            config,
            "gated_min_confidence",
            row,
            rule_label,
            weighted_label,
        ):
            override_blocked = "model_confidence"
        elif weighted_margin < resolve_gated_threshold(
            config,
            "gated_min_gap",
            row,
            rule_label,
            weighted_label,
        ):
            override_blocked = "weighted_margin"
        elif fails_precision_guard(row, rule_label, weighted_label, rule_scores):
            override_blocked = "precision_guard"
        else:
            gated_label = weighted_label

    return {
        "gold_label": row["gold_label"],
        "rule_scores": rule_scores,
        "model_scores": model_scores,
        "model_raw_scores": model_raw,
        "context_scores": context_scores,
        "rule_label": rule_label,
        "model_label": model_label,
        "weighted_label": weighted_label,
        "gated_label": gated_label,
        "naive_label": top_label(naive_scores),
        "rule_model_conflict": rule_label != model_label,
        "constraints": constraints,
        "override_blocked": override_blocked,
        "model_confidence": model_confidence,
        "model_margin": model_margin,
        "weighted_margin": weighted_margin,
        "thresholds": thresholds,
    }


def evaluate_predictions(predictions, label_key):
    support = collections.Counter()
    tp = collections.Counter()
    fp = collections.Counter()
    fn = collections.Counter()
    confusion = collections.Counter()
    sample_stats = collections.defaultdict(lambda: {"correct": 0, "total": 0})
    error_rows = []

    for row in predictions:
        gold = row["gold_label"]
        pred = row[label_key]
        support[gold] += 1
        confusion[(gold, pred)] += 1
        sample_stats[row["sample_id"]]["total"] += 1
        if pred == gold:
            tp[gold] += 1
            sample_stats[row["sample_id"]]["correct"] += 1
        else:
            fp[pred] += 1
            fn[gold] += 1
            error_rows.append(
                {
                    "sample_id": row["sample_id"],
                    "split": row["split"],
                    "gold_label": gold,
                    "predicted_label": pred,
                    "rule_label": row["rule_label"],
                    "model_label": row["model_label"],
                    "weighted_label": row["weighted_label"],
                    "gated_label": row["gated_label"],
                    "override_blocked": row.get("override_blocked", ""),
                    "model_confidence": round(row.get("model_confidence", 0.0), 4),
                    "model_margin": round(row.get("model_margin", 0.0), 4),
                    "weighted_margin": round(row.get("weighted_margin", 0.0), 4),
                    "text": row["text"],
                    "manual_notes": row.get("manual_notes", ""),
                }
            )

    per_label = []
    all_labels = sorted(set(support) | set(tp) | set(fp) | set(fn))
    for label in all_labels:
        t = tp[label]
        f_p = fp[label]
        f_n = fn[label]
        precision = t / (t + f_p) if (t + f_p) else 0.0
        recall = t / (t + f_n) if (t + f_n) else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
        per_label.append(
            {
                "label": label,
                "tp": t,
                "fp": f_p,
                "fn": f_n,
                "precision": round(precision, 4),
                "recall": round(recall, 4),
                "f1": round(f1, 4),
                "support": support[label],
            }
        )

    total_tp = sum(tp.values())
    total_fp = sum(fp.values())
    total_fn = sum(fn.values())
    micro_precision = total_tp / (total_tp + total_fp) if (total_tp + total_fp) else 0.0
    micro_recall = total_tp / (total_tp + total_fn) if (total_tp + total_fn) else 0.0
    micro_f1 = (
        2 * micro_precision * micro_recall / (micro_precision + micro_recall)
        if (micro_precision + micro_recall)
        else 0.0
    )

    targeted = {
        "heading_false_positive_count": sum(
            1 for row in predictions if row[label_key] == "heading" and row["gold_label"] != "heading"
        ),
        "separator_as_list_count": sum(
            1
            for row in predictions
            if row["gold_label"] == "separator" and row[label_key] == "list_item"
        ),
        "false_table_promotion_count": sum(
            1
            for row in predictions
            if row[label_key] in {"table_like", "form_row"}
            and row["gold_label"] not in {"table_like", "form_row"}
        ),
        "false_noise_drop_count": sum(
            1
            for row in predictions
            if row[label_key] == "footer_header_noise"
            and row["gold_label"] not in {"footer_header_noise", "separator"}
        ),
        "footer_header_false_negative_count": sum(
            1
            for row in predictions
            if row["gold_label"] == "footer_header_noise"
            and row[label_key] != "footer_header_noise"
        ),
        "link_text_false_positive_count": sum(
            1 for row in predictions if row[label_key] == "link_text" and row["gold_label"] != "link_text"
        ),
        "link_text_false_negative_count": sum(
            1
            for row in predictions
            if row["gold_label"] == "link_text"
            and row[label_key] != "link_text"
        ),
    }

    confusion_rows = [
        {"gold_label": gold, "predicted_label": pred, "count": count}
        for (gold, pred), count in sorted(confusion.items())
    ]
    sample_rows = []
    for sample_id, stats in sorted(sample_stats.items()):
        total = stats["total"]
        correct = stats["correct"]
        sample_rows.append(
            {
                "sample_id": sample_id,
                "correct": correct,
                "total": total,
                "accuracy": round(correct / total, 4) if total else 0.0,
            }
        )
    return {
        "micro": {
            "support": sum(support.values()),
            "precision": round(micro_precision, 4),
            "recall": round(micro_recall, 4),
            "f1": round(micro_f1, 4),
        },
        "per_label": per_label,
        "targeted": targeted,
        "confusion": confusion_rows,
        "sample_rows": sample_rows,
        "errors": error_rows,
    }


def build_prediction_rows(rows, model, config):
    out = []
    for row in rows:
        pred = predict_row(row, model, config)
        enriched = dict(row)
        enriched.update(pred)
        out.append(enriched)
    return out


def summarize_conflicts(predictions):
    counts = collections.Counter()
    for row in predictions:
        counts[(row["rule_label"], row["model_label"])] += 1
    return [
        {"rule_label": rule, "model_label": model, "count": count}
        for (rule, model), count in sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    ]


def compare_against_rules(rule_metrics, other_metrics):
    rule_by_sample = {row["sample_id"]: row for row in rule_metrics["sample_rows"]}
    delta_rows = []
    improved = 0
    regressed = 0
    for row in other_metrics["sample_rows"]:
        sample_id = row["sample_id"]
        baseline = rule_by_sample.get(sample_id, {"accuracy": 0.0, "correct": 0, "total": 0})
        delta = row["accuracy"] - baseline["accuracy"]
        if delta > 0:
            improved += 1
        elif delta < 0:
            regressed += 1
        delta_rows.append(
            {
                "sample_id": sample_id,
                "baseline_accuracy": baseline["accuracy"],
                "candidate_accuracy": row["accuracy"],
                "delta_accuracy": round(delta, 4),
            }
        )
    return {
        "improved_sample_count": improved,
        "regressed_sample_count": regressed,
        "sample_deltas": delta_rows,
    }


def write_strategy_outputs(output_dir, split_name, strategy_name, metrics):
    base = os.path.join(output_dir, f"{split_name}_{strategy_name}")
    write_tsv(
        base + "_summary.tsv",
        metrics["per_label"],
        ["label", "tp", "fp", "fn", "precision", "recall", "f1", "support"],
    )
    write_tsv(
        base + "_confusion.tsv",
        metrics["confusion"],
        ["gold_label", "predicted_label", "count"],
    )
    write_tsv(
        base + "_errors.tsv",
        metrics["errors"],
        [
            "sample_id",
            "split",
            "gold_label",
            "predicted_label",
            "rule_label",
            "model_label",
            "weighted_label",
            "gated_label",
            "override_blocked",
            "model_confidence",
            "model_margin",
            "weighted_margin",
            "text",
            "manual_notes",
        ],
    )


def main():
    parser = argparse.ArgumentParser(
        description="Run local-only report/eval ablations for the PDF layout-assist spike.",
    )
    parser.add_argument(
        "--manifest",
        action="append",
        required=True,
        help="Manifest TSV path. Can be provided multiple times.",
    )
    parser.add_argument(
        "--feature-dir",
        action="append",
        required=True,
        help="Directory containing exported *.features.tsv files. Can be provided multiple times.",
    )
    parser.add_argument(
        "--output-dir",
        default=".external/layout_model/eval",
        help="Directory for local-only eval outputs.",
    )
    parser.add_argument(
        "--model-output",
        default=".external/layout_model/models/pdf_layout_linear_local_eval.json",
        help="Local-only model JSON output path.",
    )
    parser.add_argument(
        "--preset",
        default=DEFAULT_PRESET,
        choices=sorted(PRESETS.keys()),
        help="Named report-only gating preset.",
    )
    args = parser.parse_args()

    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    manifests = [os.path.join(root, path) for path in args.manifest]
    feature_dirs = [os.path.join(root, path) for path in args.feature_dir]
    output_dir = os.path.join(root, args.output_dir)
    model_output = os.path.join(root, args.model_output)
    preset = PRESETS[args.preset]
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(os.path.dirname(model_output), exist_ok=True)

    manifest_rows = []
    for manifest in manifests:
        manifest_rows.extend(load_manifest_rows(manifest))

    labeled_rows, controls, skipped, counts_per_sample = load_labeled_rows(manifest_rows, feature_dirs)
    train_rows = [row for row in labeled_rows if row["split"] == "train"]
    heldout_rows = [row for row in labeled_rows if row["split"] == "heldout"]
    if not train_rows:
        raise SystemExit("no labeled train rows found")
    if not heldout_rows:
        raise SystemExit("no labeled heldout rows found")

    model = build_model(prepare_model_rows(train_rows), ",".join(args.manifest))
    write_json(model_output, model)

    train_predictions = build_prediction_rows(train_rows, model, preset)
    heldout_predictions = build_prediction_rows(heldout_rows, model, preset)

    strategies = {
        "rules_only": "rule_label",
        "model_only": "model_label",
        "rules_model_naive": "naive_label",
        "rules_model_weighted": "weighted_label",
        "rules_model_gated": "gated_label",
    }

    summary = {
        "best_report_only_baseline": DEFAULT_PRESET,
        "selected_preset": args.preset,
        "preset_notes": preset["notes"],
        "preset_config": preset,
        "available_presets": sorted(PRESETS.keys()),
        "model_artifact_policy": "local_only_weights_no_runtime_embedding",
        "train_row_count": len(train_rows),
        "heldout_row_count": len(heldout_rows),
        "counts_per_sample": dict(counts_per_sample),
        "skipped": dict(skipped),
        "controls": controls,
        "conflict_matrix": summarize_conflicts(heldout_predictions),
        "strategies": {},
    }

    heldout_rule_metrics = None
    for split_name, rows in (("train", train_predictions), ("heldout", heldout_predictions)):
        for strategy_name, label_key in strategies.items():
            metrics = evaluate_predictions(rows, label_key)
            write_strategy_outputs(output_dir, split_name, strategy_name, metrics)
            summary["strategies"].setdefault(strategy_name, {})[split_name] = {
                "micro": metrics["micro"],
                "targeted": metrics["targeted"],
            }
            if split_name == "heldout" and strategy_name == "rules_only":
                heldout_rule_metrics = metrics

    if heldout_rule_metrics is None:
        raise SystemExit("failed to compute heldout rules_only metrics")

    ablation_rows = []
    for strategy_name in strategies:
        metrics = evaluate_predictions(heldout_predictions, strategies[strategy_name])
        comparison = compare_against_rules(heldout_rule_metrics, metrics)
        summary["strategies"][strategy_name]["heldout"]["vs_rules_only"] = comparison
        ablation_rows.append(
            {
                "strategy": strategy_name,
                "support": metrics["micro"]["support"],
                "precision": metrics["micro"]["precision"],
                "recall": metrics["micro"]["recall"],
                "f1": metrics["micro"]["f1"],
                "heading_false_positive_count": metrics["targeted"]["heading_false_positive_count"],
                "separator_as_list_count": metrics["targeted"]["separator_as_list_count"],
                "false_table_promotion_count": metrics["targeted"]["false_table_promotion_count"],
                "false_noise_drop_count": metrics["targeted"]["false_noise_drop_count"],
                "footer_header_false_negative_count": metrics["targeted"]["footer_header_false_negative_count"],
                "link_text_false_positive_count": metrics["targeted"]["link_text_false_positive_count"],
                "link_text_false_negative_count": metrics["targeted"]["link_text_false_negative_count"],
                "improved_sample_count": comparison["improved_sample_count"],
                "regressed_sample_count": comparison["regressed_sample_count"],
            }
        )

    write_tsv(
        os.path.join(output_dir, "heldout_ablation.tsv"),
        ablation_rows,
        [
            "strategy",
            "support",
            "precision",
            "recall",
            "f1",
            "heading_false_positive_count",
            "separator_as_list_count",
            "false_table_promotion_count",
            "false_noise_drop_count",
            "footer_header_false_negative_count",
            "link_text_false_positive_count",
            "link_text_false_negative_count",
            "improved_sample_count",
            "regressed_sample_count",
        ],
    )
    write_tsv(
        os.path.join(output_dir, "heldout_conflict_matrix.tsv"),
        summary["conflict_matrix"],
        ["rule_label", "model_label", "count"],
    )
    write_tsv(
        os.path.join(output_dir, "eval_controls.tsv"),
        controls,
        ["sample_id", "split", "record_kind", "feature_path", "candidate_count", "notes"],
    )
    write_json(os.path.join(output_dir, "summary.json"), summary)

    print(json.dumps(summary["strategies"], ensure_ascii=False, indent=2))
    print(f"wrote local eval summary to {os.path.relpath(os.path.join(output_dir, 'summary.json'), root)}")


if __name__ == "__main__":
    main()
