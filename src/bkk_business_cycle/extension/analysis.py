"""Pure port of R/extension_run.R, including all matched-sample diagnostics."""

from itertools import combinations

import numpy as np
import polars as pl

from .data import balanced_panel, quarter_number, quarter_text, window
from .domain import Config, Inputs, Method, Result, Table
from .statistics import bootstrap, mean_moments, pair_values

type Row = dict[str, str | int | float | None]


def analyze(inputs: Inputs, config: Config = Config()) -> Result:
    levels = balanced_panel(inputs.current)
    first, last = int(levels.quarters[0]) + 11, int(levels.quarters[-1])
    periods = (("full_common", first, last), ("pre_pandemic", first, quarter_number("2019-Q4")),
               ("thesis_overlap", first, quarter_number("2015-Q1")), ("post_thesis", quarter_number("2015-Q2"), last))
    rows: dict[Table, list[Row]] = {table: [] for table in Table}
    for period, start, end in periods:
        for method in Method:
            sample = window(levels, method, start, end)
            pairs = pair_values(sample)
            boot = bootstrap(sample, config)
            label: Row = {"period": period, "method": method.value}
            rows[Table.SUMMARY].append(label | {
                "start": quarter_text(start), "end": quarter_text(end), "quarters": len(sample.quarters),
                "countries": len(sample.countries), "pairs": len(pairs), "output_correlation": float(boot.point[0]),
                "consumption_correlation": float(boot.point[1]), "gap": float(boot.point[2]),
                "gap_lower": float(boot.lower[2]), "gap_upper": float(boot.upper[2]),
                "positive_pairs": int(np.sum(pairs[:, 2] > 0)), "median_gap": float(np.median(pairs[:, 2])),
                "block_length": 8, "repetitions": config.repetitions, "seed": config.seed,
            })
            for k, (country_i, country_j) in enumerate(combinations(sample.countries, 2)):
                rows[Table.PAIRS].append(label | {
                    "country_i": country_i, "country_j": country_j, "output_correlation": float(pairs[k, 0]),
                    "consumption_correlation": float(pairs[k, 1]), "gap": float(pairs[k, 2]),
                    "gap_lower": float(boot.lower[k + 3]), "gap_upper": float(boot.upper[k + 3]),
                })
            for length in (4, 8, 12):
                supported = len(sample.quarters) >= max(40, 4 * length)
                sensitivity = (boot if length == 8 else bootstrap(sample, config, length)) if supported else None
                rows[Table.BLOCK].append(label | {
                    "block_length": length, "quarters": len(sample.quarters), "gap": float(boot.point[2]),
                    "lower": float(sensitivity.lower[2]) if sensitivity is not None else None,
                    "upper": float(sensitivity.upper[2]) if sensitivity is not None else None,
                    "status": "estimated" if supported else "fewer_than_four_blocks",
                    "repetitions": config.repetitions if supported else 0,
                })

    for method in Method:
        for end in range(first + 39, last + 1):
            moments = mean_moments(window(levels, method, end - 39, end))
            rows[Table.ROLLING].append({
                "method": method.value, "start": quarter_text(end - 39), "end": quarter_text(end), "quarters": 40,
                "output_correlation": float(moments[0]), "consumption_correlation": float(moments[1]), "gap": float(moments[2]),
            })
        for end in (quarter_number("2015-Q1"), quarter_number("2019-Q4"), last - 4):
            truncated = mean_moments(window(levels, method, first, end))
            full = mean_moments(window(levels, method, first, end, context_end=last))
            rows[Table.CONTEXT].append({
                "method": method.value, "start": quarter_text(first), "end": quarter_text(end),
                "truncated_gap": float(truncated[2]), "full_context_gap": float(full[2]), "difference": float(full[2] - truncated[2]),
            })
        full_sample = window(levels, method, first, last)
        contiguous = {"between_crises": (quarter_number("2010-Q1"), quarter_number("2019-Q4")),
                      "after_2021": (quarter_number("2022-Q1"), last)}
        exclusions = {"excluding_2008_2009": (2008, 2009), "excluding_2020_2021": (2020, 2021),
                      "excluding_both": (2008, 2009, 2020, 2021)}
        for name in (*contiguous, *exclusions):
            if name in contiguous:
                start, end = contiguous[name]
                sample = window(levels, method, start, end)
                context_end = end
            else:
                sample = full_sample.take(~np.isin(full_sample.quarters // 4, exclusions[name]))
                context_end = last
            moments = mean_moments(sample)
            rows[Table.EPISODES].append({
                "method": method.value, "diagnostic": name, "quarters": len(sample.quarters),
                "filter_context_end": quarter_text(context_end), "output_correlation": float(moments[0]),
                "consumption_correlation": float(moments[1]), "gap": float(moments[2]), "inference": "descriptive_only",
            })
        for year in range(1999, 2026):
            sample = full_sample.take(full_sample.quarters // 4 != year)
            moments = mean_moments(sample)
            rows[Table.YEAR].append({
                "method": method.value, "omitted_year": year, "quarters": len(sample.quarters),
                "gap": float(moments[2]), "change_from_full": float(moments[2] - mean_moments(full_sample)[2]),
            })

    old_levels = balanced_panel(inputs.original)
    overlap_start = max(int(old_levels.quarters[0]), int(levels.quarters[0]))
    overlap_end = min(int(old_levels.quarters[-1]), int(levels.quarters[-1]))
    old = balanced_panel(inputs.original, overlap_start, overlap_end)
    new = balanced_panel(inputs.current, overlap_start, overlap_end)
    for method in Method:
        old_sample = window(old, method, overlap_start + 11, overlap_end)
        new_sample = window(new, method, overlap_start + 11, overlap_end)
        difference = bootstrap(new_sample, config, other=old_sample)
        rows[Table.VINTAGE].append({
            "method": method.value, "start": quarter_text(overlap_start + 11), "end": quarter_text(overlap_end),
            "quarters": len(old_sample.quarters), "original_gap": float(mean_moments(old_sample)[2]),
            "current_gap": float(mean_moments(new_sample)[2]), "difference": float(difference.point[2]),
            "difference_lower": float(difference.lower[2]), "difference_upper": float(difference.upper[2]),
            "block_length": 8, "repetitions": config.repetitions,
        })
    for variable, old_matrix, new_matrix in (("gdp", old.output, new.output), ("consumption", old.consumption, new.consumption)):
        for j, country in enumerate(levels.countries):
            old_growth, new_growth = np.diff(old_matrix[:, j]) * 100, np.diff(new_matrix[:, j]) * 100
            rows[Table.VINTAGE_SERIES].append({
                "location": country, "variable": variable, "start": quarter_text(overlap_start + 1),
                "end": quarter_text(overlap_end), "quarters": len(old_growth),
                "growth_correlation": float(np.corrcoef(old_growth, new_growth)[0, 1]),
                "rms_growth_difference_pp": float(np.sqrt(np.mean((new_growth - old_growth) ** 2))),
                "max_abs_growth_difference_pp": float(np.max(np.abs(new_growth - old_growth))),
            })
    return Result({table: pl.DataFrame(records) for table, records in rows.items()}, config, int(levels.quarters[0]), first, last)
