"""Report embedding must preserve data and never close its JSON script element."""
import json
import unittest
from match_report import html_report, summarize


class MatchReportTests(unittest.TestCase):
    def test_script_content_is_safe_and_round_trips(self):
        report = {"runs": [{"error": '</script><script>alert("x")</script>& café'}], "summary": {}}
        page = html_report(report)
        payload = page.split('<script id="payload" type="application/json">')[1].split('</script>')[0]
        self.assertNotIn('<', payload)
        self.assertEqual(json.loads(payload), report)

    def test_completed_duration_excludes_timeouts(self):
        result = summarize([{"scenario": "integrated", "outcome": "win", "duration": 750,
                             "metrics": {"heavy_hits": 4, "wood_remaining": 100}},
                            {"scenario": "integrated", "outcome": "timeout", "duration": 1800}])["integrated"]
        self.assertEqual(result["median_completed_duration"], 750)
        self.assertEqual(result["completed_in_target"], 1)
        self.assertEqual(result["median_heavy_hits"], 4)

    def test_pairs_match_difficulty(self):
        runs = [{"scenario": "baseline_easy", "seed": 42, "outcome": "win", "duration": 10,
                 "effective_config": {"rules": {"difficulty": "easy"}}},
                {"scenario": "baseline", "seed": 42, "outcome": "win", "duration": 20},
                {"scenario": "integrated_easy", "seed": 42, "outcome": "win", "duration": 13,
                 "effective_config": {"rules": {"difficulty": "easy"}}}]
        result = summarize(runs)["integrated_easy"]
        self.assertEqual(result["paired_runs"], 1)
        self.assertEqual(result["median_paired_duration_delta"], 3)

    def test_failure_and_timeout_comparison(self):
        runs = [
            {"scenario": "baseline", "seed": 42, "outcome": "technical_failure"},
            {"scenario": "baseline", "seed": 43, "outcome": "timeout", "duration": 5, "first_king_damage": -1},
        ]
        result = summarize(runs)["baseline"]
        self.assertEqual(result["technical_failures"], 1)
        self.assertEqual(result["timeouts"], 1)
        self.assertEqual(result["wins"], 0)
        self.assertEqual(result["median_duration"], 5)


if __name__ == '__main__':
    unittest.main()
