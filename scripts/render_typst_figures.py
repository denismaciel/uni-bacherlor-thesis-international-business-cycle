"""Render Typst assets with the shared thesis and extension figure style."""

from pathlib import Path
from shutil import copyfile
from tempfile import TemporaryDirectory

from bkk_business_cycle.analysis import analyze
from bkk_business_cycle.figure_data import build_figure_data
from bkk_business_cycle.figures import export_figures
from bkk_business_cycle.inputs import InvalidInputs, load_inputs

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "paper/typst/assets"


def main() -> None:
    inputs = load_inputs(ROOT / "data/raw")
    if isinstance(inputs, InvalidInputs):
        raise ValueError(inputs)
    data = build_figure_data(analyze(inputs), inputs)
    OUT.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory() as directory:
        export_figures(data, Path(directory))
        for source in Path(directory).glob("*.svg"):
            copyfile(source, OUT / source.name)


if __name__ == "__main__":
    main()
