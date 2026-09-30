#!/usr/bin/env python3
"""Check actual match capture consistency: python3 tests/validate_replay.py report.json."""
import json
import math
import sys
from collections import Counter
from pathlib import Path


def validate(run):
    assert run['outcome'] in ('win', 'timeout'), run.get('error')
    assert run['replay_version'] == 2
    geometry = run['map']
    assert geometry['size'] == [4600, 2600]
    assert len(geometry['lanes']) == 3 and len(geometry['pads']) == 9
    assert geometry['obstacles'] and geometry['trees']
    frames = run['timeline']
    assert frames[0]['t'] == 0
    assert math.isclose(frames[-1]['t'], run['duration'], abs_tol=1e-6)
    identities = {}
    for i, frame in enumerate(frames):
        if i:
            delta = frame['t'] - frames[i - 1]['t']
            assert 0 <= delta <= 1.05, delta
        ids = [entity[5] for entity in frame['entities']]
        assert len(ids) == len(set(ids)), 'duplicate entity ID in frame'
        for entity in frame['entities']:
            assert len(entity) == 9
            identity = (entity[0], entity[1], entity[7])
            assert identities.setdefault(entity[5], identity) == identity, 'ID changed role or team'
            assert entity[6] > 0 and 0 <= entity[4] <= entity[6]
        for team in frame['teams']:
            composition = Counter(e[1] for e in frame['entities'] if e[0] == team['id'])
            assert team['army'] == sum(composition[k] for k in ('melee', 'ranged', 'tank'))
            assert team['workers'] == composition['worker']
            assert team['towers'] == composition['tower']
    times = [event['t'] for event in run['events']]
    assert times == sorted(times)
    assert all(0 <= t <= run['duration'] + 0.051 for t in times)  # older rounded event times
    for team in (1, 2):
        events = [e for e in run['events'] if e['team'] == team]
        assert run['towers_built'][str(team)] == sum(e['type'] == 'tower_built' for e in events)
        assert run['deaths'][str(team)] == sum(e['type'] == 'death' for e in events)
    if run['outcome'] == 'win':
        assert run['events'][-1]['type'] == 'match_end'
        assert run['events'][-1]['team'] == run['winning_team_id']
        losing = next(t for t in frames[-1]['teams'] if t['id'] != run['winning_team_id'])
        assert losing['king_health'] == 0
    print(f"seed {run['seed']}: {run['outcome']}, {run['duration']:.1f}s, {len(frames)} snapshots validated")


if __name__ == '__main__':
    report = json.loads(Path(sys.argv[1]).read_text())
    for match in report['matches']:
        validate(match)
