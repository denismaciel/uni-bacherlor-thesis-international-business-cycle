"""Run or independently compare the Python research extension."""

import argparse
from pathlib import Path
import sys

import polars as pl

from .analysis import analyze
from .domain import Config, SNAPSHOT, Table
from .export import export_parity, export_results
from .figures import export_figures
from .inputs import load_inputs
from .parity import compare_tables


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("run", "check-r"), nargs="?", default="run")
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--snapshot", default=SNAPSHOT)
    parser.add_argument("--repetitions", type=int, default=1999)
    parser.add_argument("--seed", type=int, default=20260905)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--r-dir", type=Path)
    parser.add_argument("--figures", action="store_true")
    args = parser.parse_args(argv)
    try:
        root = args.root.resolve()
        config = Config(args.snapshot, args.repetitions, args.seed)
        output = (args.output_dir or root / "output/extension-python" / config.snapshot).resolve()
        reference = (args.r_dir or root / "output/extension" / config.snapshot).resolve()
        if output == reference or output == (root / "output/extension" / config.snapshot).resolve():
            raise ValueError("Python output must be separate from the R reference directory")
        print(f"Computing Python extension ({config.repetitions:,} draws per bootstrap)…", flush=True)
        result = analyze(load_inputs(root, config), config)
        export_results(result, root, output)
        # These sidecars describe this run; do not retain evidence from an older run.
        for name in ("parity.csv", "PARITY.md", "figures.pdf"):
            (output / name).unlink(missing_ok=True)
        if args.figures:
            export_figures(result, output)
        if args.command == "check-r":
            references = {table: pl.read_csv(reference / f"{table.value}.csv", infer_schema_length=None)
                          for table in Table if (reference / f"{table.value}.csv").is_file()}
            serialized = {table: pl.read_csv(output / f"{table.value}.csv", infer_schema_length=None)
                          for table in Table}
            comparisons = compare_tables(serialized, references)
            export_parity(comparisons, reference, output)
            for item in comparisons:
                print(f"{item.table}: {item.detail}; max absolute error {item.max_absolute_error:.3e}")
            if not all(item.matches for item in comparisons):
                return 1
        print(f"Research report: {output / 'REPORT.md'}")
        return 0
    except (ValueError, OSError, pl.exceptions.PolarsError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
