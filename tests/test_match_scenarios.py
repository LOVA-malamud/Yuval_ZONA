"""Fast checks for scenario boundaries and diagnostic aggregation."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).parent))
from match_scenarios import load, swapped, validate
from match_report import summarize, html_report


class MatchScenarioTests(unittest.TestCase):
    def test_shared_asymmetric_and_sweep(self):
        shared = {"shared": {"team": {"money": 300}, "base_stats": {"worker_health": 80}, "units": {"melee": {"damage": 20}}, "upgrades": {"income": {"amount": 3}}, "balance": {"tower_health": 600}}}
        validate(shared)
        asymmetric = {"teams": {"1": {"money": 100}, "2": {"money": 400}}}
        self.assertEqual(swapped(asymmetric)["teams"]["1"]["money"], 400)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenarios.json"
            path.write_text(json.dumps({"version": 1, "scenarios": {"base": {}}, "sweeps": {"income": {"base": "base", "path": "shared.base_stats.income", "values": [10, 12]}}}))
            self.assertEqual(len(load(path)), 3)

    def test_invalid_fields_and_values(self):
        for config in ({"shared": {"mystery": 2}}, {"teams": {"3": {}}}, {"shared": {"team": {"workers": 11}}}, {"shared": {"base_stats": {"worker_health": 0}}}, {"shared": {"balance": {"tower_health": float("nan")}}}):
            with self.subTest(config=config), self.assertRaises(ValueError):
                validate(config)

    def test_rework_fields(self):
        validate({"shared": {"balance": {"heavy_stun": 0.5, "guard_damage_reduction": 0.7},
                              "deployment": {"window_size": 30, "tolerance": 0},
                              "towers": {"long_range": {"minimum_range": 100, "splash_radius": 0, "wood_cost": 100}},
                              "groves": [{"center": [450, 900], "count": 8, "wood": 100, "zone": "home"}]}})
        for shared in ({"deployment": {"window_size": 0}}, {"deployment": {"tolerance": 1.5}},
                       {"balance": {"guard_damage_reduction": 1.1}}, {"towers": {"unknown": {}}},
                       {"groves": [{"center": [2400, 900], "count": 8, "wood": 100, "zone": "home"}]}):
            with self.subTest(shared=shared), self.assertRaises(ValueError):
                validate({"shared": shared})
        self.assertEqual(len(load(Path(__file__).parent / "scenarios/integrated_rework.json")), 3)

    def test_timeout_failure_and_html(self):
        runs = [{"scenario": "a", "outcome": "timeout", "duration": 10, "first_king_damage": -1, "candidate_team": 1}, {"scenario": "a", "outcome": "technical_failure", "candidate_team": 1}]
        summary = summarize(runs)["a"]
        self.assertEqual((summary["timeouts"], summary["technical_failures"]), (1, 1))
        self.assertIn('id="payload"', html_report({"runs": runs, "summary": {"a": summary}}))


if __name__ == "__main__":
    unittest.main()
