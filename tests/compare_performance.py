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
    parser.add_argument('--baseline', default='7179af9')
    parser.add_argument('--baseline-dir', type=Path, help='Use a preserved baseline project instead of git archive')
    parser.add_argument('--godot', default=shutil.which('godot'))
    parser.add_argument('--output', type=Path, default=ROOT / 'tests/artifacts/performance_overhaul')
    parser.add_argument('--wait-for-idle', action='store_true', help='Wait for other Godot instances to exit before measuring')
    parser.add_argument('--mode', choices=('headless', 'rendered'), default='headless')
    args = parser.parse_args()
    if not args.godot:
        parser.error('Godot unavailable; supply --godot')
    if args.baseline_dir and not (args.baseline_dir / 'project.godot').is_file():
        parser.error('--baseline-dir must contain project.godot')
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
                if args.baseline_dir:
                    shutil.copytree(args.baseline_dir, stage, ignore=shutil.ignore_patterns('.git', '.godot', '.aws', '.codex', 'artifacts', 'builds', '__pycache__'))
                else:
                    stage.mkdir()
                    archive = subprocess.check_output(['git', 'archive', args.baseline], cwd=ROOT)
                    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
                        if hasattr(tarfile, 'data_filter'):
                            bundle.extractall(stage, filter='data')
                        else:
                            # Git archive of a local revision contains repository paths.
                            bundle.extractall(stage)
                fixture = stage / 'tests/performance_probe.gd'
                source = fixture.read_text()
                if 'game.session.step()' not in source:
                    source = source.replace('\t\tvar after_units := Time.get_ticks_usec()',
                        '\t\tfor projectile in get_nodes_in_group("projectiles"):\n'
                        '\t\t\tif not projectile.is_queued_for_deletion():\n'
                        '\t\t\t\tprojectile._physics_process(STEP)\n'
                        '\t\tvar after_units := Time.get_ticks_usec()')
                source = source.replace('"p95": values[', '"p50": values[int(values.size() * 0.5)], "p95": values[')
                source = source.replace('\troot.add_child(game)\n\tcurrent_scene = game',
                    '\tvar capture_viewport: Viewport = root\n'
                    '\tif mode != "headless":\n'
                    '\t\tvar surface := SubViewport.new()\n'
                    '\t\tsurface.size = Vector2i(int(size_parts[0]), int(size_parts[1]))\n'
                    '\t\tsurface.render_target_update_mode = SubViewport.UPDATE_ALWAYS\n'
                    '\t\troot.add_child(surface)\n'
                    '\t\tcapture_viewport = surface\n'
                    '\tcapture_viewport.add_child(game)\n'
                    '\tcurrent_scene = game if mode == "headless" else capture_viewport')
                source = source.replace('var picture := root.get_texture().get_image()', 'var picture := capture_viewport.get_texture().get_image()')
                source = source.replace('if picture.get_size() != root.size:', 'if picture.get_size() != Vector2i(int(size_parts[0]), int(size_parts[1])):')
                source = source.replace('\t_setup_capacity()\n', '\t_setup_capacity()\n\tgame.player.controller.set_scripted_command(Vector2.ZERO, false)\n')
                source = source.replace('\tif _total_damage_taken() <= 1000.0', '\tif mode != "headless" and capture_viewport.get_texture().get_image().get_size() != Vector2i(int(size_parts[0]), int(size_parts[1])):\n\t\tpush_error("Incorrect baseline rendered dimensions")\n\t\tquit(1)\n\t\treturn\n\tif _total_damage_taken() <= 1000.0')
                fixture.write_text(source)
            else:
                shutil.copytree(ROOT, stage, ignore=shutil.ignore_patterns('.git', '.godot', '.aws', '.codex', 'artifacts', 'builds', '__pycache__'))
            (stage / 'tests/artifacts').mkdir(exist_ok=True)
            env = os.environ.copy()
            for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
                env[key] = str(Path(temporary) / key.lower())
            def run(label, arguments):
                headless = args.mode == 'headless' or label.endswith('_import')
                result = subprocess.run([args.godot, *(['--headless'] if headless else []), '--path', str(stage), *arguments],
                    cwd=stage, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
                (args.output / f'{label}.log').write_text(result.stdout)
                if result.returncode or diagnostics(result.stdout, label):
                    raise RuntimeError(f'{label} failed; see its log')
                return result.stdout
            run(f'{version}_import', ['--editor', '--import', '--quit'])
            for index in range(3):
                label = f'{version}_{index+1}'
                log = run(label, ['--script', 'tests/performance_probe.gd', '--', args.mode, '1280x720', label, '15'])
                report = json.loads(next(line.removeprefix('PERFORMANCE REPORT ') for line in log.splitlines() if line.startswith('PERFORMANCE REPORT ')))
                reports.append(report)
                measurement = 'total_script_ms' if args.mode == 'headless' else 'frame_ms'
                print(f'{label}: {measurement} p95={report["metrics"][measurement]["p95"]:.3f}ms', flush=True)
                for artifact in (stage / 'tests/artifacts').glob(f'performance_{label}*'):
                    shutil.copy2(artifact, args.output / artifact.name)
    summary = {}
    for metric in ('p50', 'p95', 'max'):
        baseline = median(r['metrics'][measurement][metric] for r in reports if r['label'].startswith('baseline'))
        current = median(r['metrics'][measurement][metric] for r in reports if r['label'].startswith('current'))
        summary[metric] = dict(baseline_ms=baseline, current_ms=current, change_percent=(current / baseline - 1) * 100)
    payload = dict(hardware=platform.uname()._asdict(), baseline=args.baseline, mode=args.mode, runs=reports, summary=summary,
                   baseline_directory=str(args.baseline_dir.resolve()) if args.baseline_dir else None,
                   baseline_correction='Baseline fixture adapted for p50, exact-size rendering and idle input; projectile phase added only to pre-session baselines.',
                   needs_investigation=summary['p95']['change_percent'] > 10)
    (args.output / 'comparison.json').write_text(json.dumps(payload, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
