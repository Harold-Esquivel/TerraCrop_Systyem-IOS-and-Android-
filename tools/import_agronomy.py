#!/usr/bin/env python3
"""Import the supplied JSON or workbook as data; never execute embedded text.

Only Python's standard library is required. Workbook cells are retained in
rawTables, or the complete JSON in rawDocument, alongside the normalized data.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import posixpath
import re
import xml.etree.ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


def text_nodes(node):
    return "".join(part.text or "" for part in node.findall(".//m:t", NS))


def read_workbook(path: Path):
    tables = []
    formula_cells = []
    with ZipFile(path) as archive:
        strings = []
        if "xl/sharedStrings.xml" in archive.namelist():
            strings = [text_nodes(node) for node in ET.fromstring(archive.read("xl/sharedStrings.xml")).findall("m:si", NS)]
        relationships = {}
        for item in ET.fromstring(archive.read("xl/_rels/workbook.xml.rels")):
            if item.get("TargetMode") != "External":
                target = item.attrib["Target"]
                relationships[item.attrib["Id"]] = target.lstrip("/") if target.startswith("/") else posixpath.normpath("xl/" + target)
        for sheet in ET.fromstring(archive.read("xl/workbook.xml")).findall("m:sheets/m:sheet", NS):
            target = relationships[sheet.attrib["{" + REL + "}id"]]
            if not target.startswith("xl/") or ".." in target.split("/"):
                raise ValueError("Worksheet target outside workbook")
            rows = []
            for row in ET.fromstring(archive.read(target)).findall("m:sheetData/m:row", NS):
                cells = {}
                for cell in row.findall("m:c", NS):
                    value_node = cell.find("m:v", NS)
                    value = value_node.text if value_node is not None else None
                    if cell.get("t") == "s" and value is not None:
                        value = strings[int(value)]
                    elif cell.get("t") == "inlineStr":
                        inline = cell.find("m:is", NS)
                        value = text_nodes(inline) if inline is not None else ""
                    if cell.find("m:f", NS) is not None:
                        formula_cells.append({"sheet": sheet.attrib["name"], "cell": cell.attrib["r"], "formula": cell.find("m:f", NS).text, "cachedValue": value})
                    if value is not None:
                        cells[cell.attrib["r"]] = value
                if cells:
                    rows.append({"row": int(row.attrib["r"]), "cells": cells})
            tables.append({"name": sheet.attrib["name"], "rows": rows})
    return tables, formula_cells


def records(tables, name, id_column="A", pattern=None):
    sheet = next(t for t in tables if t["name"] == name)
    for row in sheet["rows"]:
        if row["row"] == 1:
            continue
        cells = {re.sub(r"\d+$", "", key): value for key, value in row["cells"].items()}
        if id_column not in cells or pattern and not re.fullmatch(pattern, cells[id_column].strip()):
            continue
        yield cells


def convert(row, schema):
    result = {}
    for column, field, kind in schema:
        value = row.get(column)
        if kind in (float, int):
            result[field] = kind(float(value)) if value is not None and value.strip() else None
        elif kind == bool:
            result[field] = value is not None and value.strip().casefold() in ("sí", "si", "yes", "true", "1")
        elif kind == list:
            result[field] = [part.strip() for part in (value or "").split(";") if part.strip()]
        else:
            result[field] = (value or "").strip()
    return result


CROP = [
    ("A", "id", str), ("B", "name", str), ("C", "scientificName", str), ("D", "family", str),
    ("E", "type", str), ("F", "isLegume", bool), ("G", "classification", str), ("H", "evidence", str),
    ("I", "waterMin", float), ("J", "waterMax", float), ("K", "waterMean", float), ("L", "waterUnit", str),
    ("M", "periodMin", float), ("N", "periodMax", float), ("O", "periodMean", float), ("P", "periodDescription", str),
    ("Q", "temperatureMin", float), ("R", "temperatureMax", float), ("S", "phMin", float), ("T", "phMax", float),
    ("U", "nMin", float), ("V", "nMax", float), ("W", "pMin", float), ("X", "pMax", float),
    ("Y", "kMin", float), ("Z", "kMax", float), ("AA", "salinityCategory", str), ("AB", "ecThreshold", float),
    ("AC", "salinityNote", str), ("AD", "observations", str), ("AE", "validation", str),
]
COMPATIBILITY = [("A", "previousId", str), ("B", "previousName", str), ("C", "nextId", str), ("D", "nextName", str), ("E", "level", str), ("F", "score", int), ("G", "condition", str), ("H", "observation", str)]
SEQUENCE = [("A", "id", str), ("B", "role", str), ("C", "sequence", str), ("D", "totalWater", float), ("E", "totalDays", float), ("F", "waterPerDay", float), ("G", "demandDifference", float), ("H", "sensitiveCampaigns", int), ("I", "differentFamilies", int), ("J", "benefit", str), ("K", "conditions", str), ("L", "limitations", str), ("M", "microorganismIds", list)]
STEP = [("A", "sequenceId", str), ("B", "campaign", int), ("C", "cropId", str), ("D", "cropName", str), ("E", "family", str), ("F", "classification", str), ("G", "water", float), ("H", "days", float), ("I", "salinityCategory", str)]
MICRO = [("A", "id", str), ("B", "group", str), ("C", "species", str), ("D", "function", str), ("E", "problem", str), ("F", "crops", str), ("G", "conditions", str), ("H", "application", str), ("I", "limitations", str)]
RULE = [("A", "id", str), ("B", "parameter", str), ("C", "condition", str), ("D", "interpretation", str), ("E", "action", str), ("F", "microorganismIds", list), ("G", "warning", str)]
SOURCE = [("A", "id", str), ("B", "reference", str), ("C", "support", str), ("D", "url", str)]


def validate(data):
    for key in ("crops", "compatibility", "sequences", "sequenceDetails", "microorganisms", "soilRules", "sources"):
        if not data[key]:
            raise ValueError(f"Empty required table: {key}")
    for key in ["crops", "sequences", "microorganisms", "soilRules", "sources"]:
        ids = [r["id"] for r in data[key]]
        if len(ids) != len(set(ids)):
            raise ValueError(f"Duplicate IDs in {key}")
    crop_ids = {r["id"] for r in data["crops"]}
    micro_ids = {r["id"] for r in data["microorganisms"]}
    sequence_ids = {r["id"] for r in data["sequences"]}
    pairs = {(r["previousId"], r["nextId"]) for r in data["compatibility"]}
    if len(pairs) != len(data['compatibility']) or pairs != {(a, b) for a in crop_ids for b in crop_ids}:
        raise ValueError("Compatibility must cover every ordered crop pair exactly once")
    for row in data["compatibility"]:
        if row["score"] not in (0, 1, 2, 3):
            raise ValueError("Compatibility score outside 0–3")
    for row in data["sequences"] + data["soilRules"]:
        if not set(row["microorganismIds"]).issubset(micro_ids):
            raise ValueError("Unknown microorganism reference")
    for row in data["sequenceDetails"]:
        if row["sequenceId"] not in sequence_ids or row["cropId"] not in crop_ids:
            raise ValueError("Unknown reference in sequence step")
    for sequence in data['sequences']:
        steps = [r for r in data['sequenceDetails'] if r['sequenceId'] == sequence['id']]
        if sorted(r['campaign'] for r in steps) != list(range(1, len(steps) + 1)) or not steps:
            raise ValueError('Invalid campaign order')
        for field, total in [('water', 'totalWater'), ('days', 'totalDays')]:
            if not math.isclose(sum(r[field] for r in steps), sequence[total]):
                raise ValueError(f"Sequence {sequence['id']}: inconsistent {total}")
    for crop in data["crops"]:
        for prefix in ("water", "period", "temperature", "ph", "n", "p", "k"):
            low, high = crop[prefix + "Min"], crop[prefix + "Max"]
            if prefix == "period" and low is None and high is None and crop["periodMean"] is None:
                continue
            if low is None or high is None or not math.isfinite(low) or not math.isfinite(high) or low > high:
                raise ValueError(f"Invalid {prefix} range for {crop['id']}")
            mean = crop.get(prefix + "Mean")
            if mean is not None and not low <= mean <= high:
                raise ValueError(f"Mean outside range for {crop['id']}")


def import_data(path):
    if path.suffix.lower() == '.json':
        from import_agronomy_json import import_json
        data = import_json(path)
        validate(data)
        return data
    tables, formulas = read_workbook(path)
    data = {
        "schemaVersion": 1,
        "source": {"fileName": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "region": "La Joya, Arequipa", "verification": "Datos proporcionados en el Excel; referencias y estados preservados, sin verificación independiente.", "nutrientUnit": "kg/ha de N, P2O5 y K2O: referencias de fertilización, no concentraciones medidas en suelo.", "waterMeaning": "Demanda hídrica del cultivo, no riego aplicado ni ahorro de agua."},
        "crops": [convert(r, CROP) for r in records(tables, "Cultivos", pattern=r"C\d{3}")],
        "compatibility": [convert(r, COMPATIBILITY) for r in records(tables, "Compatibilidad", pattern=r"C\d{3}")],
        "sequences": [convert(r, SEQUENCE) for r in records(tables, "Secuencias", pattern=r"S\d{2}")],
        "sequenceDetails": [convert(r, STEP) for r in records(tables, "Secuencias detalle", pattern=r"S\d{2}")],
        "microorganisms": [convert(r, MICRO) for r in records(tables, "Microorganismos", pattern=r"M\d{3}")],
        "soilRules": [convert(r, RULE) for r in records(tables, "Suelo Reglas", pattern=r"S\d{3}")],
        "sources": [convert(r, SOURCE) for r in records(tables, "Fuentes", pattern=r"F\d{2}")],
        "notes": [row["cells"].get("B" + str(row["row"]), "").strip() for row in tables[0]["rows"] if row["row"] >= 13],
        "sequenceNotes": [row["cells"]["A" + str(row["row"])].strip() for row in next(t for t in tables if t["name"] == "Secuencias")["rows"] if row["row"] > 4],
        "rawTables": tables,
        "formulaCells": formulas,
    }
    for source in data["sources"]:
        source["url"] = source["url"] or None
    validate(data)
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", nargs="?", type=Path, default=ROOT / "data/agronomy/TerraCrop_base_para_app_v2.json")
    parser.add_argument("--output", type=Path, default=ROOT / "assets/data/agronomy.json")
    args = parser.parse_args()
    data = import_data(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(f"Imported {len(data['crops'])} crops, {len(data['compatibility'])} compatibility pairs, {len(data['soilRules'])} soil rules → {args.output}")


if __name__ == "__main__":
    main()
