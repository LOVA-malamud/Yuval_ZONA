"""Project skills must not reference files, flags or fixtures that no longer exist."""
import unittest
from check_skills import check_all


class SkillTests(unittest.TestCase):
    def test_skills_match_the_project(self):
        self.assertEqual(check_all(), [])


if __name__ == '__main__':
    unittest.main()
