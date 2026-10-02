#!/usr/bin/env python3
"""Sequential three-run headless capacity comparison, including projectiles."""
import argparse
import io
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
from statistics import median
import tarfile
import tempfile
import time

from verify import diagnostics

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', default='707a51a')
    parser.add_argument('--godot', default=shutil.which('godot'))
    parser.add_argument('--output', type=Path, default=ROOT / 'tests/artifacts/performance_overhaul')
    parser.add_argument('--wait-for-idle', action='store_true', help='Wait for other Godot instances to exit before measuring')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    def godot_running():
        for path in Path('/proc').iterdir():
            if path.name.isdigit():
                try:
                    if (path / 'comm').read_text().strip() == 'godot':
                        return True
                except OSError:
                    pass
        return False
    if args.wait_for_idle:
        deadline = time.monotonic() + 18000
        while True:
            if time.monotonic() > deadline:
                raise RuntimeError('Other Godot instances did not finish within five hours')
            if not godot_running():
                time.sleep(10)
                if not godot_running():
                    break
            time.sleep(10)
        print('No other Godot instances; starting sequential capacity comparison', flush=True)
    elif godot_running():
        raise RuntimeError('Close other Godot instances or use --wait-for-idle')
    reports = []
    for version in ('baseline', 'current'):
        with tempfile.TemporaryDirectory(prefix='crownfront-performance-') as temporary:
            stage = Path(temporary) / 'project'
            if version == 'baseline':
                stage.mkdir()
                archive = subprocess.check_output(['git', 'archive', args.baseline], cwd=ROOT)
                with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
                    bundle.extractall(stage, filter='data')
                fixture = stage / 'tests/performance_probe.gd'
                source = fixture.read_text()
                source = source.replace('\t\tvar after_units := Time.get_ticks_usec()',
                    '\t\tfor projectile in get_nodes_in_group("projectiles"):\n'
                    '\t\t\tif not projectile.is_queued_for_deletion():\n'
                    '\t\t\t\tprojectile._physics_process(STEP)\n'
                    '\t\tvar after_units := Time.get_ticks_usec()')
                fixture.write_text(source)
            else:
                shutil.copytree(ROOT, stage, ignore=shutil.ignore_patterns('.git', '.godot', '.aws', '.codex', 'artifacts', 'builds', '__pycache__'))
            (stage / 'tests/artifacts').mkdir(exist_ok=True)
            env = os.environ.copy()
            for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
                env[key] = str(Path(temporary) / key.lower())
            def run(label, arguments):
                result = subprocess.run([args.godot, '--headless', '--path', str(stage), *arguments],
                    cwd=stage, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
                (args.output / f'{label}.log').write_text(result.stdout)
                if result.returncode or diagnostics(result.stdout, label):
                    raise RuntimeError(f'{label} failed; see its log')
                return result.stdout
            run(f'{version}_import', ['--editor', '--import', '--quit'])
            for index in range(3):
                label = f'{version}_{index+1}'
                log = run(label, ['--script', 'tests/performance_probe.gd', '--', 'headless', '1280x720', label, '15'])
                report = json.loads(next(line.removeprefix('PERFORMANCE REPORT ') for line in log.splitlines() if line.startswith('PERFORMANCE REPORT ')))
                reports.append(report)
                print(f'{label}: p95={report["metrics"]["total_script_ms"]["p95"]:.3f}ms', flush=True)
    summary = {}
    for metric in ('p50', 'p95', 'max'):
        baseline = median(r['metrics']['total_script_ms'][metric] for r in reports if r['label'].startswith('baseline'))
        current = median(r['metrics']['total_script_ms'][metric] for r in reports if r['label'].startswith('current'))
        summary[metric] = dict(baseline_ms=baseline, current_ms=current, change_percent=(current / baseline - 1) * 100)
    payload = dict(hardware=platform.uname()._asdict(), baseline=args.baseline, runs=reports, summary=summary,
                   baseline_correction='Added missing projectile physics update; otherwise original fixture.',
                   needs_investigation=summary['p95']['change_percent'] > 10)
    (args.output / 'comparison.json').write_text(json.dumps(payload, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
