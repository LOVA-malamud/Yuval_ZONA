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
