#!/usr/bin/env python3
"""Capture the native animation lab, battlefield zoom limits and real worker activity."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from verify import diagnostics, project_digest

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot'))
    parser.add_argument('--output', type=Path, default=ROOT / 'tests/artifacts/pixel_visuals')
    args = parser.parse_args()
    if not args.godot:
        parser.error('Godot unavailable')
    args.output.mkdir(parents=True, exist_ok=True)
    checks = []
    with tempfile.TemporaryDirectory(prefix='crownfront-pixel-review-') as temporary:
        stage = Path(temporary) / 'project'
        shutil.copytree(ROOT, stage, ignore=shutil.ignore_patterns(
            '.git', '.godot', '.aws', '.codex', 'artifacts', 'builds', '__pycache__'))
        (stage / 'tests/artifacts').mkdir(exist_ok=True)
        source_digest = project_digest(stage)
        env = os.environ.copy()
        for key in ('XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME'):
            env[key] = str(Path(temporary) / key.lower())

        def run(name, arguments, headless=False):
            result = subprocess.run([args.godot, *(['--headless'] if headless else []),
                '--path', str(stage), *arguments], env=env, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
            (args.output / (name+'.log')).write_text(result.stdout)
            passed = result.returncode==0 and not diagnostics(result.stdout,name)
            checks.append(dict(name=name,passed=passed,exit_code=result.returncode))
            print(('PASS ' if passed else 'FAIL ')+name,flush=True)
            for picture in (stage/'tests/artifacts').glob('*.png'):
                shutil.copy2(picture,args.output/picture.name)
            if not passed:
                raise RuntimeError('Capture failed: '+name+'; see its log')
        run('import',['--editor','--import','--quit'],True)
        run('animation_preview',['--script','tests/pixel_art_preview.gd','--','--capture'])
        for size in ['1280x720','1600x720']:
            for zoom in ['0.7','0.9','1.1']:
                run('battle_'+size+'_'+zoom,['--script','tests/visual_review.gd','--','battle',size,'en',zoom])
        run('workers',['--script','tests/visual_review.gd','--','workers','1600x720','en','1.1'])
        for locale in ['en','ru']:
            run('small_mobile_'+locale,['--script','tests/visual_review.gd','--','battle','960x540',locale])
        for picture in (stage/'tests/artifacts').glob('*.png'):
            shutil.copy2(picture,args.output/picture.name)
    (args.output/'summary.json').write_text(json.dumps(dict(source_digest=source_digest,checks=checks,passed=all(c['passed'] for c in checks)),indent=2)+'\n')


if __name__=='__main__':
    main()
