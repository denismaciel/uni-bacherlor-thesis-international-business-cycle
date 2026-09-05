"""Download a dated OECD QNA snapshot; build a validated, unfiltered CSV panel.

Run with uv run --no-project python scripts/collect_oecd.py.
Only the Python standard library is required; econometric analysis stays in R.
"""

import argparse
import csv
import hashlib
import io
import json
import math
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
import re
import ssl
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
BASE = "https://sdmx.oecd.org/public/rest/v1"
FLOW = "OECD.SDD.NAD,DSD_NAMAIN1@DF_QNA,1.1"
COUNTRIES = ("AUS", "AUT", "CAN", "CHE", "DEU", "FRA", "GBR", "ITA", "JPN", "USA")
DIMENSIONS = (
    "FREQ", "ADJUSTMENT", "REF_AREA", "SECTOR", "COUNTERPART_SECTOR",
    "TRANSACTION", "INSTR_ASSET", "ACTIVITY", "EXPENDITURE", "UNIT_MEASURE",
    "PRICE_BASE", "TRANSFORMATION", "TABLE_IDENTIFIER",
)
VARIABLES = {
    ("S1", "B1GQ", "L"): "gdp",
    ("S1M", "P3", "L"): "consumption",
    ("S13", "P3", "L"): "government",
    ("S1", "P51G", "L"): "investment",
    ("S1", "B1GQ", "V"): "gdp_nominal",
    ("S1", "P6", "V"): "exports_nominal",
    ("S1", "P7", "V"): "imports_nominal",
}
FIELDS = (
    "location", "time", "variable", "value", "unit_measure", "unit_mult",
    "currency", "price_base", "reference_year", "adjustment", "transformation",
    "obs_status", "conf_status", "base_period", "decimals", "series_key",
)
PROVENANCE_HEADERS = {
    "date", "content-type", "content-length", "content-language", "etag",
    "last-modified", "cache-control", "age", "api-supported-versions",
}


def quarter_index(period):
    if not re.fullmatch(r"\d{4}-Q[1-4]", period):
        raise ValueError(f"Invalid quarter: {period!r}")
    return int(period[:4]) * 4 + int(period[-1]) - 1


def quarter_label(index):
    return f"{index // 4:04d}-Q{index % 4 + 1}"


def request_urls():
    countries = "+".join(COUNTRIES)
    real = f"Q.Y.{countries}.S1+S1M+S13.S1.B1GQ+P3+P51G._Z._Z+_T._Z+_T.XDC.L.N.T0102"
    nominal = f"Q.Y.{countries}.S1.S1.B1GQ+P6+P7._Z._Z._Z.XDC.V.N.T0102"
    return {
        "structure.xml": (f"{BASE}/dataflow/OECD.SDD.NAD/DSD_NAMAIN1@DF_QNA/1.1?references=all", "application/vnd.sdmx.structure+xml;version=2.1"),
        "real.csv": (f"{BASE}/data/{FLOW}/{real}", "text/csv"),
        "nominal.csv": (f"{BASE}/data/{FLOW}/{nominal}", "text/csv"),
    }


def download(url, accept):
    # uv-managed Python may not find the NixOS system certificate store itself.
    ca_bundle = Path("/etc/ssl/certs/ca-certificates.crt")
    context = ssl.create_default_context(cafile=str(ca_bundle) if ca_bundle.exists() else None)
    for attempt in range(3):
        try:
            request = Request(url, headers={"Accept": accept, "User-Agent": "BKK-thesis-research/1.0"})
            with urlopen(request, timeout=50, context=context) as response:
                body = response.read()
                metadata = {
                    "url": url, "accept": accept, "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
                    "http_status": response.status,
                    "response_headers": {key: value for key, value in response.headers.items()
                                         if key.lower() in PROVENANCE_HEADERS},
                    "sha256": hashlib.sha256(body).hexdigest(), "bytes": len(body),
                }
                return body, metadata
        except (HTTPError, URLError, TimeoutError) as error:
            if isinstance(error, HTTPError) and error.code not in (429, 500, 502, 503, 504):
                raise
            if attempt == 2:
                raise
            print(f"Request failed ({error}); retrying", flush=True)
            time.sleep(5 * (attempt + 1))


def normalize(raw_rows):
    result, seen = [], set()
    for row in raw_rows:
        variable = VARIABLES.get((row["SECTOR"], row["TRANSACTION"], row["PRICE_BASE"]))
        if variable is None:
            continue  # Broad real query also returns total-economy consumption.
        expected = {"FREQ": "Q", "ADJUSTMENT": "Y", "COUNTERPART_SECTOR": "S1",
                    "INSTR_ASSET": "_Z", "ACTIVITY": "_T" if variable == "investment" else "_Z",
                    "EXPENDITURE": "_T" if variable in ("consumption", "government") else "_Z",
                    "UNIT_MEASURE": "XDC", "TRANSFORMATION": "N", "TABLE_IDENTIFIER": "T0102"}
        for dimension, value in expected.items():
            if row[dimension] != value:
                raise ValueError(f"Unexpected {dimension}: {row[dimension]}")
        if row["REF_AREA"] not in COUNTRIES:
            raise ValueError(f"Unexpected country: {row['REF_AREA']}")
        quarter_index(row["TIME_PERIOD"])
        identity = (row["REF_AREA"], row["TIME_PERIOD"], variable)
        if identity in seen:
            raise ValueError(f"Duplicate observation: {identity}")
        seen.add(identity)
        value = float(row["OBS_VALUE"])
        if not math.isfinite(value) or value <= 0:
            raise ValueError(f"Non-positive or non-finite level: {identity}")
        result.append(dict(zip(FIELDS, (
            row["REF_AREA"], row["TIME_PERIOD"], variable, row["OBS_VALUE"],
            row["UNIT_MEASURE"], row["UNIT_MULT"], row.get("CURRENCY", ""), row["PRICE_BASE"],
            row.get("REF_YEAR_PRICE", ""), row["ADJUSTMENT"], row["TRANSFORMATION"],
            row.get("OBS_STATUS", ""), row.get("CONF_STATUS", ""), row.get("BASE_PER", ""),
            row.get("DECIMALS", ""), ".".join(row[d] for d in DIMENSIONS),
        ))))
    return sorted(result, key=lambda r: (r["location"], r["variable"], r["time"]))


def coverage(panel):
    groups = defaultdict(list)
    for row in panel:
        groups[row["location"], row["variable"]].append(row)
    expected = {(country, variable) for country in COUNTRIES for variable in VARIABLES.values()}
    if set(groups) != expected:
        raise ValueError(f"Missing/unexpected series: {sorted(expected.symmetric_difference(groups))}")
    result = []
    for (country, variable), rows in sorted(groups.items()):
        periods = {quarter_index(row["time"]) for row in rows}
        missing = sorted(set(range(min(periods), max(periods) + 1)) - periods)
        for field in ("unit_measure", "unit_mult", "currency", "reference_year", "price_base"):
            if len({row[field] for row in rows}) != 1:
                raise ValueError(f"Measurement changes within {country}/{variable}: {field}")
        result.append({
            "location": country, "variable": variable, "first": quarter_label(min(periods)),
            "last": quarter_label(max(periods)), "observations": len(rows),
            "missing_quarters": ";".join(map(quarter_label, missing)),
            "observations_after_2015_Q1": sum(p > quarter_index("2015-Q1") for p in periods),
            "status_counts": json.dumps(dict(sorted(Counter(r['obs_status'] for r in rows).items()))),
            "currency": rows[0]["currency"], "unit_mult": rows[0]["unit_mult"],
            "reference_year": rows[0]["reference_year"],
        })
    return result


def write_csv(path, rows, fields):
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def build(snapshot):
    manifest = json.loads((snapshot / "manifest.json").read_text())
    if set(manifest["requests"]) != set(request_urls()):
        raise ValueError("Incomplete raw snapshot")
    for filename, request in manifest["requests"].items():
        if hashlib.sha256((snapshot / filename).read_bytes()).hexdigest() != request["sha256"]:
            raise ValueError(f"Raw checksum mismatch: {filename}")
    structure = ET.parse(snapshot / "structure.xml")
    ns = {"s": "http://www.sdmx.org/resources/sdmxml/schemas/v2_1/structure"}
    dimensions = structure.findall(".//s:DimensionList/s:Dimension", ns)
    if tuple(d.get("id") for d in sorted(dimensions, key=lambda d: int(d.get("position")))) != DIMENSIONS:
        raise ValueError("OECD dimension order changed")
    raw = []
    for filename in ("real.csv", "nominal.csv"):
        raw.extend(csv.DictReader(io.StringIO((snapshot / filename).read_text(encoding="utf-8-sig"))))
    panel = normalize(raw)
    summary = coverage(panel)
    output = ROOT / "data" / "processed" / "oecd" / snapshot.name
    output.mkdir(parents=True, exist_ok=True)
    write_csv(output / "panel.csv", panel, FIELDS)
    write_csv(output / "coverage.csv", summary, summary[0].keys())
    core = [r for r in summary if r["variable"] in ("gdp", "consumption")]
    start, end = max(r["first"] for r in core), min(r["last"] for r in core)
    all_start, all_end = max(r["first"] for r in summary), min(r["last"] for r in summary)
    gaps = sum(bool(r["missing_quarters"]) for r in summary)
    lines = ["# OECD QNA collection coverage", "", f"Snapshot: `{snapshot.name}`.", "",
             f"{len(panel):,} observations; {len(summary)} series; {len(COUNTRIES)} individual countries.",
             f"GDP/consumption common endpoint overlap: **{start} to {end}**.",
             f"All seven variables' common endpoint overlap: **{all_start} to {all_end}**.",
             f"Series with internal missing quarters: **{gaps}** (see coverage.csv).", "",
             "| Country | GDP first | GDP latest | Consumption first | Consumption latest |",
             "|---|---|---|---|---|"]
    indexed = {(r["location"], r["variable"]): r for r in core}
    for country in COUNTRIES:
        y, c = indexed[country, "gdp"], indexed[country, "consumption"]
        lines.append(f"| {country} | {y['first']} | {y['last']} | {c['first']} | {c['last']} |")
    lines.extend(["", "## Measurement and interpretation", "",
        "Real series: chain-linked volumes (L), national currency (XDC), calendar and seasonally adjusted (Y), quarterly levels (N).",
        "Consumption includes households and NPISH (S1M); government is S13; GDP and fixed investment are S1.",
        "Nominal GDP, exports and imports use current prices (V), with the same frequency/adjustment/transformation.",
        "Values retain OECD units: multiply by 10^unit_mult for currency units. Do not compare national-currency levels across countries.",
        "No logs, filtering, interpolation, splicing, annualization or currency conversion have been applied.",
        "The original thesis uses fixed-PPP dollar volume estimates and annualized levels. These are not identical definitions; constant scaling does not affect log cycles, but methodological revisions can.",
        "Do not append this vintage to the 2015 files. Compare old and new vintages on overlapping dates, then analyze the new vintage's full history.",
        "Observation status flags are retained (including reported breaks/provisional estimates where present). Full code lists and provider attributes are preserved in the raw snapshot.",
        "The overlap is an availability summary, not a claim that structural breaks or cross-country measurement differences have been resolved.",
        "Employment, hours, population and consumption by durability are not included in this collection.", "",
        "Source: https://www.oecd.org/en/data/datasets/gdp-and-non-financial-accounts.html",
        "API: https://www.oecd.org/en/data/insights/data-explainers/2024/09/api.html", ""])
    (output / "COVERAGE.md").write_text("\n".join(lines))
    print(f"Validated {len(panel):,} observations, {len(summary)} series. Report: {output / 'COVERAGE.md'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rebuild", type=Path, help="Verify and rebuild an existing raw snapshot without network access")
    args = parser.parse_args()
    if args.rebuild:
        build(args.rebuild.resolve())
        return
    snapshot = ROOT / "data" / "raw" / "oecd_snapshots" / datetime.now(timezone.utc).strftime("%Y-%m-%dT%H%M%SZ")
    snapshot.mkdir(parents=True, exist_ok=False)
    manifest = {"source": "OECD Quarterly National Accounts", "dataflow": FLOW,
                "countries": COUNTRIES, "requests": {}}
    for filename, (url, accept) in request_urls().items():
        print(f"Downloading {filename}…", flush=True)
        body, metadata = download(url, accept)
        (snapshot / filename).write_bytes(body)
        manifest["requests"][filename] = metadata
        (snapshot / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    build(snapshot)


if __name__ == "__main__":
    main()
