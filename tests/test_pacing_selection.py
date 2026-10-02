import copy
import unittest
from select_pacing import select


def runs():
    rows = []
    for index in range(8):
        config = {"shared": {"rules": {"rally_wait_seconds": 3 if index & 1 else 6,
                                     "army_speed_multiplier": 1.15 if index & 2 else 1},
                              "balance": {"tower_health": 432 if index & 4 else 480}}}
        for seed in range(42, 62):
            rows.append(dict(scenario="baseline" if index == 0 else f"candidate{index}",
                             seed=seed, outcome="win", duration=1200 if index == 0 else 900,
                             effective_config={"requested": config}))
    return rows


class SelectionTests(unittest.TestCase):
    def test_minimal_change_wins(self):
        result = select(runs())
        self.assertTrue(result["target_met"])
        self.assertEqual(result["selected"]["changes"], 1)

    def test_eligible_baseline_is_retained(self):
        rows = runs()
        for row in rows[:20]:
            row["duration"] = 1000
        self.assertEqual(select(rows)["selected"]["scenario"], "baseline")

    def test_missing_seed_and_failure_rejected(self):
        rows = runs()
        with self.assertRaises(ValueError):
            select(rows[:-1])
        failed = copy.deepcopy(rows)
        failed[0]["outcome"] = "technical_failure"
        with self.assertRaises(ValueError):
            select(failed)

    def test_unmet_target_reported(self):
        rows = runs()
        for row in rows:
            row["duration"] = 1400
        result = select(rows)
        self.assertFalse(result["target_met"])
        self.assertEqual(result["selected"]["scenario"], "baseline")
