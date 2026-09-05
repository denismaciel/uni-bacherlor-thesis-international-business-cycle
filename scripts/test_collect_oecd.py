"""Scientific data-contract checks; no network calls."""

import unittest

from collect_oecd import COUNTRIES, DIMENSIONS, VARIABLES, coverage, normalize, quarter_index


def observation(country="USA", period="2026-Q1", sector="S1", transaction="B1GQ", price="L"):
    activity = "_T" if transaction == "P51G" else "_Z"
    expenditure = "_T" if transaction == "P3" else "_Z"
    values = ("Q", "Y", country, sector, "S1", transaction, "_Z", activity, expenditure, "XDC", price, "N", "T0102")
    return dict(zip(DIMENSIONS, values)) | {
        "TIME_PERIOD": period, "OBS_VALUE": "123.456789", "UNIT_MULT": "6",
        "CURRENCY": "USD", "REF_YEAR_PRICE": "2017" if price == "L" else "",
        "OBS_STATUS": "P", "CONF_STATUS": "F",
    }


def complete_panel():
    return normalize([
        observation(country=country, sector=sector, transaction=transaction, price=price)
        for country in COUNTRIES for sector, transaction, price in VARIABLES
    ])


class CollectionTests(unittest.TestCase):
    def test_input_order_does_not_change_panel(self):
        rows = [observation(period="2026-Q2"), observation(period="2026-Q1")]
        self.assertEqual(normalize(rows), normalize(rows[::-1]))

    def test_preserves_precision_and_status(self):
        row = normalize([observation()])[0]
        self.assertEqual(row["value"], "123.456789")
        self.assertEqual(row["obs_status"], "P")

    def test_consumption_is_households_plus_npish_not_total(self):
        rows = [observation(sector="S1", transaction="P3"), observation(sector="S1M", transaction="P3")]
        self.assertEqual([r["variable"] for r in normalize(rows)], ["consumption"])

    def test_duplicate_observations_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            normalize([observation(), observation()])

    def test_growth_rates_rejected(self):
        with self.assertRaisesRegex(ValueError, "TRANSFORMATION"):
            normalize([observation() | {"TRANSFORMATION": "G1"}])

    def test_nonpositive_and_nonfinite_levels_rejected(self):
        for value in ("0", "-1", "nan", "inf", ""):
            with self.subTest(value=value), self.assertRaises(ValueError):
                normalize([observation() | {"OBS_VALUE": value}])

    def test_missing_country_series_rejected(self):
        with self.assertRaisesRegex(ValueError, "Missing/unexpected"):
            coverage(complete_panel()[:-1])

    def test_internal_gap_reported_not_filled(self):
        panel = complete_panel() + normalize([observation(period="2026-Q3")])
        row = next(r for r in coverage(panel) if (r["location"], r["variable"]) == ("USA", "gdp"))
        self.assertEqual(row["missing_quarters"], "2026-Q2")
        self.assertEqual(row["observations"], 2)

    def test_unit_changes_rejected(self):
        panel = complete_panel() + normalize([observation(period="2026-Q2") | {"UNIT_MULT": "3"}])
        with self.assertRaisesRegex(ValueError, "Measurement changes"):
            coverage(panel)

    def test_quarters_validate_and_cross_year_boundary(self):
        self.assertEqual(quarter_index("2026-Q1") - quarter_index("2025-Q4"), 1)
        with self.assertRaises(ValueError):
            quarter_index("2026-Q5")


if __name__ == "__main__":
    unittest.main()
