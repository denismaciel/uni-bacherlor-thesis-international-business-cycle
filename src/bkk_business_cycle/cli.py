"""Command-line reproduction and reference checks."""

import argparse
from pathlib import Path

from .analysis import run_analysis
from .export import check_reference, export_tables


def main() -> None:
    parser = argparse.ArgumentParser(description="Reproduce the BKK thesis analysis using Polars")
    parser.add_argument("command", choices=("run", "check", "figures"), nargs="?", default="run")
    parser.add_argument("--data-dir", type=Path, default=Path("data/raw"))
    parser.add_argument("--output-dir", type=Path, default=Path("output"))
    parser.add_argument("--reference-dir", type=Path, default=Path("reference/tables"))
    parser.add_argument("--figures", action="store_true", help="Also render all thesis figures")
    args = parser.parse_args()
    results = run_analysis(args.data_dir)
    if args.command == "check":
        check_reference(results, args.reference_dir)
        print("All five exported thesis tables exactly match reference artifacts.")
    if args.command in ("run", "check"):
        export_tables(results, args.output_dir / "tables")
        print(f"Exported tables to {args.output_dir / 'tables'} ({results.panel.height:,} panel rows).")
    if args.command == "figures" or args.figures:
        from .figures import export_figures
        export_figures(results, args.data_dir, args.output_dir / "figures")
        print(f"Exported seven figures to {args.output_dir / 'figures'}.")
