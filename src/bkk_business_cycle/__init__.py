"""Python/Polars reproduction of the BKK international business cycle thesis."""

from .analysis import AnalysisResult, analyze
from .application import run_analysis
from .inputs import InvalidInputs, load_inputs
from .domain import ValidatedInputs, THESIS_2015, TableId, Variable

__all__ = [
    "AnalysisResult",
    "analyze",
    "run_analysis",
    "load_inputs",
    "InvalidInputs",
    "ValidatedInputs",
    "THESIS_2015",
    "TableId",
    "Variable",
]
