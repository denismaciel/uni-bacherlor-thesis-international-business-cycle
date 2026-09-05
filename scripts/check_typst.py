"""Check the compiled Typst document's structure and migration coverage."""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PAPER = ROOT / "paper/typst"
EXPECTED_FIGURES = {
    "<tab:modelresult>", "<tab:variables>", "<tab:timespan>", "<tab:stdv>",
    "<tab:corrwithin>", "<tab:corusa>", "<tab:avgcor>", "<tab:measure>",
    "<tab:emptimespan>", "<fig:filteredgdp>", "<fig:cor>", "<fig:gdpconplot>", "<fig:emp>",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--font-path")
    args = parser.parse_args()
    options = ["--font-path", args.font_path, "--ignore-system-fonts"] if args.font_path else []

    def query(selector: str, field: str) -> list:
        result = subprocess.run(["typst", "query", "--root", str(ROOT), *options,
                                 str(PAPER / "main.typ"), selector, "--field", field],
                                text=True, capture_output=True, check=True)
        if result.stderr:
            raise RuntimeError(result.stderr)
        return json.loads(result.stdout)

    labels = query("figure", "label")
    assert len(labels) == 13 and set(labels) == EXPECTED_FIGURES, labels
    assert len(query("footnote", "body")) == 13, "Footnote lost or duplicated"
    counts = json.loads((PAPER / "data/migration-counts.json").read_text())
    for name, expected in counts.items():
        text = (PAPER / "chapters" / Path(name).with_suffix(".typ")).read_text()
        assert text.count("#footnote[") == expected["footnotes"], name
        assert len(re.findall(r"^(?:=+ |#heading\()", text, re.M)) == expected["sections"], name
        assert "BKKINSERT" not in text and "#link(<" not in text, name
    tables = json.loads((PAPER / "data/publication-tables.json").read_text())
    for key, rows, columns in (("3", 11, 13), ("4", 11, 8), ("5", 11, 8), ("6", 10, 8), ("7", 7, 12)):
        assert len(tables[key]) == rows and all(len(row) == columns for row in tables[key]), key
    # Publication values differ from today's recomputation; do not silently replace them.
    assert tables["4"][8][6] == ".48 (.44)"
    assert tables["5"][6][6] == ".58 (.77)"
    assert tables["6"][6][6] == ".16 (.26)"
    print("Typst checks passed: 9 tables, 4 composite figures, 13 footnotes; chapter and publication-table coverage intact.")


if __name__ == "__main__":
    main()
