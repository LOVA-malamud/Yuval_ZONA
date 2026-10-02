#!/usr/bin/env python3
"""Stage production source and export a signed, installable Android debug APK."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import json

ROOT = Path(__file__).resolve().parents[1]


def run_logged(command, env, log_path, timeout=180):
    """Keep diagnostics from interrupted/failed exports and bound editor setup."""
    with log_path.open('w') as log:
        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                timeout=timeout, check=False)
    if result.returncode:
        raise RuntimeError('Export step failed; see ' + str(log_path))


def stage_production(stage, template):
    stage.mkdir(parents=True, exist_ok=True)
    for name in ('assets', 'localization', 'resources', 'scenes', 'scripts'):
        shutil.copytree(ROOT / name, stage / name)
    config = (ROOT / 'project.godot').read_text()
    config = re.sub(r'^McpRuntimeAutoload=.*\n', '', config, flags=re.M)
    config = re.sub(r'\[editor_plugins\]\s*enabled=.*?\n', '', config)
    config = config.replace('[rendering]\n', '[rendering]\ntextures/vram_compression/import_etc2_astc=true\n')
    (stage / 'project.godot').write_text(config)
    preset = (ROOT / 'export_presets.cfg').read_text()
    head, separator, android = preset.partition('[preset.1.options]')
    if not separator:
        raise RuntimeError('Android export preset is missing')
    android = android.replace('custom_template/debug=""', 'custom_template/debug=' + json.dumps(template.resolve().as_posix()))
    (stage / 'export_presets.cfg').write_text(head + separator + android)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True)
    parser.add_argument('--template', type=Path, required=True, help='Matching official android_debug.apk')
    parser.add_argument('--sdk', type=Path, default=Path.home() / 'Library/Android/sdk')
    parser.add_argument('--java', type=Path, help='JDK home; defaults to JAVA_HOME or java_home on macOS')
    parser.add_argument('--output', type=Path, default=ROOT / 'builds/Crownfront-debug.apk')
    args = parser.parse_args()
    if not args.template.is_file() or not (args.sdk / 'platform-tools/adb').is_file():
        parser.error('Provide the matching Android template and an Android SDK with platform-tools')
    java = args.java or Path(os.environ.get('JAVA_HOME') or subprocess.check_output(['/usr/libexec/java_home'], text=True).strip())
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    keystore = output.parent / 'android-debug.keystore'
    if not keystore.exists():
        subprocess.run([str(java / 'bin/keytool'), '-genkeypair', '-keystore', str(keystore), '-storepass', 'android', '-alias', 'androiddebugkey', '-keypass', 'android', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000', '-dname', 'CN=Android Debug,O=Crownfront,C=US'], check=True)
    env = os.environ.copy()
    env.update(GODOT_ANDROID_KEYSTORE_DEBUG_PATH=str(keystore), GODOT_ANDROID_KEYSTORE_DEBUG_USER='androiddebugkey', GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD='android')
    with tempfile.TemporaryDirectory(prefix='crownfront-android-') as temporary:
        stage = Path(temporary)
        stage_production(stage, args.template)
        common = [args.engine, '--headless', '--path', str(stage)]
        run_logged([*common, '--editor', '--script', str(ROOT / 'tests/android_export_config.gd'), '--', str(args.sdk.resolve()), str(java.resolve())], env, output.parent / 'android-config.log', timeout=30)
        run_logged([*common, '--import'], env, output.parent / 'android-import.log')
        run_logged([*common, '--export-debug', 'Android', str(output)], env, output.parent / 'android-export.log')
    if not output.is_file():
        raise RuntimeError('Android export did not produce an APK')
    output.with_suffix('.sha256').write_text(hashlib.sha256(output.read_bytes()).hexdigest() + '  ' + output.name + '\n')
    tools = sorted((args.sdk / 'build-tools').iterdir(), key=lambda p: tuple(int(part) for part in p.name.split('.')))
    subprocess.run([str(tools[-1] / 'apksigner'), 'verify', str(output)], env={**env, 'JAVA_HOME': str(java)}, check=True)
    print('Verified debug APK:', output)
    print('Install:', args.sdk / 'platform-tools/adb', 'install -r', output)


if __name__ == '__main__':
    main()
