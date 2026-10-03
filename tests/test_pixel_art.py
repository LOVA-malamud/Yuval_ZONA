"""Check the baked art/runtime interface without requiring Pillow or Godot."""
import json
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/pixel_art'


class PixelArtTests(unittest.TestCase):
    def setUp(self):
        self.meta = json.loads((ART / 'atlas.json').read_text())

    def test_runtime_pose_order_matches_baked_atlas(self):
        source = (ROOT / 'scripts/visuals/character_visual.gd').read_text()
        declaration = re.search(r'const ACTIONS:.*?= \[(.*?)\]', source).group(1)
        self.assertEqual(re.findall(r'&"([^"]+)"', declaration), self.meta['actions'])
        self.assertEqual(self.meta['directions'], ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE'])
        self.assertEqual(self.meta['anchor'], [16, 31])
        self.assertEqual(self.meta['pixel_scale'], 2)

    def test_all_roles_and_teams_have_transparent_aligned_layers(self):
        w, h = self.meta['cell']
        columns = len(self.meta['directions']) * self.meta['frames']
        for role in self.meta['roles']:
            for team in self.meta['teams']:
                for part, rows in [('body', len(self.meta['actions'])), ('legs', 3)]:
                    path = ART / f'{role}-{team}-{part}.png'
                    with self.subTest(asset=path.name):
                        raw = path.read_bytes()
                        self.assertEqual(raw[:8], b'\x89PNG\r\n\x1a\n')
                        width, height, bits, color_type = struct.unpack('>IIBB', raw[16:26])
                        self.assertEqual((width, height), (w * columns, h * rows))
                        self.assertEqual((bits, color_type), (8, 6), 'Sprites need RGBA transparency')
                        self.assertLessEqual(width, 2048, 'Keep mobile atlas width modest')


if __name__ == '__main__':
    unittest.main()
