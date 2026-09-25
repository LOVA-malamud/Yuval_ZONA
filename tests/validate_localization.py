"""Validate native text Translation catalogs without requiring a Godot import."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRY = re.compile(r'^\[&"", &"([A-Z_]+)"\]: \[&("(?:[^"\\]|\\.)*")\]', re.M)
CATALOGS = {locale: {key: json.loads(value) for key, value in ENTRY.findall((ROOT / f'localization/{locale}.tres').read_text())} for locale in ('en', 'ru')}
assert CATALOGS['en'].keys() == CATALOGS['ru'].keys(), 'Catalog key mismatch'
assert len(CATALOGS['en']) >= 100, 'Missing catalog content'
for key, english in CATALOGS['en'].items():
    russian = CATALOGS['ru'][key]
    assert english and russian, key
    assert re.findall(r'%[-+0-9.]*[sdf]', english) == re.findall(r'%[-+0-9.]*[sdf]', russian), key
prefixes = ('HUD_', 'PAUSE_', 'ROLE_', 'TEAM_', 'COMMANDER_', 'STATUS_', 'LANE_', 'MAP_', 'PAD_', 'UNIT_', 'UPGRADE_', 'STAT_', 'LANGUAGE_')
for base in ('scripts', 'resources'):
    for path in (ROOT / base).rglob('*'):
        if path.suffix not in ('.gd', '.tres'):
            continue
        text = path.read_text()
        references = re.findall(r'\b(?:tr|notify|_label|_button)\("([A-Z][A-Z_]+)"', text)
        references += [value for value in re.findall(r'"([A-Z][A-Z_]+)"', text) if value.startswith(prefixes) and not value.endswith('_')]
        for key in references:
            if key.endswith("_"):
                continue  # Dynamic UNIT_ + kind keys are covered by the game smoke test.
            assert key in CATALOGS['en'], (path.relative_to(ROOT), key)
print(f'PASS: {len(CATALOGS["en"])} bilingual keys, placeholder parity, and literal presentation-key references.')
