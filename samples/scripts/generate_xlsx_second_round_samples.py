#!/usr/bin/env python3
from __future__ import annotations

import shutil
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[2]
MAIN_SRC = ROOT / "samples" / "main_process" / "xlsx"
META_SRC = ROOT / "samples" / "metadata" / "xlsx"
BENCH_SRC = ROOT / "samples" / "benchmark" / "xlsx"


def read_zip_text(path: Path, part: str) -> str:
    with ZipFile(path) as zf:
        return zf.read(part).decode("utf-8")


def copy_zip_with_updates(src: Path, dst: Path, updates: dict[str, str]) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(src) as zin:
        written: set[str] = set()
        with ZipFile(dst, "w", compression=ZIP_DEFLATED) as zout:
            for info in zin.infolist():
                data = zin.read(info.filename)
                if info.filename in updates:
                    data = updates[info.filename].encode("utf-8")
                    written.add(info.filename)
                zout.writestr(info, data)
            for name, text in updates.items():
                if name in written:
                    continue
                zout.writestr(name, text.encode("utf-8"))


def make_sheet_xml(dimension: str, rows_xml: str, merge_xml: str = "") -> str:
    return (
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        "<sheetPr><outlinePr summaryBelow=\"1\" summaryRight=\"1\"/><pageSetUpPr/></sheetPr>"
        f'<dimension ref="{dimension}"/>'
        "<sheetViews><sheetView workbookViewId=\"0\"><selection activeCell=\"A1\" sqref=\"A1\"/></sheetView></sheetViews>"
        "<sheetFormatPr baseColWidth=\"8\" defaultRowHeight=\"15\"/>"
        f"<sheetData>{rows_xml}</sheetData>"
        f"{merge_xml}"
        "<pageMargins left=\"0.75\" right=\"0.75\" top=\"1\" bottom=\"1\" header=\"0.5\" footer=\"0.5\"/>"
        "</worksheet>"
    )


def inline_cell(ref: str, text: str) -> str:
    return f'<c r="{ref}" t="inlineStr"><is><t>{text}</t></is></c>'


def number_cell(ref: str, value: int | float | str) -> str:
    return f'<c r="{ref}"><v>{value}</v></c>'


def string_formula_cell(ref: str, formula: str) -> str:
    return f'<c r="{ref}" t="str"><f>{formula}</f><v></v></c>'


def number_formula_cell(ref: str, formula: str) -> str:
    return f'<c r="{ref}"><f>{formula}</f><v></v></c>'


def error_cell(ref: str, code: str) -> str:
    return f'<c r="{ref}" t="e"><v>{code}</v></c>'


def row_xml(row_index: int, cells: list[str]) -> str:
    return f'<row r="{row_index}">{"".join(cells)}</row>'


def make_formula_cached_values() -> None:
    src = MAIN_SRC / "xlsx_formula_cached_value_current_policy.xlsx"
    dst = MAIN_SRC / "xlsx_formula_cached_values.xlsx"
    sheet = read_zip_text(src, "xl/worksheets/sheet1.xml")
    sheet = sheet.replace('ref="A1:B3"', 'ref="A1:B7"')
    sheet = sheet.replace(
        '<row r="2"><c r="A2" t="inlineStr"><is><t>Cached formula</t></is></c><c r="B2"><f>1+2</f><v>3</v></c></row><row r="3"><c r="A3" t="inlineStr"><is><t>Missing cached formula</t></is></c><c r="B3"><f>2+3</f><v></v></c></row>',
        '<row r="2"><c r="A2" t="inlineStr"><is><t>Numeric cached formula</t></is></c><c r="B2"><f>1+2</f><v>3</v></c></row>'
        '<row r="3"><c r="A3" t="inlineStr"><is><t>String cached formula</t></is></c><c r="B3" t="str"><f>CONCAT("a","b")</f><v>ab</v></c></row>'
        '<row r="4"><c r="A4" t="inlineStr"><is><t>Boolean cached formula</t></is></c><c r="B4" t="b"><f>1=1</f><v>1</v></c></row>'
        '<row r="5"><c r="A5" t="inlineStr"><is><t>Error cached formula</t></is></c><c r="B5" t="e"><f>1/0</f><v>#DIV/0!</v></c></row>'
        '<row r="6"><c r="A6" t="inlineStr"><is><t>Missing cached formula</t></is></c><c r="B6"><f>2+3</f><v></v></c></row>'
        '<row r="7"><c r="A7" t="inlineStr"><is><t>Mixed normal cell</t></is></c><c r="B7" t="inlineStr"><is><t>literal</t></is></c></row>',
    )
    copy_zip_with_updates(src, dst, {"xl/worksheets/sheet1.xml": sheet})


def make_formula_missing_cache() -> None:
    src = MAIN_SRC / "xlsx_formula_cached_value_current_policy.xlsx"
    dst = MAIN_SRC / "xlsx_formula_missing_cache.xlsx"
    sheet = read_zip_text(src, "xl/worksheets/sheet1.xml")
    sheet = sheet.replace('ref="A1:B3"', 'ref="A1:B5"')
    sheet = sheet.replace(
        '<row r="2"><c r="A2" t="inlineStr"><is><t>Cached formula</t></is></c><c r="B2"><f>1+2</f><v>3</v></c></row><row r="3"><c r="A3" t="inlineStr"><is><t>Missing cached formula</t></is></c><c r="B3"><f>2+3</f><v></v></c></row>',
        '<row r="2"><c r="A2" t="inlineStr"><is><t>Case</t></is></c><c r="B2" t="inlineStr"><is><t>Value</t></is></c></row>'
        '<row r="3"><c r="A3" t="inlineStr"><is><t>Missing numeric cache</t></is></c><c r="B3"><f>1+2</f><v></v></c></row>'
        '<row r="4"><c r="A4" t="inlineStr"><is><t>Missing string cache</t></is></c><c r="B4" t="str"><f>CONCAT("a","b")</f><v></v></c></row>'
        '<row r="5"><c r="A5" t="inlineStr"><is><t>Error cache present</t></is></c><c r="B5" t="e"><f>1/0</f><v>#DIV/0!</v></c></row>',
    )
    copy_zip_with_updates(src, dst, {"xl/worksheets/sheet1.xml": sheet})


def make_formula_eval_arithmetic() -> None:
    src = MAIN_SRC / "xlsx_formula_cached_value_current_policy.xlsx"
    dst = MAIN_SRC / "xlsx_formula_eval_arithmetic.xlsx"
    rows = [
        row_xml(
            1,
            [
                inline_cell("A1", "Left"),
                inline_cell("B1", "Right"),
                inline_cell("C1", "Expression"),
                inline_cell("D1", "Value"),
            ],
        ),
        row_xml(
            2,
            [
                number_cell("A2", 1),
                number_cell("B2", 2),
                inline_cell("C2", "A2+B2"),
                number_formula_cell("D2", "A2+B2"),
            ],
        ),
        row_xml(
            3,
            [
                number_cell("A3", 5),
                number_cell("B3", 3),
                inline_cell("C3", "A3-B3"),
                number_formula_cell("D3", "A3-B3"),
            ],
        ),
        row_xml(
            4,
            [
                number_cell("A4", 4),
                number_cell("B4", 6),
                inline_cell("C4", "A4*B4"),
                number_formula_cell("D4", "A4*B4"),
            ],
        ),
        row_xml(
            5,
            [
                number_cell("A5", 10),
                number_cell("B5", 2),
                inline_cell("C5", "A5/B5"),
                number_formula_cell("D5", "A5/B5"),
            ],
        ),
        row_xml(
            6,
            [
                number_cell("A6", 3),
                number_cell("B6", 7),
                inline_cell("C6", "(A6+B6)*2"),
                number_formula_cell("D6", "(A6+B6)*2"),
            ],
        ),
    ]
    copy_zip_with_updates(
        src,
        dst,
        {"xl/worksheets/sheet1.xml": make_sheet_xml("A1:D6", "".join(rows))},
    )


def make_formula_eval_ranges() -> None:
    src = MAIN_SRC / "xlsx_formula_cached_value_current_policy.xlsx"
    dst = MAIN_SRC / "xlsx_formula_eval_ranges.xlsx"
    rows = [
        row_xml(
            1,
            [
                inline_cell("A1", "Label"),
                inline_cell("B1", "Value"),
                inline_cell("C1", "Expression"),
                inline_cell("D1", "Result"),
            ],
        ),
        row_xml(2, [inline_cell("A2", "n1"), number_cell("B2", 1)]),
        row_xml(3, [inline_cell("A3", "n2"), number_cell("B3", 2)]),
        row_xml(4, [inline_cell("A4", "n3"), number_cell("B4", 3)]),
        row_xml(5, [inline_cell("A5", "n4"), number_cell("B5", 4)]),
        row_xml(6, [inline_cell("A6", "n5"), number_cell("B6", 5)]),
        row_xml(
            7,
            [
                inline_cell("A7", "SUM"),
                inline_cell("C7", "SUM(B2:B6)"),
                number_formula_cell("D7", "SUM(B2:B6)"),
            ],
        ),
        row_xml(
            8,
            [
                inline_cell("A8", "AVERAGE"),
                inline_cell("C8", "AVERAGE(B2:B6)"),
                number_formula_cell("D8", "AVERAGE(B2:B6)"),
            ],
        ),
        row_xml(
            9,
            [
                inline_cell("A9", "MIN"),
                inline_cell("C9", "MIN(B2:B6)"),
                number_formula_cell("D9", "MIN(B2:B6)"),
            ],
        ),
        row_xml(
            10,
            [
                inline_cell("A10", "MAX"),
                inline_cell("C10", "MAX(B2:B6)"),
                number_formula_cell("D10", "MAX(B2:B6)"),
            ],
        ),
        row_xml(
            11,
            [
                inline_cell("A11", "COUNT"),
                inline_cell("C11", "COUNT(B2:B6)"),
                number_formula_cell("D11", "COUNT(B2:B6)"),
            ],
        ),
        row_xml(
            12,
            [
                inline_cell("A12", "COUNTA"),
                inline_cell("C12", "COUNTA(B2:B6)"),
                number_formula_cell("D12", "COUNTA(B2:B6)"),
            ],
        ),
    ]
    copy_zip_with_updates(
        src,
        dst,
        {"xl/worksheets/sheet1.xml": make_sheet_xml("A1:D12", "".join(rows))},
    )


def make_formula_eval_if_round_text() -> None:
    src = MAIN_SRC / "xlsx_formula_cached_value_current_policy.xlsx"
    dst = MAIN_SRC / "xlsx_formula_eval_if_round_text.xlsx"
    rows = [
        row_xml(
            1,
            [
                inline_cell("A1", "Left"),
                inline_cell("B1", "Right"),
                inline_cell("C1", "Expression"),
                inline_cell("D1", "Value"),
            ],
        ),
        row_xml(
            2,
            [
                number_cell("A2", 12),
                inline_cell("C2", 'IF(A2>10,"high","low")'),
                string_formula_cell("D2", 'IF(A2>10,"high","low")'),
            ],
        ),
        row_xml(
            3,
            [
                number_cell("A3", 5),
                inline_cell("C3", 'IF(A3>10,"high","low")'),
                string_formula_cell("D3", 'IF(A3>10,"high","low")'),
            ],
        ),
        row_xml(
            4,
            [
                number_cell("A4", 10),
                inline_cell("C4", "ROUND(A4/3,2)"),
                number_formula_cell("D4", "ROUND(A4/3,2)"),
            ],
        ),
        row_xml(
            5,
            [
                inline_cell("A5", "Hello"),
                inline_cell("B5", "World"),
                inline_cell("C5", "CONCAT(A5,B5)"),
                string_formula_cell("D5", "CONCAT(A5,B5)"),
            ],
        ),
        row_xml(
            6,
            [
                inline_cell("A6", "Hello"),
                inline_cell("B6", "World"),
                inline_cell("C6", "A6&B6"),
                string_formula_cell("D6", "A6&B6"),
            ],
        ),
    ]
    copy_zip_with_updates(
        src,
        dst,
        {"xl/worksheets/sheet1.xml": make_sheet_xml("A1:D6", "".join(rows))},
    )


def make_formula_eval_unsupported() -> None:
    src = MAIN_SRC / "xlsx_formula_cached_value_current_policy.xlsx"
    dst = MAIN_SRC / "xlsx_formula_eval_unsupported.xlsx"
    rows = [
        row_xml(
            1,
            [
                inline_cell("A1", "Case"),
                inline_cell("B1", "Expression"),
                inline_cell("C1", "Value"),
            ],
        ),
        row_xml(
            2,
            [
                inline_cell("A2", "Unsupported function"),
                inline_cell("B2", "VLOOKUP(1,A1:B3,2,FALSE)"),
                number_formula_cell("C2", "VLOOKUP(1,A1:B3,2,FALSE)"),
            ],
        ),
        row_xml(
            3,
            [
                inline_cell("A3", "Cross-sheet reference"),
                inline_cell("B3", "Sheet2!A1"),
                number_formula_cell("C3", "Sheet2!A1"),
            ],
        ),
        row_xml(
            4,
            [
                inline_cell("A4", "Volatile function"),
                inline_cell("B4", "TODAY()"),
                number_formula_cell("C4", "TODAY()"),
            ],
        ),
        row_xml(
            5,
            [
                inline_cell("A5", "Array-like range arithmetic"),
                inline_cell("B5", "A1:A3+B1:B3"),
                number_formula_cell("C5", "A1:A3+B1:B3"),
            ],
        ),
    ]
    copy_zip_with_updates(
        src,
        dst,
        {"xl/worksheets/sheet1.xml": make_sheet_xml("A1:C5", "".join(rows))},
    )


def make_formula_eval_errors() -> None:
    src = MAIN_SRC / "xlsx_formula_cached_value_current_policy.xlsx"
    dst = MAIN_SRC / "xlsx_formula_eval_errors.xlsx"
    rows = [
        row_xml(
            1,
            [
                inline_cell("A1", "Case"),
                inline_cell("B1", "Expression"),
                inline_cell("C1", "Value"),
                inline_cell("D1", "Helper"),
            ],
        ),
        row_xml(
            2,
            [
                inline_cell("A2", "Division by zero"),
                inline_cell("B2", "1/0"),
                number_formula_cell("C2", "1/0"),
            ],
        ),
        row_xml(
            3,
            [
                inline_cell("A3", "Bad reference"),
                inline_cell("B3", "Z99+1"),
                number_formula_cell("C3", "Z99+1"),
            ],
        ),
        row_xml(
            4,
            [
                inline_cell("A4", "Reference error cell"),
                inline_cell("B4", "D4"),
                number_formula_cell("C4", "D4"),
                error_cell("D4", "#N/A"),
            ],
        ),
        row_xml(
            5,
            [
                inline_cell("A5", "Circular reference A"),
                inline_cell("B5", "C6+1"),
                number_formula_cell("C5", "C6+1"),
            ],
        ),
        row_xml(
            6,
            [
                inline_cell("A6", "Circular reference B"),
                inline_cell("B6", "C5+1"),
                number_formula_cell("C6", "C5+1"),
            ],
        ),
    ]
    copy_zip_with_updates(
        src,
        dst,
        {"xl/worksheets/sheet1.xml": make_sheet_xml("A1:D6", "".join(rows))},
    )


def make_merged_cells_policy() -> None:
    src = MAIN_SRC / "xlsx_merged_cells_current_policy.xlsx"
    dst = MAIN_SRC / "xlsx_merged_cells_policy.xlsx"
    sheet = read_zip_text(src, "xl/worksheets/sheet1.xml")
    sheet = sheet.replace('ref="A1:C3"', 'ref="A1:D5"')
    sheet = sheet.replace(
        '<row r="1"><c r="A1" t="inlineStr"><is><t>Case</t></is></c><c r="B1" t="inlineStr"><is><t>Value</t></is></c></row><row r="2"><c r="A2" t="inlineStr"><is><t>Merged top-left</t></is></c><c r="B2" t="inlineStr"><is><t>TopLeft</t></is></c></row><row r="3"></row></sheetData><mergeCells count="1"><mergeCell ref="B2:C3"/></mergeCells>',
        '<row r="1"><c r="A1" t="inlineStr"><is><t>Group</t></is></c><c r="B1" t="inlineStr"><is><t>Subgroup</t></is></c><c r="C1" t="inlineStr"><is><t>Value</t></is></c><c r="D1" t="inlineStr"><is><t>Notes</t></is></c></row>'
        '<row r="2"><c r="A2" t="inlineStr"><is><t>Header merge</t></is></c><c r="B2" t="inlineStr"><is><t>North</t></is></c><c r="D2" t="inlineStr"><is><t>top-left owns text</t></is></c></row>'
        '<row r="3"><c r="A3" t="inlineStr"><is><t>Body merge</t></is></c><c r="B3" t="inlineStr"><is><t>Shared label</t></is></c><c r="D3" t="inlineStr"><is><t>covered cells stay blank</t></is></c></row>'
        '<row r="4"><c r="A4" t="inlineStr"><is><t>Normal</t></is></c><c r="B4" t="inlineStr"><is><t>Leaf</t></is></c><c r="C4"><v>42</v></c><c r="D4" t="inlineStr"><is><t>unmerged row</t></is></c></row>'
        '<row r="5"><c r="A5" t="inlineStr"><is><t>Blank covered</t></is></c><c r="B5" t="inlineStr"><is><t>Anchor</t></is></c><c r="D5" t="inlineStr"><is><t>blank merge block</t></is></c></row></sheetData>'
        '<mergeCells count="3"><mergeCell ref="B2:C2"/><mergeCell ref="B3:C4"/><mergeCell ref="B5:C5"/></mergeCells>',
    )
    copy_zip_with_updates(src, dst, {"xl/worksheets/sheet1.xml": sheet})


def make_typed_cells_matrix() -> None:
    src = MAIN_SRC / "xlsx_cell_types.xlsx"
    dst = MAIN_SRC / "xlsx_typed_cells_matrix.xlsx"
    shutil.copyfile(src, dst)


def make_hidden_sheets_policy() -> None:
    src = MAIN_SRC / "xlsx_hidden_sheet_current_behavior.xlsx"
    dst = MAIN_SRC / "xlsx_hidden_sheets_policy.xlsx"
    workbook = read_zip_text(src, "xl/workbook.xml")
    rels = read_zip_text(src, "xl/_rels/workbook.xml.rels")
    sheet1 = read_zip_text(src, "xl/worksheets/sheet1.xml")
    sheet2 = read_zip_text(src, "xl/worksheets/sheet2.xml")

    workbook = workbook.replace(
        '<sheets><sheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" name="Visible" sheetId="1" state="visible" r:id="rId1"/><sheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" name="HiddenData" sheetId="2" state="hidden" r:id="rId2"/></sheets>',
        '<sheets><sheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" name="Visible" sheetId="1" state="visible" r:id="rId1"/><sheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" name="HiddenData" sheetId="2" state="hidden" r:id="rId2"/><sheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" name="VeryHiddenAudit" sheetId="3" state="veryHidden" r:id="rId3"/></sheets>',
    )
    rels = rels.replace(
        '<Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="/xl/worksheets/sheet2.xml" Id="rId2"/>',
        '<Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="/xl/worksheets/sheet2.xml" Id="rId2"/><Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="/xl/worksheets/sheet3.xml" Id="rId3"/>',
    )
    sheet3 = sheet2.replace("secret", "vault").replace('ref="A1:A1"', 'ref="A1:B2"').replace(
        "</sheetData>",
        '<row r="2"><c r="A2" t="inlineStr"><is><t>classification</t></is></c><c r="B2" t="inlineStr"><is><t>veryHidden</t></is></c></row></sheetData>',
    )
    copy_zip_with_updates(
        src,
        dst,
        {
            "xl/workbook.xml": workbook,
            "xl/_rels/workbook.xml.rels": rels,
            "xl/worksheets/sheet3.xml": sheet3,
        },
    )


def make_metadata_policy_fixture() -> None:
    src = META_SRC / "xlsx_metadata_formula_or_merged_policy.xlsx"
    dst = META_SRC / "xlsx_metadata_formula_or_merged_policy.xlsx"
    # Checked-in metadata fixture already exists. Keep stable and rebuild only
    # if the file is absent in a fresh checkout.
    if dst.exists():
        return
    shutil.copyfile(src, dst)


def make_formula_heavy_missing_cache() -> None:
    src = MAIN_SRC / "xlsx_formula_cached_value_current_policy.xlsx"
    dst = BENCH_SRC / "xlsx_formula_heavy_missing_cache.xlsx"
    rows = [
        row_xml(
            1,
            [
                inline_cell("A1", "Left"),
                inline_cell("B1", "Right"),
                inline_cell("C1", "Expression"),
                inline_cell("D1", "Value"),
            ],
        )
    ]
    for idx in range(2, 202):
        left = idx - 1
        right = (idx % 9) + 1
        formula = (
            f"(A{idx}+B{idx})*2"
            if idx % 3 == 0
            else f"ROUND(A{idx}/B{idx},2)"
            if idx % 3 == 1
            else f"A{idx}*B{idx}"
        )
        rows.append(
            row_xml(
                idx,
                [
                    number_cell(f"A{idx}", left),
                    number_cell(f"B{idx}", right),
                    inline_cell(f"C{idx}", formula),
                    number_formula_cell(f"D{idx}", formula),
                ],
            )
        )
    copy_zip_with_updates(
        src,
        dst,
        {"xl/worksheets/sheet1.xml": make_sheet_xml("A1:D201", "".join(rows))},
    )


def make_formula_unsupported_many() -> None:
    src = MAIN_SRC / "xlsx_formula_cached_value_current_policy.xlsx"
    dst = BENCH_SRC / "xlsx_formula_unsupported_many.xlsx"
    rows = [
        row_xml(
            1,
            [
                inline_cell("A1", "Case"),
                inline_cell("B1", "Expression"),
                inline_cell("C1", "Value"),
            ],
        )
    ]
    formulas = [
        ("Unsupported function", "VLOOKUP(1,A1:B3,2,FALSE)"),
        ("Cross-sheet reference", "Sheet2!A1"),
        ("Volatile function", "TODAY()"),
        ("Array-like range arithmetic", "A1:A3+B1:B3"),
    ]
    for idx in range(2, 162):
        label, formula = formulas[(idx - 2) % len(formulas)]
        rows.append(
            row_xml(
                idx,
                [
                    inline_cell(f"A{idx}", label),
                    inline_cell(f"B{idx}", formula),
                    number_formula_cell(f"C{idx}", formula),
                ],
            )
        )
    copy_zip_with_updates(
        src,
        dst,
        {"xl/worksheets/sheet1.xml": make_sheet_xml("A1:C161", "".join(rows))},
    )


def make_benchmark_copies() -> None:
    copies = [
        (MAIN_SRC / "xlsx_formula_cached_values.xlsx", BENCH_SRC / "xlsx_formula_heavy.xlsx"),
        (MAIN_SRC / "xlsx_merged_cells_policy.xlsx", BENCH_SRC / "xlsx_merged_heavy.xlsx"),
        (MAIN_SRC / "xlsx_typed_cells_matrix.xlsx", BENCH_SRC / "xlsx_typed_cells.xlsx"),
        (MAIN_SRC / "xlsx_formula_eval_arithmetic.xlsx", BENCH_SRC / "xlsx_formula_eval_arithmetic.xlsx"),
        (MAIN_SRC / "xlsx_formula_eval_ranges.xlsx", BENCH_SRC / "xlsx_formula_eval_ranges.xlsx"),
    ]
    for src, dst in copies:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)


def main() -> None:
    make_formula_cached_values()
    make_formula_missing_cache()
    make_formula_eval_arithmetic()
    make_formula_eval_ranges()
    make_formula_eval_if_round_text()
    make_formula_eval_unsupported()
    make_formula_eval_errors()
    make_merged_cells_policy()
    make_typed_cells_matrix()
    make_hidden_sheets_policy()
    make_metadata_policy_fixture()
    make_formula_heavy_missing_cache()
    make_formula_unsupported_many()
    make_benchmark_copies()


if __name__ == "__main__":
    main()
