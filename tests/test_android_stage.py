"""Production staging can be verified without launching Godot."""
import tempfile
from pathlib import Path
import unittest
from build_android import stage_production


class AndroidStageTests(unittest.TestCase):
    def test_production_stage_excludes_development_and_keeps_desktop_template(self):
        with tempfile.TemporaryDirectory() as directory:
            stage = Path(directory) / 'production'
            template = Path(directory) / 'android debug.apk'
            stage_production(stage, template)
            self.assertEqual({p.name for p in stage.iterdir()},
                             {'assets', 'localization', 'resources', 'scenes', 'scripts', 'project.godot', 'export_presets.cfg'})
            config = (stage / 'project.godot').read_text()
            self.assertNotIn('McpRuntime', config)
            self.assertNotIn('addons/', config)
            preset = (stage / 'export_presets.cfg').read_text()
            desktop, android = preset.split('[preset.1.options]')
            self.assertIn('custom_template/debug=""', desktop)
            self.assertIn(template.resolve().as_posix(), android)
            self.assertIn('permissions/internet=false', android)


if __name__ == '__main__':
    unittest.main()
